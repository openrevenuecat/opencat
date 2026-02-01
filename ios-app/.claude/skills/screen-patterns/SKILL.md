---
name: screen-patterns
description: Provides Rush Day iOS app screen implementation patterns including ViewModels, list views, navigation, and common UI patterns. Auto-applies when creating or modifying screens.
---

# Screen Implementation Patterns

## ViewModel Pattern

```swift
@MainActor
class FeatureViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var isSelectMode = false
    @Published var selectedIds: Set<String> = []

    private let eventId: String
    private let repository: RepositoryProtocol

    init(eventId: String) {
        self.eventId = eventId
        self.repository = DIContainer.shared.repository
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await repository.getItems(eventId: eventId)
        } catch {
            print("Failed: \(error)")
        }
    }
}
```

## List View Pattern

```swift
struct FeatureListView: View {
    @StateObject private var viewModel: FeatureViewModel
    @State private var showAddSheet = false

    init(eventId: String) {
        _viewModel = StateObject(wrappedValue: FeatureViewModel(eventId: eventId))
    }

    var body: some View {
        List { ... }
        .task { await viewModel.loadData() }
        .sheet(isPresented: $showAddSheet) { ... }
    }
}
```

## Optimistic Updates

```swift
func toggleStatus(_ id: String) {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return }
    let original = items[index]

    // Update UI immediately
    items[index].status = .completed

    // Sync with backend
    Task {
        do {
            try await repository.update(id: id, status: .completed)
        } catch {
            // Rollback on failure
            items[index] = original
        }
    }
}
```

## Stretchy Header

```swift
GeometryReader { scrollGeometry in
    let offset = scrollGeometry.frame(in: .global).minY
    Image("cover")
        .frame(height: offset > 0 ? 300 + offset : 300)
        .offset(y: offset > 0 ? -offset : 0)
}
.frame(height: 300)
```

## Swipe Actions

```swift
.swipeActions(edge: .trailing) {
    Button(role: .destructive) { delete(item) } label: {
        Label("Delete", systemImage: "trash")
    }
}
```
