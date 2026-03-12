import { BalanceMap } from './ledgerService';

export interface Transfer {
    fromUserId: string;
    toUserId: string;
    amount: number;
}

export interface BalanceEntry {
    userId: string;
    amount: number;
}

/**
 * Optimal Settlement Algorithm using DFS/Backtracking
 * Finds the minimum number of transactions needed to settle all debts
 */
export const settlementAlgorithm = {
    /**
     * Main entry point - automatically chooses best algorithm
     */
    autoSettle(balances: BalanceMap): Transfer[] {
        const nonZero = this.filterNonZero(balances);

        if (nonZero.length === 0) {
            return [];
        }

        // Use optimal for small groups, greedy for large groups
        if (nonZero.length <= 15) {
            return this.optimalSettle(balances);
        } else {
            return this.greedySettle(balances);
        }
    },

    /**
     * Optimal algorithm using DFS/Backtracking
     * Guarantees minimum number of transactions
     */
    optimalSettle(balances: BalanceMap): Transfer[] {
        const nonZero = this.filterNonZero(balances);

        if (nonZero.length === 0) {
            return [];
        }

        const amounts = nonZero.map(b => b.amount);
        const userIds = nonZero.map(b => b.userId);

        let minTransfers = Infinity;
        let bestPlan: Transfer[] = [];

        const dfs = (current: number[], transfers: Transfer[]): void => {
            // Pruning: if already worse than best, stop
            if (transfers.length >= minTransfers) {
                return;
            }

            // Find first non-zero balance
            let i = 0;
            while (i < current.length && Math.abs(current[i]) < 0.01) {
                i++;
            }

            // All balanced - found a solution
            if (i === current.length) {
                if (transfers.length < minTransfers) {
                    minTransfers = transfers.length;
                    bestPlan = [...transfers];
                }
                return;
            }

            // Try matching with each opposite sign
            for (let j = i + 1; j < current.length; j++) {
                // Skip if same sign (both positive or both negative)
                if (current[i] * current[j] >= 0) {
                    continue;
                }

                // Calculate transfer amount
                const amount = Math.min(Math.abs(current[i]), Math.abs(current[j]));
                const newCurrent = [...current];

                let transfer: Transfer;

                if (current[i] < 0) {
                    // i owes money, j receives money
                    newCurrent[i] += amount;
                    newCurrent[j] -= amount;
                    transfer = {
                        fromUserId: userIds[i],
                        toUserId: userIds[j],
                        amount: Math.round(amount * 100) / 100
                    };
                } else {
                    // i receives money, j owes money
                    newCurrent[i] -= amount;
                    newCurrent[j] += amount;
                    transfer = {
                        fromUserId: userIds[j],
                        toUserId: userIds[i],
                        amount: Math.round(amount * 100) / 100
                    };
                }

                dfs(newCurrent, [...transfers, transfer]);
            }
        };

        dfs(amounts, []);
        return bestPlan;
    },

    /**
     * Greedy algorithm (fallback for large groups)
     * Fast but may not be optimal
     */
    greedySettle(balances: BalanceMap): Transfer[] {
        const nonZero = this.filterNonZero(balances);

        if (nonZero.length === 0) {
            return [];
        }

        // Separate debtors and creditors
        const debtors = nonZero
            .filter(b => b.amount < -0.01)
            .map(b => ({ ...b, amount: Math.abs(b.amount) }))
            .sort((a, b) => b.amount - a.amount);

        const creditors = nonZero
            .filter(b => b.amount > 0.01)
            .sort((a, b) => b.amount - a.amount);

        const transfers: Transfer[] = [];
        let di = 0, ci = 0;

        while (di < debtors.length && ci < creditors.length) {
            const debtor = debtors[di];
            const creditor = creditors[ci];
            const amount = Math.min(debtor.amount, creditor.amount);

            if (amount > 0.01) {
                transfers.push({
                    fromUserId: debtor.userId,
                    toUserId: creditor.userId,
                    amount: Math.round(amount * 100) / 100
                });
            }

            debtor.amount -= amount;
            creditor.amount -= amount;

            if (debtor.amount < 0.01) di++;
            if (creditor.amount < 0.01) ci++;
        }

        return transfers;
    },

    /**
     * Filter out zero or near-zero balances
     */
    filterNonZero(balances: BalanceMap): BalanceEntry[] {
        const entries: BalanceEntry[] = [];

        for (const [userId, amount] of Object.entries(balances)) {
            if (Math.abs(amount) > 0.01) {
                entries.push({ userId, amount });
            }
        }

        return entries;
    },

    /**
     * Calculate total amount that needs to be transferred
     */
    getTotalDebt(balances: BalanceMap): number {
        let total = 0;
        for (const amount of Object.values(balances)) {
            if (amount < 0) {
                total += Math.abs(amount);
            }
        }
        return Math.round(total * 100) / 100;
    },

    /**
     * Verify that a settlement plan is valid
     */
    validatePlan(balances: BalanceMap, transfers: Transfer[]): boolean {
        const testBalances = { ...balances };

        for (const transfer of transfers) {
            testBalances[transfer.fromUserId] = (testBalances[transfer.fromUserId] || 0) + transfer.amount;
            testBalances[transfer.toUserId] = (testBalances[transfer.toUserId] || 0) - transfer.amount;
        }

        // Check all balances are near zero
        for (const amount of Object.values(testBalances)) {
            if (Math.abs(amount) > 0.01) {
                return false;
            }
        }

        return true;
    }
};
