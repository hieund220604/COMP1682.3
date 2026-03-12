/**
 * Exchange Rate Service
 * Provides currency conversion for multi-currency groups
 * Uses exchangerate-api.com free tier or fallback static rates
 */

// Static fallback rates (relative to VND)
const STATIC_RATES_TO_VND: Record<string, number> = {
    'VND': 1,
    'USD': 25_400,
    'EUR': 27_500,
    'GBP': 32_000,
    'JPY': 170,
    'KRW': 19,
    'CNY': 3_500,
    'THB': 710,
    'SGD': 18_900,
    'AUD': 16_500,
    'CAD': 18_200,
    'CHF': 28_500,
    'HKD': 3_260,
    'TWD': 790,
    'MYR': 5_700,
    'PHP': 450,
    'IDR': 1.6,
    'INR': 303,
};

// Cache for API rates (TTL: 1 hour)
let cachedRates: { rates: Record<string, number>; fetchedAt: number } | null = null;
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

export const exchangeRateService = {
    /**
     * Get exchange rate from one currency to another
     * Returns how many units of `toCurrency` equals 1 unit of `fromCurrency`
     */
    async getRate(fromCurrency: string, toCurrency: string): Promise<number> {
        const from = fromCurrency.toUpperCase();
        const to = toCurrency.toUpperCase();

        if (from === to) return 1;

        try {
            const rates = await this.getRatesToVND();
            const fromRate = rates[from];
            const toRate = rates[to];

            if (!fromRate || !toRate) {
                throw new Error(`Unsupported currency pair: ${from} -> ${to}`);
            }

            // fromCurrency -> VND -> toCurrency
            // 1 fromCurrency = fromRate VND
            // 1 toCurrency = toRate VND
            // So 1 fromCurrency = fromRate / toRate toCurrency
            return fromRate / toRate;
        } catch (error) {
            console.error('[ExchangeRate] API failed, using static rates:', error);
            return this.getStaticRate(from, to);
        }
    },

    /**
     * Convert amount from one currency to another
     */
    async convert(amount: number, fromCurrency: string, toCurrency: string): Promise<{
        convertedAmount: number;
        rate: number;
        fromCurrency: string;
        toCurrency: string;
    }> {
        const rate = await this.getRate(fromCurrency, toCurrency);
        const convertedAmount = Math.round(amount * rate * 100) / 100;

        return {
            convertedAmount,
            rate: Math.round(rate * 10000) / 10000,
            fromCurrency: fromCurrency.toUpperCase(),
            toCurrency: toCurrency.toUpperCase(),
        };
    },

    /**
     * Get all rates relative to VND (from API or cache)
     */
    async getRatesToVND(): Promise<Record<string, number>> {
        // Check cache
        if (cachedRates && (Date.now() - cachedRates.fetchedAt) < CACHE_TTL_MS) {
            return cachedRates.rates;
        }

        try {
            // Try fetching from exchangerate-api (free tier, no key needed for open endpoint)
            const response = await fetch('https://open.er-api.com/v6/latest/VND');
            const data: any = await response.json();

            if (data.result === 'success' && data.rates) {
                // API returns rates FROM VND, we need TO VND
                // If 1 VND = 0.00003937 USD, then 1 USD = 1/0.00003937 = 25400 VND
                const ratesToVND: Record<string, number> = { 'VND': 1 };

                for (const [currency, rate] of Object.entries(data.rates)) {
                    if (typeof rate === 'number' && rate > 0) {
                        ratesToVND[currency] = Math.round((1 / rate) * 100) / 100;
                    }
                }

                cachedRates = { rates: ratesToVND, fetchedAt: Date.now() };
                return ratesToVND;
            }
        } catch (error) {
            console.error('[ExchangeRate] Failed to fetch API rates:', error);
        }

        // Fallback to static rates
        return STATIC_RATES_TO_VND;
    },

    /**
     * Fallback: get static rate
     */
    getStaticRate(fromCurrency: string, toCurrency: string): number {
        const from = fromCurrency.toUpperCase();
        const to = toCurrency.toUpperCase();

        const fromRate = STATIC_RATES_TO_VND[from];
        const toRate = STATIC_RATES_TO_VND[to];

        if (!fromRate || !toRate) {
            throw new Error(`Unsupported currency: ${from} or ${to}`);
        }

        return fromRate / toRate;
    },

    /**
     * Get list of supported currencies
     */
    getSupportedCurrencies(): string[] {
        return Object.keys(STATIC_RATES_TO_VND);
    },

    /**
     * Clear cache (for testing)
     */
    clearCache(): void {
        cachedRates = null;
    }
};
