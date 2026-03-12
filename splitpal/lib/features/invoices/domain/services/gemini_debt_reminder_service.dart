import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Service that generates creative debt reminder messages using Gemini AI.
class GeminiDebtReminderService {
  final String _apiKey;
  static const String _geminiModelName = 'gemini-2.0-flash';

  GeminiDebtReminderService({required String apiKey}) : _apiKey = apiKey;

  /// Create a fresh GenerativeModel for each request to avoid any caching issues
  GenerativeModel _createModel() {
    return GenerativeModel(
      model: _geminiModelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 1.2,
        topP: 0.95,
        topK: 40,
        maxOutputTokens: 256,
      ),
    );
  }

  /// Available reminder styles
  static const Map<String, String> styles = {
    'funny': 'Hài hước, vui vẻ 😄',
    'polite': 'Khéo léo, lịch sự 🎯',
    'serious': 'Nghiêm túc, dứt khoát 😤',
    'poetic': 'Thơ mộng, bay bổng 💕',
    'gangster': 'Giang hồ, đe dọa vui 🔥',
  };

  /// Style-specific instructions for the prompt
  static const Map<String, String> _styleInstructions = {
    'funny':
        'Viết theo phong cách HÀI HƯỚC, dùng từ lóng gen Z, meme, so sánh buồn cười. Ví dụ: chia sẻ nỗi đau ví rỗng, nói đùa về việc bán thận. Giọng văn phải khiến người đọc bật cười.',
    'polite':
        'Viết theo phong cách LỊCH SỰ, nhẹ nhàng, tôn trọng. Dùng kính ngữ, lời lẽ khéo léo. Nhắc nhở một cách tinh tế, không gây áp lực. Giọng văn như một người bạn tốt nhẹ nhàng nhắc nhở.',
    'serious':
        'Viết theo phong cách NGHIÊM TÚC, thẳng thắn, dứt khoát. Đi thẳng vào vấn đề, nêu rõ số tiền và deadline. Giọng văn chuyên nghiệp, không đùa giỡn, thể hiện sự cấp bách.',
    'poetic':
        'Viết theo phong cách THƠ MỘNG, bay bổng. Dùng vần điệu, ẩn dụ, hình ảnh lãng mạn. Có thể viết dưới dạng thơ lục bát hoặc thơ tự do. Giọng văn đầy cảm xúc và nghệ thuật.',
    'gangster':
        'Viết theo phong cách GIANG HỒ VUI, dùng tiếng lóng đường phố, giọng điệu đe dọa nhưng HÀI HƯỚC (không thật sự đe dọa). Ví dụ: nhắc đến "anh em", "đạo nghĩa", "xử đẹp". Giọng văn phải vui nhộn, không bạo lực thật.',
  };

  /// Style-specific fallback messages (multiple per style for variety)
  static const Map<String, List<String>> _styleFallbacks = {
    'funny': [
      'Ê {name} ơi! 😂 Tiền đâu rồi?? {amount} {currency} kìa, quên rồi hả? Ví mình đói lắm rồi bạn ơi! 💸 Trả nhanh kẻo mình bán thận đóng tiền net! 🎮',
      'Hey {name}! 🤣 {amount} {currency} nha, quên nhanh quá ta! Mình thì nhớ dai lắm, y như crush nhớ cái ex vậy đó! 😏 Thanh toán nha!',
      '{name} ơi! 😜 Nợ {amount} {currency} mà cứ im re, mình tưởng bạn bốc hơi luôn rồi! 👻 Trả đi để còn add friend lại nha! 💕',
    ],
    'polite': [
      'Chào {name} nhé! 🌸 Mình muốn nhắc nhẹ về khoản {amount} {currency} bạn đang nợ. Khi nào tiện thì bạn thanh toán giúp mình nhé. Cảm ơn bạn rất nhiều! 🙏',
      'Hi {name}! 😊 Mình xin phép nhắc bạn về khoản {amount} {currency}. Mình hiểu ai cũng bận, nhưng nếu được thì bạn sắp xếp trả giúp mình nha. Cảm ơn bạn! 💫',
      '{name} thân mến! 🌷 Nhắc nhẹ bạn khoản {amount} {currency} nha. Không vội đâu, khi nào thuận tiện thì bạn chuyển giúp mình nhé. Chúc bạn ngày tốt lành! ☀️',
    ],
    'serious': [
      '{name}, mình cần nhắc về khoản nợ {amount} {currency}. ⏰ Đề nghị bạn thanh toán sớm. Việc trì hoãn ảnh hưởng đến tài chính chung. Mong bạn xử lý trong hôm nay.',
      'Thông báo đến {name}: 📋 Khoản nợ {amount} {currency} vẫn chưa được thanh toán. Yêu cầu bạn chuyển khoản trong thời gian sớm nhất. Đây là lần nhắc chính thức.',
      '{name}, khoản {amount} {currency} đã quá hạn. ⚠️ Mình đề nghị bạn ưu tiên thanh toán ngay. Nếu có khó khăn, hãy trao đổi trực tiếp với mình.',
    ],
    'poetic': [
      'Gửi {name} yêu dấu 💕\nTiền tình như lá thu rơi,\n{amount} {currency} chờ đợi bao lời hẹn thề.\nXin người hãy nhớ đường về,\nThanh toán cho trọn câu thề ban đầu~ 🌸',
      '{name} ơi, 🌙\nNhư trăng nhớ biển, mây nhớ trời,\nMình nhớ {amount} {currency} của người thiếu ta.\nXin đừng để nhớ thêm xa,\nChuyển khoản đi nhé, tình ta vẹn tròn~ 💫',
      'Hỡi {name}! 🦋\nGió thu mang theo lời nhắn nhủ,\n{amount} {currency} như cánh hoa chờ đợi.\nMong người mở ví trao tay,\nĐể tình bạn mãi đong đầy yêu thương~ 🌺',
    ],
    'gangster': [
      'Ê {name}! 🔥 Nghe đây, {amount} {currency} anh em nói rồi mà chưa thấy động tĩnh gì! 💪 Đạo nghĩa giang hồ là nợ thì phải trả, hiểu chưa?! Xử đẹp đi nha! 😎',
      '{name}! 🗡️ Anh em nhắc lần này thôi nha, {amount} {currency} mang ra đây! Giang hồ ai cũng biết, thiếu nợ là mất uy tín! 💀 Chuyển nhanh kẻo anh em buồn! 🔥',
      'Nghe đây {name}! 😤 {amount} {currency} anh em đòi đẹp lời rồi đó! Đạo nghĩa là trên hết, thiếu nợ thì phải trả! 🔥 Xử lý gấp kẻo anh em phải "hỏi thăm sức khỏe"! 💪😂',
    ],
  };

  /// Generates a debt reminder message.
  Future<String> generateReminder({
    required String debtorName,
    required List<Map<String, dynamic>> debts,
    required String style,
  }) async {
    try {
      final debtDetails = debts
          .map((d) =>
              '- ${d['amount']} ${d['currency']} (khoản: ${d['reason'] ?? 'không rõ'})')
          .join('\n');

      final totalAmount = debts.fold<double>(
          0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0));
      final currency =
          debts.isNotEmpty ? debts.first['currency'] ?? 'VND' : 'VND';

      final styleInstruction =
          _styleInstructions[style] ?? _styleInstructions['funny']!;
      final styleLabel = styles[style] ?? styles['funny']!;

      // Add randomness seed to prompt to avoid cached/identical responses
      final randomSeed = Random().nextInt(99999);

      final prompt = '''Bạn là trợ lý viết tin nhắn nhắc nợ cho ứng dụng chia tiền nhóm.

NHIỆM VỤ: Viết MỘT tin nhắn nhắc bạn "$debtorName" trả nợ.

THÔNG TIN NỢ:
- Tổng nợ: $totalAmount $currency
- Chi tiết:
$debtDetails

PHONG CÁCH BẮT BUỘC: $styleLabel
$styleInstruction

QUY TẮC:
1. Viết bằng tiếng Việt
2. Dùng emoji phù hợp với phong cách
3. Nhắc tên "$debtorName" và số tiền $totalAmount $currency
4. Độ dài: 2-4 câu, tối đa 150 từ
5. CHỈ trả về nội dung tin nhắn, KHÔNG giải thích
6. KHÔNG dùng dấu ngoặc kép bao quanh
7. Phong cách phải RÕ RÀNG khác biệt theo yêu cầu trên
8. Sáng tạo và KHÁC BIỆT hoàn toàn so với các lần trước (seed: $randomSeed)''';

      debugPrint('[GeminiDebtReminder] Generating with style: $style');
      debugPrint('[GeminiDebtReminder] Prompt length: ${prompt.length}');

      // Create a fresh model each time to avoid any state issues
      final model = _createModel();
      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      final text = response.text?.trim() ?? '';
      debugPrint('[GeminiDebtReminder] Response text length: ${text.length}');

      if (text.isEmpty) {
        debugPrint('[GeminiDebtReminder] Empty response, using styled fallback');
        return _getStyledFallbackMessage(debtorName, totalAmount, currency, style);
      }
      return text;
    } catch (e) {
      debugPrint('[GeminiDebtReminder] API ERROR: $e');

      final totalAmount = debts.fold<double>(
          0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0));
      final currency =
          debts.isNotEmpty ? debts.first['currency'] ?? 'VND' : 'VND';

      // Return style-specific fallback instead of generic one
      return _getStyledFallbackMessage(debtorName, totalAmount, currency, style);
    }
  }

  /// Returns a STYLE-SPECIFIC fallback message (randomly chosen from pool)
  String _getStyledFallbackMessage(
      String debtorName, double amount, String currency, String style) {
    final fallbacks = _styleFallbacks[style] ?? _styleFallbacks['funny']!;
    final random = Random();
    final template = fallbacks[random.nextInt(fallbacks.length)];

    return template
        .replaceAll('{name}', debtorName)
        .replaceAll('{amount}', amount.toStringAsFixed(0))
        .replaceAll('{currency}', currency);
  }
}
