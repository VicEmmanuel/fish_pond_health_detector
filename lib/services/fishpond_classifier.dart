import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

enum FishpondModelVariant { legacy, edgeImpulseV3 }

enum FishpondResizeMode { squash, fitShortest }

enum FishpondInputScalingMode { rawBytes, normalizedZeroToOne }

class FishpondModelConfig {
  const FishpondModelConfig({
    required this.variant,
    required this.modelAssetPath,
    required this.labelsAssetPath,
    required this.resizeMode,
    required this.inputScalingMode,
  });

  final FishpondModelVariant variant;
  final String modelAssetPath;
  final String labelsAssetPath;
  final FishpondResizeMode resizeMode;
  final FishpondInputScalingMode inputScalingMode;
}

class FishpondImagePreprocessor {
  const FishpondImagePreprocessor._();

  static img.Image resizeForModel(
    img.Image source, {
    required int targetWidth,
    required int targetHeight,
    required FishpondResizeMode resizeMode,
  }) {
    switch (resizeMode) {
      case FishpondResizeMode.squash:
        return img.copyResize(source, width: targetWidth, height: targetHeight);
      case FishpondResizeMode.fitShortest:
        final cropSize = _calculateCenteredCrop(
          srcWidth: source.width,
          srcHeight: source.height,
          dstWidth: targetWidth,
          dstHeight: targetHeight,
        );

        final cropped = img.copyCrop(
          source,
          x: (source.width - cropSize.$1) ~/ 2,
          y: (source.height - cropSize.$2) ~/ 2,
          width: cropSize.$1,
          height: cropSize.$2,
        );

        return img.copyResize(
          cropped,
          width: targetWidth,
          height: targetHeight,
        );
    }
  }

  static (int, int) _calculateCenteredCrop({
    required int srcWidth,
    required int srcHeight,
    required int dstWidth,
    required int dstHeight,
  }) {
    if (srcWidth > srcHeight) {
      return ((dstWidth * srcHeight) ~/ dstHeight, srcHeight);
    }

    return (srcWidth, (dstHeight * srcWidth) ~/ dstWidth);
  }
}

class FishpondClassifier {
  FishpondClassifier._();
  static final instance = FishpondClassifier._();

  static const FishpondModelVariant defaultModel =
      FishpondModelVariant.edgeImpulseV3;

  static const Map<FishpondModelVariant, FishpondModelConfig> _configs = {
    FishpondModelVariant.legacy: FishpondModelConfig(
      variant: FishpondModelVariant.legacy,
      modelAssetPath: 'assets/edge_impulse/model.tflite',
      labelsAssetPath: 'assets/edge_impulse/labels.txt',
      resizeMode: FishpondResizeMode.squash,
      inputScalingMode: FishpondInputScalingMode.rawBytes,
    ),
    FishpondModelVariant.edgeImpulseV3: FishpondModelConfig(
      variant: FishpondModelVariant.edgeImpulseV3,
      modelAssetPath: 'assets/edge_impulse/model_two.tflite',
      labelsAssetPath: 'assets/edge_impulse/labels.txt',
      resizeMode: FishpondResizeMode.fitShortest,
      inputScalingMode: FishpondInputScalingMode.normalizedZeroToOne,
    ),
  };

  late Interpreter _interpreter;
  late List<String> _labels;
  bool _initialized = false;
  FishpondModelVariant? _activeModel;
  Future<void>? _initFuture;

  Future<void> init({FishpondModelVariant model = defaultModel}) {
    if (_initialized && _activeModel == model) {
      return Future.value();
    }

    if (_initFuture != null && _activeModel == model) {
      return _initFuture!;
    }

    _activeModel = model;
    final future = _loadModel(_configs[model]!);
    late final Future<void> wrappedFuture;
    wrappedFuture = future.whenComplete(() {
      if (identical(_initFuture, wrappedFuture)) {
        _initFuture = null;
      }
    });
    _initFuture = wrappedFuture;
    return _initFuture!;
  }

  Future<void> _loadModel(FishpondModelConfig config) async {
    if (_initialized) {
      _interpreter.close();
      _initialized = false;
    }

    _interpreter = await Interpreter.fromAsset(config.modelAssetPath);

    final raw = await rootBundle.loadString(config.labelsAssetPath);
    _labels = raw.split('\n').where((e) => e.trim().isNotEmpty).toList();

    _initialized = true;
  }

  List<String> get labels => _labels;
  FishpondModelVariant? get activeModel => _activeModel;

