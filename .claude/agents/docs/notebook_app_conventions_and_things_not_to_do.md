# Code Review Guide

A checklist and reference for reviewing code changes in the PocketLab Notebook monorepo. Used by a reviewer Claude Code agent.

## Review Process

When reviewing changes:

1. **Identify what changed** — determine which files and class types are affected
2. **Check conventions** — naming, formatting, imports, class structure
3. **Check for anti-patterns** — the specific issues listed in the Checklist section
4. **Check logic** — correctness, edge cases, missing error handling
5. **Check tests** — are they present, adequate, following patterns from `testing.md`

---

## Class Types & Naming Conventions

### Angular App (`services/app`)

| Class Type | Suffix | Naming Pattern | File Pattern | Example |
|------------|--------|---------------|-------------|---------|
| Component | `Component` | `NounVerbComponent` | `noun-verb.component.ts` | `ClassEditComponent` |
| Directive | `Directive` | `FunctionDirective` | `function.directive.ts` | `AutofocusDirective` |
| Store | `Store` | `NounStore` | `noun.store.ts` | `EntryStore` |
| Action | `Action` | `VerbNounAction` | `verb-noun.action.ts` | `CreateCourseAction` |
| PolicyService | `PolicyService` | `VerbNounPolicyService` | `verb-noun-policy.service.ts` | `ActAsTeacherPolicyService` |
| AuthGuardService | `AuthGuardService` | — | — | (not used — auth is via policies) |
| Strategy | `Strategy` | `NounVerbStrategy` | `noun-verb-strategy.ts` | `CurriculumChildDestinationStrategy` |
| Factory | `Factory` | `NounFactory` | `noun-factory.ts` | `AppNotebookFactory` |
| Reactor | `Reactor` | `NounReactor` | `noun.reactor.ts` | `EntryReactor` |

### Imports

```typescript
// 1. Framework imports (Angular, RxJS)
import {Injectable, OnDestroy} from '@angular/core';
import {Observable, BehaviorSubject, ReplaySubject} from 'rxjs';
import {map, filter, takeUntil} from 'rxjs/operators';

// 2. Third-party library imports
import {TranslateService} from '@ngx-translate/core';

// 4. Local imports (stores, services, actions, components, utils)
import {EntryStore} from '@stores/entry.store';
import {UserStore} from '@stores/user.store';
```

**Rules:**
- Group by type/library, separated by an empty line
- Order from framework → third-party → shared → local (top of stack → bottom)
- No whitespace inside single-import curly brackets: `{Injectable}` not `{ Injectable }`
- Multi-import curly brackets: each import on its own line, alphabetical order
- **Never import paths containing `/src/`** — use path aliases (`@stores/`, `@services/`, etc.)
- **No barrel files - import only what you need** — use `import * as` instead of `import {all} from` and avoid importing index.js where possible

### Templates

- After the tag name and the first attribute, all subsequent attributes go on a new line aligned with the first attribute
- Closing angle bracket on the same line as the last attribute, no space before `>`
- Use single quotes for attribute values in templates
- Use `class` bindings instead of `ngClass`
- Use `style` bindings instead of `ngStyle`
- Use native control flow (`@if`, `@for`, `@switch`) instead of `*ngIf`, `*ngFor`, `*ngSwitch`
- Custom directive selectors use `pl` prefix

```html
<button mat-button
        class='primary-action'
        [disabled]='isLoading'
        (click)='handleClick()'>
  {{ 'i18n.key' | translate }}
</button>
```

### Angular Decorators & Lifecycle

- `@Input()`, `@Output()`, `@ViewChild()` — variable on the line BELOW the decorator, not inline
- Prefer `input()` and `output()` signal functions over decorators in new code
- `@ViewChild`/`@ViewChildren` — use type and selector rather than template variable where possible
- **Do NOT use `@HostBinding` or `@HostListener`** — use the `host` object in `@Component`/`@Directive` decorator instead
- Lifecycle methods in framework call order: `ngOnInit`, `ngOnChanges`, `ngAfterContentInit`, `ngAfterViewInit`, `ngOnDestroy`
- All lifecycle methods directly below the constructor

---

## Architecture Patterns to Enforce

### Stores (Angular)

