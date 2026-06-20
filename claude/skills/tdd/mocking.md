# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, cloud control planes, etc.)
- Databases (sometimes - prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Unit tests never touch the real boundary

A unit test must not hit a live external API, database, or cloud tenant. **Mock every call that crosses a system boundary** so the test is deterministic, offline, and side-effect-free; reserve real boundaries for integration/e2e tests. An unmocked boundary call from a "unit" test can mutate live state (e.g. creating real cloud resources) and makes the test slow and flaky. If a boundary command isn't mocked, the test is not a unit test.

## Make mocks prove wiring through the return

Have each boundary mock **echo its inputs into its return value**, then assert on the result instead of spying on the call. The result then proves the right data was wired to the boundary without any `toHaveBeenCalledWith` / `Should -Invoke -ParameterFilter`:

```typescript
// The mock reflects the appId it was given, so the returned object proves the
// service principal was created from the right application.
const graph = {
  createServicePrincipal: ({ appId }) => ({ id: `sp-for-${appId}`, appId }),
};

const sp = await createServicePrincipal("my-app", graph);
expect(sp.appId).toBe("my-app"); // outcome, not "was createServicePrincipal called with my-app"
```

Rule: never both return a value from a mock **and** assert its invocation for the same behaviour — assert the result.

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. Prefer SDK-style interfaces over generic fetchers**

Create specific functions for each external operation instead of one generic function with conditional logic:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The SDK approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per endpoint
