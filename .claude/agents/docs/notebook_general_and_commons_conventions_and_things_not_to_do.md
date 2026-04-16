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

### General Naming Rules

- **Classes:** PascalCase, always suffixed with class type
- **Utility functions:** `verbNoun` (e.g. `editClass`, `generateSortKey`)
- **Callbacks:** `nounPastParticiple` (e.g. `classEdited`, `entryCopied`)
- **Variables, methods:** camelCase starting with lowercase
- **Private instance variables** (not constructor-injected): prefix with `_` (e.g. `_destroyed$`, `_state$`)
- **Enums:** PascalCase names and values (e.g. `EntryType.LabReport`)
- **Observables and signals:** suffix with `$` (e.g. `user$`, `state$`)
- **Model interfaces:** suffix with `Entry` for entries, `SectionEntry` for sections
- **Type aliases** for entries with same shape but different semantic meaning: `export type NewEntry = ExistingEntry`

---

## Formatting Conventions

### General

- **Indentation:** 2 spaces, no tabs
- **Quotes:** Single quotes `'` everywhere (TypeScript, templates, SCSS). Double quotes only for strings nested inside single quotes
- **Max line length:** 140 characters
- **Empty lines:** Maximum 2 consecutive empty lines
- **Commented code:** Remove all commented-out code. Only keep descriptive comments
- **Semicolons:** Required

### Imports

```typescript
1. Common/shared library imports
import * as PL2 from '@common/utils/dist/models/models-pl2.js';
import * as APIM from '@common/utils/dist/models/api-messages.js';
import {KeyUtilsPL2 as KU} from '@common/utils/dist/utils/key-utils-pl2.js';
```

**Rules:**
- Group by type/library, separated by an empty line
- Order from framework → third-party → shared → local (top of stack → bottom)
- No whitespace inside single-import curly brackets: `{Injectable}` not `{ Injectable }`
- Multi-import curly brackets: each import on its own line, alphabetical order
- **Never import paths containing `/src/`** — use path aliases (`@stores/`, `@services/`, etc.)
- **No barrel files - import only what you need** — use `import * as` instead of `import {all} from` and avoid importing index.js where possible

## Architecture Patterns to Enforce

## Review Checklist

### Critical Issues (Must Fix)

- [ ] **No `/src/` in import paths** — all imports must use path aliases (`@stores/`, `@services/`, `@common/utils/dist/`, etc.)
- [ ] **No circular dependencies** — check that new imports don't create circular references between modules/services

### Import Issues

- [ ] No unused imports
- [ ] Imports grouped by type (framework → third-party → shared → local) with empty line separators
- [ ] No whitespace inside single-import curly brackets
- [ ] Multi-import curly brackets: imports on separate lines, alphabetical order
- [ ] No `import ... from 'rxjs/Rx'` (use specific imports)
- [ ] Backend: `.js` extensions on all relative imports

### Naming Issues

- [ ] Classes suffixed with their type (`Component`, `Store`, `Action`, `PolicyService`, `Domain`, etc.)
- [ ] Class names: Noun + Verb pattern (e.g. `ClassEditComponent`, not `EditClassComponent`)
- [ ] Utility functions: Verb + Noun pattern (e.g. `editClass`)
- [ ] Callbacks: Noun + Past Participle (e.g. `classEdited`)
- [ ] Private non-constructor variables prefixed with `_`
- [ ] Enum names and values PascalCase
- [ ] Model interfaces: `Entry` suffix for entries, `SectionEntry` for sections
- [ ] File names: kebab-case matching the class name pattern

### Formatting Issues

- [ ] 2-space indentation, no tabs (check both TypeScript and templates)
- [ ] Single quotes everywhere (TypeScript, templates, SCSS)
- [ ] No more than 2 consecutive empty lines
- [ ] No commented-out code (only descriptive comments allowed)
- [ ] Template attributes: first attr on tag line, subsequent attrs on new lines aligned with first, closing `>` on same line as last attr
- [ ] Line length ≤ 140 characters

### Code Smell Checks

- [ ] No `any` type where a proper type can be inferred or defined
- [ ] No empty `catch` blocks
- [ ] No logic in constructors beyond dependency injection and simple initialization
- [ ] No business logic in components — delegate to actions, stores, or services
- [ ] Single responsibility — each class does one thing
- [ ] No dead code (unreachable branches, unused variables, unused methods)
- [ ] Error handling present at system boundaries (user input, API calls)
- [ ] Logging in backend code uses `[ClassName.methodName]` prefix format
- [ ] No console.log in production frontend code (use console.warn/error/debug only)

### Test Coverage

- [ ] New code has corresponding spec files
- [ ] Spec files follow patterns from `testing.md`
- [ ] Tests actually reach their assertions (check `done()` is called, `fakeAsync` uses `flush()`/`tick()`)

---

## Common Anti-Patterns to Flag

### 1. Import Path with /src/

**Bad:**
```typescript
import {MyService} from '../../../src/app/services/my.service';
```

**Good:**
```typescript
import {MyService} from '@services/my.service';
```

### 1. Circular Dependencies

Watch for circular imports between:
- Stores that import each other
- Services that import components that import the same service
- Actions that import other actions
- Policies that import stores that import policies

---

## Key Source Files for Reviewers

| File | Why It Matters |
|------|---------------|
| `common/utils/src/models/api-messages.ts` (lines 367-439) | EventIntent enum — all event types |
| `common/utils/src/models/models-pl2.ts` (lines 270-323) | EntryType enum — all entry type codes |
| `sort_key_and_entry_hierarchy.md` | Sort key structure — verify key operations are correct |
| `event_system_and_project_structure.md` | Event system — verify event flow is correct |
| `*_testing.md` | Test patterns — verify tests follow conventions |
