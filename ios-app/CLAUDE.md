# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Important Notes for Claude

**Preferred Simulator** - Always use **iPhone 16e (iOS 26.1)** for testing. Shut down other simulators before running scripts to ensure consistency:
```bash
xcrun simctl shutdown all 2>/dev/null || true
xcrun simctl boot "iPhone 16e" 2>/dev/null || true
```

**Xcode Cloud commit messages** - Xcode Cloud only displays the last (HEAD) commit message, not all commits in a push. When creating commits for features that will be pushed together, either:
1. Squash commits before pushing (`git rebase -i`) to have one comprehensive message
2. Make the final commit message descriptive of all changes in the push

## Project Overview

Rush Day is a native iOS event management app built with SwiftUI. Users can create, manage, and share events with features including guest management, task tracking, expenses, agenda scheduling, and RSVP handling.

This is a rewrite of the Flutter mobile app to native Swift/SwiftUI for iOS.

## Common Commands

```bash
# Open in Xcode
open RushDay.xcodeproj

# Regenerate gRPC Swift files after proto changes
cd RushDay/Core/Services/GRPC/Proto && ./generate.sh

# Clean build folder (if needed)
xcodebuild -project RushDay.xcodeproj -scheme RushDay clean
```

## Auto-Build & Testing Scripts

The project includes scripts for automated building, testing, and screenshots.

### Auto-Build Script (`scripts/auto-build.sh`)

```bash
# FASTEST: Install Xcode's build + relaunch + screenshot (use after Cmd+B in Xcode)
./scripts/auto-build.sh quick [screenshot-name]

# Just install from Xcode's existing build (no screenshot)
./scripts/auto-build.sh install

# Full xcodebuild + relaunch + screenshot (slower, ~30s)
./scripts/auto-build.sh full [screenshot-name]

# Just build via xcodebuild (incremental)
./scripts/auto-build.sh build

# Just relaunch the app
./scripts/auto-build.sh relaunch

# Just take a screenshot
./scripts/auto-build.sh screenshot [name]

# Watch mode - auto-rebuild when Swift files change
./scripts/auto-build.sh watch
```

### App Tester Script (`scripts/app-tester.sh`)

```bash
# Take screenshot of simulator
./scripts/app-tester.sh screenshot [output-path]
./scripts/app-tester.sh ss .claude/screenshots/test.png

# Open deep link URL
./scripts/app-tester.sh open rushday://debug/feature-paywall

# Launch/terminate app
./scripts/app-tester.sh launch
./scripts/app-tester.sh terminate

# List available simulators
./scripts/app-tester.sh list
```

### Debug Deep Links (DEBUG builds only)

Navigate directly to screens for testing:

```bash
./scripts/app-tester.sh open rushday://debug/paywall              # Main paywall
./scripts/app-tester.sh open rushday://debug/feature-paywall      # Feature paywall sheet
./scripts/app-tester.sh open rushday://debug/onboarding           # Onboarding flow
./scripts/app-tester.sh open rushday://debug/ai-planner           # AI event planner wizard
./scripts/app-tester.sh open rushday://debug/home                 # Home screen
./scripts/app-tester.sh open rushday://debug/settings             # Settings screen
./scripts/app-tester.sh open rushday://debug/profile              # Profile screen
./scripts/app-tester.sh open rushday://debug/console              # Debug console
./scripts/app-tester.sh open rushday://debug/create-event         # Create event screen
./scripts/app-tester.sh open rushday://debug/event-details        # Event details (first event)
./scripts/app-tester.sh open rushday://debug/guests               # Guests list (first event)
./scripts/app-tester.sh open rushday://debug/tasks                # Tasks list (first event)
./scripts/app-tester.sh open rushday://debug/agenda               # Agenda (first event)
./scripts/app-tester.sh open rushday://debug/expenses             # Expenses (first event)
./scripts/app-tester.sh open rushday://debug/invitation-preview   # Invitation preview (first event)
./scripts/app-tester.sh open rushday://debug/edit-event           # Edit event (first event)
./scripts/app-tester.sh open rushday://debug/notification-settings # Notification settings
```

