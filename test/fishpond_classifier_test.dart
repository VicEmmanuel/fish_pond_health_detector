import 'package:fishpond_edge/services/fishpond_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('FishpondImagePreprocessor', () {
    test('fitShortest uses centered crop before resize', () {
      final source = img.Image(width: 300, height: 100);

      for (int y = 0; y < source.height; y++) {
        for (int x = 0; x < source.width; x++) {
          if (x < 100) {
            source.setPixelRgb(x, y, 255, 0, 0);
          } else if (x < 200) {
            source.setPixelRgb(x, y, 0, 255, 0);
          } else {
            source.setPixelRgb(x, y, 0, 0, 255);
          }
        }
      }

      final resized = FishpondImagePreprocessor.resizeForModel(
        source,
        targetWidth: 50,
        targetHeight: 50,
        resizeMode: FishpondResizeMode.fitShortest,
      );

      final centerPixel = resized.getPixel(25, 25);
      expect(centerPixel.g, greaterThan(200));
      expect(centerPixel.r, lessThan(30));
      expect(centerPixel.b, lessThan(30));
    });

    test('squash preserves side colors instead of center-cropping', () {
      final source = img.Image(width: 300, height: 100);

      for (int y = 0; y < source.height; y++) {
        for (int x = 0; x < source.width; x++) {
          if (x < 100) {
            source.setPixelRgb(x, y, 255, 0, 0);
          } else if (x < 200) {
            source.setPixelRgb(x, y, 0, 255, 0);
          } else {
            source.setPixelRgb(x, y, 0, 0, 255);
          }
        }
      }

      final resized = FishpondImagePreprocessor.resizeForModel(
        source,
        targetWidth: 50,
        targetHeight: 50,
        resizeMode: FishpondResizeMode.squash,
      );

      final leftPixel = resized.getPixel(5, 25);
      final rightPixel = resized.getPixel(45, 25);

      expect(leftPixel.r, greaterThan(150));
      expect(rightPixel.b, greaterThan(150));
    });
  });
}
