# Twimotion

**Turn Text Into Motion** - A production-ready SwiftUI iOS app that creates kinetic typography GIFs from text input.

## 🎯 Overview

Twimotion transforms simple text into stunning animated GIFs optimized for social media. The app features a deterministic animation engine that ensures preview and export match exactly, with micro-variations for uniqueness.

## ✨ Features

- **Deterministic Animation Engine**: Preview matches exported GIF exactly
- **6 Beautiful Animation Styles**: Typewriter, Zoom, Stagger, Fade & Slide, Ticker, Pulse
- **Micro-Variations**: "Remix" feature for unique variations
- **HD Export**: 1080×1080 default, with HD and Ultra HD options
- **Offline-First**: Works fully offline using local templates
- **SwiftUI Native**: Built with SwiftUI and Apple Human Interface Guidelines
- **Production Ready**: IAP integration, analytics, and error handling

## 🏗️ Architecture

### Core Components

```
Twimotion/
├── Models/
│   └── Template.swift              # Template and AnimationPreset models
├── Views/
│   ├── AnimatedSlideView.swift     # Core animation rendering
│   ├── HomeView.swift              # Main text input interface
│   ├── ExportView.swift            # Export settings and progress
│   └── SettingsView.swift          # App configuration
├── Utils/
│   ├── TextSplitter.swift          # Intelligent text parsing
│   ├── DeterministicAnimationEngine.swift # Animation state calculation
│   └── GIFExporter.swift           # Animated GIF export
├── Services/
│   ├── BackendAPI.swift            # Remote API and caching
│   └── IAPManager.swift            # In-App Purchase management
└── Data/
    └── templates.json              # Animation templates
```

### Key Design Principles

1. **Deterministic Rendering**: All animations use normalized time (0.0-1.0) for consistency
2. **Offline-First**: App works without internet using local templates
3. **Modular Architecture**: Clean separation of concerns
4. **SwiftUI Native**: No external UI frameworks
5. **Production Ready**: Error handling, analytics, and IAP integration

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0 or later
- iOS 17.0 or later
- Swift 5.9 or later

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Twimotion
   ```

2. **Open in Xcode**
   ```bash
   open Twimotion.xcodeproj
   ```

3. **Add Background Assets**
   - Add the following PNG files to `Assets.xcassets`:
     - `typewriter_bg.png`
     - `zoom_hero_bg.png`
     - `stagger_bg.png`
     - `fade_slide_bg.png`
     - `ticker_bg.png`
     - `pulse_bg.png`

4. **Configure IAP** (Optional)
   - Update product identifiers in `IAPManager.swift`
   - Configure StoreKit in Xcode project settings

5. **Build and Run**
   - Select your target device or simulator
   - Press Cmd+R to build and run

## 🎨 Adding New Animation Styles

### 1. Update templates.json

Add a new template to `Data/templates.json`:

```json
{
  "id": "your_new_style",
  "name": "Your Style Name",
  "backgroundAsset": "your_bg.png",
  "defaultDuration": 4.0,
  "defaultFPS": 24,
  "tokens": { "bg": "#000000", "primary": "#FFFFFF", "accent": "#1D9BF0" },
  "placeholder": { "role":"headline", "font":"Inter-Bold", "fontSize":56, "maxLines":3, "safeInset":36 },
  "animation": { "family":"your_family", "minDuration":3.0, "maxDuration":6.0 }
}
```

### 2. Implement Animation Family

Add your animation family to `DeterministicAnimationEngine.swift`:

```swift
case "your_family":
    return calculateYourFamilyAnimation(phraseT: phraseT, variations: variations)