### Typical Workflow

```bash
# RECOMMENDED: Fast iteration using Xcode's build
# 1. Make code changes
# 2. Build in Xcode (Cmd+B) - fast incremental build
# 3. Quick install + screenshot (~4 seconds):
./scripts/auto-build.sh quick my-feature

# Or navigate to specific screen first:
./scripts/app-tester.sh open rushday://debug/feature-paywall
sleep 2
./scripts/auto-build.sh ss feature-paywall

# ALTERNATIVE: Full xcodebuild (slower, ~30s)
./scripts/auto-build.sh full my-feature
```

**Tip:** Building in Xcode (Cmd+B) is faster than xcodebuild because Xcode's incremental build is highly optimized. Use `quick` mode to leverage Xcode's build cache.

## Architecture

The app follows **Clean Architecture** with MVVM for the presentation layer:

```
RushDay/
├── App/                    # App entry point and global state
│   ├── RushDayApp.swift    # @main entry point, Firebase config
│   ├── AppState.swift      # Global app state (auth, navigation)
│   └── ContentView.swift   # Root view with auth flow
├── Core/                   # Core utilities and services
│   ├── DI/                 # Dependency injection container
│   ├── Extensions/         # Swift/SwiftUI extensions (Color, Font)
│   ├── Services/           # External service implementations
│   │   ├── Firebase/       # Auth, Firestore, Storage, FCM, Analytics
│   │   ├── GRPC/           # gRPC client and proto files
│   │   │   ├── Proto/      # .proto source files + generate.sh
│   │   │   └── Generated/  # Generated Swift files (do not edit)
│   │   ├── Networking/     # Network layer
│   │   └── RevenueCat/     # In-app purchases
│   ├── Storage/            # Local storage
│   └── Helpers/            # Utility functions
├── Domain/                 # Business logic layer
│   ├── Entities/           # Business objects (Event, Guest, EventTask, etc.)
│   └── Repositories/       # Repository protocols
├── Data/                   # Data layer
│   ├── DataSources/        # Remote/local data sources
│   ├── Models/             # DTOs for API/storage
│   ├── Mappers/            # Entity-to-model mapping
│   └── RepositoriesImpl/   # Repository implementations
├── Presentation/           # UI layer
│   ├── Screens/            # Feature screens
│   │   ├── Auth/           # Login, signup, social auth
│   │   ├── Home/           # Main tab view, event list
│   │   ├── CreateEvent/    # Event creation flow
│   │   ├── EventDetails/   # Event detail view
│   │   ├── Guests/         # Guest management
│   │   ├── Tasks/          # Task management with drag-reorder
│   │   ├── Expenses/       # Expense tracking
│   │   ├── Agenda/         # Agenda/timeline
│   │   ├── Onboarding/     # First-time user flow
│   │   ├── Profile/        # User profile and settings
│   │   ├── Paywall/        # Subscription screens (RevenueCat)
│   │   ├── AIEventPlanner/ # AI-assisted event creation wizard
│   │   ├── InvitationPreview/ # Event invitation preview and sharing
│   │   └── Debug/          # Debug tools (dev only)
│   ├── Components/         # Reusable UI components (RDButton, RDCard, etc.)
│   └── ViewModels/         # View models (when separate from views)
└── Resources/              # Assets, fonts, localizations
    ├── Assets.xcassets/    # Images and colors
    ├── Fonts/              # Custom fonts
    └── Localizable.xcstrings # Localized strings
```

## Key Technologies

- **Minimum iOS**: 17.0
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **UI Framework**: SwiftUI
- **Backend**: gRPC (primary) + Firebase (Auth, Storage, FCM, Analytics)
- **In-App Purchases**: RevenueCat SDK v5+
- **Architecture**: Clean Architecture + MVVM
- **Package Manager**: Swift Package Manager (SPM)

## Dependency Injection

Uses a singleton `DIContainer` for dependency injection:

