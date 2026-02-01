---
name: flutter-translation
description: Translates Flutter/Dart code to Swift/SwiftUI for Rush Day iOS app. Auto-applies when implementing features from the Flutter app or comparing implementations.
---

# Flutter to Swift Translation Guide

## Source Location
Flutter app: `/Users/shaxbozaka/WebstormProjects/rushday/frontend/mobile/`

## Translation Mappings

| Flutter | Swift |
|---------|-------|
| Freezed models | Codable structs |
| Cubit/BLoC | `@MainActor` ObservableObject |
| `GetIt` | `DIContainer.shared` |
| `SharedPreferences` | `UserDefaults` |
| `FlutterSecureStorage` | Keychain |
| `go_router` | `NavigationStack` |
| `easy_localization` | String Catalogs (`L10n.key`) |
| `BuildContext` | `@Environment` |
| `StatefulWidget` | SwiftUI View with `@State` |
| `StreamBuilder` | Combine or `@Published` |

## Architecture Mapping

| Flutter Layer | Swift Layer |
|---------------|-------------|
| `lib/domain/entities/` | `Domain/Entities/` |
| `lib/domain/repositories/` | `Domain/Repositories/` |
| `lib/data/models/` | `Data/Models/` |
| `lib/data/repositories/` | `Data/RepositoriesImpl/` |
| `lib/presentation/screens/` | `Presentation/Screens/` |
| `lib/presentation/cubits/` | ViewModels in screen folders |

## Key Differences

- Use gRPC backend (Flutter uses Firestore)
- Use `rd` prefixed design system
- Use `async/await` (not Futures with `.then`)
- Use `@Published` for state (not emit/state)
