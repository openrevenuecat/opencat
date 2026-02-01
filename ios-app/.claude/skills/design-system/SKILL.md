---
name: design-system
description: Rush Day iOS app design system including colors, typography, and components. Auto-applies when working with UI, styling, or components.
---

# Rush Day Design System

## Colors (use `rd` prefix)

```swift
// Primary
.rdPrimary      // #A17BF4
.rdPrimaryLight // #E1D3FF
.rdPrimaryDark  // #8251EB
.rdAccent       // #A17BF4

// Backgrounds
.rdBackground          // #F2F2F7
.rdBackgroundSecondary // #FFFFFF
.rdSurface             // #E9E9EA
.rdDivider             // #D1D1D6

// Text
.rdTextPrimary    // #0D1017
.rdTextSecondary  // #83828D
.rdTextTertiary   // #9E9EAA

// Status
.rdSuccess  // #B9D600
.rdWarning  // #DB4F47
.rdError    // #DB4F47
```

**IMPORTANT**: Always use `rd` prefix to avoid SwiftUI conflicts.

## Typography (use `rd` prefix)

```swift
.font(.rdDisplay())    // 34pt bold
.font(.rdHeadline())   // 20pt semibold
.font(.rdTitle())      // 16pt medium
.font(.rdBody())       // 15pt regular
.font(.rdLabel())      // 12pt medium
.font(.rdCaption())    // 11pt regular

// Size variants
.font(.rdBody(.large))  // 17pt
.font(.rdBody(.medium)) // 15pt
.font(.rdBody(.small))  // 13pt
```

## Components

### RDButton
```swift
// Unnamed first parameter!
RDButton("Continue", action: { })
RDButton("Delete", style: .destructive, action: { })
RDButton("Add", icon: "plus", action: { })

// Styles: .primary, .secondary, .outline, .ghost, .destructive
```

### SwiftUI Button (toolbars)
```swift
// Use systemImage parameter, NOT Image inside label
Button("", systemImage: "chevron.left") { dismiss() }
Button("", systemImage: "ellipsis") { }.tint(.white)
```

### RDTextField
```swift
RDTextField("Email", text: $email, icon: "envelope")
RDTextField("Password", text: $password, isSecure: true)
```

## Dark Mode

Colors auto-adapt. For custom dark mode logic:
```swift
@Environment(\.colorScheme) private var colorScheme
let bg = colorScheme == .dark ? Color(hex: "2C2C2E") : .white
```

## Shimmer Effect (Loading Skeletons)

**IMPORTANT**: Use `TimelineView` for shimmer animations - state-based animations (`.animation()`, `withAnimation`, `.repeatForever()`) have bugs on iOS 17.

### Usage
```swift
// Apply to any view
MyPlaceholderView()
    .shimmer()
```

### Implementation Pattern (iOS 17+ compatible)
```swift
struct ShimmerModifier: ViewModifier {
    let duration: Double = 1.5

    func body(content: Content) -> some View {
        content
            .overlay(
                TimelineView(.animation) { timeline in
                    let phase = calculatePhase(from: timeline.date)

                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: UnitPoint(x: phase - 1, y: 0.5),
                        endPoint: UnitPoint(x: phase, y: 0.5)
                    )
                }
            )
            .mask(content)  // Respects corner radius!
    }

    private func calculatePhase(from date: Date) -> CGFloat {
        let seconds = date.timeIntervalSinceReferenceDate
        let phase = (seconds.truncatingRemainder(dividingBy: duration)) / duration
        return CGFloat(phase * 2)
    }
}
```

### Why This Works
- **`TimelineView(.animation)`**: Bypasses iOS 17 animation bugs completely
- **No state/onAppear**: Avoids lifecycle timing issues in ScrollViews
- **`UnitPoint` animation**: No GeometryReader needed
- **`.mask(content)`**: Clips shimmer to content shape (respects rounded corners)

### Pre-built Components
```swift
ShimmerRect(width: 200, height: 19)  // Rounded rectangle placeholder
ShimmerCircle(size: 24)              // Circle placeholder (avatars)
```

### Shimmer Views for Screens
- `TasksShimmerView` - Tasks list loading
- `GuestsShimmerView` - Guests list loading
- `AgendaShimmerView` - Agenda loading
- `ExpensesShimmerView` - Expenses loading
- `HomeEventsShimmerView` - Home screen event cards loading