```swift
// Access services and repositories
let authService = DIContainer.shared.authService
let eventRepository = DIContainer.shared.eventRepository
let taskRepository = DIContainer.shared.taskRepository
```

All services use protocol-based abstraction for testability:
- `AuthServiceProtocol` - Authentication
- `StorageServiceProtocol` - File storage
- `NotificationServiceProtocol` - Push notifications
- `GRPCClientService` - Main backend communication (ALL data operations)

**IMPORTANT: Use gRPC for ALL data operations.** Do NOT use Firestore for data storage. All repositories (Events, Guests, Tasks, Expenses, Agenda) must use gRPC backend via `GRPCClientService`.

## Design System

### Colors (rd prefix to avoid SwiftUI conflicts)

```swift
// Primary (Purple theme matching Flutter)
.rdPrimary      // #A17BF4 (Flutter: primary)
.rdPrimaryLight // #E1D3FF
.rdPrimaryDark  // #8251EB
.rdAccent       // #A17BF4 (same as primary)

// Backgrounds
.rdBackground          // #F2F2F7 (Flutter: backgroundPrimary)
.rdBackgroundSecondary // #FFFFFF (Flutter: backgroundFields)
.rdSurface             // #E9E9EA (Flutter: fillSecondary)
.rdDivider             // #D1D1D6 (Flutter: grey)

// Text
.rdTextPrimary    // #0D1017 (Flutter: textPrimary)
.rdTextSecondary  // #83828D (Flutter: smokyGrey)
.rdTextTertiary   // #9E9EAA (Flutter: textHint)

// Status
.rdSuccess  // #B9D600 (lime/olive)
.rdWarning  // #DB4F47
.rdError    // #DB4F47
```

**IMPORTANT**: Always use `rd` prefixed colors (e.g., `.rdAccent` not `.accent`) to avoid conflicts with SwiftUI's built-in color names.

### Typography

Use the `rd` prefixed font functions:

```swift
.font(.rdDisplay())     // Display text (34pt bold)
.font(.rdHeadline())    // Headlines (20pt semibold)
.font(.rdTitle())       // Titles (16pt medium)
.font(.rdBody())        // Body text (15pt regular)
.font(.rdLabel())       // Labels (12pt medium)
.font(.rdCaption())     // Captions (11pt regular)

// With size variants
.font(.rdBody(.large))  // 17pt
.font(.rdBody(.medium)) // 15pt (default)
.font(.rdBody(.small))  // 13pt
```

### Components

#### RDButton
```swift
// Primary button (unnamed first parameter for title)
RDButton("Continue", action: { })

// With style
RDButton("Delete", style: .destructive, action: { })

// With icon
RDButton("Add Guest", icon: "plus", action: { })

// Styles: .primary, .secondary, .outline, .ghost, .destructive
// Sizes: .small, .medium, .large
```

**IMPORTANT**: RDButton uses an unnamed first parameter for the title:
- Correct: `RDButton("Title", style: .primary, action: {})`
- Wrong: `RDButton(title: "Title", style: .primary, action: {})`

#### SwiftUI Button (for toolbars and simple buttons)

**IMPORTANT**: Do NOT use `Image` inside `Button`. Use the Button initializer with `systemImage` or `image` parameter:

```swift
// System SF Symbol - use systemImage parameter
Button("", systemImage: "chevron.left") { dismiss() }

// Custom asset image - use image parameter with ImageResource
Button("", image: ImageResource(name: "icon_images", bundle: .main)) { action() }

// With tint color
Button("", systemImage: "ellipsis") { showMenu = true }
    .tint(.white)
```

**WRONG** - Don't do this:
```swift
// DON'T put Image inside Button label
Button { action() } label: {
    Image(systemName: "chevron.left")  // Wrong!
}
```

#### RDTextField
```swift
RDTextField("Email", text: $email, icon: "envelope")
RDTextField("Password", text: $password, isSecure: true)
```

#### RDCard
```swift
RDCard(event: event, onTap: { })
```

#### Shimmer Effect (Loading Skeletons)

