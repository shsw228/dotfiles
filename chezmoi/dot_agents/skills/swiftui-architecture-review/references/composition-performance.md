# View Composition and Performance

## Aggressive View Decomposition

SwiftUI is designed for composition. When a View grows large, break it apart.

### Benefits

- Easier to read, test, and reuse
- Passing only the data a subview needs lets SwiftUI update only the parts that changed
- Improved performance

```swift
// GOOD: decomposed into small Views
struct OrderRowView: View {
    let order: Order

    var body: some View {
        HStack {
            OrderStatusBadge(status: order.status)
            OrderInfoView(name: order.name, date: order.date)
            Spacer()
            OrderAmountView(amount: order.amount)
        }
    }
}
```

## Reevaluation vs Rerendering

- **Reevaluation**: SwiftUI checks the diff tree to determine which Views need rerendering. Very fast.
- **Rerendering**: Actually redrawing pixels on screen. Only Views with changes are rerendered.

`body` being called is not a problem by itself. Only changed Views are actually rerendered.

### Performance Tips

- Pass only the minimum necessary data to subviews
- When using large Stores with `@Environment`, be aware that reevaluation scope can widen
- Split Stores if needed to limit reevaluation scope

```swift
// GOOD: pass only needed values
struct OrderAmountView: View {
    let amount: Decimal  // just the needed value, not the entire Order

    var body: some View {
        Text(amount, format: .currency(code: "JPY"))
    }
}
```

## Keep Simple Logic in Views

Formatting, flag toggles, and button enable/disable decisions can stay in the View.

```swift
// GOOD: simple logic stays in the View
struct OrderView: View {
    let order: Order

    // simple formatting in View
    private var formattedDate: String {
        order.date.formatted(date: .abbreviated, time: .shortened)
    }

    // simple validation in View
    private var canSubmit: Bool {
        !order.items.isEmpty && order.totalAmount > 0
    }
}
```

However, when logic grows or gets reused, move it to a helper or a separate type.

## Swift Concurrency

- Use `.task` for data loading (tied to View lifecycle)
- Use async functions for background work
- Update state when results arrive

```swift
// GOOD: lifecycle-managed with .task
struct OrderListContainer: View {
    @Environment(OrderStore.self) private var store

    var body: some View {
        OrderListView(orders: store.orders)
            .task { await store.fetchOrders() }
    }
}
```

## Review Criteria

- Are large Views properly decomposed?
- Are subviews receiving only the minimum necessary data?
- Is simple logic kept in Views (no over-abstraction)?
- Is async work properly managed with `.task`?
- Are Stores growing too large, widening reevaluation scope?
