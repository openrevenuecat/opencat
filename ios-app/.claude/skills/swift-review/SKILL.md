---
name: swift-review
description: Reviews Swift/SwiftUI code for Rush Day iOS app architecture compliance, best practices, and project conventions. Auto-applies when reviewing code or checking code quality.
---

# Swift Code Review Guidelines

## Architecture Rules

- **Clean Architecture**: Presentation → Domain → Data layer separation
- **MVVM Pattern**: ViewModels with `@MainActor` and `@Published` properties
- **DI**: Use `DIContainer.shared` for all dependencies
- **Repositories**: Protocol-based with gRPC implementations

## SwiftUI Rules

- **Colors**: Use `rd` prefix (`.rdPrimary`, `.rdTextPrimary`, not `.accent`)
- **Fonts**: Use `rd` prefix (`.rdBody()`, `.rdHeadline()`)
- **RDButton**: Unnamed first param: `RDButton("Title", action: {})`
- **Button images**: Use `systemImage` param, not `Image` inside label
- **Animations**: Use `.animation(.spring(response: 0.3), value:)`

## Backend Rules

- **gRPC ONLY**: Never use Firestore for data storage
- **Optimistic updates**: Update UI first, rollback on failure
- **Error handling**: Catch all async errors with user feedback

## Code Style

- Use `// MARK: -` for sections
- Extract subviews for readability
- Use computed properties for derived state
- Prefer `async/await` over callbacks
- iOS 26 features: Use `@available(iOS 26.0, *)` checks