```typescript
@Injectable({providedIn: 'root'})
export class MyStore extends Store<MyState> implements OnDestroy {
  private _destroyed$ = new ReplaySubject<boolean>();

  constructor() {
    super(initialState);
  }

  // State modifications ALWAYS through setState() or modifyStateWithTransformer()
  // Never mutate state directly
  // Use immer's produce() for complex state transformations
}
```

**Rules:**
- Stores extend `Store<S>` (from `abstract-store.ts`)
- `state$` is `Observable<S>` (public, read-only)
- `state()` returns current value synchronously
- `setState(nextState)` emits new state
- `modifyStateWithTransformer(data, transformer)` for immutable updates
- **Never mutate state inside an RxJS pipe operator** — always call `setState()` explicitly

### Actions

```typescript
@Injectable()
export class VerbNounAction implements Action<InputType, OutputType> {
  constructor(private store: SomeStore, ...) {}

  execute(input: InputType): Observable<OutputType> {
    // Thin — delegate to stores/services
  }
}
```

- `@Injectable()` (not `providedIn: 'root'`)
- Implement `Action<I, O>` (async) or `SynchronousAction<I, O>` (sync)
- Keep thin — business logic belongs in stores and domains

### Policies

```typescript
@Injectable()
export class ActAsNounPolicyService implements ActionPolicy {
  constructor(private userStore: UserStore) {}

  can$(pK?: string): Observable<boolean> {
    return this.userStore.state$.pipe(
      map(user => /* boolean based on CURRENT USER */)
    );
  }
}
```

**Critical Rule: `ActAs*` policies must check the current user as the subject.** The `pK` parameter is for context (which entry is being acted upon), but the subject being authorized is always the current user from `UserStore`. Policies like `ActAsStudentCopyPolicyService` that check entry type rather than user role are a known anti-pattern — they should be named differently (e.g. `IsStudentCopyPolicyService`) or refactored.

### Reactors

```typescript
@Injectable({providedIn: 'root'})
export class NounReactor implements OnDestroy {
  private _destroyed$ = new ReplaySubject<boolean>();

  constructor(private store: SomeStore) {
    this.store.state$.pipe(
      // operators...
      takeUntil(this._destroyed$),  // ALWAYS last operator
    ).subscribe(/* side effects */);
  }

  ngOnDestroy() {
    this._destroyed$.next(true);
    this._destroyed$.complete();
  }
}
```

- Side-effect managers that subscribe to store observables
- **Always use `takeUntil(this._destroyed$)` as the last pipe operator**
- Implement `OnDestroy` with `_destroyed$.next(true)` + `_destroyed$.complete()`

### Components (Angular)

- Prefer `standalone: true` for new components
- Set `changeDetection: ChangeDetectionStrategy.OnPush`
- Use `input()` and `output()` functions instead of decorators
- Use `computed()` for derived state
- Use `inject()` function instead of constructor injection (new code)

---

## Review Checklist

### Critical Issues (Must Fix)

- [ ] **No signal `effect()` usage** — `effect()` should not be used. Use explicit subscriptions with `takeUntil` cleanup instead. Known violations exist in `shimmer.directive.ts` and `list.component.ts` — do not add more
- [ ] **No `/src/` in import paths** — all imports must use path aliases (`@stores/`, `@services/`, `@common/utils/dist/`, etc.)
- [ ] **No circular dependencies** — check that new imports don't create circular references between modules/services
- [ ] **No store state mutation in RxJS pipes** — state changes must go through `setState()` or `modifyStateWithTransformer()`, never inside `map()`, `tap()`, `switchMap()`, etc. operating on the same store's observable. Exception: `tap()` calling `setState()` on a *different* store is acceptable (but prefer doing it in subscribe)
- [ ] **`takeUntil` on all subscriptions** — every `.subscribe()` in components, reactors, and services must have `takeUntil(this._destroyed$)` as the last pipe operator. Only exception: one-shot observables that complete naturally (e.g. HTTP requests, `first()`)
- [ ] **Policy subject correctness** — `ActAs*` policies must authorize based on the current user, not on entry type or other non-user attributes. If a policy checks entry type, it should not be named `ActAs*`

### Angular-Specific Issues

