# Testing Guide

A reference guide for understanding and writing tests across the PocketLab Notebook monorepo. Intended for use by Claude Code agents when developing, testing, and reviewing code.

## Quick Reference: Commands by Project

| Project | Test Command | Build & Test | Watch | Framework |
|---------|-------------|--------------|-------|-----------|
| `common/utils` | `cd common/utils && yarn test` | `yarn cbt` | — | Jasmine 5.1 |
| `common/ble` | `cd common/ble && yarn test` | `yarn cbt` | — | Jasmine 5.1 |
| `services/entries` | `cd services/entries && yarn test` | `yarn cbt` | — | Jasmine 4.3 |
| `services/ai` | `cd services/ai && yarn test` | `yarn cbt` | — | Jasmine 4.3 |
| `services/websocket` | `cd services/websocket && yarn test` | `yarn cbt` | — | Jasmine 4.3 |
| `services/notifications` | `cd services/notifications && yarn test` | `yarn cbt` | — | Jasmine 4.3 |
| `services/users` | `cd services/users && yarn test` | `yarn cbt` | — | Jasmine 4.3 |
| `services/auth` | `cd services/auth && yarn test` | `yarn cbt` | — | Jasmine 4.3 |
| `services/payments` | `cd services/payments && yarn test` | `yarn cbt` | — | Jasmine 4.3 |
| `services/etl` | — | — | — | Tests disabled |
| `common/ble` (single) | `cd common/ble && yarn test -- -spec=<filename>` | — | — | Jasmine 5.1 |

**`cbt`** = Clean, Build, Test (runs `clean && build && test` in sequence).

Backend & Common Package Testing

## Configuration

All backend services and common packages share a consistent setup:

- **Framework:** Jasmine (4.3.1 for services, 5.1.0 for common packages)
- **Mocking:** Sinon 9.0.3
- **Spec Pattern:** `dist/**/*.spec.js` (compiled from TypeScript)
- **Execution:** Randomized order
- **Reporter:** `jasmine-spec-reporter` with PRETTY stack traces
- **Default Timeout:** 5000ms
- **Module System:** ES2020 modules (`.js` extensions in imports)

### Build Flow

```bash
yarn cbt                     # Standard: clean → build → test

# Equivalent to:
yarn clean                   # rm -rf dist/ tsconfig.tsbuildinfo
yarn build                   # tsc --build tsconfig.json
yarn test                    # jasmine --config=jasmine.json
```

**Important:** Specs must be compiled before running. Jasmine reads from `dist/`, not `src/`. Always run `yarn build` (or `yarn cbt`) after changing test files.

### Jasmine Configuration

All services share essentially the same `jasmine.json`:

```json
{
  "spec_dir": "dist",
  "spec_files": ["**/*.spec.js"],
  "helpers": ["**/test/reporter.js"],
  "oneFailurePerSpec": true,
  "random": true
}
```

## Shared Test Utilities

### TestUtilsPL2 (TU) — `common/utils/src/test/utils-pl2.ts`

Entry and data builders used across all projects:

```typescript
import {TestUtilsPL2 as TU} from '@common/utils/dist/test/utils-pl2.js';

// Constants
TU.uId          // 'userId'
TU.mId          // 'masterId'
TU.aDate        // '1550421001523'
TU.cC           // 'classCode'
TU.sId          // 'studentId'

// Pre-built sort keys
TU.cSK0         // '00001234'          (class sort key)
TU.aSK0         // '00001234030000'    (assignment sort key)
TU.sCSK0        // '00001234030000020000' (student copy sort key)
TU.lRSK0        // '00010000'          (lab report sort key)

// User builders
TU.buildUser()           // Lite user
TU.buildStudent()        // Student user
TU.buildPro()            // Pro user
TU.buildSuperUser()      // Super user with auth permissions
TU.buildLiteUser()       // Lite user with liteId

// Entry builders
TU.buildEntry(type, parentSK?)           // Generic entry
TU.buildLr(attrs?)                       // Lab report
TU.buildClass(attrs?)                    // Class
TU.buildAssignment(attrs?)               // Assignment
TU.buildStudentCopy(attrs?)              // Student copy
TU.buildTextSection(attrs?)              // Text section
TU.buildDataAnalysisSection(attrs?)      // Data analysis section
TU.buildQuestionSection(attrs?)          // Question section
TU.buildVideoSection(attrs?)             // Video section
TU.buildImageSection(attrs?)             // Image section
TU.buildCourse(attrs?)                   // Course
TU.buildCurriculum(attrs?)               // Curriculum
TU.buildStudentUser(attrs?)              // Student user entry
TU.buildLabReportUser(attrs?)            // Lab report user entry
TU.buildLicense(attrs?)                  // License entry
TU.buildAnswer(attrs?)                   // Answer entry
TU.buildComment(attrs?)                  // Comment entry
// ... and more for every entry type

// Key builders
TU.sK(entryType, parentSK?, random?)     // Generate sort key
TU.pK(entryType, parentPK?, random?)     // Generate primary key
```

