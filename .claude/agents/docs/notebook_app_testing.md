# Testing Guide

A reference guide for understanding and writing tests across the PocketLab Notebook monorepo. Intended for use by Claude Code agents when developing, testing, and reviewing code.

## Quick Reference: Commands by Project

| Project | Test Command | Build & Test | Watch | Framework |
|---------|-------------|--------------|-------|-----------|
| `services/app` | `cd services/app && yarn test` | `yarn build-and-test` | `yarn test-watch` | Jasmine 3.6 + Karma |

**App-specific commands:**

```bash
cd services/app
yarn test                    # Run tests with codebuild karma config
yarn test-watch              # Run tests in watch mode (Chrome)
yarn test-watch-headless     # Run tests in watch mode (ChromeHeadless)
```

## Configuration

- **Framework:** Jasmine 3.6.0 + Karma task runner
- **Browser:** Chrome (ChromeHeadless for CI)
- **Timeout:** 210 seconds (karma.conf.js)
- **Coverage:** HTML + lcov reports
- **TypeScript:** Path aliases (`@models/*`, `@services/*`, `@stores/*`, `@components/*`, `@actions/*`, `@utils/*`, `@test/*`) defined in `src/tsconfig.spec.json`

## Core Test Utilities

### File Overview

| File | Purpose |
|------|---------|
| `src/app/test-utils.ts` | `Setup` module — component/injectable/directive builders, DOM helpers, custom matchers |
| `src/app/stub-utils.ts` | `StubUtils` module — `StubFactory`, `StubDataHolder`, provider replacement functions |
| `src/app/stub-data-utils.ts` | `StubDataUtils` module — pre-built stub data for all common stores and services |
| `src/app/call-records.ts` | `CallRecords` class — records method invocations on stubs for assertion |

### CallRecords

The custom spy/observation system used instead of Jasmine spies. Every stubbed service method automatically records its calls.

```typescript
class CallRecords {
  add(callDetails: {f: string, args: any[]})  // Record a call
  all()                    // Get all recorded calls
  clear()                  // Clear call history
  last(fnName?: string)    // Last call (optionally filtered by function name)
  first(fnName?: string)   // First call (optionally filtered)
  none()                   // True if no calls recorded
  at(index: number)        // Get call at index (supports negative indexing)
  includes(f: string)      // True if function was ever called
  get(f: string)           // Get all calls to a specific function
}
```

**Usage in assertions:**

```typescript
expect(records.includes('sendEvent')).toBeTrue();
expect(records.last('setState').args[0]).toEqual(expectedState);
expect(records.first('delete').args).toEqual([entryId]);
expect(records.get('open').length).toBe(2);
expect(records.none()).toBeTrue();
```

### StubFactory

Creates stubs for any class/service, wrapping all methods to log calls to `CallRecords`:

```typescript
const stubFactory = new SU.StubFactory();

// Generic stub — wraps all methods on the prototype with recording + return values
const stub = stubFactory.buildStub(
  MyService.prototype,           // prototype to stub
  records,                       // CallRecords instance
  { doSomething: of(someValue) } as StubData<MyService>  // optional return values
);

// Store stub — adds state$, state(), setState() support
const storeStub = stubFactory.buildStoreStub(
  MyStore.prototype,
  records,
  stubData.get(MyStore)
);

// Entry store stub — adds modifyStateWithTransformer() on top of store stub
const entryStoreStub = stubFactory.buildEntryStoreStub(
  EntryStore.prototype,
  records,
  stubData.get(EntryStore)
);
```

**How `buildStub` works internally:**
1. Creates a copy of the prototype
2. Overlays any provided `StubData` values
3. Wraps every method: logs `{f: methodName, args}` to `records`, then returns the StubData value
4. Optionally runs an `init` callback for custom setup

### StubDataHolder

Type-safe registry for test data, keyed by class/service type:

