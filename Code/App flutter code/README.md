# 🌾 Rice Leaf Disease Detection App

An AI-powered Flutter mobile application that detects rice leaf diseases and provides comprehensive treatment recommendations.

## 🎯 Features

- **🔍 AI Disease Detection**: Identifies 4 rice conditions using TensorFlow Lite
  - Healthy leaves
  - Insect damage
  - Leaf Scald disease
  - Rice Blast disease (critical)

- **💊 Treatment Recommendations**: 
  - Specific chemicals with exact dosages
  - Biological control methods
  - Cultural management practices
  - Application schedules

- **📚 Quick Reference Guide**: Fast access to disease information for field use

- **📸 Flexible Input**: Camera capture or gallery selection

- **✅ Smart Validation**: Rejects non-plant images automatically

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Android Studio / VS Code
- Android device or emulator

### Installation

1. **Navigate to app directory**:
   ```bash
   cd "App flutter code"
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

### Build APK

```bash
flutter build apk --release
```

APK will be available at: `build/app/outputs/flutter-apk/app-release.apk`

## 📖 How to Use

1. **Launch the app** and wait for the splash screen
2. **Choose input method**:
   - Tap **Camera** to capture a live photo
   - Tap **Gallery** to select existing image
3. **Wait for analysis** (takes <1 second)
4. **View result** with disease name and confidence
5. **Tap "View Details & Treatment"** for comprehensive information
6. **Access Quick Reference** (book icon) for fast field lookup

## 🎓 Disease Classes

| Disease | Severity | Action Required |
|---------|----------|----------------|
| ✅ Healthy | None | Continue monitoring |
| 🐛 Insect Damage | Medium-High | Treat within 24h |
| 🍂 Leaf Scald | Medium | Treat within 48h |
| 💥 Rice Blast | **CRITICAL** | **Treat IMMEDIATELY** |

## 💊 Treatment Information

Each disease includes:
- **Chemical Control**: Product names, dosages, application methods
- **Biological Control**: Natural alternatives
- **Cultural Practices**: Field management techniques
- **Prevention**: Long-term protection strategies
- **Safety Guidelines**: Pesticide handling tips

## 📂 Project Structure

```
App flutter code/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── splash.dart                  # Splash screen
│   ├── home.dart                    # Main detection screen
│   ├── disease_info.dart            # Disease database
│   ├── disease_detail_page.dart     # Treatment details
│   └── quick_reference_card.dart    # Quick guide
├── assets/
│   ├── model_unquant.tflite         # TensorFlow Lite model
│   ├── labels.txt                   # Disease class labels
│   └── animation.json               # Lottie animation
└── pubspec.yaml                     # Dependencies
```

## 🔧 Technical Details

- **Framework**: Flutter 3.9.2+
- **ML Model**: TensorFlow Lite
- **Input Size**: 224×224×3 RGB
- **Inference Time**: <500ms
- **Platforms**: Android, iOS

## ⚠️ Important Notes

1. **Model Accuracy**: AI is a tool, not a replacement for expert consultation
2. **Safety First**: Always wear protective equipment when applying chemicals
3. **Local Adaptation**: Consult local agricultural officers for region-specific advice
4. **Dosage Precision**: Follow product labels and recommended dosages exactly

## 🐛 Troubleshooting

### Camera not working
- Grant camera permissions in device settings
- Restart the app

### Low detection confidence
- Ensure good lighting (natural daylight)
- Focus clearly on the leaf
- Fill frame with leaf
- Avoid blurry images

### Model not loading
- Check that `model_unquant.tflite` exists in `assets/`
- Run `flutter clean` and `flutter pub get`

## 📄 Documentation

- **Implementation Guide**: See `../IMPLEMENTATION_GUIDE.md`
- **Complete Features**: See `../COMPLETE_FEATURES_GUIDE.md`

---

**Made with ❤️ for farmers worldwide 🌾**
