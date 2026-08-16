import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final image = img.Image(width: 1024, height: 1024);
  img.fill(image, color: img.ColorRgb8(0x00, 0x83, 0x8F));
  img.fillCircle(
    image,
    x: 512,
    y: 512,
    radius: 360,
    color: img.ColorRgb8(0xFF, 0xFF, 0xFF),
  );
  img.fillCircle(
    image,
    x: 512,
    y: 512,
    radius: 200,
    color: img.ColorRgb8(0x00, 0x83, 0x8F),
  );
  final bytes = img.encodePng(image);
  File('assets/icon_placeholder.png').writeAsBytesSync(bytes);
  // ignore: avoid_print
  print('wrote ${bytes.length} bytes');
}