**IMPORTANT**: Use `TimelineView` for shimmer - state-based animations have bugs on iOS 17.

```swift
// Apply shimmer to any placeholder view
ShimmerRect(width: 200, height: 19)  // Rounded rectangle
ShimmerCircle(size: 24)              // Circle (for avatars)
MyCustomView().shimmer()             // Custom view
```

See `ShimmerView.swift` for implementation. Key pattern:
- Use `TimelineView(.animation)` instead of `.animation()` modifier
- Use `.mask(content)` to respect corner radius
- Pre-built shimmer views: `TasksShimmerView`, `GuestsShimmerView`, `AgendaShimmerView`, `ExpensesShimmerView`, `HomeEventsShimmerView`

## Entity Properties

### Event
```swift
event.id
event.eventType      // Not `type` - use `eventType`
event.title
event.date
event.location
event.hostId
event.coverImage
```

### EventTask
```swift
task.id
task.eventId
task.name
task.status          // TaskStatus: .pending, .completed
task.dueDate         // Optional notification/due date
task.notes
task.order           // Position for custom ordering (drag-reorder)
task.createdAt
task.updatedAt
```

### AgendaItem
```swift
item.id
item.title
item.startTime
item.endTime
item.duration        // Computed: TimeInterval?
item.durationText    // Computed: String? (e.g., "1h 30m")
item.location
item.order
```

**Note**: `AgendaItem` has NO `durationMinutes` property. Duration is computed from `startTime` and `endTime`.

### Guest
```swift
guest.id
guest.eventId
guest.name
guest.email
guest.phone
guest.status          // GuestStatus: .pending, .confirmed, .declined
guest.invitedAt
guest.respondedAt
```

### Expense
```swift
expense.id
expense.eventId
expense.title
expense.amount
expense.category      // ExpenseCategory enum
expense.paidBy
expense.createdAt
```

## Screen Patterns

### List Views (Tasks, Guests, Expenses, Agenda)

All list views follow a similar pattern:
- `@StateObject` ViewModel initialized with `eventId`
- Multi-select mode with delete bar
- Floating add button
- Sheet for adding/editing items
- Swipe actions for delete/complete
- Empty state view
- Optimistic UI updates with backend sync

```swift
struct TasksListView: View {
    @StateObject private var viewModel: TasksViewModel
    @State private var showAddTask = false

    init(eventId: String) {
        _viewModel = StateObject(wrappedValue: TasksViewModel(eventId: eventId))
    }
}
```

### ViewModels

ViewModels are `@MainActor` classes with `@Published` properties:

```swift
@MainActor
class TasksViewModel: ObservableObject {
    @Published var tasks: [EventTask] = []
    @Published var isLoading = false
    @Published var isSelectMode = false
    @Published var selectedTaskIds: Set<String> = []

    private let eventId: String
    private let taskRepository: TaskRepositoryProtocol

    init(eventId: String) {
        self.eventId = eventId
        self.taskRepository = DIContainer.shared.taskRepository
    }

    func loadTasks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            tasks = try await taskRepository.getTasksForEvent(eventId: eventId)
            tasks.sort { $0.order < $1.order }
        } catch {
            print("Failed to load tasks: \(error)")
        }
    }

    // Optimistic update pattern
    func toggleTaskStatus(_ taskId: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let originalTask = tasks[index]
        let newStatus: TaskStatus = originalTask.status == .completed ? .pending : .completed

        // Update UI immediately
        tasks[index].status = newStatus

        // Sync with backend
        Task {
            do {
                try await taskRepository.updateTaskStatus(taskId: taskId, status: newStatus)
            } catch {
                // Rollback on failure
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[idx].status = originalTask.status
                }
            }
        }
    }
}
```

### Conditional View Modifiers

Use the `.if` extension for conditional modifiers:

```swift
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Usage - only add tap gesture in select mode
.if(isSelectMode) { view in
    view.onTapGesture { onSelect() }
}
```

## Code Style

