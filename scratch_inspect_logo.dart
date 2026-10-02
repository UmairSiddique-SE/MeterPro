import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/images/logo.png');
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    return;
  }
  print('Image dimensions: ${image.width}x${image.height}');

  // Let's inspect pixel colors at corners and center
  final c00 = image.getPixel(0, 0);
  final cCenter = image.getPixel(image.width ~/ 2, image.height ~/ 2);
  final cTopMid = image.getPixel(image.width ~/ 2, 50);
  print('TopLeft pixel: R=${c00.r}, G=${c00.g}, B=${c00.b}, A=${c00.a}');
  print('Center pixel: R=${cCenter.r}, G=${cCenter.g}, B=${cCenter.b}');
  print('TopMid pixel: R=${cTopMid.r}, G=${cTopMid.g}, B=${cTopMid.b}');
}
