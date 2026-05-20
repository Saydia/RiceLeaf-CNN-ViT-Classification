import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:developer';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class Home extends StatefulWidget {
  final List<CameraDescription> cameras;
  const Home({Key? key, required this.cameras}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late CameraController cameraController;
  Interpreter? interpreter;
  List<String> labels = [];
  bool isCameraInitialized = false;
  bool isModelLoaded = false;
  bool isProcessing = false;
  String? result;
  File? _image;

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      initCamera(widget.cameras[0]);
    }
    loadModel();
    // loadLabels() will be called after first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadLabels();
    });
  }

  Future<void> initCamera(CameraDescription cameraDescription) async {
    cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
    );
    await cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        isCameraInitialized = true;
      });
    });
  }

  Future<void> loadModel() async {
    try {
      print('Starting to load TensorFlow Lite model...');
      // Add a small delay to ensure the app is fully initialized
      await Future.delayed(const Duration(milliseconds: 100));

      // Try to load using rootBundle first
      try {
        final ByteData modelData = await rootBundle.load(
          'assets/model_unquant.tflite',
        );
        final Uint8List modelBytes = modelData.buffer.asUint8List();
        print('Model loaded from rootBundle, size: ${modelBytes.length} bytes');
        interpreter = Interpreter.fromBuffer(modelBytes);
      } catch (e) {
        print('Failed to load with rootBundle: $e, trying fromAsset...');
        interpreter = await Interpreter.fromAsset(
          'assets/model_unquant.tflite',
        );
      }

      print('TensorFlow Lite model loaded successfully');
      print('Input tensor shape: ${interpreter!.getInputTensors()}');
      print('Output tensor shape: ${interpreter!.getOutputTensors()}');
      if (mounted) {
        setState(() {
          isModelLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading TensorFlow Lite model: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          isModelLoaded = false;
        });
      }
    }
  }

  Future<void> loadLabels() async {
    try {
      final labelsData = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/labels.txt');
      labels = labelsData
          .split('\n')
          .where((label) => label.isNotEmpty)
          .toList();
      print('Labels loaded: ${labels.length} classes');
      for (int i = 0; i < labels.length; i++) {
        print('Class $i: ${labels[i]}');
      }
    } catch (e) {
      print('Error loading labels: $e');
    }
  }

  // Validate if the image contains rice leaf before classification
  bool validateRiceLeafImage(img.Image image) {
    int greenPixels = 0;
    int brownPixels = 0;
    int validColorPixels = 0;
    int totalSamples = 0;

    // Sample pixels (check every 8th pixel for performance)
    for (int i = 0; i < image.height; i += 8) {
      for (int j = 0; j < image.width; j += 8) {
        totalSamples++;
        var pixel = image.getPixel(j, i);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // Check for green vegetation colors (healthy leaf)
        if (g > r && g > b && g > 60 && g < 200) {
          greenPixels++;
          validColorPixels++;
        }
        // Check for brown/yellow colors (diseased leaf)
        else if ((r > 80 && g > 60 && b < 100 && r > b) || // Brown
            (r > 100 && g > 80 && b < 120 && r > b && g > b)) {
          // Yellow-brown
          brownPixels++;
          validColorPixels++;
        }
      }
    }

    double vegetationRatio = validColorPixels / totalSamples;

    print(
      'Vegetation analysis - Green: $greenPixels, Brown: $brownPixels, Total valid: $validColorPixels',
    );
    print(
      'Total samples: $totalSamples, Vegetation ratio: ${(vegetationRatio * 100).toStringAsFixed(1)}%',
    );

    // Require at least 25% vegetation-like colors for rice leaf
    return vegetationRatio >= 0.25;
  }

  // Check if prediction confidence suggests a valid rice leaf
  bool validatePredictionConfidence(List<double> predictions) {
    double maxConfidence = predictions.reduce((a, b) => a > b ? a : b);
    double secondMaxConfidence = 0.0;

    // Find second highest confidence
    for (double conf in predictions) {
      if (conf != maxConfidence && conf > secondMaxConfidence) {
        secondMaxConfidence = conf;
      }
    }

    double confidenceGap = maxConfidence - secondMaxConfidence;

    print('Max confidence: ${(maxConfidence * 100).toStringAsFixed(1)}%');
    print(
      'Second max confidence: ${(secondMaxConfidence * 100).toStringAsFixed(1)}%',
    );
    print('Confidence gap: ${(confidenceGap * 100).toStringAsFixed(1)}%');

    // Require reasonable confidence (30%) and clear distinction (15% gap)
    return maxConfidence >= 0.30 && confidenceGap >= 0.15;
  }

  img.Image preprocessImageTeachableMachine(img.Image image, int targetSize) {
    img.Image resized = img.copyResize(
      image,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.linear,
    );
    return resized;
  }

  Float32List imageToFloat32ListTeachableMachine(img.Image image) {
    var convertedBytes = Float32List(1 * 224 * 224 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (int i = 0; i < 224; i++) {
      for (int j = 0; j < 224; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }
    return convertedBytes;
  }

  String processPredictionResults(List<double> predictions) {
    if (predictions.isEmpty) return 'No predictions available';

    double maxConfidence = 0;
    int predictedIndex = -1;

    for (int i = 0; i < predictions.length && i < labels.length; i++) {
      if (predictions[i] > maxConfidence) {
        maxConfidence = predictions[i];
        predictedIndex = i;
      }
    }

    print(
      'Best prediction: ${labels[predictedIndex]} with ${(maxConfidence * 100).toStringAsFixed(1)}% confidence',
    );

    // Use stricter threshold (40%) for disease classification
    if (maxConfidence > 0.40 && predictedIndex < labels.length) {
      return '${labels[predictedIndex]}\n${(maxConfidence * 100).toStringAsFixed(1)}% confidence';
    } else {
      return 'Uncertain prediction\n${(maxConfidence * 100).toStringAsFixed(1)}% confidence\nPlease use a clearer rice leaf image';
    }
  }

  Future<void> runInference(File imageFile) async {
    try {
      print('Starting runInference method');

      if (!isModelLoaded || interpreter == null) {
        print('Model not loaded yet or interpreter is null');
        setState(() {
          result = 'Error: Model not loaded';
          isProcessing = false;
        });
        return;
      }

      if (!await imageFile.exists()) {
        print('Image file does not exist: ${imageFile.path}');
        setState(() {
          result = 'Error: Image file does not exist';
          isProcessing = false;
        });
        return;
      }

      print('Starting inference on image: ${imageFile.path}');
      setState(() {
        result = 'Analyzing image...';
      });

      final imageBytes = await imageFile.readAsBytes();
      print('Image bytes loaded: ${imageBytes.length} bytes');

      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        print('Could not decode image');
        setState(() {
          result = 'Error: Could not decode image';
          isProcessing = false;
        });
        return;
      }

      print('Image loaded: ${originalImage.width}x${originalImage.height}');

      // STEP 1: Validate if image contains rice leaf
      bool isValidRiceLeaf = validateRiceLeafImage(originalImage);
      if (!isValidRiceLeaf) {
        setState(() {
          result =
              'Invalid Image!\n\nThis doesn\'t appear to be a rice leaf image.\nPlease capture a clear image of a rice leaf.';
          isProcessing = false;
        });
        return;
      }

      setState(() {
        result = 'Valid rice leaf detected. Running disease analysis...';
      });

      img.Image processedImage = preprocessImageTeachableMachine(
        originalImage,
        224,
      );
      print(
        'Image preprocessed to: ${processedImage.width}x${processedImage.height}',
      );

      Float32List inputTensor = imageToFloat32ListTeachableMachine(
        processedImage,
      );
      print('Input tensor prepared, length: ${inputTensor.length}');

      var outputTensor = List.filled(
        1 * labels.length,
        0.0,
      ).reshape([1, labels.length]);
      print('Output tensor prepared for ${labels.length} classes');

      print('Running interpreter...');
      interpreter!.run(inputTensor.reshape([1, 224, 224, 3]), outputTensor);
      print('Inference completed');

      List<double> predictions = outputTensor[0].cast<double>();

      // Print all predictions
      for (int i = 0; i < predictions.length && i < labels.length; i++) {
        print('${labels[i]}: ${(predictions[i] * 100).toStringAsFixed(1)}%');
      }

      // STEP 2: Validate prediction confidence
      bool isValidPrediction = validatePredictionConfidence(predictions);
      if (!isValidPrediction) {
        setState(() {
          result =
              'Uncertain Analysis\n\nThe model cannot confidently classify this image.\nPlease try:\n• Better lighting\n• Clearer focus\n• Closer view of the leaf';
          isProcessing = false;
        });
        return;
      }

      String predictionResult = processPredictionResults(predictions);
      print('Final result: $predictionResult');

      setState(() {
        result = predictionResult;
        isProcessing = false;
      });
    } catch (e, stackTrace) {
      print('Error during inference: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        result = 'Error during analysis: $e';
        isProcessing = false;
      });
    }
  }

  Future<void> pickImage(ImageSource source) async {
    if (isProcessing) {
      print('Already processing, ignoring new request');
      return;
    }

    try {
      print('Starting pickImage from source: $source');
      setState(() {
        isProcessing = true;
        result = 'Selecting image...';
      });

      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        print('Image picked: ${imageFile.path}');

        if (await imageFile.exists()) {
          print('Image file exists, size: ${await imageFile.length()} bytes');
          setState(() {
            _image = imageFile;
            result = 'Image selected, starting analysis...';
          });

          await runInference(imageFile);
        } else {
          print('Image file does not exist: ${imageFile.path}');
          setState(() {
            isProcessing = false;
            result = 'Error: Could not access selected image';
          });
        }
      } else {
        print('No image was selected');
        setState(() {
          isProcessing = false;
          result = 'No image selected';
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        isProcessing = false;
        result = 'Error selecting image: $e';
      });
    }
  }

  @override
  void dispose() {
    if (isCameraInitialized) {
      cameraController.dispose();
    }
    interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rice Leaf Disease Detection',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E8), Color(0xFFF1F8E9)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.eco, size: 40, color: Color(0xFF2E7D32)),
                      const SizedBox(height: 8),
                      Text(
                        'Model Status: ${isModelLoaded ? 'Ready' : 'Loading...'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Classes: ${labels.length}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _image == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 80,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Select an image to analyze',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          )
                        : Image.file(
                            _image!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Analysis Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: isProcessing
                            ? const Column(
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2E7D32),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Processing...',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              )
                            : Text(
                                result ??
                                    'No analysis performed yet\n\nPlease select a clear image of a rice leaf for disease detection.',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text(
                        'Camera',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => pickImage(ImageSource.gallery),
                      icon: const Icon(
                        Icons.photo_library,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Gallery',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF388E3C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