- Use SwiftUI's native patterns (no UIKit unless necessary)
- Prefer `async/await` over completion handlers
- Use `@MainActor` for ViewModels
- Mark sections with `// MARK: -` comments
- Keep views focused - extract subviews into separate structs
- Use computed properties for derived state
- Protocol-first design for services and repositories
- Use spring animations for smooth UI transitions: `.animation(.spring(response: 0.3), value: state)`
- Use `@available(iOS 26.0, *)` checks for liquid glass effects (see `InvitationPreviewView.swift`)

## gRPC Integration

The app uses gRPC as the primary backend communication. Proto files are in `Core/Services/GRPC/Proto/`.

### Regenerating Swift Files

After modifying any `.proto` file:

```bash
cd RushDay/Core/Services/GRPC/Proto
./generate.sh
```

This generates Swift files in `Core/Services/GRPC/Generated/`. Prerequisites:
- `protoc` (brew install protobuf)
- `swift-protobuf` (brew install swift-protobuf)
- grpc-swift v1.x plugin at `~/bin/protoc-gen-grpc-swift-1`

### Using gRPC Client

```swift
// Connect on app launch
let grpc = GRPCClientService.shared
try grpc.connect(configuration: .production) // or .development for localhost:50051
grpc.setAuthToken(firebaseIdToken)

// Use typed clients
let events = try await grpc.listEvents()
let user = try await grpc.getCurrentUser()
let tasks = try await grpc.listTasks(eventId: eventId)

// Reorder tasks (drag-and-drop)
let reordered = try await grpc.reorderTasks(eventId: eventId, taskIds: orderedIds)
```

### Proto Services

| File | Purpose |
|------|---------|
| `user.proto` | User management, migration |
| `event.proto` | Events, Tasks, Guests, Agenda, Budget |
| `vendor.proto` | Vendor listings |
| `invitation.proto` | Public invitation links |
| `ai_planner.proto` | AI event planning |
| `common.proto` | Shared types |

### Adding New RPC Methods

1. Add method to `.proto` file in `Proto/` directory
2. Run `./generate.sh` to regenerate Swift files
3. Add wrapper method to `GRPCClientService.swift`
4. Add to repository protocol in `Domain/Repositories/Repositories.swift`
5. Implement in `Data/RepositoriesImpl/RepositoryImplementations.swift`

## Firebase Integration

Firebase is configured in `AppDelegate`:

```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions...) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
```

Services are in `Core/Services/Firebase/`:
- `FirebaseAuthService.swift` - Authentication (provides tokens for gRPC)
- `FirebaseStorageService.swift` - File storage (images)
- `FCMNotificationService.swift` - Push notifications
- `AnalyticsService.swift` - Event tracking (use `AnalyticsService.shared`)

**Note:** Firestore is NOT used for data storage. All data (Events, Guests, Tasks, Expenses, Agenda) goes through gRPC backend.

## Additional Services

### AppsFlyer (Attribution & Analytics)
```swift
// Log events
AppsFlyerService.shared.logTrialStart(productId: "...")
AppsFlyerService.shared.logSubscriptionPurchase(productId: "...", price: 9.99, currency: "USD")

// Deep linking handled in AppDelegate
```

### Image Caching
```swift
// Use CachedAsyncImage for remote images
CachedAsyncImage(url: URL(string: imageUrl)) { image in
    image.resizable().aspectRatio(contentMode: .fill)
} placeholder: {
    ProgressView()
}

// Prefetch images
ImageCache.shared.prefetch(url: URL(string: coverUrl))
```

### Rate Us Service
```swift
// Trigger rate prompt after conditions met
RateUsService.shared.incrementEventCount()
RateUsService.shared.showRateUsIfNeeded()

// Reset for testing (Debug only)
RateUsStorage.shared.reset()
```

### Analytics (Dual Tracking)

The app uses both Firebase Analytics and AppsFlyer:

