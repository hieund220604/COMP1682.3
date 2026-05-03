import { OriginalDebt } from '../models/OriginalDebt';
import mongoose from 'mongoose';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export interface DebtNode {
    userId: string;
    /** Positive = creditor (is owed money), Negative = debtor (owes money) */
    amount: number;
}

export interface SettlementTransfer {
    fromUserId: string;
    toUserId: string;
    amount: number;
}

export interface DebtAllocation {
    originalDebtId: string;
    amount: number;
}

export interface SettlementTransferWithAllocation extends SettlementTransfer {
    debtAllocations: DebtAllocation[];
}

/** Raw pairwise debt record from DB */
export interface RawDebt {
    debtorId: string;
    creditorId: string;
    remainingAmount: number;
}

// ─────────────────────────────────────────────
// Strategy 1: Greedy
// Match largest debtor ↔ largest creditor
// Ensure minimum number of transfers
// ─────────────────────────────────────────────

function greedySettle(nodes: DebtNode[]): SettlementTransfer[] {
    const debtors: { userId: string; amount: number }[] = [];
    const creditors: { userId: string; amount: number }[] = [];

    for (const node of nodes) {
        if (node.amount < -0.01) {
            debtors.push({ userId: node.userId, amount: Math.abs(node.amount) });
        } else if (node.amount > 0.01) {
            creditors.push({ userId: node.userId, amount: node.amount });
        }
    }

    // Sort descending by amount
    debtors.sort((a, b) => b.amount - a.amount);
    creditors.sort((a, b) => b.amount - a.amount);

    const transfers: SettlementTransfer[] = [];
    let di = 0, ci = 0;

    while (di < debtors.length && ci < creditors.length) {
        const debtor = debtors[di];
        const creditor = creditors[ci];
        const transferAmount = Math.min(debtor.amount, creditor.amount);

        if (transferAmount > 0.01) {
            transfers.push({
                fromUserId: debtor.userId,
                toUserId: creditor.userId,
                amount: Math.round(transferAmount * 100) / 100
            });
        }

        debtor.amount -= transferAmount;
        creditor.amount -= transferAmount;

        if (debtor.amount < 0.01) di++;
        if (creditor.amount < 0.01) ci++;
    }

    return transfers;
}

// ─────────────────────────────────────────────
// Strategy 2: MinCostFlow
// Prioritize net-off for direct 2-way debts.
// Example: A owes B 100k, B owes A 60k -> net-off so A owes B 40k.
// Remaining parts (no direct debts) fallback to Greedy.
// ─────────────────────────────────────────────

function minCostFlowSettle(
    nodes: DebtNode[],
    rawDebts: RawDebt[]
): SettlementTransfer[] {
    // Build a mutable pairwise net map from raw debts:
    // netMap[A][B] = how much A owes B (net, can be negative)
    const pairNet = new Map<string, Map<string, number>>();

    const getOrCreate = (map: Map<string, Map<string, number>>, key: string) => {
        if (!map.has(key)) map.set(key, new Map());
        return map.get(key)!;
    };

    for (const debt of rawDebts) {
        const row = getOrCreate(pairNet, debt.debtorId);
        const current = row.get(debt.creditorId) || 0;
        row.set(debt.creditorId, current + debt.remainingAmount);
    }

    // Netoff mutual debts: if A owes B and B owes A, cancel them out
    const processedPairs = new Set<string>();
    for (const [debtorId, creditorMap] of pairNet) {
        for (const [creditorId] of creditorMap) {
            const pairKey = [debtorId, creditorId].sort().join(':');
            if (processedPairs.has(pairKey)) continue;
            processedPairs.add(pairKey);

            const aOwesB = pairNet.get(debtorId)?.get(creditorId) || 0;
            const bOwesA = pairNet.get(creditorId)?.get(debtorId) || 0;

            if (aOwesB > 0.01 && bOwesA > 0.01) {
                // Netoff
                const net = aOwesB - bOwesA;
                getOrCreate(pairNet, debtorId).set(creditorId, Math.max(0, net));
                getOrCreate(pairNet, creditorId).set(debtorId, Math.max(0, -net));
            }
        }
    }

    // Build direct transfers from netted pairwise debts
    const directTransfers: SettlementTransfer[] = [];
    const remainingNodes = new Map<string, number>(
        nodes.map(n => [n.userId, n.amount])
    );

    for (const [debtorId, creditorMap] of pairNet) {
        for (const [creditorId, amount] of creditorMap) {
            if (amount > 0.01) {
                directTransfers.push({
                    fromUserId: debtorId,
                    toUserId: creditorId,
                    amount: Math.round(amount * 100) / 100
                });
                // Adjust remaining balances
                remainingNodes.set(debtorId, (remainingNodes.get(debtorId) || 0) + amount);
                remainingNodes.set(creditorId, (remainingNodes.get(creditorId) || 0) - amount);
            }
        }
    }

    // Fallback: settle remaining imbalances with Greedy
    const residualNodes: DebtNode[] = [];
    for (const [userId, balance] of remainingNodes) {
        if (Math.abs(balance) > 0.01) {
            residualNodes.push({ userId, amount: Math.round(balance * 100) / 100 });
        }
    }

    const residualTransfers = greedySettle(residualNodes);

    return [...directTransfers, ...residualTransfers];
}

