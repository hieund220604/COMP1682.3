/**
 * ═══════════════════════════════════════════════════════════════════
 * DEBT SETTLEMENT ENGINE
 * ═══════════════════════════════════════════════════════════════════
 *
 * Optimizes group debt payments using a 2-phase pipeline:
 *
 *   PHASE 1 — Strategy: Calculate optimal transfer list
 *     Step 1.1: Auto-detect mutual debts → choose strategy
 *     Step 1.2: Execute strategy (Greedy or MinCostFlow)
 *              → Output: SettlementTransfer[] (who pays whom, how much)
 *
 *   PHASE 2 — Allocation: Map each transfer back to OriginalDebt records
 *     Step 2.1: FIFO direct allocation (fast path)
 *     Step 2.2: Edmonds-Karp graph search (multi-hop fallback)
 *              → Output: SettlementTransferWithAllocation[]
 *
 * Algorithms used:
 *   - Greedy Two-Pointer: minimize number of transfers via net balance matching
 *   - Pairwise Net-off: cancel circular flows (A↔B) before optimization
 *   - Edmonds-Karp (BFS-based Max-Flow): allocate transfers through debt chains
 *
 * Epsilon: 0.01 throughout (1 xu VND) to handle IEEE 754 floating-point errors
 * ═══════════════════════════════════════════════════════════════════
 */

import { OriginalDebt } from '../models/OriginalDebt';
import mongoose from 'mongoose';

// ─────────────────────────────────────────────────────────────────
// DATA TYPES
// ─────────────────────────────────────────────────────────────────

/** A user's net balance position in the group */
export interface DebtNode {
    userId: string;
    /** Positive = creditor (is owed money), Negative = debtor (owes money) */
    amount: number;
}

/** A single optimized transfer from debtor to creditor */
export interface SettlementTransfer {
    fromUserId: string;
    toUserId: string;
    amount: number;
}

/** Links an allocated amount to a specific OriginalDebt record */
export interface DebtAllocation {
    originalDebtId: string;
    amount: number;
}

/** Final output: a transfer with full traceability to original debts */
export interface SettlementTransferWithAllocation extends SettlementTransfer {
    debtAllocations: DebtAllocation[];
}

/** Raw pairwise debt record from DB (input to the engine) */
export interface RawDebt {
    debtorId: string;
    creditorId: string;
    remainingAmount: number;
}

// ═════════════════════════════════════════════════════════════════
// PHASE 1 — STRATEGY: Calculate optimal transfer list
// ═════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// Phase 1, Step 1.1: Auto-Detection
// Scan rawDebts to detect mutual (bidirectional) debts.
// If found → use MinCostFlow (net-off first, then Greedy).
// If not   → use Greedy directly (already optimal).
// Complexity: O(n), n = number of OriginalDebt records
// ─────────────────────────────────────────────────────────────────

function hasMutualDebts(rawDebts: RawDebt[]): boolean {
    // Build a set of all directional debt pairs
    const pairs = new Set<string>();
    for (const debt of rawDebts) {
        pairs.add(`${debt.debtorId}:${debt.creditorId}`);
    }
    // If any reverse pair exists → mutual debts detected
    for (const debt of rawDebts) {
        if (pairs.has(`${debt.creditorId}:${debt.debtorId}`)) {
            return true;
        }
    }
    return false;
}

// ─────────────────────────────────────────────────────────────────
// Phase 1, Step 1.2a: Greedy Two-Pointer Strategy
//
// Algorithm:
//   1. Partition users into debtors (negative balance) and creditors (positive balance)
//   2. Sort both lists descending by amount
//   3. Two-pointer: match largest debtor with largest creditor
//      → transfer min(debtor.amount, creditor.amount)
//      → advance pointer of whichever is exhausted
//
// Properties:
//   - Maximum transfers = debtors.length + creditors.length - 1 = n - 1
//   - Zero-sum guarantee: total debtor amounts = total creditor amounts
//   - Complexity: O(n log n) dominated by sorting
// ─────────────────────────────────────────────────────────────────

