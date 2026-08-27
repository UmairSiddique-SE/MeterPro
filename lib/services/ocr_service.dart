import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Structured result returned after processing an electricity bill or meter image.
class OCRScanResult {
  final int? meterReading;
  final String? referenceNo;
  final String? consumerNo;
  final String? meterNo;
  final String? consumerName;
  final DateTime? billDate;
  final int? sanctionedLoad;
  final bool? isProtected;
  final String rawText;
  final List<String> detectedLines;
  final double confidence;

  const OCRScanResult({
    this.meterReading,
    this.referenceNo,
    this.consumerNo,
    this.meterNo,
    this.consumerName,
    this.billDate,
    this.sanctionedLoad,
    this.isProtected,
    required this.rawText,
    required this.detectedLines,
    this.confidence = 0.0,
  });

  bool get hasValidData =>
      meterReading != null || referenceNo != null || meterNo != null;

  /// The registration bill scan needs both identifiers printed in Consumer
  /// Detail. This prevents a random 14-digit number from being accepted.
  bool get hasValidBillData =>
      referenceNo != null &&
      referenceNo!.length == 14 &&
      consumerNo != null &&
      consumerNo!.length >= 8 &&
      meterReading != null;

  /// A bill is accepted only when its due/last date belongs to this month.
  bool get isForCurrentMonth {
    final date = billDate;
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  @override
  String toString() {
    return 'OCRScanResult(reading: $meterReading, ref: $referenceNo, consumerNo: $consumerNo, meterNo: $meterNo, name: $consumerName)';
  }
}

/// OCR service powered by Google ML Kit to parse electric meter displays
/// and electricity bills (e.g. FESCO/LESCO/IESCO/MEPCO/DISCO bills).
class OCRService {
  OCRService._();
  static final OCRService instance = OCRService._();

  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Analyzes an [InputImage] using Google ML Kit and extracts structured data.
  Future<OCRScanResult> processImage(InputImage inputImage) async {
    try {
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      return parseRecognizedText(recognizedText.text, recognizedText.blocks);
    } catch (e) {
      return OCRScanResult(
        rawText: 'Error performing OCR: $e',
        detectedLines: const [],
      );
    }
  }

  /// Parses raw recognized text blocks to isolate meter readings, reference numbers, and consumer names.
  OCRScanResult parseRecognizedText(String rawText, List<TextBlock> blocks) {
    final lines = <String>[];
    for (final block in blocks) {
      for (final line in block.lines) {
        final cleanLine = line.text.trim();
        if (cleanLine.isNotEmpty) {
          lines.add(cleanLine);
        }
      }
    }

    final fullText = lines.join('\n');

    final meterReading = _extractMeterReading(lines, fullText);
    final referenceNo = _extractReferenceNumber(lines, fullText);
    final consumerNo = _extractConsumerNumber(lines, fullText);
    final meterNo = _extractMeterNo(lines, fullText);
    final consumerName = _extractConsumerName(lines);
    final billDate = _extractBillDate(fullText);
    final billMonthStr = _extractBillMonthLabel(fullText);
    final sanctionedLoad = _extractSanctionedLoad(fullText);
    final isProtected = _extractProtectedStatus(fullText);

    // If we have a billMonthStr like "JUL 26", try to parse it as a date if billDate is null
    DateTime? finalBillDate = billDate;
    if (finalBillDate == null && billMonthStr != null) {
      finalBillDate = _parseMonthYear(billMonthStr);
    }

    double confidence = 0.0;
    if (meterReading != null) confidence += 0.4;
    if (referenceNo != null) confidence += 0.3;
    if (meterNo != null) confidence += 0.2;
    if (consumerName != null) confidence += 0.1;

    return OCRScanResult(
      meterReading: meterReading,
      referenceNo: referenceNo,
      consumerNo: consumerNo,
      meterNo: meterNo,
      consumerName: consumerName,
      billDate: finalBillDate,
      sanctionedLoad: sanctionedLoad,
      isProtected: isProtected,
      rawText: fullText,
      detectedLines: lines,
      confidence: confidence,
    );
  }

