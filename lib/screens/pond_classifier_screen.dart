import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/fishpond_classifier.dart';

class PondClassifierScreen extends StatefulWidget {
  const PondClassifierScreen({super.key});

  @override
  State<PondClassifierScreen> createState() => _PondClassifierScreenState();
}

class _PondClassifierScreenState extends State<PondClassifierScreen>
    with SingleTickerProviderStateMixin {
  File? _image;
  Map<String, dynamic>? _result;
  bool _loading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    FishpondClassifier.instance.init();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickAndClassify() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _result = null;
      _loading = true;
    });
    _animController.forward(from: 0);

    try {
      final res = await FishpondClassifier.instance.classify(File(picked.path));
      setState(() => _result = res);
    } catch (e) {
      setState(() => _result = {'error': e.toString()});
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _result?['label'] as String?;
    final score = _result?['score'] as double?;
    final error = _result?['error'];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Pond Health AI',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: 0.5,
            color: Colors.white
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Animated background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0E21),
                  const Color(0xFF1D1E33),
                  const Color(0xFF0A0E21),
                ],
              ),
            ),
          ),
          // Floating orbs effect
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.cyan.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Image preview card
                  Expanded(
                    child: _buildImageCard(),
                  ),
                  const SizedBox(height: 24),
                  // Result section
                  if (_loading) _buildLoadingIndicator(),
                  if (!_loading && error != null) _buildErrorCard(error),
                  if (!_loading && label != null && error == null)
                    _buildResultCard(label, score),
                  const SizedBox(height: 24),
                  // Action button
                  _buildActionButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: _image != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    _image!,
                    fit: BoxFit.cover,
                  ),
                  // Subtle overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
                : _buildEmptyState(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.cyan.withOpacity(0.2),
                  Colors.purple.withOpacity(0.2),
                ],
              ),
            ),
            child: Icon(
              Icons.water,
              size: 64,
              color: Colors.cyan.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Upload Pond Image',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap below to analyze water quality',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.cyan.withOpacity(0.1),
              Colors.purple.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.cyan.shade300,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Analyzing...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(dynamic error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.15),
            Colors.red.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade300,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '$error',
              style: TextStyle(
                color: Colors.red.shade200,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(String label, double? score) {
    final isProblem = label == 'problem';
    final statusColor = isProblem ? Colors.red : Colors.green;
    final statusIcon = isProblem ? Icons.warning_rounded : Icons.check_circle_rounded;
    final statusText = isProblem ? 'ISSUE DETECTED' : 'HEALTHY';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withOpacity(0.2),
              statusColor.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: statusColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withOpacity(0.2),
              ),
              child: Icon(
                statusIcon,
                size: 48,
                color: statusColor.shade300,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: statusColor.shade300,
                letterSpacing: 1.2,
              ),
            ),
            if (score != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 18,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Confidence: ${(score * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.cyan.shade400,
            Colors.blue.shade600,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _pickAndClassify,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _image == null ? Icons.add_photo_alternate : Icons.refresh,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  _image == null ? 'Select Image' : 'Analyze Another',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}