- [ ] No `@HostBinding` or `@HostListener` decorators — use `host` object in `@Component`/`@Directive`
- [ ] No `ngClass` — use `class` bindings
- [ ] No `ngStyle` — use `style` bindings
- [ ] Prefer native control flow (`@if`, `@for`, `@switch`) over structural directives (`*ngIf`, `*ngFor`)
- [ ] No `mutate` on signals — use `update` or `set`
- [ ] Lifecycle methods in framework call order, directly below constructor
- [ ] `@Input()` / `@Output()` / `@ViewChild()` decorators on line above variable, not inline
- [ ] New components should be `standalone: true` with `ChangeDetectionStrategy.OnPush`
- [ ] Use `input()` / `output()` functions for new components instead of decorators
- [ ] Use `inject()` function for new code instead of constructor injection
- [ ] Reactive forms preferred over template-driven forms

### RxJS Issues

- [ ] No `subscribe()` without `takeUntil` in long-lived objects (components, services, reactors)
- [ ] No nested subscribes — use `switchMap`, `mergeMap`, `concatMap` instead
- [ ] No store state mutation inside `pipe()` operators on that store's own observable
- [ ] Use `async` pipe in templates where possible
- [ ] No `rxjs/Rx` barrel import

---

## Common Anti-Patterns to Flag

### 1. State Mutation in Pipe

**Bad:**
```typescript
this.store.state$.pipe(
  tap(state => {
    state.someProperty = newValue;  // Direct mutation!
  })
);
```

**Good:**
```typescript
this.store.state$.pipe(
  tap(() => {
    this.store.setState({...this.store.state(), someProperty: newValue});
  })
);
// Or better yet, do it in subscribe or a separate method
```

### 2. Missing takeUntil

**Bad:**
```typescript
export class MyComponent implements OnInit {
  ngOnInit() {
    this.store.state$.pipe(
      map(s => s.value)
    ).subscribe(v => this.handle(v));  // Memory leak!
  }
}
```

**Good:**
```typescript
export class MyComponent implements OnInit, OnDestroy {
  private _destroyed$ = new ReplaySubject<boolean>();

  ngOnInit() {
    this.store.state$.pipe(
      map(s => s.value),
      takeUntil(this._destroyed$),
    ).subscribe(v => this.handle(v));
  }

  ngOnDestroy() {
    this._destroyed$.next(true);
    this._destroyed$.complete();
  }
}
```

### 3. Signal Effect Usage

**Bad:**
```typescript
effect(() => {
  this.applyStyle(this.myInput());
});
```

**Good:**
```typescript
// Use explicit subscription or computed()
myComputed = computed(() => this.calculateStyle(this.myInput()));
```

### 4. Wrong Policy Subject

**Bad** — `ActAs*` policy checking entry type instead of user:
```typescript
export class ActAsStudentCopyPolicyService implements ActionPolicy {
  can$(pPK: string): Observable<boolean> {
    return this.entryStore.state$.pipe(
      map(() => this.entryStore.state()[pPK]?.e.t === EntryType.StudentCopy)
    );
  }
}
```

**Better naming** — if it checks entry, don't name it `ActAs*`:
```typescript
export class IsStudentCopyPolicyService implements ActionPolicy { ... }
```

### 7. Nested Subscribes

**Bad:**
```typescript
this.store.state$.subscribe(state => {
  this.otherService.getData(state.id).subscribe(data => {
    this.handle(data);
  });
});
```

**Good:**
```typescript
this.store.state$.pipe(
  switchMap(state => this.otherService.getData(state.id)),
  takeUntil(this._destroyed$),
).subscribe(data => this.handle(data));
```

---

## Key Source Files for Reviewers

| File | Why It Matters |
|------|---------------|
| `services/app/src/app/stores/abstract-store.ts` | Base store pattern — 35 lines, defines all state management |
| `services/app/src/app/directives/policy/action-policy.ts` | ActionPolicy interface — 7 lines, defines policy contract |
| `services/app/src/app/app.module.ts` (lines 155-183) | Decorator chain wiring — understand event flow |
| `sort_key_and_entry_hierarchy.md` | Sort key structure — verify key operations are correct |
| `event_system_and_project_structure.md` | Event system — verify event flow is correct |
| `*_testing.md` | Test patterns — verify tests follow conventions |