```

### 3. Add Background Asset

- Add `your_bg.png` to `Assets.xcassets`
- Ensure it's optimized for 1080×1080 resolution

## 🔧 Configuration

### Backend API

Update `BackendAPI.swift` with your server endpoints:

```swift
private let baseURL = "https://your-api.com"
```

### In-App Purchases

Configure product identifiers in `IAPManager.swift`:

```swift
enum ProductIdentifier: String, CaseIterable {
    case pro = "com.yourcompany.twimotion.pro"
    // Add your products
}
```

### Analytics

Update analytics events in `BackendAPI.swift` to match your tracking system.

## 📱 Usage

### Basic Flow

1. **Enter Text**: Type or paste your text in the home screen
2. **Preview**: Watch your animation come to life with interactive controls
3. **Export**: Configure quality settings and export GIF
4. **Share**: Save to Photos or share via system share sheet

### Advanced Features

- **Remix**: Generate variations of the same style
- **Quality Settings**: Choose export resolution (Standard/HD/Ultra HD)
- **Watermark**: Toggle watermark for free vs premium users
- **Auto-save**: Automatically save exports to Photos

## 🧪 Testing

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme Twimotion -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -scheme Twimotion -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TwimotionTests/DeterministicAnimationTests
```

### Test Coverage

The app includes comprehensive tests for:
- Deterministic animation engine
- Text splitting algorithms
- Template loading and parsing
- GIF export pipeline

## 📊 Performance

### Optimization Features

- **Efficient Rendering**: Pre-calculated font sizes and layouts
- **Memory Management**: `autoreleasepool` in export loops
- **Background Processing**: Export runs on background queue
- **Caching**: Local template and asset caching

### Export Performance

- **Standard (1080×1080)**: ~30 seconds for 4-second GIF
- **HD (1920×1920)**: ~60 seconds for 4-second GIF
- **Ultra HD (2160×2160)**: ~120 seconds for 4-second GIF

## 🔒 Privacy & Security

- **Local Processing**: All GIF generation happens on-device
- **Minimal Data Collection**: Only essential analytics
- **Secure Storage**: Sensitive data encrypted in Keychain
- **No Personal Data**: Text input not stored or transmitted

## 🚢 Production Checklist

### Pre-Launch

- [ ] **Assets**: Add all background images to Assets.xcassets
- [ ] **IAP Configuration**: Set up StoreKit products and sandbox testing
- [ ] **Backend API**: Configure production endpoints and API keys
- [ ] **Analytics**: Set up analytics tracking and events
- [ ] **Privacy Policy**: Update privacy policy with data collection details
- [ ] **App Store Assets**: Create app icons, screenshots, and metadata

### Testing

- [ ] **Device Testing**: Test on various iPhone models and iOS versions
- [ ] **Export Testing**: Verify GIF export works on device (not simulator)
- [ ] **IAP Testing**: Test purchase flows with sandbox accounts
- [ ] **Offline Testing**: Verify app works without internet connection
- [ ] **Memory Testing**: Test with long text inputs and multiple exports

### App Store

- [ ] **Metadata**: App name, description, keywords, screenshots
- [ ] **Age Rating**: Configure appropriate age rating
- [ ] **Categories**: Select relevant App Store categories
- [ ] **Localization**: Add support for target markets
- [ ] **App Review**: Prepare for App Store review process

## 🐛 Troubleshooting

### Common Issues

**Export fails on simulator**
- GIF export requires a physical device
- Simulator doesn't support CGImageDestination properly

**Templates not loading**
- Ensure `templates.json` is added to bundle
- Check JSON syntax is valid

**IAP not working**
- Verify StoreKit configuration
- Test with sandbox accounts
- Check product identifiers match App Store Connect

**Memory issues during export**
- Reduce export resolution
- Limit text length
- Check device available storage

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

- **Documentation**: Check this README and code comments
- **Issues**: Report bugs via GitHub Issues
- **Email**: Contact support@twimotion.app

## 🔮 Roadmap

### Version 1.1
- [ ] Additional animation families
- [ ] Custom font support
- [ ] Batch export
- [ ] Cloud sync

### Version 1.2
- [ ] AI-powered text suggestions
- [ ] Advanced customization options
- [ ] Collaboration features
- [ ] Export to multiple formats

---

**Built with ❤️ using SwiftUI and Apple Human Interface Guidelines**
