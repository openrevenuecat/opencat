# Rush Day - iOS (Swift/SwiftUI)

Native iOS app for Rush Day event management platform, built with SwiftUI and following Clean Architecture principles.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Project Structure

```
RushDay/
├── App/                      # App entry point and configuration
│   ├── RushDayApp.swift      # Main app entry
│   ├── AppState.swift        # Global app state
│   └── ContentView.swift     # Root view with navigation
│
├── Core/                     # Core utilities and services
│   ├── DI/                   # Dependency injection
│   ├── Extensions/           # Swift extensions
│   │   ├── Color+Theme.swift # Color palette
│   │   └── Font+Theme.swift  # Typography
│   ├── Helpers/              # Utility functions
│   ├── Services/             # Firebase and external services
│   │   ├── Firebase/
│   │   ├── RevenueCat/
│   │   └── Networking/
│   └── Storage/              # Local storage (UserDefaults, Keychain)
│
├── Domain/                   # Business logic layer
│   ├── Entities/             # Business models
│   │   ├── User.swift
│   │   ├── Event.swift
│   │   ├── Guest.swift
│   │   ├── EventTask.swift
│   │   ├── Agenda.swift
│   │   └── Expense.swift
│   ├── Repositories/         # Repository protocols
│   └── UseCases/             # Business logic operations
│
├── Data/                     # Data layer
│   ├── DataSources/          # Remote/local data sources
│   ├── Models/               # DTOs and API models
│   ├── Mappers/              # Entity-Model mapping
│   └── RepositoriesImpl/     # Repository implementations
│
├── Presentation/             # UI layer
│   ├── Components/           # Reusable UI components
│   │   ├── RDButton.swift
│   │   ├── RDTextField.swift
│   │   └── RDCard.swift
│   ├── Screens/              # Feature screens
│   │   ├── Auth/
│   │   ├── Onboarding/
│   │   ├── CreateEvent/
│   │   ├── Home/
│   │   ├── Guests/
│   │   ├── Tasks/
│   │   ├── Agenda/
│   │   ├── Expenses/
│   │   └── Settings/
│   └── ViewModels/           # Screen view models
│
└── Resources/                # Assets and resources
    ├── Assets.xcassets/      # Images and colors
    ├── Fonts/                # Custom fonts
    └── Localizations/        # String translations
```

## Architecture

The app follows **Clean Architecture** with **MVVM** pattern:

### Layers

1. **Domain Layer** - Contains business logic, entities, and repository interfaces
2. **Data Layer** - Implements repositories, handles data sources and mapping
3. **Presentation Layer** - SwiftUI views and ViewModels

### State Management

- `@StateObject` / `@ObservedObject` for view-specific state
- `@EnvironmentObject` for app-wide state (AppState)
- Combine for reactive data flow

## Dependencies

Managed via Swift Package Manager:

- **Firebase SDK** - Auth, Firestore, Storage, Messaging, Analytics, Crashlytics
- **RevenueCat** - In-app purchases and subscriptions
- **Alamofire** - HTTP networking
- **Nuke** - Image loading and caching
- **Lottie** - Animations

## Setup Instructions

### 1. Clone and Open

```bash
cd frontend/ios-swift
open RushDay.xcodeproj
```

### 2. Firebase Configuration

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Download `GoogleService-Info.plist`
3. Add it to the Xcode project

### 3. RevenueCat Setup

1. Create a RevenueCat account
2. Add your API key to the app configuration

### 4. Build and Run

```bash
# Using Xcode
xcodebuild -scheme RushDay -destination 'platform=iOS Simulator,name=iPhone 15'

# Or open in Xcode and press Cmd+R
```

## Design System

### Colors

Colors are defined in `Core/Extensions/Color+Theme.swift`:

- Primary colors
- Background colors
- Text colors
- Event type colors (birthday, wedding, corporate, etc.)

### Typography

Font styles in `Core/Extensions/Font+Theme.swift`:

- Display (large, medium, small)
- Headline (large, medium, small)
- Title (large, medium, small)
- Body (large, medium, small)
- Label (large, medium, small)
- Caption (large, medium, small)

### Components

Reusable components in `Presentation/Components/`:

- `RDButton` - Primary, secondary, outline, ghost, destructive styles
- `RDTextField` - Text input with icons and validation
- `RDCard` - Card containers
- `EventCard` - Event preview cards
- `SelectionCard` - Radio-style selection cards

## Features

### Implemented

- [x] App structure and navigation
- [x] Authentication flow (Apple, Google, Email)
- [x] Onboarding screens
- [x] Create Event flow
  - [x] Select event type
  - [x] Name, date, and venue
  - [x] Add guests
  - [x] Review and create
- [x] Home screen with event cards
- [x] Tab bar navigation
- [x] Design system (colors, typography, components)

### In Progress

- [ ] Firebase integration
- [ ] Event details screen
- [ ] Guest management
- [ ] Task management
- [ ] Agenda builder
- [ ] Expense tracking
- [ ] Push notifications
- [ ] RevenueCat subscriptions
- [ ] Deep linking

## Flutter to Swift Migration Notes

| Flutter | Swift |
|---------|-------|
| Freezed models | Codable structs |
| Cubit/BLoC | ObservableObject/ViewModel |
| GetIt | DIContainer singleton |
| SharedPreferences | UserDefaults |
| FlutterSecureStorage | Keychain |
| go_router | NavigationStack |
| easy_localization | String Catalogs |

## Performance Considerations

- Native Metal rendering for blur effects (addresses Flutter lag issues)
- Lazy loading with `LazyVStack` / `LazyHStack`
- Image caching with Nuke
- Background task scheduling with BGTaskScheduler

## Contributing

1. Follow the established architecture patterns
2. Use the design system components
3. Write SwiftUI previews for all views
4. Keep ViewModels testable