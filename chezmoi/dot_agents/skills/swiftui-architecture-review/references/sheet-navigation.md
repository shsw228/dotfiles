# Sheet and Navigation Management

## Sheet Management: Single Enum Pattern

Manage sheet state with a single enum instead of multiple Bool flags.

### Violation Pattern (Bad)

```swift
// BAD: proliferating Bool flags
@State private var showingProfile = false
@State private var showingSettings = false
@State private var showingConfirmation = false

var body: some View {
    Button("Profile") { showingProfile = true }
    .sheet(isPresented: $showingProfile) { ProfileView() }
    .sheet(isPresented: $showingSettings) { SettingsView() }
    .sheet(isPresented: $showingConfirmation) { ConfirmationView() }
}
```

Problems:
- Management complexity grows with each flag
- Multiple flags can be true simultaneously, causing bugs
- Stacking sheets degrades user experience

### Correct Pattern (Good)

```swift
// GOOD: single enum management
enum SheetType: Identifiable {
    case profile
    case settings
    case confirmation(Item)

    var id: String {
        switch self {
        case .profile: "profile"
        case .settings: "settings"
        case .confirmation(let item): "confirmation-\(item.id)"
        }
    }
}

@State private var activeSheet: SheetType?

var body: some View {
    Button("Profile") { activeSheet = .profile }
    .sheet(item: $activeSheet) { sheet in
        switch sheet {
        case .profile: ProfileView()
        case .settings: SettingsView()
        case .confirmation(let item): ConfirmationView(item: item)
        }
    }
}
```

Benefits:
- Structurally impossible to show two sheets simultaneously
- Adding a new sheet is just adding an enum case
- `.sheet(item:)` naturally controls open/close via nil/non-nil

## Navigation

### Sharing state via NavigationStack

```swift
// GOOD: inject Store at NavigationStack level
struct OrderFlow: View {
    @State private var store = OrderStore()

    var body: some View {
        NavigationStack {
            OrderListContainer()
        }
        .environment(store)
    }
}
```

### Data Flow Patterns

- **Simple cases**: closures are sufficient
- **Multiple interactions**: represent events with an enum
- **Complex scenarios**: Observation / Combine (but do not introduce early)

```swift
// GOOD: closure for simple cases
OrderRowView(order: order, onTap: { selectedOrder = order })

// GOOD: enum for multiple events
enum OrderAction {
    case select(Order)
    case delete(Order)
    case edit(Order)
}
OrderRowView(order: order, onAction: handleAction)
```

## Exposing Actions via Environment

```swift
// GOOD: expose actions through Environment
struct ShowToastKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var showToast: (String) -> Void {
        get { self[ShowToastKey.self] }
        set { self[ShowToastKey.self] = newValue }
    }
}
```

## Applying the Same Pattern

The same single-enum pattern applies to alerts and confirmationDialogs.

## Review Criteria

- Are sheets managed with Bool flags instead of an enum?
- Are multiple `.sheet(isPresented:)` modifiers attached to the same View?
- Does the sheet enum conform to `Identifiable`?
- Are alerts and confirmationDialogs also using the enum pattern?
- Are Stores shared via Environment at the correct navigation level?