  String? _extractBillMonthLabel(String fullText) {
    // Looks for "BILL MONTH" followed by "JUL 26" or similar
    final match = RegExp(r'BILL\s*MONTH\s*\n?\s*([A-Z]{3})\s*(\d{2})',
            caseSensitive: false)
        .firstMatch(fullText);
    if (match != null) {
      return "${match.group(1)} ${match.group(2)}";
    }

    // Fallback: search for month name and year separately near each other
    const monthsPattern =
        r'(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)';
    final monthYearMatch =
        RegExp('$monthsPattern\\s*\\d{2}', caseSensitive: false)
            .firstMatch(fullText);
    return monthYearMatch?.group(0);
  }

  DateTime? _parseMonthYear(String input) {
    const months = {
      'JAN': 1,
      'FEB': 2,
      'MAR': 3,
      'APR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AUG': 8,
      'SEP': 9,
      'OCT': 10,
      'NOV': 11,
      'DEC': 12,
    };
    final parts = input.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final month = months[parts[0].toUpperCase()];
    final year = int.tryParse(parts[1]);
    if (month != null && year != null) {
      return DateTime(2000 + year, month, 1);
    }
    return null;
  }

  int? _extractSanctionedLoad(String fullText) {
    // Support decimals like 1.5 kW and handle variations in label/unit
    final match = RegExp(
            r'(?:sanctioned\s*load|load|san\s*load)\s*[:.\-]?\s*(\d+(?:\.\d+)?)\s*(?:kw|k\.w|kv|kwh)',
            caseSensitive: false)
        .firstMatch(fullText);
    if (match != null) {
      final value = double.tryParse(match.group(1)!);
      return value?.round();
    }
    return null;
  }

  bool? _extractProtectedStatus(String fullText) {
    if (RegExp(r'\bprotected\b', caseSensitive: false).hasMatch(fullText)) {
      return true;
    }
    if (RegExp(r'\bunprotected\b', caseSensitive: false).hasMatch(fullText)) {
      return false;
    }
    return null;
  }

  /// Extracts numeric meter readings (kWh / units) from extracted lines.
  int? _extractMeterReading(List<String> lines, String fullText) {
    // Digital meters commonly show either "001234 kWh" or "kWh 001234".
    for (final line in lines) {
      final reading = _extractKwhValue(line);
      if (reading != null) return reading;
    }

    // 1. Try to find specifically labeled reading
    final readingKeywords = [
      RegExp(
          r'(?:present|curr(?:ent)?|new|last|prev(?:ious)?)\s*(?:reading|rdg|units?)',
          caseSensitive: false),
      RegExp(r'\b(?:kwh|k\.w\.h|units?|reading|active\s*energy)\b',
          caseSensitive: false),
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final kwRegex in readingKeywords) {
        if (kwRegex.hasMatch(line)) {
          final readingFromSameLine = _extractDigitsFromSegment(line);
          if (readingFromSameLine != null &&
              _isValidReadingRange(readingFromSameLine)) {
            return readingFromSameLine;
          }

          // Check neighbors
          for (int j = i - 2; j <= i + 2; j++) {
            if (j >= 0 && j < lines.length && j != i) {
              final val = _extractDigitsFromSegment(lines[j]);
              if (val != null && _isValidReadingRange(val)) return val;
            }
          }
        }
      }
    }

    // Additional fallback: Look for a 4-6 digit number near "CONSUMER DETAIL" or "UNITS"
    final unitMatch =
        RegExp(r'units\s*[:.\-]?\s*(\d{1,6})', caseSensitive: false)
            .firstMatch(fullText);
    if (unitMatch != null) {
      return int.tryParse(unitMatch.group(1)!);
    }

    return null;
  }

