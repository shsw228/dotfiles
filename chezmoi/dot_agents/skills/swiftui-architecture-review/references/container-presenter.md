# Container/Presenter Pattern

A design pattern that splits Views into two roles. Clear responsibility boundaries make bugs easier to locate and improve testability.

## Container (Screen)

- Handles data fetching, state management, and business logic invocation
- Interacts with Stores and Services
- Passes pure data down to Presenters

## Presenter (Display)

- Receives data and renders UI only
- No networking or business logic
- Easy to test and preview

## Correct Pattern

```swift
// Container: prepares data
struct OrderListContainer: View {
    @Environment(OrderStore.self) private var store

    var body: some View {
        OrderListView(
            orders: store.orders,
            onDelete: store.delete
        )
        .task { await store.fetchOrders() }
    }
}

// Presenter: focuses on UI only
struct OrderListView: View {
    let orders: [Order]
    let onDelete: (Order) -> Void

    var body: some View {
        List(orders) { order in
            OrderRowView(order: order)
        }
    }
}
```

## Violation Patterns

### Presenter fetches data

```swift
// BAD: Presenter is doing the Container's job
struct OrderListView: View {
    @Environment(OrderStore.self) private var store

    var body: some View {
        List(store.orders) { order in
            Text(order.name)
        }
        .task { await store.fetchOrders() }  // Presenter should not fetch data
    }
}
```

### Mixed responsibilities in a single View

```swift
// BAD: data fetching and UI mixed into one View
struct OrderListView: View {
    @State private var orders: [Order] = []
    let service = OrderService()

    var body: some View {
        List(orders) { order in
            // complex UI...
        }
        .task {
            orders = try await service.fetchOrders()
        }
    }
}
```

## Review Criteria

- Are screen-level Views split into Container and Presenter?
- Does the Presenter avoid directly accessing Stores via `@Environment`?
- Does the Presenter receive data via `let` properties and closures?
- Does the Container manage data fetching with `.task`?
- Small components do not need this split (avoid over-separation)
