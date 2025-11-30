# Fishpond Health Detector – Mobile App

Android mobile app that uses an Edge Impulse image classification model to detect **normal** vs **problem** fishpond conditions from images.

The app lets a user capture or pick a pond photo, runs on-device inference, and shows whether the pond looks **normal** or there are **problems** based on the trained model.

---

## Features

- Capture image from camera or pick from gallery
- Run on-device ML inference using an Edge Impulse model
- Predict one of two classes:
    - `normal`
    - `problem`
- Show prediction label and confidence score
- Simple UI designed for quick checks in the field

---

## Tech Stack

- **Framework:** Flutter
- **Language:** Dart
- **Target platform:** Android
- **ML runtime:** TensorFlow Lite (via Edge Impulse export / TFLite integration)
- **Model:** Edge Impulse “Transfer Learning (Images)” model
    - Input: 96×96 image
    - Output classes: `normal`, `problem`

---

## Project Structure (mobile app)

```text
.
├─ lib/
│  ├─ main.dart                 # App entry point
│  ├─ screens/                  # pond_classifier_screen.dart
│  ├─ widgets/                  # Reusable widgets
│  ├─ ml/
│  │  ├─ fishpond_classifier.dart   # Model loading + inference
│  │  └─ image_preprocessing.dart   # Resize/normalize helpers
│  └─ ...
├─ assets/
│  └─ edge_impulse/
│     ├─ model.tflite          # Exported model from Edge Impulse
│     └─ labels.txt            # Class labels (normal, problem)
├─ android/
├─ ios/
├─ pubspec.yaml
└─ ...