function greedySettle(nodes: DebtNode[]): SettlementTransfer[] {
    // 1. Partition into debtors and creditors
    const debtors: { userId: string; amount: number }[] = [];
    const creditors: { userId: string; amount: number }[] = [];

    for (const node of nodes) {
        if (node.amount < -0.01) {
            debtors.push({ userId: node.userId, amount: Math.abs(node.amount) });
        } else if (node.amount > 0.01) {
            creditors.push({ userId: node.userId, amount: node.amount });
        }
    }

    // 2. Sort descending — largest amounts first for greedy matching
    debtors.sort((a, b) => b.amount - a.amount);
    creditors.sort((a, b) => b.amount - a.amount);

    // 3. Two-pointer matching
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

        // Advance pointer when a party's balance is exhausted
        if (debtor.amount < 0.01) di++;
        if (creditor.amount < 0.01) ci++;
    }

    return transfers;
}

// ─────────────────────────────────────────────────────────────────
// Phase 1, Step 1.2b: MinCostFlow Strategy (Net-off + Greedy)
//
// Used when mutual debts exist (A owes B AND B owes A).
// Without net-off, Greedy would create redundant circular transfers.
//
// Algorithm (3 sub-steps):
//   Step A — Build pairwise net map: aggregate rawDebts by (debtor, creditor) pair
//   Step B — Net-off mutual pairs: if A→B and B→A both exist, cancel the overlap
//            Example: A→B: 100k, B→A: 60k → net: A→B: 40k (60k cancelled)
//   Step C — Recompute net balances from netted debts → feed into Greedy
//
// This ensures circular flows are eliminated BEFORE Greedy optimizes transfer count.
// Complexity: O(P + n log n), P = number of unique pairs
// ─────────────────────────────────────────────────────────────────

function minCostFlowSettle(
    nodes: DebtNode[],
    rawDebts: RawDebt[]
): SettlementTransfer[] {

    // ── Step A: Build pairwise net map ──
    // Aggregate all rawDebts into pairNet[debtorId][creditorId] = totalAmount
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

    // ── Step B: Net-off mutual debts ──
    // For each pair (A, B): if A→B > 0 AND B→A > 0, cancel the smaller amount
    // Use sorted canonical key to ensure each pair is processed exactly once
    const processedPairs = new Set<string>();
    let netOffCount = 0;
    let netOffTotal = 0;

    for (const [debtorId, creditorMap] of pairNet) {
        for (const [creditorId] of creditorMap) {
            const pairKey = [debtorId, creditorId].sort().join(':');
            if (processedPairs.has(pairKey)) continue;
            processedPairs.add(pairKey);

            const aOwesB = pairNet.get(debtorId)?.get(creditorId) || 0;
            const bOwesA = pairNet.get(creditorId)?.get(debtorId) || 0;

            if (aOwesB > 0.01 && bOwesA > 0.01) {
                const cancelled = Math.min(aOwesB, bOwesA);
                netOffCount++;
                netOffTotal += cancelled;

                // Keep only the net difference, zero out the smaller direction
                const net = aOwesB - bOwesA;
                getOrCreate(pairNet, debtorId).set(creditorId, Math.max(0, net));
                getOrCreate(pairNet, creditorId).set(debtorId, Math.max(0, -net));
            }
        }
    }

    // ── Step C: Recompute net balances → Greedy ──
    // Calculate each user's net position from the netted pairwise debts
    const nettedBalances = new Map<string, number>();
    for (const [debtorId, creditorMap] of pairNet) {
        for (const [creditorId, amount] of creditorMap) {
            if (amount > 0.01) {
                nettedBalances.set(debtorId, (nettedBalances.get(debtorId) || 0) - amount);
                nettedBalances.set(creditorId, (nettedBalances.get(creditorId) || 0) + amount);
            }
        }
    }

    // Convert to DebtNode array, filtering out zero-balance users
    const nettedNodes: DebtNode[] = [];
    for (const [userId, balance] of nettedBalances) {
        if (Math.abs(balance) > 0.01) {
            nettedNodes.push({ userId, amount: Math.round(balance * 100) / 100 });
        }
    }

    console.log(`[MinCostFlow] Net-off: ${netOffCount} mutual pairs, cancelled ${netOffTotal} circular flow`);

    // Feed netted balances into Greedy for minimum transfer count
    return greedySettle(nettedNodes);
}