  int? _extractKwhValue(String line) {
    const digitChars = r'[0-9OoIiLlSsZzBb\s.,]{3,14}';
    final patterns = [
      RegExp(
        '(?:k\\s*\\.?\\s*w\\s*\\.?\\s*h|kw/h)\\s*[:=\\-]?\\s*($digitChars)',
        caseSensitive: false,
      ),
      RegExp(
        '($digitChars)\\s*(?:k\\s*\\.?\\s*w\\s*\\.?\\s*h|kw/h)',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      final rawValue = match?.group(1);
      if (rawValue == null) continue;
      // Meter LCDs often show a fractional digit (e.g. 1811.25 kWh). The
      // app stores whole kWh, so keep the integer part instead of allowing
      // OCR to skip it and mistakenly save only the fraction, such as 12.
      final normalized =
          _correctOcrDigitMisreads(rawValue).replaceAll(RegExp(r'\s+'), '');
      final wholeKwh = normalized.split(RegExp(r'[.,]')).first;
      final value = int.tryParse(wholeKwh);
      if (value != null && _isValidReadingRange(value)) return value;
    }
    return null;
  }

  /// Extracts bill 14-digit reference number.
  String? _extractReferenceNumber(List<String> lines, String fullText) {
    final cleanText = fullText.replaceAll(RegExp(r'[\s\-]+'), '');
    final discoRefRegex = RegExp(r'\d{14}');
    final match = discoRefRegex.firstMatch(cleanText);
    return match?.group(0);
  }

  /// Extracts the consumer ID/number printed in Consumer Detail on a bill.
  String? _extractConsumerNumber(List<String> lines, String fullText) {
    final labeled = RegExp(
      r'(?:consumer\s*(?:id|no|number))\s*[:.\-#]?\s*(\d{8,12})',
      caseSensitive: false,
    ).firstMatch(fullText.replaceAll('\n', ' '));
    if (labeled != null) return labeled.group(1);

    for (var i = 0; i + 1 < lines.length; i++) {
      if (RegExp(r'consumer\s*(?:id|no|number)', caseSensitive: false)
          .hasMatch(lines[i])) {
        final value = RegExp(r'\b\d{8,12}\b').firstMatch(lines[i + 1]);
        if (value != null) return value.group(0);
      }
    }
    return null;
  }

  /// Extracts meter serial number (e.g., S-P 86361 or 792623).
  String? _extractMeterNo(List<String> lines, String fullText) {
    // Prefer values next to a bill's meter/serial label. A broad greedy match
    // can swallow the rest of an OCR line and miss the actual meter number.
    final serialLabelRegex = RegExp(
        r'(?:s\.?\s*r\.?\s*no|sr\.?\s*no|serial\s*(?:no|number)?|meter\s*(?:no|number)?|m\.?\s*no|s/n)\s*[:.\-#]?\s*([A-Z0-9][A-Z0-9\s\-]{2,16})',
        caseSensitive: false);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = serialLabelRegex.firstMatch(line);
      if (match != null) {
        final candidate = _normaliseSerialCandidate(match.group(1));
        if (candidate != null) return candidate;
      }

      if (RegExp(r'(?:s\.?\s*r\.?\s*no|sr\.?\s*no|serial|meter\s*(?:no|number)?|m\.?\s*no|s/n)',
                  caseSensitive: false)
              .hasMatch(line) &&
          i + 1 < lines.length) {
        final candidate = _normaliseSerialCandidate(lines[i + 1]);
        if (candidate != null) return candidate;
      }
    }

    // 2. Look for numeric patterns that look like serial numbers (5-9 digits)
    final serialRegex = RegExp(r'\b\d{5,9}\b');
    final matches = serialRegex.allMatches(fullText);
    for (final match in matches) {
      final val = match.group(0);
      if (val != null) return val;
    }

    return null;
  }