### SetupAWSInterfaceMock — `common/utils/src/test/setup-aws-interface-mock.ts`

Fluent builder for DynamoDB mock expectations (wraps sinon.mock):

```typescript
import * as AWSU from '@common/utils/dist/test/setup-aws-interface-mock.js';

const mock = sinon.mock(db);

AWSU.setupAWSMock(mock, {tableName: 'myTable'})
  .get({key: {mId, sK}, item: expectedItem})                  // Expect get, return item
  .put({item: entryToStore})                                    // Expect put
  .query({args: queryParams, items: [item1, item2]})            // Expect query, return items
  .query({args: otherParams, items: [], lastEvaluatedKey: key}) // Paginated query
  .delete({key: {mId, sK}})                                    // Expect delete
  .update({key, exp: 'SET #n = :v', vals: {':v': value}})      // Expect update
  .batchWrite({requestItems: {...}})                            // Expect batch write
  .batchGet({args: {...}, response: {...}})                     // Expect batch get

// After domain execution:
mock.verify();  // Assert all expectations were met
```

**Error simulation:**

```typescript
AWSU.setupAWSMock(mock, {tableName: 'myTable'})
  .query({error: 'DynamoDB error'})         // Simulate query error
  .put({item: entry, err: 'PutItem failed'}) // Simulate put error
```

### ext-service-utils-v2 Test Stubs — `common/ext-service-utils-v2/src/test.ts`

Pre-built stubs for common backend dependencies:

```typescript
import * as Test from '@common/ext-service-utils-v2/dist/test.js';

Test.dbStub()                  // DynamoDB client stub (put, get, query, delete, etc.)
Test.asyncOutputHolderStub()   // AsyncOutputHolder stub (addOutput, getOutput, addError, etc.)
Test.errorSinkStub()           // ErrorSink stub (error, debug)
Test.httpClientStub()          // HTTP client stub (post, get)
Test.secretsManagerStub()      // SecretsManager stub (callback-based getSecretValue)
Test.secretsManagerClientStub() // SecretsManager stub (promise-based send)
Test.cispStub()                // Cognito Identity Provider stub
Test.queryParamsF(defaults)    // Factory for building QueryCommandInput
Test.testSubject(fn, done, onSuccess?, onError?)  // Async test helper
```

### testSubject Helper

Simplifies promise-based test assertions:

```typescript
Test.testSubject(
  () => domain.execute(input),   // async operation
  done,                           // jasmine done callback
  (result) => {                   // success handler
    expect(result).toEqual(expected);
  },
  (err) => {                      // error handler (optional)
    expect(err.code).toBe(500);
  },
);
```

## Backend Test Patterns

### Pattern 1: Simple Utility/Function Test

```typescript
import {myFunction} from './my-utils.js';

describe('myFunction', () => {
  it('returns expected result', () => {
    const result = myFunction(input);
    expect(result).toEqual(expected);
  });
});
```

### Pattern 2: Domain with DynamoDB (Sinon Mock)

```typescript
import sinon from 'sinon';
import * as Test from '@common/ext-service-utils-v2/dist/test.js';
import * as AWSU from '@common/utils/dist/test/setup-aws-interface-mock.js';
import {TestUtilsPL2 as TU} from '@common/utils/dist/test/utils-pl2.js';

describe('MyDomain', () => {
  let db: any;
  let mock: sinon.SinonMock;

  beforeEach(() => {
    db = Test.dbStub();
  });

  afterEach(() => {
    if (mock) mock.verify();   // Verify all mock expectations
  });

  it('reads and processes entries', (done) => {
    mock = sinon.mock(db);
    const entry = TU.buildLr();

    AWSU.setupAWSMock(mock, {tableName: 'entriesTable'})
      .get({key: {mId: entry.mId, sK: entry.sK}, item: entry})
      .query({args: queryParams, items: [child1, child2]});

    new MyDomain(db, 'entriesTable')
      .execute({mId: entry.mId, sK: entry.sK})
      .then((result) => {
        expect(result.length).toBe(2);
        done();
      });
  });

  it('handles errors', (done) => {
    mock = sinon.mock(db);

    AWSU.setupAWSMock(mock, {tableName: 'entriesTable'})
      .get({key: {mId: 'bad', sK: 'bad'}, item: null});

    new MyDomain(db, 'entriesTable')
      .execute({mId: 'bad', sK: 'bad'})
      .then(
        () => { fail('should have rejected'); done(); },
        (err) => { expect(err).toBeDefined(); done(); },
      );
  });
});
```

### Pattern 3: Domain with AsyncOutputHolder