// ═════════════════════════════════════════════════════════════════
// PHASE 2 — ALLOCATION: Map transfers to OriginalDebt records
// ═════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// Phase 2, Helper: BFS shortest-path through the debt graph
//
// Used by Edmonds-Karp algorithm to find augmenting paths.
// Each edge = an OriginalDebt record with remaining capacity.
// Returns the shortest path (fewest hops) and its bottleneck capacity.
// Complexity: O(V + E) per call
// ─────────────────────────────────────────────────────────────────

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

            // Reached the target → return the augmenting path
            if (edge.toUserId === target) {
                return { path: newPath, capacity: newCapacity };
            }

            visited.add(edge.toUserId);
            queue.push({ userId: edge.toUserId, path: newPath, capacity: newCapacity });
        }
    }

    return null; // No path exists
}

// ─────────────────────────────────────────────────────────────────
// Phase 2, Step 2.1 + 2.2: Debt Allocation per Transfer
//
// For each transfer from Phase 1 (e.g. "User4 pays User2: 1.4M"),
// find which OriginalDebt records this money settles.
//
// OPTIMIZATION: All debts are pre-loaded once in settle() and passed here.
// A shared debtRemaining map tracks capacity across all transfers,
// preventing double-allocation and eliminating redundant DB queries.
//
// Two-step approach:
//   Step 2.1 — FIFO direct: filter pre-loaded debts for (debtorId → creditorId),
//              allocate oldest-first. Fast path for most cases.
//   Step 2.2 — Edmonds-Karp: BFS finds multi-hop paths through the debt graph
//              when direct debts are insufficient.
//
// Complexity: Step 2.1 = O(D), Step 2.2 = O(V·E²) worst case
// ─────────────────────────────────────────────────────────────────

function allocateDebtsForTransfer(
    allDebts: Array<{ id: string; debtorId: string; creditorId: string; createdAt: Date }>,
    debtRemaining: Map<string, number>,
    debtorId: string,
    creditorId: string,
    amount: number
): DebtAllocation[] {

    // ── Step 2.1: FIFO Direct Allocation (fast path) ──
    // Filter pre-loaded debts for direct (debtorId → creditorId), sorted oldest first
    const directDebts = allDebts
        .filter(d => d.debtorId === debtorId && d.creditorId === creditorId && (debtRemaining.get(d.id) || 0) > 0.01)
        .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime()); // FIFO

    const allocations: DebtAllocation[] = [];
    let remaining = amount;

    for (const debt of directDebts) {
        if (remaining <= 0.01) break;
        const cap = debtRemaining.get(debt.id) || 0;
        const allocAmount = Math.min(remaining, cap);
        allocations.push({
            originalDebtId: debt.id,
            amount: Math.round(allocAmount * 100) / 100
        });
        debtRemaining.set(debt.id, cap - allocAmount);
        remaining -= allocAmount;
    }

    // If fully allocated via direct debts → return immediately (fast path)
    if (remaining <= 0.01) return allocations;

    // ── Step 2.2: Graph-based Allocation (Edmonds-Karp / BFS Max-Flow) ──
    // Greedy may create transfers that don't have direct OriginalDebt records.
    // Example: Greedy says "C pays B: 200k" but DB only has C→A and A→B.
    // Solution: BFS finds path C→A→B and allocates flow along both hops.
    console.log(`[DebtAllocation] Direct FIFO insufficient for ${debtorId}→${creditorId} (${amount - remaining}/${amount}). Using Edmonds-Karp...`);

    // Edmonds-Karp loop: repeatedly find augmenting paths via BFS
    while (remaining > 0.01) {
        // Build adjacency graph from current remaining capacities
        const adjacency = new Map<string, Array<{ toUserId: string; debtId: string; capacity: number }>>();
        for (const debt of allDebts) {
            const cap = debtRemaining.get(debt.id) || 0;
            if (cap <= 0.01) continue;

            const edges = adjacency.get(debt.debtorId) || [];
            edges.push({ toUserId: debt.creditorId, debtId: debt.id, capacity: cap });
            adjacency.set(debt.debtorId, edges);
        }

        // BFS: find shortest augmenting path from debtorId → creditorId
        const result = bfsFindPath(adjacency, debtorId, creditorId);
        if (!result) break; // No more augmenting paths

        // Push flow along the found path
        const flowAmount = Math.round(Math.min(remaining, result.capacity) * 100) / 100;
        for (const edge of result.path) {
            allocations.push({ originalDebtId: edge.debtId, amount: flowAmount });
            debtRemaining.set(edge.debtId, (debtRemaining.get(edge.debtId) || 0) - flowAmount);
        }
        remaining -= flowAmount;
    }

    // Verify: all amount must be allocated
    if (remaining > 0.01) {
        console.error('[DebtAllocation] Insufficient debts even with graph search:', {
            debtorId, creditorId,
            requestedAmount: amount,
            allocatedAmount: amount - remaining,
            shortfall: remaining,
        });
        throw new Error(
            `Cannot allocate ${amount} VND. Only ${(amount - remaining).toFixed(0)} VND available in debt paths from ${debtorId} to ${creditorId}`
        );
    }

    console.log(`[DebtAllocation] Edmonds-Karp OK: ${allocations.length} allocations for ${amount} VND`);
    return allocations;
}