```swift
// Firebase Analytics
AnalyticsService.shared.logPaywallView(source: "home")
AnalyticsService.shared.logSubscriptionPurchase(packageType: "annual", productId: "...", price: 49.99, currency: "USD")

// AppsFlyer (attribution)
AppsFlyerService.shared.logRegistration(method: "apple")
AppsFlyerService.shared.logSubscriptionPurchase(productId: "...", price: 49.99, currency: "USD")
```

## Common Patterns

### Navigation
```swift
// In ViewModel
@Published var navigateTo: Destination?

// In View
.navigationDestination(item: $viewModel.navigateTo) { destination in
    switch destination {
    case .guests: GuestsListView(eventId: eventId)
    case .tasks: TasksListView(eventId: eventId)
    }
}
```

### Async Data Loading
```swift
.task {
    await viewModel.loadData()
}
```

### Environment Dismiss
```swift
@Environment(\.dismiss) private var dismiss

Button("Close") { dismiss() }
```

### Scroll-Aware Navigation Title
```swift
@State private var showNavTitle = false

ScrollView {
    GeometryReader { geometry in
        Color.clear.preference(
            key: ScrollOffsetPreferenceKey.self,
            value: geometry.frame(in: .named("scroll")).minY
        )
    }
    .frame(height: 0)

    // Content with inline header
    Text("Title")
        .font(.rdHeadline())
}
.coordinateSpace(name: "scroll")
.onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
    showNavTitle = offset < -20
}
.navigationBarTitleDisplayMode(.inline)
.toolbar {
    ToolbarItem(placement: .principal) {
        Text("Title")
            .opacity(showNavTitle ? 1 : 0)
    }
}
```

### Drag and Drop Reordering
```swift
ForEach(items) { item in
    ItemRow(item: item)
        .draggable(item.id) {
            ItemDragPreview(item: item)
        }
        .dropDestination(for: String.self) { droppedIds, _ in
            guard let droppedId = droppedIds.first else { return false }
            viewModel.moveItem(droppedId, to: item.id)
            return true
        }
}
```

### Custom Drag with Long Press (Tasks)
```swift
// TasksListView uses custom gesture for more control
LongPressGesture(minimumDuration: 0.2)
    .sequenced(before: DragGesture(coordinateSpace: .named("tasksList")))
    .onChanged { value in
        // Handle drag
    }
    .onEnded { _ in
        // Commit reorder
    }
```

### Contact Import (Guests)
```swift
import Contacts

// Request permission
let store = CNContactStore()
try await store.requestAccess(for: .contacts)

// Fetch contacts
let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey, CNContactPhoneNumbersKey]
let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
try store.enumerateContacts(with: request) { contact, _ in
    // Process contact
}
```

### Backdrop Blur (True Image Blur)

iOS materials (`.ultraThinMaterial`, etc.) always add color tint from the background. For a true backdrop blur without color tint, use a duplicate blurred image with a gradient mask:

```swift
ZStack(alignment: .bottom) {
    // Sharp image
    CachedAsyncImage(url: imageUrl) { image in
        image.resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: height)
            .clipped()
    }

    // Blurred image with gradient mask - seamless blend
    CachedAsyncImage(url: imageUrl) { image in
        image.resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: height)
            .blur(radius: 15)
            .clipped()
    }
    .frame(height: height)
    .mask(
        // Gradient mask: transparent at top, opaque at bottom
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.72),  // Blur starts here
                .init(color: .black, location: 0.82),  // Fully blurred
                .init(color: .black, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    )

    // Content on top
    VStack { /* text content */ }
}
```

**Key points:**
- Load the image twice (sharp + blurred)
- Apply `.blur(radius:)` to the second copy
- Use a gradient mask to fade blur seamlessly into sharp image
- Adjust `location` values to control where blur starts
- See `GeneratedEventCoverHeader` in `GeneratedEventResultView.swift` for full example

## Important Files

