import 'package:translator/translator.dart';
import 'translations.dart';

class TranslationService {
  static final _onlineTranslator = GoogleTranslator(client: ClientType.siteGT);

  static Future<String> translate(String textPt) async {
    if (textPt.trim().isEmpty) return textPt;

    try {
      print('🌐 Traduzindo online: $textPt');
      var translation = await _onlineTranslator
          .translate(textPt, from: 'pt', to: 'en')
          .timeout(const Duration(seconds: 5));

      print('✅ Traduzido: ${translation.text}');
      return translation.text;
    } catch (e) {
      print('⚠️ Tradução online falhou: $e');
      print('📖 Usando dicionário local...');
      return Translator.translate(textPt);
    }
  }

  static Future<List<String>> translateBatch(List<String> texts) async {
    List<String> translated = [];
    for (String text in texts) {
      translated.add(await translate(text));
    }
    return translated;
  }
}
