import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/images/logo.png');
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes)!;

  // Let's create assets/icon directory if not exists
  Directory('assets/icon').createSync(recursive: true);

  // Let's create an edge-to-edge filled icon (512x512)
  // The yellow background in the logo is around (R: 254, G: 215..225, B: 40..60)
  // Let's crop the yellow region or fill the corners with the yellow gradient.
  
  // Crop the inner squircle to fill 100% of the canvas
  // The inner yellow area starts around inset 38 pixels on each side
  final int cropInset = 42;
  final cropped = img.copyCrop(
    image,
    x: cropInset,
    y: cropInset,
    width: image.width - (cropInset * 2),
    height: image.height - (cropInset * 2),
  );

  // Resize back to 512x512
  final resized = img.copyResize(cropped, width: 512, height: 512, interpolation: img.Interpolation.cubic);

  // Also let's ensure the 4 corner pixels are filled with the background yellow rather than any grey remnants
  final yellowColor = img.ColorRgba8(254, 219, 56, 255);
  // Fill any non-yellow corner remnant
  for (int y = 0; y < 512; y++) {
    for (int x = 0; x < 512; x++) {
      final p = resized.getPixel(x, y);
      // If it's grayish (R ~ G ~ B > 200 and not yellow where R > 230, G > 180, B < 120)
      if (p.r > 200 && p.g > 200 && p.b > 180 && (p.r - p.b).abs() < 50) {
        resized.setPixel(x, y, yellowColor);
      }
    }
  }

  // Save as standard app_icon.png
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(resized));
  print('Saved assets/icon/app_icon.png (512x512, edge-to-edge yellow)');

  // Also create a foreground for adaptive icon (where the meter is safely centered with transparency or padding)
  // On adaptive icons, Android cuts a circle/squircle from the center 66% (340x340 out of 512)
  final fgImage = img.Image(width: 512, height: 512);
  // Fill fgImage with transparent
  img.fill(fgImage, color: img.ColorRgba8(0, 0, 0, 0));
  
  // Scale resized icon down to 72% so it fits comfortably in adaptive icon safe zone
  final int fgSize = (512 * 0.72).round();
  final scaledForFg = img.copyResize(resized, width: fgSize, height: fgSize, interpolation: img.Interpolation.cubic);
  
  final int offset = (512 - fgSize) ~/ 2;
  img.compositeImage(fgImage, scaledForFg, dstX: offset, dstY: offset);
  
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(img.encodePng(fgImage));
  print('Saved assets/icon/app_icon_foreground.png');

  // Also update assets/images/logo.png with the clean edge-to-edge version
  File('assets/images/logo.png').writeAsBytesSync(img.encodePng(resized));
  print('Updated assets/images/logo.png');
}
