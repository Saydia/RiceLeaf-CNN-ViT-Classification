import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'disease_info.dart';
import 'disease_detail_page.dart';
import 'quick_reference_card.dart';

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
  String? detectedDisease;
  double? detectionConfidence;

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
      ResolutionPreset.high, // Higher resolution for better quality captures
      enableAudio: false, // Disable audio since we only need images
      imageFormatGroup: ImageFormatGroup.jpeg, // Ensure consistent image format
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

      // Configure interpreter options with extended TF ops support
      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;  // Use Android NNAPI for better compatibility

      // Try to load using fromAsset first (preferred method)
      try {
        interpreter = await Interpreter.fromAsset(
          'assets/rice_model.tflite',
          options: options,
        );
        print('Model loaded from fromAsset successfully');
      } catch (e) {
        print('Failed to load with NNAPI options: $e');
        // Try without NNAPI
        final basicOptions = InterpreterOptions()..threads = 2;
        try {
          interpreter = await Interpreter.fromAsset(
            'assets/rice_model.tflite',
            options: basicOptions,
          );
          print('Model loaded with basic options');
        } catch (e2) {
          print('Failed to load with basic options: $e2');
          // Last resort - try without any options
          interpreter = await Interpreter.fromAsset('assets/rice_model.tflite');
          print('Model loaded without options');
        }
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
      // Even if model fails, allow the app to run with manual detection disabled
      if (mounted) {
        setState(() {
          isModelLoaded = false;
        });
        // Show user-friendly message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI model could not be loaded. Please check the model file.'),
            duration: Duration(seconds: 5),
          ),
        );
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
  // Strict validation to reject human faces/skin
  bool validateRiceLeafImage(img.Image image) {
    int greenPixels = 0;
    int brownGreenPixels = 0; // Brown with greenish tint (diseased leaves)
    int skinPixels = 0;
    int grayPixels = 0; // For detecting objects/artificial surfaces
    int bluePixels = 0; // Sky, screens, etc.
    int warmPixels = 0; // Warm tones (R dominant) without green
    int totalSamples = 0;

    // Sample more pixels for better accuracy (every 6th pixel)
    for (int i = 0; i < image.height; i += 6) {
      for (int j = 0; j < image.width; j += 6) {
        totalSamples++;
        var pixel = image.getPixel(j, i);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // Calculate color properties
        int maxVal = [r, g, b].reduce((a, b) => a > b ? a : b);
        int minVal = [r, g, b].reduce((a, b) => a < b ? a : b);
        int saturation = maxVal > 0 ? ((maxVal - minVal) * 100 ~/ maxVal) : 0;
        
        // Calculate ratios for skin detection
        double rgRatio = r / (g + 1.0);
        double rbRatio = r / (b + 1.0);
        double gbRatio = g / (b + 1.0);

        // FIRST: Check for clear green pixels (healthy plant tissue)
        // Green must be clearly dominant
        if (g > r && g > b && g > 60 && (g - r) > 15 && (g - b) > 15) {
          greenPixels++;
          continue;
        }

        // HUMAN SKIN DETECTION - Check this BEFORE brownish plant detection
        // Human skin characteristics: R > G > B, specific ratios, warm undertones
        bool isSkin = false;
        
        if (r > g && g >= b && r > 50) {
          // Very fair/pale skin (pinkish)
          if (r > 200 && g > 160 && b > 150 && rgRatio > 1.0 && rgRatio < 1.25 && 
              saturation < 25) {
            isSkin = true;
          }
          // Light/fair skin
          else if (r > 180 && g > 140 && b > 110 && 
              rgRatio > 1.1 && rgRatio < 1.4 && (r - b) > 30 && (r - b) < 90) {
            isSkin = true;
          }
          // Medium skin / Caucasian tan
          else if (r > 150 && r < 220 && g > 110 && g < 180 && b > 80 && b < 150 && 
              rgRatio > 1.1 && rgRatio < 1.5 && saturation > 10 && saturation < 50) {
            isSkin = true;
          }
          // South Asian / Indian skin tones (brownish)
          else if (r > 100 && r < 200 && g > 70 && g < 160 && b > 40 && b < 130 &&
              rgRatio > 1.1 && rgRatio < 1.8 && rbRatio > 1.3 && rbRatio < 3.0 &&
              saturation > 15 && saturation < 60) {
            isSkin = true;
          }
          // Darker skin tones
          else if (r > 60 && r < 150 && g > 40 && g < 110 && b > 20 && b < 90 && 
              rgRatio > 1.15 && rgRatio < 2.0 && r > b + 20) {
            isSkin = true;
          }
          // East Asian skin tones (yellowish)
          else if (r > 170 && g > 140 && b > 100 && g > b + 20 &&
              rgRatio > 1.05 && rgRatio < 1.35 && gbRatio > 1.1 && gbRatio < 1.5) {
            isSkin = true;
          }
        }
        
        if (isSkin) {
          skinPixels++;
          continue;
        }

        // Brownish-green/yellow (diseased plant tissue) - AFTER skin check
        // Must have greenish tint to differentiate from skin
        if (g > 70 && g >= b && (g - b) > 25 && saturation > 30 && 
            r < 210 && (r - g) < 60) {
          brownGreenPixels++;
          continue;
        }

        // Check for gray/artificial surfaces (low saturation)
        if (saturation < 12 && maxVal > 50 && maxVal < 220) {
          grayPixels++;
          continue;
        }

        // Check for blue-dominant pixels (sky, screens)
        if (b > r && b > g && b > 100) {
          bluePixels++;
          continue;
        }
        
        // Warm pixels (R dominant, not green, not detected as skin)
        // These are suspicious - could be skin the detector missed
        if (r > g && r > b && r > 100 && (r - g) > 15 && saturation > 15) {
          warmPixels++;
        }
      }
    }

    double skinRatio = skinPixels / totalSamples;
    double plantRatio = (greenPixels + brownGreenPixels) / totalSamples;
    double grayRatio = grayPixels / totalSamples;
    double blueRatio = bluePixels / totalSamples;
    double greenRatio = greenPixels / totalSamples;
    double warmRatio = warmPixels / totalSamples;

    print(
      'Image validation: Green=${(greenRatio * 100).toStringAsFixed(1)}%, '
      'Plant=${(plantRatio * 100).toStringAsFixed(1)}%, '
      'Skin=${(skinRatio * 100).toStringAsFixed(1)}%, '
      'Gray=${(grayRatio * 100).toStringAsFixed(1)}%, '
      'Blue=${(blueRatio * 100).toStringAsFixed(1)}%, '
      'Warm=${(warmRatio * 100).toStringAsFixed(1)}%',
    );

    // REJECT FIRST: Clear non-plant images
    
    // Reject if ANY significant skin detected (very strict)
    if (skinRatio > 0.08) {
      print('❌ REJECTED: Human skin detected (${(skinRatio * 100).toStringAsFixed(1)}%)');
      return false;
    }
    
    // Reject if high warm tones with no green (likely face/skin missed by detector)
    if (warmRatio > 0.25 && greenRatio < 0.05) {
      print('❌ REJECTED: Warm tones without green - likely skin (${(warmRatio * 100).toStringAsFixed(1)}% warm)');
      return false;
    }
    
    // Reject if skin + warm together indicate face
    if ((skinRatio + warmRatio) > 0.20 && greenRatio < 0.08) {
      print('❌ REJECTED: Combined skin indicators too high');
      return false;
    }

    // Reject if mostly gray (artificial objects)
    if (grayRatio > 0.45) {
      print('❌ REJECTED: Artificial surface/object (${(grayRatio * 100).toStringAsFixed(1)}% gray)');
      return false;
    }

    // Reject if mostly blue (sky, screens)
    if (blueRatio > 0.35) {
      print('❌ REJECTED: Sky or screen (${(blueRatio * 100).toStringAsFixed(1)}% blue)');
      return false;
    }
    
    // THEN ACCEPT: Plant content
    
    // Accept if good plant content
    if (plantRatio > 0.15) {
      print('✅ ACCEPTED: Plant content detected (${(plantRatio * 100).toStringAsFixed(1)}%)');
      return true;
    }

    // Accept if decent green ratio
    if (greenRatio > 0.12) {
      print('✅ ACCEPTED: Green content detected (${(greenRatio * 100).toStringAsFixed(1)}%)');
      return true;
    }

    // Reject if no significant plant content detected
    if (plantRatio < 0.08 && greenRatio < 0.08) {
      print('❌ REJECTED: No plant content detected');
      return false;
    }

    // Default: Accept borderline cases
    print('✅ ACCEPTED: Borderline - allowing analysis');
    return true;
  }

  // Validate prediction confidence and check for suspicious patterns
  bool validatePredictionConfidence(List<double> predictions) {
    double maxConfidence = predictions.reduce((a, b) => a > b ? a : b);
    double minConfidence = predictions.reduce((a, b) => a < b ? a : b);
    double sum = predictions.reduce((a, b) => a + b);
    
    // Calculate entropy - low entropy means model is very certain
    double entropy = 0;
    for (var p in predictions) {
      if (p > 0.001) {
        double clampedP = p.clamp(0.0001, 1.0);
        entropy -= p * math.log(clampedP) / 2.302585; // log10 = ln / ln(10)
      }
    }
    double maxEntropy = math.log(predictions.length.toDouble()) / 2.302585;
    double normalizedEntropy = maxEntropy > 0 ? entropy / maxEntropy : 0;

    print(
      'Model prediction - Max: ${(maxConfidence * 100).toStringAsFixed(1)}%, '
      'Min: ${(minConfidence * 100).toStringAsFixed(1)}%, '
      'Entropy: ${normalizedEntropy.toStringAsFixed(3)}',
    );

    // Print all class probabilities
    for (int i = 0; i < predictions.length && i < labels.length; i++) {
      print('  ${labels[i]}: ${(predictions[i] * 100).toStringAsFixed(2)}%');
    }

    // Reject if predictions don't sum to approximately 1 (model issue)
    if (sum < 0.95 || sum > 1.05) {
      print('❌ REJECTED: Predictions sum to ${sum.toStringAsFixed(2)}, expected ~1.0');
      return false;
    }

    // Reject if confidence is too low (model is uncertain)
    if (maxConfidence < 0.35) {
      print('❌ REJECTED: Maximum confidence too low (${(maxConfidence * 100).toStringAsFixed(1)}%)');
      return false;
    }

    // Check for suspicious uniform distribution (all classes ~equal)
    // This often happens with non-rice images
    if (normalizedEntropy > 0.85 && maxConfidence < 0.50) {
      print('❌ REJECTED: Predictions too uniform - likely not a rice leaf disease');
      return false;
    }

    // Check if top two predictions are too close (model is confused)
    List<double> sorted = List.from(predictions)..sort((a, b) => b.compareTo(a));
    if (sorted.length >= 2) {
      double gap = sorted[0] - sorted[1];
      if (gap < 0.10 && sorted[0] < 0.50) {
        print('❌ REJECTED: Top predictions too close (${(gap * 100).toStringAsFixed(1)}% gap) - model is uncertain');
        return false;
      }
    }

    print('✅ ACCEPTED: Model prediction is confident and valid');
    return true;
  }

  // Preprocess image exactly as expected by the TensorFlow Lite model
  // Uses center crop to maintain aspect ratio, then high-quality resize
  img.Image preprocessImageTeachableMachine(img.Image image, int targetSize) {
    print('Original image: ${image.width}x${image.height}');
    
    // Step 1: Center crop to square (maintains aspect ratio, avoids distortion)
    img.Image croppedImage;
    if (image.width != image.height) {
      int cropSize = image.width < image.height ? image.width : image.height;
      int offsetX = (image.width - cropSize) ~/ 2;
      int offsetY = (image.height - cropSize) ~/ 2;
      
      croppedImage = img.copyCrop(
        image,
        x: offsetX,
        y: offsetY,
        width: cropSize,
        height: cropSize,
      );
      print('Center cropped to: ${croppedImage.width}x${croppedImage.height}');
    } else {
      croppedImage = image;
    }
    
    // Step 2: Resize to target size with high-quality cubic interpolation
    img.Image resized = img.copyResize(
      croppedImage,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.cubic, // Higher quality than linear
    );

    print(
      'Image resized from ${image.width}x${image.height} to ${resized.width}x${resized.height}',
    );
    return resized;
  }

  // Convert image to Float32List exactly as expected by TensorFlow Lite
  Float32List imageToFloat32ListTeachableMachine(img.Image image) {
    var convertedBytes = Float32List(1 * 224 * 224 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    // Convert RGB values to 0-1 range (standard normalization)
    for (int i = 0; i < 224; i++) {
      for (int j = 0; j < 224; j++) {
        var pixel = image.getPixel(j, i);
        // Normalize to 0-1 range as expected by most TensorFlow models
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }

    print(
      'Converted image to Float32List with ${convertedBytes.length} values',
    );
    return convertedBytes;
  }

  String processPredictionResults(List<double> predictions) {
    if (predictions.isEmpty) return 'No predictions available';

    // Find top 2 predictions
    List<MapEntry<int, double>> indexed = [];
    for (int i = 0; i < predictions.length && i < labels.length; i++) {
      indexed.add(MapEntry(i, predictions[i]));
    }
    indexed.sort((a, b) => b.value.compareTo(a.value));

    int predictedIndex = indexed[0].key;
    double maxConfidence = indexed[0].value;
    double secondConfidence = indexed.length > 1 ? indexed[1].value : 0;
    double confidenceGap = maxConfidence - secondConfidence;

    print(
      'Best prediction: ${labels[predictedIndex]} with ${(maxConfidence * 100).toStringAsFixed(1)}% confidence',
    );
    print(
      'Second best: ${indexed.length > 1 ? labels[indexed[1].key] : "N/A"} with ${(secondConfidence * 100).toStringAsFixed(1)}% confidence',
    );
    print('Confidence gap: ${(confidenceGap * 100).toStringAsFixed(1)}%');

    // Get disease info
    final diseaseInfo = DiseaseInfo.getInfo(labels[predictedIndex]);

    // Use stricter threshold (50%) and require reasonable gap from second prediction
    if (maxConfidence > 0.50 &&
        confidenceGap > 0.15 &&
        predictedIndex < labels.length &&
        diseaseInfo != null) {
      // Store detected disease and confidence
      detectedDisease = labels[predictedIndex];
      detectionConfidence = maxConfidence * 100;
      return '${diseaseInfo.iconEmoji} ${diseaseInfo.name}\n${(maxConfidence * 100).toStringAsFixed(1)}% confidence\n\nTap "View Details" for treatment info';
    } else if (maxConfidence > 0.40 && diseaseInfo != null) {
      // Moderate confidence - show with warning
      detectedDisease = labels[predictedIndex];
      detectionConfidence = maxConfidence * 100;
      return '⚠️ Possible: ${diseaseInfo.name}\n${(maxConfidence * 100).toStringAsFixed(1)}% confidence\n\nConsider taking another photo for confirmation';
    } else {
      detectedDisease = null;
      detectionConfidence = null;
      return '❓ Uncertain Result\n\nThe image may not be a clear rice leaf or the disease is not recognizable.\n\nPlease try:\n• Better lighting\n• Closer view of affected area\n• Clear focus on the leaf';
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
          detectedDisease = null;
          detectionConfidence = null;
          result =
              '🚫 Not a Rice Leaf\n\nThis image doesn\'t appear to be a rice leaf.\n\nPlease ensure:\n• Image contains a rice plant leaf\n• Good lighting conditions\n• No faces or other objects\n• Leaf is clearly visible';
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
          detectedDisease = null;
          detectionConfidence = null;
          result =
              '🤔 Uncertain Analysis\n\nThe model cannot confidently identify a disease.\n\nThis could mean:\n• The leaf may be healthy\n• Image quality is insufficient\n• The disease is not in our database\n\nPlease try:\n• Better lighting\n• Clearer focus\n• Closer view of affected area';
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
        maxWidth: 800,  // Reduced for faster processing while maintaining quality
        maxHeight: 800,
        imageQuality: 90, // Higher quality for better predictions
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
        actions: [
          IconButton(
            icon: const Icon(Icons.book, color: Colors.white),
            tooltip: 'Quick Reference Guide',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QuickReferenceCard(),
                ),
              );
            },
          ),
        ],
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
                            : Column(
                                children: [
                                  Text(
                                    result ??
                                        'No analysis performed yet\n\nPlease select a clear image of a rice leaf for disease detection.',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (detectedDisease != null &&
                                      detectionConfidence != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  DiseaseDetailPage(
                                                    diseaseName:
                                                        detectedDisease!,
                                                    confidence:
                                                        detectionConfidence!,
                                                    imageFile: _image,
                                                  ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.info_outline,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'View Details & Treatment',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF1976D2,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
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
