# Testing Strategy

## Principle: Test Behavior, Not Implementation

Before writing a test, ask yourself: "What business logic am I testing?" If you cannot answer, do not write that test.

## Test Priority

1. **Store (Aggregate Root Model) tests** - where business logic concentrates
2. **Service integration tests** - verify interaction with external dependencies
3. **E2E tests** - prevent regressions from the user's perspective (highest value)

## The Mocking Trap

```swift
// BAD: mocking the database and verifying mock behavior
func testAddTransaction() {
    let mockDB = MockDatabase()
    let store = BudgetStore(database: mockDB)
    store.addTransaction(amount: 100)
    XCTAssertTrue(mockDB.insertCalled)  // only verifies the mock was called
}

// GOOD: verify behavior with a real database
func testAddTransaction() {
    let db = TestDatabase()  // real Core Data / Realm etc.
    let store = BudgetStore(database: db)
    store.addTransaction(amount: 100)
    XCTAssertEqual(store.budget.balance, 900)  // verifies actual business logic result
}
```

## What to Test

### Should test

- Store business logic (calculations, filtering, sorting, state transitions)
- Service integration with real APIs
- Critical user flows (E2E)

### Should not test

- SwiftUI Views themselves (framework-guaranteed behavior)
- Language features (testing that Swift works)
- Mock behavior (testing that mocks work)

## Anti-patterns

- Test code is 3x the size of production code -> tests for tests' sake
- 2000+ tests but none relate to the business domain
- Pursuing 100% coverage as a goal (meaningful tests matter more)

## Review Criteria

- Do tests focus on business logic (Store/Service)?
- Is mocking overused? (prefer real databases and Services)
- Are Views excessively tested?
- Do tests verify behavior rather than implementation details?
