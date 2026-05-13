# State Placement Rules

SwiftUI state management should follow the framework's design. Do not move property wrappers out of Views.

## Principles

- **UI state belongs in Views** - `@State`, `@Binding`, `@Environment` are View properties
- **Business logic belongs in Stores** - data processing, persistence, API coordination
- **Networking belongs in Services** - reusable, stateless service layer

## UI State (OK in View)

```swift
struct ContentView: View {
    // OK: UI state stays in the View
    @State private var searchText = ""
    @State private var isExpanded = false
    @State private var activeSheet: SheetType?

    // OK: UI validation is fine in the View
    private var isValid: Bool { !searchText.isEmpty }
}
```

## Business Logic (belongs in Store)

```swift
@Observable @MainActor
final class OrderStore {
    var orders: [Order] = []

    private let service: OrderService

    // OK: business logic in Store
    func placeOrder(_ order: Order) async throws {
        let saved = try await service.create(order)
        orders.append(saved)
    }

    var totalAmount: Decimal {
        orders.reduce(0) { $0 + $1.amount }
    }
}
```

## Networking (belongs in Service)

```swift
// OK: stateless Service
struct OrderService {
    func fetchOrders() async throws -> [Order] {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Order].self, from: data)
    }

    func create(_ order: Order) async throws -> Order { ... }
}
```

## Violation Patterns

### Moving @State into a ViewModel

```swift
// BAD: UI state moved outside the View
class FormViewModel: ObservableObject {
    @Published var name = ""         // should be @State
    @Published var isLoading = false // should be @State
}
```

### Networking directly in a View

```swift
// BAD: View calls API directly (not reusable)
struct OrderListView: View {
    var body: some View {
        List { ... }
        .task {
            let (data, _) = try await URLSession.shared.data(from: url)
            // ...
        }
    }
}
```

### Unnecessary abstraction

```swift
// BAD: over-abstracting simple logic
class ButtonStateManager: ObservableObject {
    @Published var isEnabled = false

    func validate(text: String) {
        isEnabled = !text.isEmpty
    }
}

// GOOD: a computed property is sufficient
private var isEnabled: Bool { !text.isEmpty }
```

## Review Criteria

- Are `@State` and `@Binding` correctly placed inside Views?
- Is business logic leaking into Views?
- Is networking separated into a Service layer?
- Are there unnecessary abstractions for simple UI state?
- Are Services stateless (no UI state)?
