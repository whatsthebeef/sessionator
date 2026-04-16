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

### Backend Services

| Class Type | Suffix | Naming Pattern | File Pattern | Example |
|------------|--------|---------------|-------------|---------|
| Domain | `Domain` | `VerbNounDomain` | `verb-noun-domain.ts` | `FetchMasterDomain` |
| Strategy | `Strategy` | `NounVerbStrategy` | `noun-verb-strategy.ts` | `GooglePostConfirmStrategy` |
| Task | `Task` | `VerbNounTask` | `verb-noun-task.ts` | `MigrateExistingDAUserTask` |
| JobStrategy | `Strategy` (implements `JobStrategy`) | `VerbNounStrategy` | `verb-noun-strategy.ts` | `CopyLRToAStrategy` |
| Factory | `Factory` or `Builder` | `NounFactory` | `noun-factory.ts` | `DomainBuilder` |
| Lambda Handler | — (exported functions) | `verbHandler` | `noun-lambda-actions.ts` | `eventHandler` |

---

## Formatting Conventions

### Logging (Backend Services)

```typescript
// Format: [ClassName.methodName] message
console.log('[FetchMasterDomain.fetch] processing entries');
console.error('[MigrateExistingDAUserTask.migrate] No class code provided');

// Lambda handlers alternative format:
console.error('[entry-lambda-actions#eventHandler] ' + err);
```

- Use `error` sparingly (triggers alarms)
- Prefer `debug` for detailed trace logging
- Always prefix with class/file and method name

---

## Architecture Patterns to Enforce

### Domains (Backend)

```typescript
export class VerbNounDomain {
  constructor(
    private docClient: DynamoDBDocument,
    private tableName: string,
  ) {}

  verb(input: InputType): Promise<OutputType> {
    // DynamoDB operations
  }
}
```

- Single responsibility
- Constructor injection of AWS clients
- Methods return `Promise<T>`
- Type-safe DynamoDB operations (`PutCommandInput`, `QueryCommandInput`)

## Review Checklist

### Backend-Specific Issues

- [ ] Domain classes are single-responsibility
- [ ] DynamoDB operations use typed command inputs (`PutCommandInput`, `QueryCommandInput`)
- [ ] Promises have `.catch()` handlers or are in try-catch blocks
- [ ] Lambda handlers follow the `(event, context, callback)` signature pattern
- [ ] Event intent mapping in `generateEntryIntent` is correct for new entry types
- [ ] EventBridge rules in `event-bus-rules.yaml` are added for new event intents
- [ ] S3 is used for large payloads (>200KB threshold)

### Test Coverage

- [ ] Backend: uses `sinon.mock()` + `setupAWSMock()` for DynamoDB
- [ ] Backend: uses `Test.dbStub()` and other shared stubs
- [ ] Backend: `mock.verify()` in `afterEach()`
- [ ] Tests actually reach their assertions (check `done()` is called, `fakeAsync` uses `flush()`/`tick()`)

## Key Source Files for Reviewers

| File | Why It Matters |
|------|---------------|
| `services/events/stacks/event-bus-rules.yaml` | EventBridge routing — verify new intents have rules |
| `services/entries/src/utils/generate-entry-intent.ts` | Intent mapping — verify new types are mapped |
| `sort_key_and_entry_hierarchy.md` | Sort key structure — verify key operations are correct |
| `event_system_and_project_structure.md` | Event system — verify event flow is correct |
| `*_testing.md` | Test patterns — verify tests follow conventions |