```typescript
const stubData = SDU.buildFrequentStubData({
  u: TU.buildUser(),
  cr: cr({e: TU.buildLr(), c: [{e: TU.buildTextSection()}]}),
});

stubData.get(EntryStore)     // Get EntryStore stub data
stubData.get(UserStore)      // Get UserStore stub data
stubData.has(CustomStore)    // Check if data exists
stubData.put(CustomStore, myStubData)  // Register custom stub data
stubData.getSortedKeys()     // Extract {pK, cPKs} from EntryStore state
```

### buildFrequentStubData — The Primary Entry Point

This is the main function used to set up test data. It creates stub data for all commonly needed stores and services:

```typescript
const stubData = SDU.buildFrequentStubData({
  u?: User,                    // User (defaults to a basic user)
  cr?: EntryCreateRequest,     // Entry hierarchy to populate EntryStore
  routeState?: Partial<RouteState>,  // Route state overrides
  overwritePK?: string,        // Override primary key
  decisions?: AppDecisions,    // Feature flag decisions
});
```

**What it sets up:**
- `EntryStore` — populated from `cr` (create request) parameter
- `UserStore` — populated from `u` parameter
- `RouteStore` — populated from `routeState` parameter
- `EventAPIService` — default stub returning `of(void 0)`
- `WebsocketService`, `ServiceCommsWrapperService` — default stubs
- `APIService`, `EntryApiService`, `HttpService` — default stubs
- `MatDialog`, `MatDialogRef` — dialog stubs
- `WindowSizeStore`, `APIStateStore`, `GeolocationStore` — store stubs
- `ActiveEventStore`, `WebsocketStatusStore`, `ActiveAPIServiceStore` — store stubs
- `AppDecisionsBuilder`, `DialogRendererService` — stubs
- `TranslateService` — uses real English translations from `en.json`
- `WINDOW`, `DOCUMENT`, `STORAGE` — browser API stubs

### Provider Replacement Functions

```typescript
// Replace ALL commonly needed providers in one call
const config = SU.replaceFrequentProviders(stubData, moduleConfig, stubFactory, records);

// Add additional custom provider overrides
const config = SU.replaceProviders(
  [{ provide: CustomService, useFactory: () => stubFactory.buildStub(...) }],
  SU.replaceFrequentProviders(stubData, moduleConfig, stubFactory, records)
);
```

`replaceFrequentProviders` replaces these providers in the module config:
- `WebsocketService`, `ServiceCommsWrapperService`, `DatePipe`, `WindowSizeStore`
- `S3Service`, `APIStateStore`, `TranslateService`, `APIService`
- `MatDialogRef`, `MatDialog`, `UserStore`, `EntryStore`, `RouteStore`
- `EntryApiService`, `ActiveAPIServiceStore`, `AppDecisionsBuilder`
- `DialogRendererService`, `EventAPIServiceToken`
- `HttpService`, `HttpClient`, `BluetoothConnectionService`
- `GeolocationStore`, `CacheExpirationStrategyService`
- `ActiveEventStore`, `WebsocketStatusStore`
- `WINDOW`, `DOCUMENT`, `STORAGE` injection tokens

### Setup Module — Building Test Subjects

#### Testing Components

```typescript
// Modern pattern (preferred)
const fixture = Setup.buildComponent2(
  MyComponent,
  moduleConfig   // after replaceFrequentProviders
);

// Standalone components
const fixture = Setup.buildComponentStnd(
  MyStandaloneComponent,
  moduleConfig
);

// Old pattern (returns tuple)
const [ids, fixture, records] = Setup.buildComponent(state, moduleConfig, variables);
```

#### Testing Injectables (Services, Actions)

```typescript
// Modern pattern (preferred)
const service = Setup.buildInjectable2(
  MyService,
  [Dep1, Dep2, Dep3],    // dependency order MUST match constructor order
  moduleConfig
);
```

**Important:** The `dependencies` array order MUST match the constructor parameter order.

#### Testing Directives

```typescript
// Standard directive
const fixture = Setup.buildDirective2(MyDirective, moduleConfig);

// Standalone directive
const fixture = Setup.buildDirectiveStnd(MyStandaloneDirective, moduleConfig);
```

### DOM Helper Functions

Available from `test-utils.ts` for component testing:

```typescript
// Interaction
click(fixture, selector)              // Click an element
select(fixture, selector, value)      // Select dropdown value
keydown(fixture, selector, key)       // Dispatch keydown event
keyup(fixture, selector, key)
mousedown(fixture, selector)
mouseEnter(fixture, selector)
mouseLeave(fixture, selector)
setInputValue(fixture, selector, value)

// Assertions
hasElement(fixture, selector)                    // Element exists
hasExactlyNElements(fixture, selector, n)        // Exactly n elements
hasText(fixture, selector, text)                 // Exact text match
containsText(fixture, selector, text)            // Partial text match
hasInputText(fixture, selector, text)            // Input value match
hasAttribute(fixture, selector, attr, value)     // Attribute value
isDisabled(fixture, selector)                    // Disabled state
isChecked(fixture, selector)                     // Checked state
isHidden(fixture, selector)                      // Display: none
hasStyle(fixture, selector, style, value)        // Inline style
hasClass(fixture, selector, className)           // CSS class
hasFocus(fixture, selector)                      // Focus state

// Overlay (for Material overlays/dialogs outside component DOM)
overlayHasExactlyNElements(fixture, selector, n)
overlayHasText(fixture, selector, text)
```

### Test Data Builder Helpers

```typescript
// Entry hierarchy builder
cr({e: TU.buildLr(), c: [{e: TU.buildTextSection()}]})  // EntryCreateRequest shorthand

// Build entry state from containers
Setup.buildEntryStateFromRequest(createRequest)
Setup.buildEntryStateWithContainerEntries(container)

// Build data visualization config
Setup.buildDataConfigState({
  'pl1bar-alt': { p: [[0, 1], [0.1, 2], [0.2, 3]] }
})

// Build cached entry for store
buildCachedEntry(entry)
buildEntryState({entries...})
buildKey(mId, sK)
getPK(entry)
getEntry(fixture, pK)
```

## Angular App Test Patterns

### Pattern 1: Component Test

```typescript
describe('MyComponent', () => {
  let records: CallRecords;
  let stubFactory: SU.StubFactory;

  const moduleConfig: Setup.ModuleConfig = {
    declarations: [MyComponent],
    imports: [NoopAnimationsModule, MatButtonModule],
    providers: [EntryStore, RouteStore, UserStore],
  };

  beforeEach(() => {
    records = new CallRecords();
    stubFactory = new SU.StubFactory();
  });

  it('renders the component', fakeAsync(() => {
    const stubData = SDU.buildFrequentStubData({
      u: TU.buildUser(),
      cr: cr({e: TU.buildLr(), c: [{e: TU.buildTextSection()}]}),
    });

    const fixture = Setup.buildComponent2(MyComponent, buildModule(stubData));

    fixture.detectChanges();
    flush();

    expect(hasElement(fixture, '.my-selector')).toBeTruthy();
    expect(hasText(fixture, 'h1', 'Expected Title')).toBeTruthy();
  }));

  function buildModule(stubData: SU.StubDataHolder): Setup.ModuleConfig {
    return SU.replaceFrequentProviders(stubData, moduleConfig, stubFactory, records);
  }
});
```

### Pattern 2: Injectable/Action Test

```typescript
describe('MyAction', () => {
  let records: CallRecords;
  let stubFactory: SU.StubFactory;

  const moduleConfig: Setup.ModuleConfig = {
    declarations: [],     // Not needed for injectables
    imports: [],          // Not needed for injectables
    providers: [],
  };

  // Order MUST match constructor parameter order
  const dependencies = [UserStore, EntryStore, DumbEventAPIService];

  beforeEach(() => {
    records = new CallRecords();
    stubFactory = new SU.StubFactory();
  });

  it('sends an event', (done) => {
    const stubData = SDU.buildFrequentStubData({u: TU.buildUser()});

    const action = Setup.buildInjectable2(
      MyAction,
      dependencies,
      buildModule(stubData),
    );

    action.execute().subscribe(() => {
      expect(records.includes('sendEvent')).toBeTrue();
      expect(records.first('sendEvent').args[0].eventType).toBe(EventIntent.EntryCreate);
      done();
    });
  });

  function buildModule(stubData: SU.StubDataHolder): Setup.ModuleConfig {
    return SU.replaceProviders(
      [{
        provide: DumbEventAPIService,
        useFactory: () => stubFactory.buildStub(
          DumbEventAPIService.prototype, records, stubData.get(DumbEventAPIService),
        ),
      }],
      SU.replaceFrequentProviders(stubData, moduleConfig, stubFactory, records),
    );
  }
});
```

