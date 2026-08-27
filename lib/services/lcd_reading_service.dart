import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'ocr_service.dart';

/// Extracts the meter's LCD from a full-resolution photo and enhances it
/// before OCR. It is designed for seven-segment displays behind glass.
class LcdReadingService {
  LcdReadingService._();
  static final LcdReadingService instance = LcdReadingService._();

  Future<OCRScanResult> readFromPhoto(String imagePath) async {
    final original = await OCRService.instance.processImage(
      InputImage.fromFilePath(imagePath),
    );

    final source = img.decodeImage(await File(imagePath).readAsBytes());
    if (source == null) return original;
    // A full-frame result can confuse a small number printed elsewhere on the
    // meter (for example model 12) with the LCD. Use overlapping crops because
    // different phone cameras frame the LCD at different heights.
    final crops = <img.Image>[
      _crop(source, 0.05, 0.16, 0.90, 0.30),
      _crop(source, 0.08, 0.22, 0.84, 0.28),
      _crop(source, 0.10, 0.28, 0.80, 0.24),
      _crop(source, 0.12, 0.12, 0.76, 0.24),
    ];

    final readings = <int, int>{};
    OCRScanResult? bestResult;
    var bestCount = 0;
    for (var cropIndex = 0; cropIndex < crops.length; cropIndex++) {
      final passes = <img.Image>[
        _enhance(crops[cropIndex], contrast: 2.2, brightness: 0.05),
        _enhance(crops[cropIndex], contrast: 3.0, brightness: 0.10),
        _enhance(crops[cropIndex], contrast: 1.7, brightness: -0.05),
      ];
      for (var passIndex = 0; passIndex < passes.length; passIndex++) {
        final directory = await getTemporaryDirectory();
        final file =
            File('${directory.path}/meter_lcd_${cropIndex}_$passIndex.jpg');
        await file.writeAsBytes(img.encodeJpg(passes[passIndex], quality: 98));
        final result = await OCRService.instance.processImage(
          InputImage.fromFilePath(file.path),
        );
        final reading = result.meterReading;
        if (reading != null) {
          final count = (readings[reading] ?? 0) + 1;
          readings[reading] = count;
          if (bestResult == null || count > bestCount) {
            bestResult = result;
            bestCount = count;
          }
        }
      }
    }
    final lcdResult = bestResult;
    if (lcdResult == null) return original;

    // Cropping isolates the LCD, so its OCR result usually loses the serial
    // printed elsewhere on the meter. Keep the strongest reading while
    // carrying identity fields from the original full-frame scan.
    return OCRScanResult(
      meterReading: lcdResult.meterReading ?? original.meterReading,
      referenceNo: original.referenceNo,
      consumerNo: original.consumerNo,
      meterNo: original.meterNo ?? lcdResult.meterNo,
      consumerName: original.consumerName,
      billDate: original.billDate,
      sanctionedLoad: original.sanctionedLoad,
      isProtected: original.isProtected,
      rawText: original.rawText,
      detectedLines: original.detectedLines,
      confidence: lcdResult.confidence,
    );
  }

  img.Image _crop(
      img.Image image, double x, double y, double width, double height) {
    final left = (image.width * x).round().clamp(0, image.width - 1);
    final top = (image.height * y).round().clamp(0, image.height - 1);
    final cropWidth =
        (image.width * width).round().clamp(1, image.width - left);
    final cropHeight =
        (image.height * height).round().clamp(1, image.height - top);
    return img.copyCrop(image,
        x: left, y: top, width: cropWidth, height: cropHeight);
  }

  img.Image _enhance(img.Image source,
      {required double contrast, required double brightness}) {
    final gray = img.grayscale(source);
    final contrasted =
        img.adjustColor(gray, contrast: contrast, brightness: brightness);
    return img.copyResize(contrasted,
        width: contrasted.width * 2, interpolation: img.Interpolation.cubic);
  }
}
