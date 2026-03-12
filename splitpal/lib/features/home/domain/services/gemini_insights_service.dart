import 'package:google_generative_ai/google_generative_ai.dart';

/// Service that generates smart spending insights using Gemini AI.
class GeminiInsightsService {
  late final GenerativeModel _model;
  static const String _geminiModelName = 'gemini-1.5-flash';

  GeminiInsightsService({required String apiKey}) {
    _model = GenerativeModel(
      model: _geminiModelName,
      apiKey: apiKey,
    );
  }

  /// Generates friendly AI insights based on debt summary data.
  ///
  /// [totalIOwe] - Total amount the user owes others.
  /// [totalOweMe] - Total amount others owe the user.
  /// [netBalance] - Net balance (positive means others owe more).
  /// [currency] - Currency code (e.g. 'VND', 'USD').
  Future<String> generateInsights({
    required double totalIOwe,
    required double totalOweMe,
    required double netBalance,
    required String currency,
  }) async {
    try {
      final prompt = '''Bạn là trợ lý tài chính vui vẻ trong ứng dụng chia tiền nhóm SplitPal.

Phân tích dữ liệu tài chính hiện tại của người dùng:
- Tổng nợ tôi đang nợ người khác: $totalIOwe $currency
- Tổng người khác đang nợ tôi: $totalOweMe $currency
- Số dư ròng: $netBalance $currency ${netBalance >= 0 ? '(người khác nợ mình nhiều hơn)' : '(mình nợ người khác nhiều hơn)'}

Yêu cầu:
1. Viết 2-3 câu nhận xét NGẮN GỌN, thân thiện bằng tiếng Việt
2. Dùng emoji phù hợp (2-3 emoji là đủ)
3. Đưa ra 1 gợi ý/lời khuyên ngắn
4. Giọng điệu: vui vẻ, dễ thương, như bạn bè
5. Không quá 80 từ
6. CHỈ trả về nội dung nhận xét, KHÔNG giải thích gì thêm
7. Nếu tất cả số liệu bằng 0, hãy khen user và khuyên tiếp tục dùng app''';

      final response = await _model.generateContent([
        Content.text(prompt),
      ]);

      final text = response.text?.trim() ?? '';

      if (text.isEmpty) {
        return _getFallbackInsight(totalIOwe, totalOweMe, netBalance, currency);
      }

      return text;
    } catch (e) {
      return _getFallbackInsight(totalIOwe, totalOweMe, netBalance, currency);
    }
  }

  String _getFallbackInsight(
    double totalIOwe,
    double totalOweMe,
    double netBalance,
    String currency,
  ) {
    if (totalIOwe == 0 && totalOweMe == 0) {
      return '🎉 Bạn không nợ ai và không ai nợ bạn! Sạch sẽ quá đi! Cứ giữ vậy nhé! 💪';
    }
    if (netBalance >= 0) {
      return '💰 Người khác đang nợ bạn $totalOweMe $currency! Nhớ nhắc nhẹ họ nhé! 😄';
    }
    return '📝 Bạn đang nợ $totalIOwe $currency. Cố gắng thanh toán sớm để nhẹ lòng nha! 🙏';
  }
}
