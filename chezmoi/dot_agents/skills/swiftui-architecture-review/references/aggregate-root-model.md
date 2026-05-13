# Aggregate Root Model (Store)

A pattern that aggregates model objects based on Bounded Contexts instead of creating per-screen ViewModels. Borrows the Aggregate Root concept from DDD.

## ViewModel vs Aggregate Root Model

| Aspect | ViewModel | Aggregate Root Model (Store) |
|--------|-----------|------------------------------|
| Granularity | One per screen | One per domain (Bounded Context) |
| Responsibility | Format data for display | Provide access to and operate on entities |
| Small apps | Multiple VMs | A single Store is enough |

## Scaling Strategy

### Small apps

```swift
// A single Store covers the entire app
@Observable
@MainActor
final class AppStore {
    var orders: [Order] = []
    var user: User?

    private let orderService: OrderService

    func fetchOrders() async { ... }
    func deleteOrder(_ order: Order) { ... }
}
```

### Large apps - split by domain

```swift
@Observable @MainActor
final class OrderStore {
    var orders: [Order] = []
    // ...
}

@Observable @MainActor
final class UserStore {
    var currentUser: User?
    // ...
}

@Observable @MainActor
final class InventoryStore {
    var products: [Product] = []
    // ...
}
```

## Injection

```swift
// Inject via Environment (recommended)
@main
struct MyApp: App {
    @State private var orderStore = OrderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(orderStore)
        }
    }
}
```

## Violation Patterns

### Per-screen ViewModels

```swift
// BAD: ViewModel-style splitting
class OrderListViewModel: ObservableObject { ... }
class OrderDetailViewModel: ObservableObject { ... }
class AddOrderViewModel: ObservableObject { ... }
```

### Too many Stores (screen-level splitting)

```swift
// BAD: split by screen instead of domain
class OrderListStore: ObservableObject { ... }
class OrderDetailStore: ObservableObject { ... }
// -> if same domain, consolidate into OrderStore
```

## Review Criteria

- Are there ViewModel classes? (MV pattern violation)
- Are Stores organized by domain (Bounded Context)?
- Is the app over-split for its size?
- Using `@Observable` instead of `ObservableObject`? (preferred)
- Can Stores communicate with each other when needed?
