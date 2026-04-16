import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:splitpal/features/exchange/exchange_provider.dart';

class CurrencyConverterPage extends StatefulWidget {
  const CurrencyConverterPage({super.key});

  @override
  State<CurrencyConverterPage> createState() => _CurrencyConverterPageState();
}

class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
  final _amountController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ExchangeProvider>();
      if (provider.currencies.isEmpty) {
        provider.loadCurrencies();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Converter'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<ExchangeProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryHover],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.currency_exchange,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Exchange Rate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time currency conversion',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Amount input
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.asbestos,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter amount',
                          prefixIcon: const Icon(Icons.attach_money, color: AppColors.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.silver),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        onChanged: (value) {
                          provider.amount = double.tryParse(value) ?? 0;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Currency selectors
                _buildCard(
                  child: Column(
                    children: [
                      // From currency
                      _buildCurrencySelector(
                        label: 'From',
                        value: provider.fromCurrency,
                        currencies: provider.currencies,
                        onChanged: (value) {
                          if (value != null) provider.fromCurrency = value;
                        },
                      ),

                      // Swap button
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: IconButton(
                          onPressed: provider.swapCurrencies,
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.swap_vert,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                        ),
                      ),

                      // To currency
                      _buildCurrencySelector(
                        label: 'To',
                        value: provider.toCurrency,
                        currencies: provider.currencies,
                        onChanged: (value) {
                          if (value != null) provider.toCurrency = value;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Convert button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: provider.isLoading
                        ? null
                        : () {
                            provider.amount = double.tryParse(_amountController.text) ?? 0;
                            provider.convert();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Convert',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Result
                if (provider.lastConversion != null)
                  _buildCard(
                    child: Column(
                      children: [
                        const Text(
                          'Result',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.asbestos,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_formatNumber(provider.lastConversion!.amount)} ${provider.lastConversion!.from}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(Icons.arrow_downward, color: AppColors.primary),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatNumber(provider.lastConversion!.convertedAmount)} ${provider.lastConversion!.to}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.clouds,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '1 ${provider.lastConversion!.from} = ${_formatNumber(provider.lastConversion!.rate)} ${provider.lastConversion!.to}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.asbestos,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Error
                if (provider.error != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCurrencySelector({
    required String label,
    required String value,
    required List<String> currencies,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.asbestos,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.silver),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currencies.contains(value) ? value : null,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: currencies.map((currency) {
                  return DropdownMenuItem<String>(
                    value: currency,
                    child: Row(
                      children: [
                        Text(
                          _getCurrencyFlag(currency),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currency,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getCurrencyName(currency),
                          style: const TextStyle(
                            color: AppColors.asbestos,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000) {
      return number.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (match) => '${match[1]},',
          );
    }
    if (number == number.roundToDouble()) {
      return number.toStringAsFixed(0);
    }
    return number.toStringAsFixed(2);
  }

  String _getCurrencyFlag(String currency) {
    const flags = {
      'VND': '🇻🇳',
      'USD': '🇺🇸',
      'EUR': '🇪🇺',
      'GBP': '🇬🇧',
      'JPY': '🇯🇵',
      'KRW': '🇰🇷',
      'CNY': '🇨🇳',
      'THB': '🇹🇭',
      'SGD': '🇸🇬',
      'AUD': '🇦🇺',
      'CAD': '🇨🇦',
      'CHF': '🇨🇭',
      'HKD': '🇭🇰',
      'INR': '🇮🇳',
      'MYR': '🇲🇾',
      'PHP': '🇵🇭',
      'TWD': '🇹🇼',
      'NZD': '🇳🇿',
      'SEK': '🇸🇪',
    };
    return flags[currency] ?? '💱';
  }

  String _getCurrencyName(String currency) {
    const names = {
      'VND': 'Vietnamese Dong',
      'USD': 'US Dollar',
      'EUR': 'Euro',
      'GBP': 'British Pound',
      'JPY': 'Japanese Yen',
      'KRW': 'Korean Won',
      'CNY': 'Chinese Yuan',
      'THB': 'Thai Baht',
      'SGD': 'Singapore Dollar',
      'AUD': 'Australian Dollar',
      'CAD': 'Canadian Dollar',
      'CHF': 'Swiss Franc',
      'HKD': 'Hong Kong Dollar',
      'INR': 'Indian Rupee',
      'MYR': 'Malaysian Ringgit',
      'PHP': 'Philippine Peso',
      'TWD': 'Taiwan Dollar',
      'NZD': 'New Zealand Dollar',
      'SEK': 'Swedish Krona',
    };
    return names[currency] ?? currency;
  }
}