  Future<Map<String, dynamic>> classify(
    File imageFile, {
    FishpondModelVariant model = defaultModel,
  }) async {
    await init(model: model);

    final config = _configs[_activeModel]!;

    final bytes = await imageFile.readAsBytes();
    final base = img.decodeImage(bytes);
    if (base == null) {
      throw Exception('Unable to decode image');
    }

    final inputTensor = _interpreter.getInputTensor(0);
    final inputShape = inputTensor.shape;

    if (inputShape.length != 4 || inputShape[0] != 1 || inputShape[3] != 3) {
      throw Exception('Unexpected input shape: $inputShape');
    }

    final inputHeight = inputShape[1];
    final inputWidth = inputShape[2];
    final resized = FishpondImagePreprocessor.resizeForModel(
      base,
      targetWidth: inputWidth,
      targetHeight: inputHeight,
      resizeMode: config.resizeMode,
    );

    final input = [
      List.generate(
        inputHeight,
        (y) => List.generate(inputWidth, (x) => List<num>.filled(3, 0)),
      ),
    ];

    final inScale = inputTensor.params.scale;
    final inZeroPoint = inputTensor.params.zeroPoint;
    final inputType = inputTensor.type;

    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = resized.getPixel(x, y);
        final channels = [
          pixel.r.toDouble(),
          pixel.g.toDouble(),
          pixel.b.toDouble(),
        ];

        for (int channel = 0; channel < 3; channel++) {
          input[0][y][x][channel] = _encodeInputValue(
            rawValue: channels[channel],
            scalingMode: config.inputScalingMode,
            tensorType: inputType,
            scale: inScale,
            zeroPoint: inZeroPoint,
          );
        }
      }
    }

    final outputTensor = _interpreter.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    if (outputShape.length != 2 || outputShape[0] != 1) {
      throw Exception('Unexpected output shape: $outputShape');
    }

    final numClasses = outputShape[1];
    if (_labels.length != numClasses) {
      throw Exception(
        'Labels count (${_labels.length}) does not match model output '
        'classes ($numClasses)',
      );
    }

    final outputType = outputTensor.type;
    final rawOut = [List<num>.filled(numClasses, 0)];
    _interpreter.run(input, rawOut);

    final outScale = outputTensor.params.scale;
    final outZeroPoint = outputTensor.params.zeroPoint;
    final logits = List<double>.generate(
      numClasses,
      (i) => _decodeOutputValue(
        rawValue: rawOut[0][i],
        tensorType: outputType,
        scale: outScale,
        zeroPoint: outZeroPoint,
      ),
    );

    final maxLogit = logits.reduce(math.max);
    final expValues = logits
        .map((value) => math.exp(value - maxLogit))
        .toList();
    final sumExp = expValues.reduce((a, b) => a + b);
    final probs = expValues.map((value) => value / sumExp).toList();

    int bestIdx = 0;
    double bestScore = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > bestScore) {
        bestScore = probs[i];
        bestIdx = i;
      }
    }

    return {
      'label': _labels[bestIdx],
      'score': bestScore,
      'probs': Map.fromIterables(_labels, probs),
      'model': _activeModel?.name,
    };
  }

  num _encodeInputValue({
    required double rawValue,
    required FishpondInputScalingMode scalingMode,
    required TensorType tensorType,
    required double scale,
    required int zeroPoint,
  }) {
    final value = scalingMode == FishpondInputScalingMode.rawBytes
        ? rawValue
        : rawValue / 255.0;

    switch (tensorType) {
      case TensorType.int8:
        return (value / scale + zeroPoint).round().clamp(-128, 127);
      case TensorType.uint8:
        return (value / scale + zeroPoint).round().clamp(0, 255);
      case TensorType.float32:
        return value;
      default:
        throw UnsupportedError('Unsupported input tensor type: $tensorType');
    }
  }

  double _decodeOutputValue({
    required num rawValue,
    required TensorType tensorType,
    required double scale,
    required int zeroPoint,
  }) {
    switch (tensorType) {
      case TensorType.int8:
      case TensorType.uint8:
        return (rawValue.toDouble() - zeroPoint) * scale;
      case TensorType.float32:
        return rawValue.toDouble();
      default:
        throw UnsupportedError('Unsupported output tensor type: $tensorType');
    }
  }

  void dispose() {
    if (_initialized) {
      _interpreter.close();
      _initialized = false;
    }
    _initFuture = null;
  }
}