// ═════════════════════════════════════════════════════════════════
// MAIN ENGINE — Orchestrates Phase 1 + Phase 2
// ═════════════════════════════════════════════════════════════════

export const debtSettlementEngine = {
    /**
     * Main entry point: settle all debts in a group optimally.
     *
     * Pipeline:
     *   Phase 1 → Compute optimal transfer list (who pays whom)
     *   Phase 2 → For each transfer, allocate back to OriginalDebt records
     *
     * PERFORMANCE: All OriginalDebts are loaded ONCE and shared across
     * all allocation calls via in-memory debtRemaining map.
     *
     * @param groupId     - The group to settle debts for
     * @param netBalances - Net balance Map from originalDebtService.getNetBalances()
     * @param rawDebts    - Raw pairwise debts from DB (for mutual debt detection)
     * @returns Optimized transfers with full debt allocation traceability
     */
    async settle(
        groupId: string,
        netBalances: Map<string, number>,
        rawDebts: RawDebt[]
    ): Promise<SettlementTransferWithAllocation[]> {

        // Convert net balances map to DebtNode array
        const nodes: DebtNode[] = Array.from(netBalances.entries()).map(([userId, amount]) => ({
            userId,
            amount
        }));

        // ── PHASE 1: Strategy Selection + Execution ──
        const useMCF = hasMutualDebts(rawDebts);
        const strategyName = useMCF ? 'MinCostFlow' : 'Greedy';
        console.log(`[SettlementEngine] Phase 1: Using ${strategyName} strategy`);

        const baseTransfers: SettlementTransfer[] = useMCF
            ? minCostFlowSettle(nodes, rawDebts)
            : greedySettle(nodes);

        console.log(`[SettlementEngine] Phase 1 complete: ${baseTransfers.length} transfers`);

        // ── PHASE 2: Debt Allocation ──
        // Pre-load ALL OriginalDebts for this group ONCE (eliminates N*2 DB queries)
        const allDebtDocs = await OriginalDebt.find({
            groupId,
            remainingAmount: { $gt: 0.01 }
        });

        // Build in-memory structures for allocation
        const allDebts = allDebtDocs.map(d => ({
            id: d._id.toString(),
            debtorId: d.debtorId,
            creditorId: d.creditorId,
            remainingAmount: d.remainingAmount,
            createdAt: d.createdAt
        }));

        // Shared mutable capacity map — tracks remaining across ALL transfers
        // This prevents double-allocation when multiple transfers use the same debt
        const debtRemaining = new Map<string, number>(
            allDebts.map(d => [d.id, d.remainingAmount])
        );

        const result: SettlementTransferWithAllocation[] = [];

        for (const transfer of baseTransfers) {
            if (transfer.amount <= 0.01) continue;

            const allocations = allocateDebtsForTransfer(
                allDebts,
                debtRemaining, // shared state — mutations visible to subsequent transfers
                transfer.fromUserId,
                transfer.toUserId,
                transfer.amount
            );

            result.push({ ...transfer, debtAllocations: allocations });
        }

        console.log(`[SettlementEngine] Phase 2 complete: all ${result.length} transfers allocated`);
        return result;
    }
};