| File | Purpose |
|------|---------|
| `App/RushDayApp.swift` | App entry point, Firebase setup |
| `App/AppState.swift` | Global auth state, navigation, subscription status |
| `Core/DI/DIContainer.swift` | Dependency injection, service protocols |
| `Core/Extensions/Color+Theme.swift` | App color palette (`rd` prefix) |
| `Core/Extensions/Font+Theme.swift` | Typography system (`rd` prefix) |
| `Core/Services/GRPC/GRPCClientService.swift` | gRPC client singleton |
| `Core/Services/GRPC/Proto/generate.sh` | Proto regeneration script |
| `Core/Services/AppsFlyer/AppsFlyerService.swift` | Attribution & analytics |
| `Core/Helpers/ImageCache.swift` | Remote image caching |
| `Domain/Entities/*.swift` | Business entities |
| `Domain/Repositories/Repositories.swift` | Repository protocols |
| `Data/RepositoriesImpl/RepositoryImplementations.swift` | Repository implementations |
| `Presentation/Components/RDButton.swift` | Primary button component |
| `Presentation/Screens/Paywall/PaywallScreen.swift` | Subscription UI |
| `Presentation/Screens/InvitationPreview/InvitationPreviewView.swift` | Invitation sharing |

### Screen File Sizes (for reference)

| Screen | Lines | Notes |
|--------|-------|-------|
| `GuestsListView.swift` | ~2200 | Largest - swipe actions, multi-select, contact import |
| `TasksListView.swift` | ~2100 | Drag-drop reorder, inline editing |
| `EventDetailsView.swift` | ~1900 | RSVP animations, co-hosts, calendar |
| `AIEventPlannerViewModel.swift` | ~800 | 7-step wizard state management |
| `MainTabView.swift` | ~900 | Home screen with event filtering |

## RevenueCat Integration

```swift
// Access via DIContainer
let revenueCat = DIContainer.shared.revenueCatService

// Configure on app launch
try await revenueCat.configure(apiKey: "your_api_key", userId: userId)

// Get offerings and purchase
let packages = try await revenueCat.getOfferings()
let status = try await revenueCat.purchase(package: selectedPackage)

// Check subscription status
let status = try await revenueCat.getSubscriptionStatus()
if status.isActive { /* user is premium */ }
```

**Note**: Use `package.packageType.stringValue` (not `.rawValue`) for analytics logging.

### Paywall Presentation
```swift
// From any view
.fullScreenCover(isPresented: $showPaywall) {
    PaywallScreen(source: "feature_name") {
        // On purchase success
        appState.updateSubscriptionStatus(true)
    }
}

// Check subscription status
if appState.isSubscribed {
    // Premium features
} else {
    showPaywall = true
}
```

### Invitation Preview
```swift
// Show invitation preview for editing
InvitationPreviewScreen(
    event: event,
    owner: currentUser,
    isViewOnly: false,
    onSave: { updatedEvent, localImage in
        // Handle save
    }
)

// AI-generated invite message
let message = try await GRPCClientService.shared.generateInviteMessage(eventId: eventId)
```

## Flutter-to-Swift Migration Reference

| Flutter | Swift Equivalent |
|---------|------------------|
| Freezed models | Codable structs |
| Cubit/BLoC | ObservableObject/ViewModel |
| GetIt | DIContainer singleton |
| SharedPreferences | UserDefaults |
| FlutterSecureStorage | Keychain |
| go_router | NavigationStack |
| easy_localization | String Catalogs |

When implementing features, reference the Flutter app at `../mobile/` for business logic parity.

## User Data Migration (Firestore → gRPC Backend)

One-time migration when users update the app to use the new gRPC backend:

```swift
// Call once when app launches after update
func migrateUserDataIfNeeded() async {
    let request = Rushday_V1_MigrateUserDataRequest.with {
        $0.appVersion = Bundle.main.appVersion
    }

    do {
        let response = try await GRPCClientService.shared.userClient.migrateUserData(request)
        if response.alreadyMigrated {
            print("Already migrated")
        } else {
            print("Migrated: \(response.stats.eventsMigrated) events")
        }
    } catch {
        print("Migration error: \(error)")
    }
}
```

