# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```typescript
// GOOD: Tests observable behavior
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```typescript
// BAD: Tests implementation details
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order as the primary check (see _Result-driven over invocation-spying_ for the narrow exceptions)
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```typescript
// BAD: Bypasses interface to verify
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// GOOD: Verifies through interface
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```

## Result-driven over invocation-spying

Prefer asserting on the **returned value or observable state**. Fall back to invocation checks only for behaviour that is invisible in the return.

```typescript
// BAD: spies on the call; passes even if the returned order is wrong
test("checkout charges the card", async () => {
  const pay = jest.fn();
  await checkout(cart, { charge: pay });
  expect(pay).toHaveBeenCalledWith(100);
});

// GOOD: asserts the outcome the caller receives.
// The mock echoes its input into its return, so the result proves the
// right amount was charged - no spying required.
test("checkout confirms the order and reports the charged total", async () => {
  const result = await checkout(cart, { charge: (amount) => ({ id: "ch_1", amount }) });
  expect(result.status).toBe("confirmed");
  expect(result.charge.amount).toBe(100);
});
```

Legitimate invocation checks have no return to assert on: a debounce/backoff `sleep`, a "did **not** create a duplicate" guarantee, a `--dry-run` / `--WhatIf` no-op. Never both return a value from a mock and assert its invocation for the same behaviour.
