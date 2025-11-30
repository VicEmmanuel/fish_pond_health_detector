import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FishpondClassifier {
  FishpondClassifier._();
  static final instance = FishpondClassifier._();

  late Interpreter _interpreter;
  late List<String> _labels;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Load model from assets (path must match pubspec.yaml)
    _interpreter = await Interpreter.fromAsset(
      'assets/edge_impulse/model.tflite',
    );

    // Load labels
    final raw =
    await rootBundle.loadString('assets/edge_impulse/labels.txt');
    _labels = raw.split('\n').where((e) => e.trim().isNotEmpty).toList();

    _initialized = true;
  }

  List<String> get labels => _labels;

  /// Classify an image file.
  /// Returns: { "label": String, "score": double, "probs": Map<String,double> }
  Future<Map<String, dynamic>> classify(File imageFile) async {
    if (!_initialized) {
      throw StateError('FishpondClassifier.init() not called');
    }

    // 1. Decode and resize to 96x96 RGB
    final bytes = await imageFile.readAsBytes();
    img.Image? base = img.decodeImage(bytes);
    if (base == null) {
      throw Exception('Unable to decode image');
    }
    final resized = img.copyResize(base, width: 96, height: 96);

    // 2. Build input tensor (int8 quantized)
    final inputTensor = _interpreter.getInputTensor(0);
    final inputShape = inputTensor.shape; // expected: [1, 96, 96, 3]

    if (inputShape.length != 4 ||
        inputShape[1] != 96 ||
        inputShape[2] != 96 ||
        inputShape[3] != 3) {
      throw Exception('Unexpected input shape: $inputShape');
    }

    // Quantization params for input
    final inScale = inputTensor.params.scale;
    final inZeroPoint = inputTensor.params.zeroPoint;

    // int8 matrix [96][96][3]
    final imageMatrix = List.generate(
      96,
          (y) => List.generate(
        96,
            (x) => List<int>.filled(3, 0),
      ),
    );

    for (int y = 0; y < 96; y++) {
      for (int x = 0; x < 96; x++) {
        // In image 4.x this returns a Pixel object
        final pixel = resized.getPixel(x, y);

        final r = pixel.r.toDouble(); // 0..255
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        // Quantize using tensor scale/zeroPoint
        imageMatrix[y][x][0] =
            (r / inScale + inZeroPoint).round().clamp(-128, 127);
        imageMatrix[y][x][1] =
            (g / inScale + inZeroPoint).round().clamp(-128, 127);
        imageMatrix[y][x][2] =
            (b / inScale + inZeroPoint).round().clamp(-128, 127);
      }
    }

    final input = [imageMatrix]; // [1, 96, 96, 3]

    // 3. Prepare output buffer (int8 → dequantize)
    final outputTensor = _interpreter.getOutputTensor(0);
    final outputShape = outputTensor.shape; // [1, numClasses]
    final numClasses = outputShape[1];

    final rawOut = List.generate(1, (_) => List.filled(numClasses, 0));
    _interpreter.run(input, rawOut);

    final outScale = outputTensor.params.scale;
    final outZeroPoint = outputTensor.params.zeroPoint;

    // Dequantize logits
    final logits = List<double>.generate(
      numClasses,
          (i) => (rawOut[0][i] - outZeroPoint) * outScale,
    );

    // 4. Softmax → probabilities
    final sumExp =
    logits.map((e) => math.exp(e)).reduce((a, b) => a + b);
    final probs =
    logits.map((e) => math.exp(e) / sumExp).toList();

    int bestIdx = 0;
    double bestScore = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > bestScore) {
        bestScore = probs[i];
        bestIdx = i;
      }
    }

    final bestLabel = _labels[bestIdx];

    return {
      'label': bestLabel,
      'score': bestScore,
      'probs': Map.fromIterables(_labels, probs),
    };
  }

  void dispose() {
    _interpreter.close();
  }
}
