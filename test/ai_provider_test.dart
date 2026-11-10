import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/data/events.dart';
import 'package:ottoman_empire_1800/models/game_state.dart';
import 'package:ottoman_empire_1800/services/ai_provider.dart';

void main() {
  group('قراءة ردود المزودات', () {
    test('Gemini: يجمع نص الأجزاء', () {
      final body = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'مرحبا '},
                {'text': 'بالعالم'},
              ],
            },
          },
        ],
      });
      expect(parseGeminiText(body), equals('مرحبا بالعالم'));
    });

    test('Gemini: رد فارغ يرمي خطأ مفهوما', () {
      expect(
        () => parseGeminiText(jsonEncode({'candidates': []})),
        throwsA(isA<AiException>()),
      );
    });

    test('Groq: يقرأ رسالة الرد', () {
      final body = jsonEncode({
        'choices': [
          {
            'message': {'content': '  نص الرد  '},
          },
        ],
      });
      expect(parseChatCompletionText(body), equals('نص الرد'));
    });

    test('Groq: رد بلا محتوى يرمي خطأ مفهوما', () {
      expect(
        () => parseChatCompletionText(jsonEncode({'choices': []})),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('المزودات والإعدادات', () {
    test('اختيار مزود غير معروف يرجع للمزود الأول', () {
      expect(aiProviderById('unknown').id, equals(aiProviders.first.id));
    });

    test('لكل مزود نموذج افتراضي', () {
      for (final p in aiProviders) {
        expect(p.defaultModel.trim(), isNotEmpty);
      }
    });

    test('طلب السرد يحتوي القرار ولا يحتوي مفتاحا', () {
      final event = gameEvents.first;
      final prompt = buildNarrationPrompt(
        dateLabel: 'كانون الثاني 1800',
        event: event,
        choice: event.choices.first,
        state: GameState(),
      );
      expect(prompt.contains(event.title), isTrue);
      expect(prompt.contains(event.choices.first.text), isTrue);
      expect(prompt.contains('كانون الثاني 1800'), isTrue);
    });
  });
}
