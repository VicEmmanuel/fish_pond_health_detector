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

  group('FishpondOutputPostprocessor', () {
    test('keeps probability outputs in probability space', () {
      final probs = FishpondOutputPostprocessor.toProbabilities([
        0.99,
        0.01,
      ], outputMode: FishpondOutputMode.probabilities);

      expect(probs[0], closeTo(0.99, 0.01));
      expect(probs[1], closeTo(0.01, 0.01));
    });

    test(
      'does not renormalize quantized probability outputs to 100 percent',
      () {
        final probs = FishpondOutputPostprocessor.toProbabilities([
          0.99609375,
          0.0,
        ], outputMode: FishpondOutputMode.probabilities);

        expect(probs[0], closeTo(0.99609375, 0.000001));
        expect(probs[1], 0.0);
      },
    );

    test('softmax is only applied for logits', () {
      final probs = FishpondOutputPostprocessor.toProbabilities([
        2.0,
        -2.0,
      ], outputMode: FishpondOutputMode.logits);

      expect(probs[0], greaterThan(0.95));
      expect(probs[1], lessThan(0.05));
    });
  });

  group('FishpondPredictionDecision', () {
    test('marks low-score results as uncertain', () {
      final decision = FishpondPredictionDecision.evaluate(
        ['normal', 'problem'],
        [0.74, 0.26],
      );

      expect(decision.isUncertain, isTrue);
      expect(decision.label, 'uncertain');
      expect(decision.predictedLabel, 'normal');
    });

    test('marks close results as uncertain', () {
      final decision = FishpondPredictionDecision.evaluate(
        ['normal', 'problem'],
        [0.88, 0.80],
      );

      expect(decision.isUncertain, isTrue);
      expect(decision.label, 'uncertain');
      expect(decision.reason, contains('close'));
    });

    test('returns winning label when score and margin are strong', () {
      final decision = FishpondPredictionDecision.evaluate(
        ['normal', 'problem'],
        [0.93, 0.07],
      );

      expect(decision.isUncertain, isFalse);
      expect(decision.label, 'normal');
      expect(decision.predictedLabel, 'normal');
    });
  });
}
