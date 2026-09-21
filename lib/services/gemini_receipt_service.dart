// ==============================================================================
// File: lib/services/gemini_receipt_service.dart
// Architecture: BYOK (Bring Your Own Key) Vision Service
// Stack: google_generative_ai, flutter_riverpod
// Model: gemini-2.5-flash
// Features: Dynamic Prompting, Schema Enforced JSON Extraction, Strict Exception Handling
// ==============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// --- DATA TRANSFER OBJECTS ---

class ParsedReceiptItem {
  final String name;
  final int quantity;
  final double price;

  ParsedReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory ParsedReceiptItem.fromJson(Map<String, dynamic> json) {
    return ParsedReceiptItem(
      name: json['name'] as String? ?? 'Khoản mục',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'price': price,
  };
}

class GeminiReceiptScanResult {
  final String merchant;
  final double amount;
  final DateTime date;
  final String categorySuggestion;
  final String envelopeType; // needs, wants, savings
  final double confidence;
  final List<ParsedReceiptItem> items;
  final String rawResponseText;

  GeminiReceiptScanResult({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.categorySuggestion,
    required this.envelopeType,
    required this.confidence,
    required this.items,
    required this.rawResponseText,
  });

  factory GeminiReceiptScanResult.fromJson(Map<String, dynamic> json, String rawText) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['date'] as String);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemList = rawItems
        .whereType<Map<String, dynamic>>()
        .map(ParsedReceiptItem.fromJson)
        .toList();

    return GeminiReceiptScanResult(
      merchant: json['merchant'] as String? ?? 'Chi tiêu không tên',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: parsedDate,
      categorySuggestion: json['categorySuggestion'] as String? ?? 'Khác',
      envelopeType: json['envelopeType'] as String? ?? 'wants',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.95,
      items: itemList,
      rawResponseText: rawText,
    );
  }
}

// --- BYOK SERVICE IMPLEMENTATION ---

class GeminiReceiptService {
  final String? _apiKey;

  GeminiReceiptService({String? apiKey}) : _apiKey = apiKey;

  static const String defaultSystemInstruction = '''
Bạn là chuyên gia trích xuất tài chính và số hóa hóa đơn, biên nhận, SMS biến động số dư.
Nhiệm vụ của bạn là đọc ảnh hoặc tin nhắn giao dịch và trích xuất JSON thuần túy (RFC 8259).
QUY TẮC BẮT BUỘC:
1. Không đưa thêm bất kỳ ký tự nào ngoài khối JSON (không dùng markdown ```json ... ``` nếu có thể).
2. Schema trả về:
{
  "merchant": "Tên cửa hàng, đối tác hoặc người thụ hưởng",
  "amount": 0.0,
  "date": "YYYY-MM-DD",
  "categorySuggestion": "Ăn uống / Mua sắm / Di chuyển / Hóa đơn / Giáo dục / v.v.",
  "envelopeType": "needs" | "wants" | "savings",
  "confidence": 0.98,
  "items": [
    {
      "name": "Tên hàng hóa/dịch vụ",
      "quantity": 1,
      "price": 0.0
    }
  ]
}
''';

  /// Scans image bytes using Google Gemini 2.5 Flash
  Future<GeminiReceiptScanResult> scanReceiptImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    String? customPrompt,
  }) async {
    final key = _apiKey;
    if (key == null || key.trim().isEmpty) {
      throw StateError(
        'Gemini API Key (BYOK) chưa được cấu hình. Vui lòng nhập API Key trong mục Cài đặt.',
      );
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: key,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.1,
      ),
      systemInstruction: Content.system(customPrompt ?? defaultSystemInstruction),
    );

    final promptText = TextPart(
      'Hãy đọc hóa đơn/biến động số dư đính kèm và trích xuất toàn bộ trường dữ liệu theo định dạng JSON.',
    );
    final imagePart = DataPart(mimeType, imageBytes);

    try {
      final response = await model.generateContent([
        Content.multi([promptText, imagePart])
      ]);

      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) {
        throw StateError('Gemini 2.5 Flash không phản hồi nội dung văn bản.');
      }

      // Sanitize JSON response if wrapped in markdown blocks
      String cleanedJson = rawText.trim();
      if (cleanedJson.startsWith('```json')) {
        cleanedJson = cleanedJson.replaceFirst('```json', '');
      }
      if (cleanedJson.startsWith('```')) {
        cleanedJson = cleanedJson.replaceFirst('```', '');
      }
      if (cleanedJson.endsWith('```')) {
        cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
      }
      cleanedJson = cleanedJson.trim();

      final decoded = jsonDecode(cleanedJson) as Map<String, dynamic>;
      return GeminiReceiptScanResult.fromJson(decoded, rawText);
    } on FormatException catch (e) {
      throw FormatException('Lỗi giải mã cấu trúc JSON từ Gemini: ${e.message}');
    } catch (e) {
      throw Exception('Lỗi xử lý OCR Gemini Vision: $e');
    }
  }
}

// --- RIVERPOD SERVICE PROVIDER ---

final geminiApiKeyProvider = StateProvider<String?>((ref) => null);

final geminiReceiptServiceProvider = Provider<GeminiReceiptService>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  return GeminiReceiptService(apiKey: apiKey);
});