**What Gets Migrated:**
- Devices (from `users/{uid}/devices` subcollection)
- Notification preferences
- Events where user is owner (with tasks, guests, agendas, expenses, co-hosts)
- Vendors

The backend tracks migration status in `user_migration_status` table to prevent duplicates.

## AI Event Planner Module

The AI Event Planner is a wizard-based flow for AI-assisted event creation. Located at `Presentation/Screens/AIEventPlanner/`.

### File Structure

```
AIEventPlanner/
├── AIEventPlannerView.swift      # Main coordinator view (entry point)
├── AIEventPlannerViewModel.swift # State management for wizard (shared singleton)
├── AIPlanDetailView.swift        # Post-auth preview (uses GeneratedEventResultView)
├── Models/
│   ├── AIEventPlannerEnums.swift # Presentation enums (AIEventType, BudgetTier, etc.)
│   └── GeneratedPlan.swift       # Domain models (GeneratedPlan, PlanTask, PendingEventData)
├── Components/                   # Wizard-specific reusable components
│   ├── WizardProgressBar.swift
│   ├── OptionCard.swift
│   ├── PlanResultCard.swift
│   └── ...
└── Steps/                        # Individual wizard steps
    ├── WelcomeStepView.swift
    ├── EventTypeStepView.swift
    ├── GuestCountStepView.swift
    ├── EventDetailsStepView.swift
    ├── VenueTypeStepView.swift
    ├── BudgetStepView.swift
    ├── ServicesStepView.swift
    ├── PreferencesStepView.swift
    ├── GeneratingStepView.swift
    └── ResultsStepView.swift
```

### Wizard Theme Colors

The wizard uses its own dark-mode aware color scheme (NOT the `rd` prefixed colors):

```swift
struct WizardTheme {
    let colorScheme: ColorScheme

    var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "101828")
    }
    var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "4A5565")
    }
    var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F2937").opacity(0.8) : Color.white.opacity(0.8)
    }
    var cardBorder: Color {
        colorScheme == .dark ? Color(hex: "374151") : Color(hex: "E5E7EB")
    }
}

// Usage in step views:
@Environment(\.colorScheme) private var colorScheme
private var theme: WizardTheme { WizardTheme(colorScheme: colorScheme) }
```

### AIEventPlannerViewModel (Shared Singleton)

The ViewModel uses a shared instance to preserve state across auth transitions:

```swift
// Access the shared instance
@ObservedObject private var viewModel = AIEventPlannerViewModel.shared

// Reset when flow completes
viewModel.resetState()
```

**Key Features:**
- gRPC streaming for AI plan generation
- Cached plan details to avoid duplicate API calls
- Image prefetching for smooth transitions
- Auth-gated plan details (requires sign-in)

### Stretchy Header Pattern

Used in `PlanDetailView` and `EventDetailsView`:

```swift
GeometryReader { geometry in
    ScrollView {
        VStack(spacing: 0) {
            GeometryReader { scrollGeometry in
                HeaderView(scrollOffset: scrollGeometry.frame(in: .global).minY)
            }
            .frame(height: WizardConstants.headerHeight)

            VStack { /* Content */ }
        }
    }
}
.ignoresSafeArea()
```

## Debug Tools

Available in DEBUG builds via Profile > Debug Console:

### Features
- **Environment Info**: Shows gRPC host, Firebase project, app version
- **Network Logger**: View all gRPC/HTTP requests with headers and bodies
- **Subscription Override**: Toggle premium status for testing
- **Firebase Migration**: Manually trigger Firestore → gRPC migration
- **Reset Onboarding**: Re-show onboarding flow
- **Reset Rate Us**: Clear rate prompt state
- **Liquid Glass Lab**: Test iOS 26 glass effects

### Subscription Override (for testing)
```swift
// In DebugView - persisted via @AppStorage
@AppStorage("debug_subscription_override_enabled") private var subscriptionOverrideEnabled = false
@AppStorage("debug_subscription_override_value") private var subscriptionOverrideValue = true

// AppState checks this override
appState.setSubscriptionOverride(enabled: true, value: true) // Simulate premium
```
