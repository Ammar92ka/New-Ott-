import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../models/game_event.dart';
import '../models/game_state.dart';

/// خطأ بلغة مفهومة للمستخدم عند فشل الاتصال بمزود الذكاء الاصطناعي.
class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}

abstract class AiProvider {
  /// المعرف المحفوظ في الإعدادات.
  String get id;

  /// الاسم المعروض.
  String get name;

  /// النموذج الافتراضي. يمكن تغييره من الإعدادات لأن المزودين يوقفون نماذج قديمة.
  String get defaultModel;

  Future<String> generate({
    required String prompt,
    required String apiKey,
    required String model,
  });
}

/// المزودات المتاحة. المفتاح يكتبه المستخدم في الإعدادات ويبقى على جهازه فقط.
final List<AiProvider> aiProviders = [GeminiProvider(), GroqProvider()];

AiProvider aiProviderById(String id) =>
    aiProviders.firstWhere((p) => p.id == id, orElse: () => aiProviders.first);

String _httpErrorMessage(int status) {
  if (status == 400) {
    return 'الطلب مرفوض. تحقق من المفتاح ومن اسم النموذج في الإعدادات.';
  }
  if (status == 401 || status == 403) {
    return 'المفتاح غير صالح أو لا يملك صلاحية.';
  }
  if (status == 404) return 'النموذج غير موجود. غيّر اسم النموذج من الإعدادات.';
  if (status == 429) return 'تجاوزت حد الاستخدام. انتظر قليلا ثم حاول.';
  if (status >= 500) return 'خدمة المزود غير متاحة حاليا (رمز $status).';
  return 'فشل الطلب (رمز $status).';
}

Future<http.Response> _post(
  Uri url,
  Map<String, String> headers,
  Map<String, dynamic> body,
) async {
  try {
    return await http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 40));
  } on TimeoutException {
    throw const AiException('انتهت مهلة الاتصال. حاول مرة أخرى.');
  } on SocketException {
    throw const AiException('لا يوجد اتصال بالإنترنت.');
  } on http.ClientException {
    throw const AiException('تعذر الاتصال بالخدمة. تحقق من الإنترنت.');
  }
}

/// يستخرج نص الرد من استجابة Gemini.
String parseGeminiText(String body) {
  final data = jsonDecode(body);
  if (data is Map) {
    final candidates = data['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;
      final content = first is Map ? first['content'] : null;
      final parts = content is Map ? content['parts'] : null;
      if (parts is List) {
        final text = parts
            .map((p) => p is Map ? (p['text'] ?? '') : '')
            .join()
            .trim();
        if (text.isNotEmpty) return text;
      }
    }
  }
  throw const AiException('لم يرجع النموذج نصا. قد يكون المحتوى محجوبا.');
}

/// يستخرج نص الرد من استجابة بصيغة OpenAI (تستخدمها Groq).
String parseChatCompletionText(String body) {
  final data = jsonDecode(body);
  if (data is Map) {
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      final message = first is Map ? first['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is String && content.trim().isNotEmpty) {
        return content.trim();
      }
    }
  }
  throw const AiException('لم يرجع النموذج نصا.');
}

class GeminiProvider implements AiProvider {
  @override
  String get id => 'gemini';
  @override
  String get name => 'Gemini';
  @override
  String get defaultModel => 'gemini-flash-latest';

  @override
  Future<String> generate({
    required String prompt,
    required String apiKey,
    required String model,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AiException('لا يوجد مفتاح. أضفه من الإعدادات.');
    }
    // المفتاح في الترويسة وليس في الرابط حتى لا يظهر في السجلات.
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final res = await _post(
      url,
      {'Content-Type': 'application/json', 'x-goog-api-key': apiKey.trim()},
      {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      },
    );
    if (res.statusCode != 200) {
      throw AiException(_httpErrorMessage(res.statusCode));
    }
    return parseGeminiText(utf8.decode(res.bodyBytes));
  }
}

class GroqProvider implements AiProvider {
  @override
  String get id => 'groq';
  @override
  String get name => 'Groq';
  @override
  String get defaultModel => 'openai/gpt-oss-120b';

  @override
  Future<String> generate({
    required String prompt,
    required String apiKey,
    required String model,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AiException('لا يوجد مفتاح. أضفه من الإعدادات.');
    }
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final res = await _post(
      url,
      {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${apiKey.trim()}',
      },
      {
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    );
    if (res.statusCode != 200) {
      throw AiException(_httpErrorMessage(res.statusCode));
    }
    return parseChatCompletionText(utf8.decode(res.bodyBytes));
  }
}

/// يبني طلب السرد الموسع. الذكاء الاصطناعي يكتب القصة فقط ولا يغير أي رقم في اللعبة.
String buildNarrationPrompt({
  required String dateLabel,
  required GameEvent event,
  required GameChoice choice,
  required GameState state,
}) {
  return '''أنت راو تاريخي للعبة محاكاة الدولة العثمانية عام 1800. اللاعب هو الصدر الأعظم.
التاريخ: $dateLabel
الحدث: ${event.title} - ${event.place}
الموقف: ${event.scene} ${event.dilemma}
قرار اللاعب: ${choice.text}
النتيجة الرسمية: ${choice.result}
حالة الدولة الآن: رضا السلطان ${state.sultan} من 100، الاستقرار ${state.stability} من 100.

اكتب فقرة سردية واحدة بالعربية الفصحى المبسطة (من 80 إلى 120 كلمة) تصف ما جرى في الأيام التالية بين الناس والديوان، بأسلوب أدبي مشوق.
التزم بالنتيجة الرسمية ولا تغيرها، ولا تذكر أرقاما، ولا تخترع أحداثا تاريخية كبرى أو شخصيات حقيقية جديدة.''';
}
