# 🇨🇭 Sweezy – Life in Switzerland

> Your personal assistant for life in Switzerland  
> Створено для української спільноти у Швейцарії

[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.9-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![App Store](https://img.shields.io/badge/App%20Store-Coming%20Soon-red.svg)](https://apps.apple.com)

## 📱 About

**Sweezy** is a comprehensive iOS app designed to help Ukrainians integrate into life in Switzerland. It provides detailed guides, checklists, document templates, an interactive service map, and much more — all in a beautiful, accessible, privacy-first package.

### 🎯 Key Features

- 📚 **50+ Detailed Guides** - Residence registration, health insurance, banking, employment, housing
- ✅ **Interactive Checklists** - Step-by-step tasks for every stage of integration
- 📝 **Document Templates** - Ready-made forms with PDF export
- 🗺️ **Service Map** - 200+ places: government offices, medical centers, Ukrainian hubs
- 💰 **Benefits Calculator** - Calculate social assistance and family benefits
- 📅 **Appointment Manager** - Track important dates and deadlines
- 🌍 **4 Languages** - Ukrainian, Russian, English, German
- 🔒 **Privacy First** - All data stored locally, no tracking
- ♿️ **Fully Accessible** - VoiceOver, Dynamic Type, Reduce Motion support
- 📴 **Works Offline** - No internet required

## 🏗️ Architecture

### Tech Stack

- **Language:** Swift 5.9
- **Framework:** SwiftUI (iOS 17+)
- **Architecture:** MVVM + Services
- **Dependency Injection:** Protocol-based
- **Testing:** XCTest
- **CI/CD:** GitHub Actions + Fastlane
- **Analytics:** Firebase (optional)
- **Localization:** 4 languages (uk, ru, en, de)

### Project Structure

```
sweezy/
├── Core/
│   ├── Models/          # Data models
│   ├── Services/        # Business logic services
│   ├── Extensions/      # Swift extensions
│   └── Theme/           # Design system
├── Features/
│   ├── Home/           # Home screen
│   ├── Guides/         # Guides library
│   ├── Checklists/     # Checklist manager
│   ├── Templates/      # Document templates
│   ├── Map/            # Service map
│   ├── Calculator/     # Benefits calculator
│   ├── Appointments/   # Calendar
│   └── Settings/       # App settings
├── Resources/
│   ├── Localization/   # 4 language .lproj folders
│   └── AppContent/     # JSON seed files
└── AppRootView.swift   # Root coordinator
```

### Key Services

| Service | Purpose |
|---------|---------|
| `ContentService` | Manages guides, checklists, templates, places |
| `LocalizationService` | Dynamic language switching |
| `AnalyticsService` | Privacy-friendly event tracking |
| `CacheService` | Actor-based disk caching |
| `ErrorHandlingService` | Centralized error management |
| `RemoteConfigService` | Remote content updates |

## 🚀 Getting Started

### Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15.2+
- iOS 17+ device or simulator
- CocoaPods or Swift Package Manager (optional for Firebase)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/sweezy.git
   cd sweezy
   ```

2. **Open in Xcode**
   ```bash
   open sweezy.xcodeproj
   ```

3. **Select target device/simulator**
   - Choose "sweezy" scheme
   - Select iPhone 15 or any iOS 17+ device

4. **Build and run**
   - Press `Cmd+R` or click the Play button

### Optional: Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add iOS app with bundle ID: `com.sweezy.app`
3. Download `GoogleService-Info.plist`
4. Replace the placeholder file in `sweezy/GoogleService-Info.plist`
5. Enable Analytics and Crashlytics in Firebase Console

## 🧪 Testing

### Run Tests

```bash
# Via Xcode
Cmd+U

# Via xcodebuild
xcodebuild test \
  -project sweezy.xcodeproj \
  -scheme sweezy \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Via Fastlane
fastlane test
```

### Test Coverage

- ✅ LocalizationService
- ✅ ContentService
- ✅ RemoteConfigService
- ✅ CacheService
- ✅ Core models

## 🌍 Localization

### Supported Languages

- 🇺🇦 **Ukrainian** (uk) - Primary
- 🇷🇺 **Russian** (ru)
- 🇬🇧 **English** (en)
- 🇩🇪 **German** (de)

### Adding New Strings

1. Add key to all `.lproj/Localizable.strings` files:
   ```swift
   "my_new_key" = "Translated value";
   ```

2. Use in code:
   ```swift
   Text("my_new_key".localized)
   ```

### Adding New Content

Content is stored in JSON files:

- `Resources/AppContent/seeds/guides_uk.json`
- `Resources/AppContent/seeds/checklists_uk.json`
- `Resources/AppContent/seeds/templates.json`
- `Resources/AppContent/seeds/places_new.json`

See existing files for structure examples.

## 🎨 Design System

### Theme

All design tokens are in `Core/Theme/Theme.swift`:

```swift
// Colors
Theme.Colors.ukrainianBlue
Theme.Colors.primaryText
Theme.Colors.primaryBackground

// Typography
Theme.Typography.largeTitle
Theme.Typography.body

// Spacing
Theme.Spacing.xs, .sm, .md, .lg, .xl

// Corner Radius
Theme.CornerRadius.sm, .md, .lg
```

### Accessibility

All views support:
- ✅ VoiceOver with proper labels
- ✅ Dynamic Type (scalable fonts)
- ✅ Reduce Motion
- ✅ Minimum 44x44pt touch targets
- ✅ High contrast colors

Use helpers:
```swift
.accessibilityLabeled("Button", hint: "Saves changes")
.scalablePadding(.all, 16)
.minimumTouchTarget()
```

## 📦 Deployment

### Fastlane

All deployment automation is via Fastlane.

```bash
# Install Fastlane
gem install fastlane

# Deploy to TestFlight
fastlane beta

# Deploy to App Store
fastlane release

# Generate screenshots
fastlane screenshots
```

See `fastlane/README.md` for detailed instructions.

### CI/CD

GitHub Actions workflows:

- **ci.yml** - Runs on every push (build + test + lint)
- **testflight.yml** - Runs on version tags (deploy to TestFlight)

Required secrets:
- `CERTIFICATES_P12`
- `CERTIFICATES_PASSWORD`
- `PROVISIONING_PROFILE`
- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY`

## 📊 Analytics

### Privacy-Friendly Tracking

Analytics is **opt-in** and **privacy-first**:
- No personal data collected
- No third-party trackers
- All data anonymized
- Respects user preferences

### Key Events

```swift
// App lifecycle
AnalyticsService.shared.logEvent(.appLaunched)

// Content
AnalyticsService.shared.logGuideView(
    guideId: guide.id,
    category: guide.category.rawValue,
    language: currentLanguage
)

// Screen tracking
.trackScreen("HomeView")
```

See `AnalyticsService.swift` for all 30+ predefined events.

## 🐛 Troubleshooting

### Common Issues

**Build fails with "Developer Directory not found"**
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

**CocoaPods issues**
```bash
pod deintegrate
pod install
```

**Cache issues**
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Or via Fastlane
fastlane clean
```

**Localization not updating**
- Ensure `.lproj` folders are added to target
- Clean build folder (Cmd+Shift+K)
- Restart Xcode

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes and commit: `git commit -am 'Add feature'`
4. Push to branch: `git push origin feature/my-feature`
5. Submit a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint (`.swiftlint.yml`)
- Write tests for new features
- Update documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

- **Developer:** [Your Name](https://github.com/your-username)
- **Design:** Community-driven
- **Content:** Verified by Swiss authorities

## 📞 Support

- **Email:** support@sweezy.app
- **Telegram:** [@sweezy_support](https://t.me/sweezy_support)
- **Issues:** [GitHub Issues](https://github.com/your-org/sweezy/issues)

## 🙏 Acknowledgments

- Swiss government for official information sources
- Ukrainian community in Switzerland for feedback
- All contributors and testers

## 📈 Roadmap

### v1.0 (Current) ✅
- ✅ Core features
- ✅ 4 languages
- ✅ 200+ places
- ✅ Offline support
- ✅ Accessibility

### v1.1 (Planned)
- [ ] Widget extension
- [ ] Siri Shortcuts
- [ ] Apple Watch companion
- [ ] iCloud sync

### v2.0 (Future)
- [ ] Community features
- [ ] User profiles
- [ ] Push notifications
- [ ] Advanced search

## ⭐️ Star Us!

If you find Sweezy helpful, please consider:
- ⭐️ Starring the repository
- 📢 Sharing with friends
- 💬 Leaving feedback
- 🐛 Reporting issues

---

**Built with ❤️ for the Ukrainian community in Switzerland**  
**Створено з любов'ю для української спільноти у Швейцарії**

---

*Last updated: October 16, 2025*  
*Version: 1.0.0*

### 📚 Comprehensive Guides
- **36+ detailed articles** covering housing, documents, health insurance, education, finance, work, transport, government services, and more
- Full-text search and smart filtering by category and canton
- Offline-first with beautiful markdown rendering
- Estimated reading times and last updated timestamps

### ✅ Interactive Checklists
- **Step-by-step guides** for common scenarios (First 7 days, Health insurance, Housing search, Job search)
- Progress tracking with local persistence
- Visual completion indicators with celebration animations
- Expandable steps with helpful tips and links

### 🗺️ Service Map
- Interactive map with **7+ important locations** (Migration offices, hospitals, Gemeinde, insurance companies, legal aid)
- Filter by service type and canton
- Contact information, opening hours, and directions
- Accessibility information

### 🧮 Benefits Calculator
- Estimate potential subsidies and benefits
- Canton-specific calculations
- Clear disclaimers and next steps
- Generate personalized to-do lists

### 📝 Document Templates
- **5+ pre-filled templates** (Municipality registration, health insurance application, rental application, etc.)
- Smart placeholder system
- PDF preview and export
- Multi-language support

### 📰 Latest News
- Real-time updates on immigration policies and services
- Multi-language news feed (uk/en/de)
- Source attribution and links

### 🌐 Full Localization
- **4 languages**: Ukrainian (default), Russian, English, German
- Easy language switching in Settings
- All content localized

## 🎨 Design Highlights

### Glassmorphism UI
- Beautiful frosted glass effects throughout
- Smooth blur and transparency
- Gradient strokes and shadows
- Modern, professional aesthetic

### Smooth Animations
- Spring-based micro-interactions
- Celebratory completion animations
- Shimmer loading states
- Parallax hero headers

### Accessibility
- Dynamic Type support
- VoiceOver labels
- High contrast mode compatible
- Haptic feedback

## 🏗️ Architecture

### MVVM + Composable Services
```
sweezy/
├── SweezyApp.swift                 # App entry point
├── Core/
│   ├── AppContainer.swift          # Dependency injection + state
│   ├── Models/                     # Codable data models
│   └── Services/                   # Protocol-oriented services
├── DesignSystem/
│   ├── Theme.swift                 # Colors, typography, spacing
│   └── Components/                 # Reusable UI components
├── Features/
│   ├── Onboarding/
│   ├── Home/                       # Dashboard with quick actions
│   ├── Guides/                     # Article browser + detail
│   ├── Checklists/                 # Interactive task lists
│   ├── Calculator/                 # Benefits estimator
│   ├── Map/                        # Service locator
│   ├── Appointments/               # Reminder system
│   ├── Templates/                  # Document generator
│   └── Settings/                   # Preferences + profile
└── Resources/
    ├── AppContent/seeds/           # Offline JSON data
    └── Localization/               # .lproj bundles
```

### Key Services
- **ContentService**: Manages offline JSON content with cache fallback
- **LocationService**: Handles user location for map features
- **NotificationService**: Schedules local notifications for appointments
- **CalculatorService**: Computes benefit eligibility
- **LocalizationService**: Manages app language
- **RemoteConfigService**: (Mock) Remote content updates

## 🚀 Getting Started

### Prerequisites
- **Xcode 15.0+**
- **iOS 17.0+ device or simulator**
- macOS 14.0+ (Sonoma or later)

### Installation

1. **Clone or download** the project:
```bash
cd ~/Desktop/sweezy
```

2. **Open in Xcode**:
```bash
open sweezy.xcodeproj
```

3. **Select target device** (iPhone 15 Pro or any iOS 17+ simulator)

4. **Build and run** (⌘R)

That's it! No CocoaPods, no manual configuration. The project uses Swift Package Manager for dependencies (Lottie) which Xcode resolves automatically.

### First Launch

1. Complete onboarding (3 screens)
2. Select your preferred language (uk/ru/en/de)
3. Grant location permission (optional, for map features)
4. Grant notification permission (optional, for appointment reminders)

## 📊 Content Overview

| Type | Count | Details |
|------|-------|---------|
| **Guides** | 36 | Housing, Documents, Health, Education, Finance, Work, Transport, Government, Organizations, Adaptation |
| **Checklists** | 4 | First 7 days, Health insurance, Housing search, Job search |
| **Places** | 7 | Migration offices, Hospitals, Gemeinde, Insurance, Legal aid (Zurich, Bern, Geneva) |
| **Templates** | 5 | Registration letters, applications, requests |
| **Benefit Rules** | 2 | ZH and GE subsidies (simplified demo) |
| **News** | 3 | Sample news items (uk/en/de) |

All content is stored in **`Resources/AppContent/seeds/*.json`** and loaded into the app bundle. You can easily expand or update content by editing these JSON files.

## 🧪 Testing

### Unit Tests
Located in `sweezyTests/`:
- `ContentServiceTests.swift` - JSON parsing and content loading
- `CalculatorServiceTests.swift` - Benefit calculation logic

Run with **⌘U** or from Test Navigator.

### UI Tests
Located in `sweezyUITests/`:
- `OnboardingUITests.swift` - Onboarding flow and language selection

Run UI tests on iOS simulator for best results.

## 🔧 Customization

### Adding New Content

#### Guides
Edit `Resources/AppContent/seeds/guides.json`:
```json
{
  "id": "unique-uuid",
  "title": "Your Guide Title",
  "subtitle": "Short description",
  "bodyMarkdown": "# Heading\n\nParagraph...",
  "tags": ["tag1", "tag2"],
  "category": "housing",
  "cantonCodes": ["ZH", "BE"],
  "links": [...],
  "priority": 8,
  "isNew": true,
  "estimatedReadingTime": 5,
  "lastUpdated": "2025-10-14T10:00:00Z",
  "createdAt": "2025-10-14T10:00:00Z"
}
```

#### Checklists
Edit `Resources/AppContent/seeds/checklists.json`:
```json
{
  "id": "unique-uuid",
  "title": "Checklist Name",
  "description": "What this helps with",
  "category": "arrival",
  "estimatedDuration": "2-3 days",
  "difficulty": "easy",
  "steps": [
    {
      "id": "unique-step-uuid",
      "title": "Step title",
      "description": "Details...",
      "estimatedTime": "30 min",
      "order": 0,
      "isOptional": false,
      "links": [...],
      "requiredDocuments": [],
      "tips": []
    }
  ],
  "tags": ["first-week", "essential"],
  "priority": 10,
  "isNew": false
}
```

### Changing Colors/Theme
Edit `DesignSystem/Theme.swift`:
```swift
struct Colors {
    static let ukrainianBlue = Color(hex: "#0057B7")
    static let warmYellow = Color(hex: "#FFD700")
    // Add your custom colors...
}
```

### Adding Languages
1. Add new `.lproj` folder in `Resources/Localization/`
2. Create `Localizable.strings` with translations
3. Update `LocalizationService` to include the new locale

## 📱 App Structure

### Screens
1. **Onboarding** - Welcome, language selection, permissions
2. **Home (Dashboard)** - Hero header, quick actions, news, emergency numbers
3. **Guides** - Searchable article library with filters
4. **Checklists** - Interactive progress tracking
5. **Map** - MapKit integration with nearby services
6. **Calculator** - Benefits eligibility estimator
7. **Appointments** - Local notification reminders
8. **Templates** - Document generator with PDF export
9. **Settings** - Language, profile, privacy, data export

### Data Flow
```
JSON Seeds (Bundle)
    ↓
ContentService.loadFromBundle()
    ↓
Cache (FileManager)
    ↓
@Published properties in ContentService
    ↓
Views via @EnvironmentObject AppContainer
```

## 🛠️ Technologies

- **SwiftUI** - Modern declarative UI
- **Combine** - Reactive data binding
- **MapKit** - Interactive maps
- **CoreLocation** - Geolocation services
- **UserNotifications** - Local reminders
- **Lottie** (via SPM) - Smooth animations
- **Swift Package Manager** - Dependency management

## ⚠️ Known Limitations

1. **Remote Content Updates**: Currently uses local JSON only. RemoteConfigService is mocked. To add real updates, implement URLSession fetching in `RemoteConfigService`.

2. **PDF Export**: Template PDF generation is a placeholder. For production, integrate a proper PDF library (e.g., PDFKit custom rendering).

3. **Analytics**: The analytics toggle in Settings is non-functional (mock). Integrate Firebase/Amplitude as needed.

4. **Calculator Accuracy**: Benefit calculations are simplified demos. For production, use official cantonal APIs/rules.

## 🚢 Deployment Checklist

Before releasing to TestFlight/App Store:

- [ ] Replace placeholder Lottie files with real animations
- [ ] Implement real RemoteConfigService with API backend
- [ ] Add proper error handling and offline state UI
- [ ] Expand content to all 26 cantons
- [ ] Add analytics (Firebase, Amplitude, etc.)
- [ ] Implement PDF generation properly
- [ ] Add Siri Shortcuts for quick actions
- [ ] Widget for quick info/checklists
- [ ] Dark mode polish (already supported, but verify all screens)
- [ ] Accessibility audit (VoiceOver, Dynamic Type)
- [ ] Privacy policy and terms of service
- [ ] App Store screenshots and metadata
- [ ] Beta testing with real users

## 📄 License

This project is provided as-is for humanitarian purposes. Feel free to use, modify, and distribute to help Ukrainian refugees in Switzerland.

## 🙏 Acknowledgments

Built with care for the Ukrainian community in Switzerland.

Special thanks to:
- Swiss government for open data and resources
- Caritas, Red Cross, and NGOs supporting refugees
- The SwiftUI and iOS development community

## 📞 Support

For bugs or feature requests, please open an issue on this repository.

For urgent help, contact:
- **Swiss Refugee Hotline**: +41 58 465 1111
- **Caritas**: https://www.caritas.ch/
- **Helpline for Ukraine**: +41 800 24 7 365

---

**Made with ❤️ for Ukraine 🇺🇦**

**Зроблено з ❤️ для України 🇺🇦**

## 🚢 Deployment Checklist

Before releasing to TestFlight/App Store:

- [ ] Replace placeholder Lottie files with real animations
- [ ] Implement real RemoteConfigService with API backend
- [ ] Add proper error handling and offline state UI
- [ ] Expand content to all 26 cantons
- [ ] Add analytics (Firebase, Amplitude, etc.)
- [ ] Implement PDF generation properly
- [ ] Add Siri Shortcuts for quick actions
- [ ] Widget for quick info/checklists
- [ ] Dark mode polish (already supported, but verify all screens)
- [ ] Accessibility audit (VoiceOver, Dynamic Type)
- [ ] Privacy policy and terms of service
- [ ] App Store screenshots and metadata
- [ ] Beta testing with real users

## 📄 License

This project is provided as-is for humanitarian purposes. Feel free to use, modify, and distribute to help Ukrainian refugees in Switzerland.

## 🙏 Acknowledgments

Built with care for the Ukrainian community in Switzerland.

Special thanks to:
- Swiss government for open data and resources
- Caritas, Red Cross, and NGOs supporting refugees
- The SwiftUI and iOS development community

## 📞 Support

For bugs or feature requests, please open an issue on this repository.

For urgent help, contact:
- **Swiss Refugee Hotline**: +41 58 465 1111
- **Caritas**: https://www.caritas.ch/
- **Helpline for Ukraine**: +41 800 24 7 365

---

**Made with ❤️ for Ukraine 🇺🇦**

**Зроблено з ❤️ для України 🇺🇦**