// ─────────────────────────────────────────────
// Auto-detect: check mutual debts to select strategy
// ─────────────────────────────────────────────

function hasMutualDebts(rawDebts: RawDebt[]): boolean {
    // Build set of (debtor, creditor) pairs
    const pairs = new Set<string>();
    for (const debt of rawDebts) {
        pairs.add(`${debt.debtorId}:${debt.creditorId}`);
    }
    // Check if any reverse pair exists
    for (const debt of rawDebts) {
        if (pairs.has(`${debt.creditorId}:${debt.debtorId}`)) {
            return true;
        }
    }
    return false;
}

// ─────────────────────────────────────────────
// Debt Allocation (FIFO + Graph-based BFS)
// Direct debts first, then multi-hop via BFS
// ─────────────────────────────────────────────

/**
 * BFS to find a path from source to target through the debt graph.
 * Each edge represents an OriginalDebt with remaining capacity.
 */
function bfsFindPath(
    adjacency: Map<string, Array<{ toUserId: string; debtId: string; capacity: number }>>,
    source: string,
    target: string
): { path: Array<{ debtId: string }>; capacity: number } | null {
    const visited = new Set<string>([source]);
    const queue: Array<{
        userId: string;
        path: Array<{ debtId: string }>;
        capacity: number;
    }> = [{ userId: source, path: [], capacity: Infinity }];

    while (queue.length > 0) {
        const current = queue.shift()!;
        const edges = adjacency.get(current.userId) || [];

        for (const edge of edges) {
            if (visited.has(edge.toUserId) || edge.capacity <= 0.01) continue;

            const newPath = [...current.path, { debtId: edge.debtId }];
            const newCapacity = Math.min(current.capacity, edge.capacity);

            if (edge.toUserId === target) {
                return { path: newPath, capacity: newCapacity };
            }

            visited.add(edge.toUserId);
            queue.push({ userId: edge.toUserId, path: newPath, capacity: newCapacity });
        }
    }

    return null;
}