### Pattern 3: Store Test

```typescript
describe('MyStore', () => {
  let records: CallRecords;
  let stubFactory: SU.StubFactory;

  const moduleConfig: Setup.ModuleConfig = {
    declarations: [],
    imports: [],
    providers: [],
  };

  beforeEach(() => {
    records = new CallRecords();
    stubFactory = new SU.StubFactory();
  });

  it('updates state correctly', fakeAsync(() => {
    const store = Setup.buildInjectable2(
      MyStore,
      [],
      SU.replaceFrequentProviders(
        new SU.StubDataHolder({}),
        moduleConfig, stubFactory, records,
      ),
    );

    store.doSomething(input);
    tick();

    expect(store.state().someProperty).toEqual(expectedValue);
  }));
});
```

### Pattern 4: Policy Service Test

```typescript
describe('MyPolicy', () => {
  let records: CallRecords;
  let stubFactory: SU.StubFactory;

  // CallRecords and StubFactory are created but not heavily used
  // The main pattern is subscribe + done callback

  it('allows the action', (done) => {
    const stubData = SDU.buildFrequentStubData({u: TU.buildUser()});

    const policy = Setup.buildInjectable2(
      MyPolicy,
      [UserStore, EntryStore],
      buildModule(stubData),
    );

    policy.can$(entry).subscribe((allowed) => {
      expect(allowed).toBeTrue();
      done();
    });
  });
});
```

### Important Patterns & Conventions

1. **Always use `fakeAsync()` + `flush()`/`tick()`** for component tests with async operations
2. **Use `done` callback** for Observable-based assertions (actions, policies, services)
3. **`buildModule()` helper function** — define a local `buildModule(stubData)` function per describe block for DRY test setup
4. **Route state** — set via `stubData.get(RouteStore).state$.next({containerId: ...})` before building component
5. **No teardown** — the codebase does not use `afterEach()` for cleanup (only one instance exists)
6. **`NoopAnimationsModule`** — import when the component uses Angular animations

## Async Testing Patterns

### Backend Services (done callback)

```typescript
it('processes asynchronously', (done) => {
  domain.execute(input).then(
    (result) => {
      expect(result).toEqual(expected);
      done();
    },
    (err) => {
      fail(err);
      done();
    },
  );
});
```

## Key Source Files Reference

| File | Purpose |
|------|---------|
| `common/utils/src/test/utils-pl2.ts` | TestUtilsPL2 — entry/user builders, constants |
| `common/utils/src/test/setup-aws-interface-mock.ts` | SetupAWSInterfaceMock — DynamoDB mock builder |
| `common/ext-service-utils-v2/src/test.ts` | Backend stubs (db, output holder, secrets manager, etc.) |
| `common/utils/src/test/reporter.ts` | Jasmine spec reporter config |

## Common Pitfalls

1. **Dependency order matters** — `Setup.buildInjectable2()` dependencies array must match constructor parameter order exactly
2. **Observable completion** — ensure `done()` is always called in subscribe/then handlers, including error paths
3. **Entry state setup** — use `cr()` helper with proper entry hierarchy; the sort keys encode parent-child relationships
4. **StubDataHolder.get()** throws if no data exists — use `.has()` to check first, or `.put()` to add custom data
5. **fakeAsync zone** — component tests should use `fakeAsync()` + `flush()`/`tick()` for async operations
6. **No Jasmine spies in app** — use `CallRecords` pattern instead (check `records.includes()`, `records.last()`, etc.)
7. **Entries service uses `NODE_OPTIONS='--trace-warnings'`** — helps catch unhandled promise rejections