  /// Extracts consumer name if "NAME" label is found on electricity bill.
  String? _extractConsumerName(List<String> lines) {
    final nameLabelRegex = RegExp(
        r'(?:consumer\s*name|name\s*&\s*address|name)\s*[:.\-]?\s*([A-Za-z\s]+)',
        caseSensitive: false);
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = nameLabelRegex.firstMatch(line);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.length > 3 && !_isForbiddenNameWord(name)) {
          return name;
        }
      }
      if (RegExp(r'(?:consumer\s*name|name\s*&\s*address|name)',
                  caseSensitive: false)
              .hasMatch(line) &&
          i + 1 < lines.length) {
        final name = lines[i + 1].replaceAll(RegExp(r'[^A-Za-z\s]'), '').trim();
        if (name.length > 3 && !_isForbiddenNameWord(name)) return name;
      }
    }
    return null;
  }

  DateTime? _extractBillDate(String text) {
    // Prefer the payable deadline rather than unrelated dates printed on a
    // bill, such as the previous meter-reading date.
    final dueDateWithMonthName = RegExp(
      r'(?:due|last)\s*date\D{0,25}(0?[1-9]|[12]\d|3[01])\s*(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s*,?\s*((?:20)?\d{2})',
      caseSensitive: false,
    ).firstMatch(text);
    if (dueDateWithMonthName != null) {
      return _dateFromMonthNameMatch(dueDateWithMonthName);
    }

    final dueDateMatch = RegExp(
      r'(?:due|last)\s*date\D{0,20}(0?[1-9]|[12]\d|3[01])[/-](0?[1-9]|1[0-2])[/-]((?:20)?\d{2})',
      caseSensitive: false,
    ).firstMatch(text);
    if (dueDateMatch != null) return _dateFromMatch(dueDateMatch);

    final match = RegExp(
            r'\b(0?[1-9]|[12]\d|3[01])[/-](0?[1-9]|1[0-2])[/-]((?:20)?\d{2})\b')
        .firstMatch(text);
    if (match == null) return null;
    return _dateFromMatch(match);
  }

  DateTime? _dateFromMonthNameMatch(RegExpMatch match) {
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final monthText = match.group(2)!.toLowerCase().substring(0, 3);
    final month = months[monthText];
    if (month == null) return null;
    final yearText = match.group(3)!;
    final year =
        yearText.length == 2 ? 2000 + int.parse(yearText) : int.parse(yearText);
    try {
      return DateTime(year, month, int.parse(match.group(1)!));
    } catch (_) {
      return null;
    }
  }

  DateTime? _dateFromMatch(RegExpMatch match) {
    final yearText = match.group(3)!;
    final year =
        yearText.length == 2 ? 2000 + int.parse(yearText) : int.parse(yearText);
    try {
      return DateTime(
          year, int.parse(match.group(2)!), int.parse(match.group(1)!));
    } catch (_) {
      return null;
    }
  }

  String _correctOcrDigitMisreads(String input) {
    return input
        .replaceAll(RegExp(r'[O|o|D]'), '0')
        .replaceAll(RegExp(r'[I|l|i||]'), '1')
        .replaceAll(RegExp(r'[Z|z]'), '2')
        .replaceAll(RegExp(r'[S|s]'), '5')
        .replaceAll(RegExp(r'[B]'), '8')
        .replaceAll(RegExp(r'[g|q]'), '9');
  }

  String? _normaliseSerialCandidate(String? input) {
    if (input == null) return null;
    final value = input.replaceAll(RegExp(r'[^A-Z0-9-]'), '').toUpperCase();
    if (value.length < 5 || value.length > 14) return null;
    return value;
  }

  int? _extractDigitsFromSegment(String segment) {
    final corrected = _correctOcrDigitMisreads(segment).replaceAll(' ', '');
    final matches = RegExp(r'\d{1,7}').allMatches(corrected);
    for (final match in matches) {
      final str = match.group(0);
      if (str != null) {
        final val = int.tryParse(str);
        if (val != null && _isValidReadingRange(val)) {
          return val;
        }
      }
    }
    return null;
  }

  bool _isValidReadingRange(int reading) {
    return reading >= 1 && reading <= 999999;
  }

  bool _isForbiddenNameWord(String text) {
    final lower = text.toLowerCase();
    return lower.contains('fesco') ||
        lower.contains('bill') ||
        lower.contains('meter') ||
        lower.contains('reading') ||
        lower.contains('tariff');
  }

  void dispose() {
    _textRecognizer.close();
  }
}