async function allocateDebtsForTransfer(
    groupId: string,
    debtorId: string,
    creditorId: string,
    amount: number
): Promise<DebtAllocation[]> {
    // ── Step 1: Direct allocation (fast path, FIFO) ──
    const directDebts = await OriginalDebt.find({
        groupId,
        debtorId,
        creditorId,
        remainingAmount: { $gt: 0.01 }
    }).sort({ createdAt: 1 });

    const allocations: DebtAllocation[] = [];
    let remaining = amount;

    for (const debt of directDebts) {
        if (remaining <= 0.01) break;
        const allocAmount = Math.min(remaining, debt.remainingAmount);
        allocations.push({
            originalDebtId: debt._id.toString(),
            amount: Math.round(allocAmount * 100) / 100
        });
        remaining -= allocAmount;
    }

    if (remaining <= 0.01) return allocations;

    // ── Step 2: Graph-based allocation (BFS / Edmonds-Karp) ──
    // When Greedy creates a "redirect" transfer (e.g. C→B) but only
    // chain debts exist (C→A, A→B), BFS finds the path and allocates
    // along every hop.
    console.log(`[DebtSettlementEngine] Direct allocation insufficient for ${debtorId}→${creditorId} (${amount - remaining}/${amount}). Trying graph-based allocation...`);

    const allDebts = await OriginalDebt.find({
        groupId,
        remainingAmount: { $gt: 0.01 }
    });

    // Track mutable remaining per debt (subtract already-allocated amounts)
    const debtRemaining = new Map<string, number>();
    for (const debt of allDebts) {
        const id = debt._id.toString();
        const alreadyAllocated = allocations
            .filter(a => a.originalDebtId === id)
            .reduce((sum, a) => sum + a.amount, 0);
        debtRemaining.set(id, debt.remainingAmount - alreadyAllocated);
    }

    // Edmonds-Karp: repeated BFS until remaining is filled
    while (remaining > 0.01) {
        // Build adjacency from current state
        const adjacency = new Map<string, Array<{ toUserId: string; debtId: string; capacity: number }>>();
        for (const debt of allDebts) {
            const id = debt._id.toString();
            const cap = debtRemaining.get(id) || 0;
            if (cap <= 0.01) continue;

            const edges = adjacency.get(debt.debtorId) || [];
            edges.push({ toUserId: debt.creditorId, debtId: id, capacity: cap });
            adjacency.set(debt.debtorId, edges);
        }

        const result = bfsFindPath(adjacency, debtorId, creditorId);
        if (!result) break; // No more augmenting paths

        const flowAmount = Math.round(Math.min(remaining, result.capacity) * 100) / 100;

        for (const edge of result.path) {
            allocations.push({ originalDebtId: edge.debtId, amount: flowAmount });
            debtRemaining.set(edge.debtId, (debtRemaining.get(edge.debtId) || 0) - flowAmount);
        }

        remaining -= flowAmount;
    }

    if (remaining > 0.01) {
        console.error('[DebtSettlementEngine] Insufficient debts even with graph search:', {
            groupId, debtorId, creditorId,
            requestedAmount: amount,
            allocatedAmount: amount - remaining,
            shortfall: remaining,
        });
        throw new Error(
            `Cannot allocate ${amount} VND. Only ${(amount - remaining).toFixed(0)} VND available in debt paths from ${debtorId} to ${creditorId}`
        );
    }

    console.log(`[DebtSettlementEngine] Graph-based allocation OK: ${allocations.length} allocations for ${amount} VND (${debtorId}→${creditorId})`);
    return allocations;
}

// ─────────────────────────────────────────────
// Main Engine Export
// ─────────────────────────────────────────────

export const debtSettlementEngine = {
    /**
     * Automatically select appropriate strategy and create transfers list
     *
     * Strategy selection logic:
     * - MinCostFlow: when detecting >= 1 pair (A, B) with mutual debts
     *   -> net-off first to avoid circular transfers
     * - Greedy: default for all other cases
     *   -> ensure minimum number of transfers
     *
     * @param netBalances - Net balance Map from originalDebtService.getNetBalances()
     * @param rawDebts    - Raw debts list from DB (debtorId, creditorId, remainingAmount)
     */
    async settle(
        groupId: string,
        netBalances: Map<string, number>,
        rawDebts: RawDebt[]
    ): Promise<SettlementTransferWithAllocation[]> {
        const nodes: DebtNode[] = Array.from(netBalances.entries()).map(([userId, amount]) => ({
            userId,
            amount
        }));

        // Auto-detect strategy
        const useMCF = hasMutualDebts(rawDebts);
        const strategyName = useMCF ? 'MinCostFlow' : 'Greedy';
        console.log(`[DebtSettlementEngine] Using strategy: ${strategyName}`);

        const baseTransfers: SettlementTransfer[] = useMCF
            ? minCostFlowSettle(nodes, rawDebts)
            : greedySettle(nodes);

        // Attach debt allocations (FIFO)
        const result: SettlementTransferWithAllocation[] = [];

        for (const transfer of baseTransfers) {
            if (transfer.amount <= 0.01) continue;

            const allocations = await allocateDebtsForTransfer(
                groupId,
                transfer.fromUserId,
                transfer.toUserId,
                transfer.amount
            );

            result.push({ ...transfer, debtAllocations: allocations });
        }

        return result;
    }
};