```typescript
describe('MyCreateDomain', () => {
  let db: any;
  let outputHolder: any;
  let mock: sinon.SinonMock;

  beforeEach(() => {
    db = Test.dbStub();
    outputHolder = Test.asyncOutputHolderStub();
  });

  afterEach(() => {
    if (mock) mock.verify();
  });

  it('creates entry and adds to output', (done) => {
    mock = sinon.mock(db);
    sinon.stub(outputHolder, 'addOutput').returns(Promise.resolve());

    AWSU.setupAWSMock(mock, {tableName: 'myTable'})
      .put({item: expectedEntry});

    new MyCreateDomain(db, 'myTable', outputHolder)
      .run(inputData)
      .then(() => {
        expect((outputHolder.addOutput as sinon.SinonStub).calledWith([expectedEntry])).toBeTrue();
        done();
      });
  });
});
```

### Pattern 4: BLE/Hardware Testing (Jasmine Spies)

```typescript
describe('MyProcessor', () => {
  let processor: MyProcessor;
  let mockDependency: jasmine.SpyObj<SomeDependency>;

  beforeEach(() => {
    mockDependency = jasmine.createSpyObj('SomeDependency', ['process', 'reset']);
    processor = new MyProcessor(mockDependency);
  });

  it('processes data correctly', () => {
    mockDependency.process.and.returnValue([{type: 'Reading', values: [[42]]}]);

    const result = processor.process(inputData);

    expect(result.length).toBe(1);
    expect(mockDependency.process).toHaveBeenCalledTimes(1);
    expect(mockDependency.process).toHaveBeenCalledWith(jasmine.any(DataView));
  });
});
```

### Pattern 5: Auth/External Service Testing

```typescript
describe('ValidateTokenDomain', () => {
  let smStub: SecretsManager;
  let axStub: AxiosInstance;

  beforeEach(() => {
    smStub = Test.secretsManagerStub();
    axStub = Test.httpClientStub() as AxiosInstance;
  });

  it('validates a token', (done) => {
    // Direct function assignment for stubs
    axStub.get = () => Promise.resolve({data: jwkKey} as any);
    smStub.getSecretValue = ((_p, f) =>
      f(null, {SecretString: '{"iss": "https://example.com"}'})
    ) as any;

    new ValidateTokenDomain(smStub, axStub, null)
      .validate(request)
      .then(
        (result) => { expect(result.userId).toBeDefined(); done(); },
        (err) => { fail(err); done(); },
      );
  });
});
```

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

### Observable subscribe + done

```typescript
it('emits expected value', (done) => {
  service.getData$().subscribe((value) => {
    expect(value).toEqual(expected);
    done();
  });
});
```

**Warning:** Ensure the subscription actually executes. Use a boolean guard if needed:

```typescript
it('reaches the expectation', (done) => {
  let executed = false;
  service.getData$().subscribe((value) => {
    executed = true;
    expect(value).toEqual(expected);
    done();
  });
  // Safety check if subscribe never fires
  setTimeout(() => {
    if (!executed) { fail('subscribe was not executed'); done(); }
  }, 1000);
});
```

## Entry Hierarchy Test Data Setup

### Building a Class with Assignments

```typescript
const stubData = SDU.buildFrequentStubData({
  u: TU.buildUser(),
  cr: cr({
    e: TU.buildClass(),
    c: [
      {
        e: TU.buildAssignment(),
        c: [
          {e: TU.buildTextSection()},
          {e: TU.buildQuestionSection()},
          {
            e: TU.buildStudentCopy(),
            c: [
              {e: TU.buildTextSection()},
            ],
          },
        ],
      },
      {e: TU.buildStudentUser()},
    ],
  }),
});
```

### Accessing Built Keys

```typescript
const {pK, cPKs} = stubData.getSortedKeys();
// pK   = primary key of root entry (shortest sort key)
// cPKs = child primary keys sorted by sort key length
```

## Key Source Files Reference

| File | Purpose |
|------|---------|
| `common/utils/src/test/utils-pl2.ts` | TestUtilsPL2 — entry/user builders, constants |
| `common/utils/src/test/setup-aws-interface-mock.ts` | SetupAWSInterfaceMock — DynamoDB mock builder |
| `common/ext-service-utils-v2/src/test.ts` | Backend stubs (db, output holder, secrets manager, etc.) |
| `common/utils/src/test/reporter.ts` | Jasmine spec reporter config |

## Common Pitfalls

1. **Backend tests must be compiled first** — run `yarn build` or `yarn cbt`, not just `yarn test` after changing `.ts` files
2. **Mock verification** — always call `mock.verify()` in `afterEach()` when using sinon mocks to catch missed expectations
3. **Entry state setup** — use `cr()` helper with proper entry hierarchy; the sort keys encode parent-child relationships
4. **ETL has no tests** — `services/etl` test script is `echo 'do nothing'`
5. **Entries service uses `NODE_OPTIONS='--trace-warnings'`** — helps catch unhandled promise rejections
