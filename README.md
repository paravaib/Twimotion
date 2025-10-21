# Twimotion

A beautiful iOS app for creating animated text videos with customizable themes and effects.

## Features

### 🎨 Theme System
- **6 Predefined Themes**: Twitter/X, Instagram, LinkedIn, TikTok, YouTube, and General
- **Real Brand Colors**: Each theme uses authentic platform colors
- **Custom Themes**: Create your own color combinations
- **Instant Preview**: See changes in real-time

### ✨ Animation Engine
- **Typewriter Effect**: Classic animated text reveal
- **Deterministic Animation**: Consistent results for export
- **Customizable Timing**: Adjust speed and duration
- **High-Quality Export**: Perfect for social media

### 🎯 User Experience
- **Clean Interface**: Intuitive and easy to use
- **Real-time Preview**: See your animation as you create it
- **Export Ready**: Generate videos optimized for social platforms
- **Theme Persistence**: Your selections are saved automatically

## Architecture

### Core Components
- **ThemeManager**: Handles theme selection and customization
- **AnimationPreset**: Manages animation settings and templates
- **DeterministicAnimationEngine**: Ensures consistent animation playback
- **Template System**: Extensible animation templates

### Key Files
- `Twimotion/Models/Theme.swift` - Theme definitions and color schemes
- `Twimotion/Services/ThemeManager.swift` - Theme management and persistence
- `Twimotion/Views/HomeView.swift` - Main interface and text input
- `Twimotion/Views/AnimatedSlideView.swift` - Animation rendering engine
- `Twimotion/Views/ThemeSelectionView.swift` - Theme selection interface

## Development

### Branches
- `main` - Production-ready code
- `develop` - Active development branch

### Getting Started
1. Clone the repository
2. Open `Twimotion.xcodeproj` in Xcode
3. Build and run on iOS Simulator or device

### Requirements
- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

## Theme System

The app features a comprehensive theme system that allows users to:

1. **Select Predefined Themes**: Choose from platform-specific themes with authentic brand colors
2. **Customize Colors**: Create personalized themes with custom background and text colors
3. **Preview Changes**: See theme changes in real-time in the animation preview
4. **Persistent Settings**: All theme selections are automatically saved

### Supported Themes
- **Twitter/X**: Black background with white text
- **Instagram**: Instagram Pink background with white text
- **LinkedIn**: LinkedIn Blue background with white text
- **TikTok**: Black background with white text
- **YouTube**: YouTube Red background with white text
- **General**: Dark blue background with white text

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch from `develop`
3. Make your changes
4. Submit a pull request to `develop`

## Repository Structure

```
Twimotion/
├── Twimotion/
│   ├── Models/          # Data models (Theme, Template, etc.)
│   ├── Services/        # Business logic (ThemeManager, IAPManager)
│   ├── Views/           # SwiftUI views and UI components
│   ├── Utils/           # Utility classes and helpers
│   └── Data/            # Static data files (templates.json)
├── TwimotionTests/      # Unit tests
└── README.md           # This file
```

## Recent Updates

- ✅ Implemented comprehensive theme system
- ✅ Added 6 predefined platform themes with real brand colors
- ✅ Created custom theme support
- ✅ Simplified font style selection (removed complexity)
- ✅ Fixed all compilation errors
- ✅ Set up Git repository with main and develop branches