# MV Pattern (Model-View)

In SwiftUI, the ViewModel layer is unnecessary. SwiftUI's property wrappers (`@State`, `@Binding`, `@Environment`, etc.) already fulfill the ViewModel role.

## Architecture

```
View <-> Aggregate Root Model (Store) <-> Service <-> Server
```

## Violation Patterns (Bad)

### Per-screen ViewModel

```swift
// BAD: unnecessary ViewModel layer
class OrderListViewModel: ObservableObject {
    @Published var orders: [Order] = []
    private let service: OrderService

    func fetchOrders() async { ... }
}

struct OrderListView: View {
    @StateObject var viewModel = OrderListViewModel()
}
```

### Forwarding @EnvironmentObject to a ViewModel

```swift
// BAD: bypassing what should be accessed directly in the View
struct OrderListView: View {
    @EnvironmentObject var store: OrderStore
    @StateObject var viewModel: OrderListViewModel

    init() {
        // trying to pass store into viewModel
    }
}
```

## Correct Patterns (Good)

### View accesses Store directly

```swift
// GOOD: MV pattern
struct OrderListContainer: View {
    @Environment(OrderStore.self) private var store

    var body: some View {
        OrderListView(orders: store.orders, onDelete: store.delete)
    }
}
```

### UI validation stays in the View

```swift
// GOOD: UI validation is not business logic
struct AddOrderView: View {
    @State private var name = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        TextField("Name", text: $name)
        Button("Save") { ... }
            .disabled(!isValid)
    }
}
```

## Detection Criteria

- A class named `*ViewModel` exists -> likely MV pattern violation
- Per-screen `ObservableObject` classes -> ViewModel-like usage
- UI validation (empty check, character limit, etc.) -> OK in View
- Networking code -> should be in a Service layer (for reusability)
- Business logic -> should be in a Store (Aggregate Root Model)
