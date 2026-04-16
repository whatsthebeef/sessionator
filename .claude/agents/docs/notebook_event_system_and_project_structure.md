# Event System & Project Structure

A reference guide for understanding the event-driven architecture, service communication, event routing, and project structure of PocketLab Notebook. Intended for use by Claude Code agents when developing, debugging, testing, and reviewing code.

## Project Structure Overview

```
pocketlab-notebook/
├── common/                           # Shared libraries (used by both frontend and backend)
│   ├── ble/                          # @common/ble — Web Bluetooth sensor drivers
│   ├── ext-service-utils-v2/         # @common/ext-service-utils-v2 — Backend shared utilities
│   │                                   (DynamoDB, S3, SNS, Lambda, EventBridge, OpenSearch, Cognito)
│   └── utils/                        # @common/utils — Shared pure utilities
│       └── src/
│           ├── models/
│           │   ├── api-messages.ts   # EventIntent enum, Event/EventData/Payload interfaces,
│           │   │                       EntryContainer, CopyType, query types
│           │   ├── models-pl2.ts     # EntryType enum, all entry interfaces
│           │   └── keys-pl2.ts       # Typed key system (branded string types)
│           ├── key-generators/       # Sort key and mId generation
│           ├── index-managers/       # MasterIndexManager, index attribute setting
│           ├── entry-container/      # ContainerWalk, EntryAttributeInitializer
│           └── utils/                # key-utils-pl2, entry-utils-pl2, container-utils
│
├── services/
│   ├── app/                          # Angular 17.3 frontend (SPA + SSR)
│   │   └── src/app/
│   │       ├── services/
│   │       │   ├── event-api.service.ts        # EventAPIService interface + proxy handler
│   │       │   ├── entry-api.service.ts        # HTTP fallback for events
│   │       │   ├── websocket.service.ts        # WebSocket bidirectional communication
│   │       │   ├── ws-message-receiver.service.ts  # Message deserialization (incl. S3 fetch)
│   │       │   ├── events/                     # Event input builders
│   │       │   │   ├── event-core.ts           # EventType union, EventInput interface
│   │       │   │   ├── entry-events.ts         # Create, BatchUpdate, DeepDelete, UndoDelete builders
│   │       │   │   ├── copy-events.ts          # Copy/import builders (VToSC, AcceptInvite, etc.)
│   │       │   │   ├── query-events.ts         # Read/query builders (Master, Class, UserLibrary, etc.)
│   │       │   │   ├── ai-events.ts            # AI operation builders
│   │       │   │   ├── user-details-events.ts  # UserDetails CRUD builders
│   │       │   │   ├── pending-index-events.ts # DrainPendingIndex builder
│   │       │   │   └── scorm-events.ts         # UploadScorm builder
│   │       │   ├── service-decorator/          # EventAPIService decorator chain
│   │       │   │   ├── sync-enforcer.decorator.ts
│   │       │   │   ├── posthog-spy.decorator.ts
│   │       │   │   ├── copy-event-interceptor.decorator.ts
│   │       │   │   ├── advance-entry-state-around-event.decorator.ts
│   │       │   │   ├── event-id-manager.decorator.ts
│   │       │   │   └── change-active-service.decorator.ts
│   │       │   └── websocket-message-processor/ # Incoming message handlers
│   │       │       └── dispatcher.module.ts     # Processor registry
│   │       ├── stores/
│   │       │   ├── entry.store.ts              # Entry state management
│   │       │   └── active-event.store.ts       # Pending/completed event tracking
│   │       ├── actions/
│   │       │   ├── receive-event-acknowledgement.action.ts
│   │       │   └── receive-event-success.action.ts
│   │       ├── reactors/
│   │       │   └── active-event.reactor.ts     # Event expiration (6m15s pending, 30s completed)
│   │       └── utils/
│   │           └── event-utils.ts              # intentsChangingState, intentsForQueries helpers
│   │
│   ├── ai/                           # AI service (Lambda) — translations, reading level, generation
│   ├── auth/                         # Authentication / LTI service (Lambda)
│   ├── cdn/                          # CDN / static assets service
│   ├── entries/                      # Core entries CRUD service (Lambda)
│   │   └── src/
│   │       ├── actions/
│   │       │   └── entry-lambda-actions.ts     # Main Lambda handler for entry events
│   │       ├── domains/                        # Domain logic (create, update, delete, copy, fetch)
│   │       └── utils/
│   │           └── generate-entry-intent.ts    # Maps input intents → output intents by entry type
│   ├── etl/                          # ETL pipelines (Lambda)
│   ├── events/                       # EventBridge bus and routing rules (no Lambda code)
│   │   └── stacks/
│   │       ├── event-bus.yaml                  # EventBus resource definition
│   │       └── event-bus-rules.yaml            # All EventBridge routing rules (~1037 lines)
│   ├── monitor/                      # Monitoring service (Lambda)
│   ├── notifications/                # Notification broadcasting service (Lambda)
│   │   └── src/
│   │       ├── actions/
│   │       │   ├── hubspot-notifications-lambda-actions.ts  # Hubspot integration
│   │       │   └── ed-notifications-lambda-actions.ts       # Ed (LMS) integration
│   │       └── domains/
│   │           ├── notify-hubspot-of-entry-domain.ts
│   │           └── process-ed-subjects.domain.ts
│   ├── payments/                     # Payments / Stripe integration (Lambda)
│   ├── stats/                        # Analytics and stats (Lambda)
│   ├── users/                        # User management service (Lambda)
│   └── websocket/                    # WebSocket API Gateway service (Lambda)
│       └── src/
│           ├── actions/
│           │   ├── notifications-lambda-actions.ts          # Direct Lambda notification handler
│           │   └── notifications-step-function-actions.ts   # Step Function notification handler
│           ├── domains/
│           │   ├── notify-websocket-domain.ts               # Posts messages to WebSocket connections
│           │   ├── forward-notify-websocket.domain.ts       # Simplified forwarding
│           │   └── process-websocket-subjects.domain.ts     # Subject adaptation
│           └── stacks/
│               └── notifications_workflow.asl.json          # Step Function definition
│
├── tests/                            # ATF — Playwright + Cucumber E2E tests
├── prompts/                          # AI prompt templates
└── scripts/                          # Shared build, deploy, packaging scripts
```

## Event System Architecture

### Overview

All inter-service communication flows through events. The system uses **AWS EventBridge** as the central event bus, with **WebSocket** for real-time client communication and **HTTP** as a fallback.

### Core Event Interfaces

Defined in `common/utils/src/models/api-messages.ts`:

```typescript
// The event envelope sent over the wire
interface Event<T = EventData<any>> {
  int: EventIntent;    // event intent (type)
  id: string;          // event ID (shared across related events)
  cId?: string;        // client ID
  uId?: string;        // user ID
  err?: ErrorPayload;  // error info (if applicable)
  data: T;             // payload
}

// The event payload
interface EventData<P> {
  user: User;
  rI?: RequestInitiator;
  ts?: string;               // timestamp
  c?: Array<P>;              // content array
  ctx?: Array<P>;            // context array
}

// Payload wrapper used by builders
interface Payload<T> {
  c?: Array<T>;              // content
  ctx?: Array<T>;            // context
}
```

### Complete EventIntent Enum

All 68 event intents with their numeric values. **Important:** The order is significant — `UserIdUpdate` (1) must remain at position 1 for backwards compatibility.

```
 0  UserSetupEdlinkUser       (UNUSED)
 1  UserIdUpdate              (position-sensitive — used in user service)
 2  WSSEnhanceLesson          (TODO: delete)
 3  WSSNotifications          (User sign-in event, routes to Hubspot)
 4  WSSGenerateMaterial       (TODO: delete)
 5  WSSConnect                (hardcoded in websocket/topic-subs.yaml)
 6  WSSDisconnect             (hardcoded in websocket/topic-subs.yaml)
 7  WSSNotify                 (hardcoded in websocket/topic-subs.yaml)
 8  WSSPing
 9  AppAcknowledge
10  AppPong
11  EntryBatchUpdate
12  EntryCreate
13  EntryCreateTempInvite
14  EntryCreateUninitialized
15  EntryUpdate
16  EntryDelete
17  EntryDeepDelete
18  EntryUndoDelete
19  EntryRead
20  EntryCopy
21  EntryMigrateExistingDAUser
22  EntrySynchronizeEdClasses
23  EntryUpdateHubspotWithUser
24  EntrySynchronizeEdlinkClasses  (UNUSED)
25  EntrySynchronizeGoogleClasses
26  WSSAutoMark
27  AITranslateLesson
28  AIAdjustReadingLevel
29  AIGenerateNewDocument
30  AIUseOpenEndedPrompt
31  SomethingWentWrong
32  ExistingDAUserMigrated
33  ClassesSynchronized
34  EntryCreated
35  EntryUpdated
36  EntryDeleted
37  EntryFetched
38  EntryWatched
39  EntryCopied
40  UserUpdated
41  EntrySynchronizeClasslinkClasses
42  FetchAndSyncClasses
43  UserStatsRead
44  UserStatsFetched
45  AITextStreamingChunk
46  EntryCopyVToSC
47  AssignmentCreated
48  AssignmentUpdated
49  AssignmentDeleted
50  LabReportUserCreated
51  LabReportUserUpdated
52  LicenseCreated
53  VToSCEntryCopied
54  LMSVToSCEntryCopied
55  InviteAccepted
56  LMSInviteAccepted
57  DrainPendingIndex
58  UserDetailsCreate
59  UserDetailsRead
60  UserDetailsUpdate
61  UserDetailsDelete
62  UserDetailsCreated
63  UserDetailsFetched
64  UserDetailsUpdated
65  UserDetailsDeleted
66  UploadScorm
67  ScormUploaded
```

### Intent Categories

| Category | Intents (App → Backend) | Purpose |
|----------|------------------------|---------|
| **Entry Mutations** | `EntryCreate`, `EntryBatchUpdate`, `EntryDeepDelete`, `EntryUndoDelete` | CRUD operations on entries |
| **Entry Queries** | `EntryRead` | Fetch entries by various indexes |
| **Entry Copy** | `EntryCopy`, `EntryCopyVToSC` | Copy entries (lesson to student, import, etc.) |
| **AI Operations** | `AITranslateLesson`, `AIAdjustReadingLevel`, `AIGenerateNewDocument`, `AIUseOpenEndedPrompt`, `WSSAutoMark` | AI-powered content operations |
| **User Details** | `UserDetailsCreate`, `UserDetailsRead`, `UserDetailsUpdate`, `UserDetailsDelete` | User profile management |
| **Class Sync** | `FetchAndSyncClasses` | Trigger LMS class synchronization |
| **Other** | `DrainPendingIndex`, `UploadScorm`, `UserStatsRead`, `WSSNotifications` (sign-in) | Misc operations |

| Category | Intents (Backend → App) | Purpose |
|----------|------------------------|---------|
| **Lifecycle** | `EntryCreated`, `EntryUpdated`, `EntryDeleted`, `EntryCopied`, `EntryFetched`, `EntryWatched` | Generic entry lifecycle confirmations |
| **Specific Lifecycle** | `AssignmentCreated/Updated/Deleted`, `LabReportUserCreated/Updated`, `LicenseCreated` | Type-specific confirmations (route to external services) |
| **Copy Results** | `VToSCEntryCopied`, `LMSVToSCEntryCopied`, `InviteAccepted`, `LMSInviteAccepted` | Copy operation results |
| **User Details** | `UserDetailsCreated`, `UserDetailsFetched`, `UserDetailsUpdated`, `UserDetailsDeleted` | User detail responses |
| **Sync Results** | `ClassesSynchronized`, `ExistingDAUserMigrated` | Sync completion |
| **AI Streaming** | `AITextStreamingChunk` | Progressive AI output |
| **Errors** | `SomethingWentWrong` | Error notifications |
| **System** | `AppAcknowledge`, `AppPong` | Acknowledgements and keepalive |

## Event Flow: End-to-End

### 1. Frontend Sends Event

```
Component/Action/Reactor
  → EventInputBuilder (constructs typed payload)
  → EventAPIService (via decorator chain)
  → WebSocket or HTTP to API Gateway
  → API Gateway publishes to EventBridge
```

### 2. EventBridge Routes Event

EventBridge bus `ServicesEventBus{environment}` matches events by `source` + `detail-type` and routes to target Lambda/Step Function.

### 3. Backend Processes & Responds

```
Target Service Lambda/Step Function
  → Processes event (CRUD, copy, AI, etc.)
  → Generates output intent (e.g. EntryCreate → AssignmentCreated)
  → Publishes response event to EventBridge
```

### 4. Response Routes Back to Client

```
EventBridge routes response to WebSocket service
  → WebSocket Lambda/Step Function looks up active connections
  → Posts message to connected WebSocket clients
```

### 5. Frontend Receives & Processes

```
WebSocket message received
  → WSMessageReceiverService (deserializes, fetches from S3 if needed)
  → DispatcherModule selects MessageProcessor by intent
  → MessageProcessor updates EntryStore / shows errors / retries
```

## Frontend Event System (App)

### EventAPIService Decorator Chain

The `EventAPIService` is built as a chain of decorators, assembled in `app.module.ts`:

```
Caller
  ↓
SyncEnforcerDecorator          ← Ensures uAt/uId are set on mutations
  ↓
PosthogSpyDecorator            ← Tracks analytics (Create, Read, Copy, AI events)
  ↓
CopyEventInterceptorDecorator  ← Handles delayed VToSC copies locally
  ↓
AdvanceEntryStateAroundEventDecorator ← Updates entry state machine
  ↓
EventIdManagerDecorator        ← Assigns unique eventId + clientId
  ↓
ChangeActiveServiceDecorator   ← Fallback: switches to HTTP on 504
  ↓
Proxy(EventAPIServiceProxyHandler) ← Routes to WebSocket or EntryAPI service
```

**Wiring in `app.module.ts`** (lines 166-172):

```typescript
ch.setService(new Proxy({}, pH) as EventAPIService);  // ChangeActive wraps Proxy
id.setService(ch);   // EventIdManager wraps ChangeActive
adv.setService(id);  // AdvanceEntryState wraps EventIdManager
cp.setService(adv);  // CopyEventInterceptor wraps AdvanceEntryState
spy.setService(cp);  // PosthogSpy wraps CopyEventInterceptor
sync.setService(spy); // SyncEnforcer wraps PosthogSpy (outermost)
return sync;          // SyncEnforcer is the entrypoint
```

### Event Input Builders

Builders construct strongly-typed event payloads. Key patterns:

**Entry events** (`entry-events.ts`):

```typescript
// Create entries
new EntryCreateEventInputBuilder(container, parentSK, masterId)

// Batch update
new EntryBatchUpdateEventInputBuilder(entries)

// Deep delete
new EntryDeepDeleteEventInputBuilder(entries)
```

**Copy events** (`copy-events.ts`):

```typescript
// Copy lesson version to student copies
new CopyVToSCInputBuilder({...params, delayed: false})

// Import lesson to collection
new ImportLessonToCollectionInputBuilder({...params})

// Accept lab report invitation
new AcceptInviteInputBuilder(entryId)

// Copy source to version (generates deterministic pK via seed)
new CopySrcToVersionInputBuilder(params, userId)

// More: PromoteVersionToPrimary, CreateAuthorVersion, AddCourseToCurriculum,
//       ImportLessonToMyLessons, ImportCourseToMyLessons
```

All copy builders implement `CopyEventInput` which includes a `delayed` flag. When `delayed: true`, the `CopyEventInterceptorDecorator` handles the copy locally instead of sending to the server.

**Query events** (`query-events.ts`): Builders for `EntryRead` with various index types (MasterIndex, VersionIndex, ClassIndex, UserLibraryIndex, etc.).

### WebSocket Message Processors

Incoming WebSocket messages are dispatched to processors based on intent. Processors are registered in `dispatcher.module.ts`:

| Processor | Handles Intent(s) | Action |
|-----------|-------------------|--------|
| `VoidMessageProcessor` | null/empty | No-op |
| `AcknowledgedMessageProcessor` | `AppAcknowledge` | Advances entry state to "Sent" |
| `EntryMessageProcessor` | `EntryCreated`, `EntryUpdated`, `EntryDeleted`, `EntryCopied`, `AssignmentCreated/Updated/Deleted`, `LabReportUserCreated/Updated`, `LicenseCreated`, `VToSCEntryCopied`, `LMSVToSCEntryCopied`, `InviteAccepted`, `LMSInviteAccepted`, `ClassesSynchronized`, `ExistingDAUserMigrated` | Updates entry store |
| `PongMessageProcessor` | `AppPong` | Updates API state to "online" |
| `LicenseMessageProcessor` | License events | License handling |
| `EntryFetchMessageProcessor` | `EntryFetched` | Updates entry store with fetched data |
| `UserStatsFetchMessageProcessor` | `UserStatsFetched` | Updates user stats |
| `UserDetailsFetchMessageProcessor` | `UserDetailsFetched` | Updates user details |
| `UserDetailsMutationMessageProcessor` | `UserDetailsCreated/Updated/Deleted` | Confirms user detail mutations |
| `ErrorMessageProcessor` | `SomethingWentWrong` | Retries (max 3), advances to Failed, shows error dialogs |
| `AIStreamingMessageProcessor` | `AITextStreamingChunk` | Processes progressive AI output |
| `ScormMessageProcessor` | `ScormUploaded` | SCORM upload confirmation |

### ActiveEventStore & Event Lifecycle

The `ActiveEventStore` (`stores/active-event.store.ts`) tracks pending/completed events:

```typescript
interface ActiveEvent {
  status: EventStatus;   // Pending, Success, Failure
  ts: number;            // timestamp
  retryCount: number;    // retry attempts
  event?: WebSocketEvent;
  payload?: Payload<any>;
}
```

**Entry State Machine** (managed by `AdvanceEntryStateAroundEventDecorator`):

```
Initial → Awaiting       (on sendEvent)
Awaiting → Sent          (on AppAcknowledge)
Sent → Succeeded         (on server response)
Awaiting → Failed        (on error — triggers cache expiration)
```

**Timeouts** (managed by `ActiveEventReactor`):
- Pending events expire after **6 minutes 15 seconds**
- Completed events expire after **30 seconds**

### Event Utils

`services/app/src/app/utils/event-utils.ts` provides:

```typescript
// Intents that change entry state (trigger optimistic updates)
intentsChangingState = [EntryCreate, EntryBatchUpdate, EntryDeepDelete]

// Intents that query data
intentsForQueries = [EntryRead]

// Type guards
isEntryChange(intent)  // true for mutation intents
isEntryQuery(intent)   // true for query intents
```

## Backend Event System

### EventBridge Configuration

**Bus Name:** `ServicesEventBus{environment}`

**Event Source Convention:** `pocketlab.{environment}.{service}.{handler}`

| Source | Service |
|--------|---------|
| `pocketlab.{env}.web.gateway.default` | WebSocket API Gateway (frontend events) |
| `pocketlab.{env}.ai.ai` | AI service |
| `pocketlab.{env}.auth.gateway.createTempUserClaims` | Auth service |
| `pocketlab.{env}.ent.entry` | Entries service |
| `pocketlab.{env}.ent.exodus` | Exodus (class sync) service |
| `pocketlab.{env}.not.edNotifications` | Ed notifications service |
| `pocketlab.{env}.use.details` | User details service |

### EventBridge Routing Rules

All rules are defined in `services/events/stacks/event-bus-rules.yaml`.

#### From Web Gateway → Backend Services

| Rule | Intent(s) | Target |
|------|-----------|--------|
| `EntryCreateRule` | `EntryCreate` | Entry Workflow Step Function |
| `EntryBatchUpdateRule` | `EntryBatchUpdate` | Entry Workflow Step Function |
| `EntryDeepDeleteRule` | `EntryDeepDelete` | Entry Workflow Step Function |
| `EntryCopyVToSCRule` | `EntryCopyVToSC` | Entry Copy Workflow Step Function |
| `EntryCopyRule` | `EntryCopy` | Entry Lambda (direct) |
| `QueryRule` | `EntryRead` | Entry Lambda (direct) |
| `EntryUndoDeleteRule` | `EntryUndoDelete` | Entry Lambda (direct) |
| `AIAdjustReadingLevelRule` | `AIAdjustReadingLevel` | AI Step Function |
| `AIGenerateNewDocumentRule` | `AIGenerateNewDocument` | AI Step Function |
| `AITranslateLessonRule` | `AITranslateLesson` | AI Step Function |
| `AIUseOpenEndedPromptRule` | `AIUseOpenEndedPrompt` | AI Step Function |
| `WSSAutoMark` | `WSSAutoMark` | AI Step Function |
| `WSSEnhanceLessonRule` | `WSSEnhanceLesson` | AI Step Function |
| `WSSGenerateMaterialRule` | `WSSGenerateMaterial` | AI Step Function |
| `UserSignedInRule` | `WSSNotifications` | Hubspot Notifications Lambda |
| `FetchAndSyncClassesRule` | `FetchAndSyncClasses` | Entry Lambda |
| `UserStatsReadRule` | `UserStatsRead` | Entry Lambda |
| `UploadScormRule` | `UploadScorm` | Entry Lambda |
| `DrainPendingIndexRule` | `DrainPendingIndex` | DrainPendingIndex Lambda |
| `UserIdUpdateRule` | `UserIdUpdate` | User Update Lambda |
| `UserDetailsCreate/Read/Update/DeleteRule` | `UserDetailsCreate/Read/Update/Delete` | User Update Lambda |

#### From Entries Service → WebSocket + Notifications

| Rule | Intent(s) | Target |
|------|-----------|--------|
| `EntryCreatedEntryRule` | `EntryCreated`, `AssignmentCreated`, `LabReportUserCreated`, `LicenseCreated` | WebSocket Notifications Step Function |
| `EntryUpdatedEntryRule` | `EntryUpdated`, `AssignmentUpdated`, `LabReportUserUpdated` | WebSocket Notifications Step Function |
| `EntryDeletedEntryRule` | `EntryDeleted`, `AssignmentDeleted` | WebSocket Notifications Step Function |
| `EntryCopiedEntryRule` | `EntryCopied`, `VToSCEntryCopied`, `LMSVToSCEntryCopied`, `InviteAccepted`, `LMSInviteAccepted` | WebSocket Notifications Step Function |
| `EntryFetchedEntryRule` | `EntryFetched` | WebSocket Forward Lambda |
| `EntryWatchedEntryRule` | `EntryWatched` | WebSocket Connections Lambda |
| `SomethingWentWrongEntryRule` | `SomethingWentWrong` | WebSocket Forward Lambda |
| `ScormUploadedEntryRule` | `ScormUploaded` | WebSocket Forward Lambda |
| `UserStatsFetchedRule` | `UserStatsFetched` | WebSocket Forward Lambda |
| `EntryHubspotRule` | `VToSCEntryCopied`, `LMSVToSCEntryCopied`, `LicenseCreated` | Hubspot Notifications Lambda |
| `EntryEdRule` | `AssignmentUpdated`, `AssignmentDeleted`, `LabReportUserUpdated`, `LMSVToSCEntryCopied`, `LMSInviteAccepted` | Ed Notifications Lambda |
| `EntrySynchronize*Rule` | `EntrySynchronizeEdClasses`, `...GoogleClasses`, `...ClasslinkClasses` | Exodus Lambda |

#### From AI Service → WebSocket + Entries

| Rule | Intent(s) | Target |
|------|-----------|--------|
| `EntryCreateUninitializedAIRule` | `EntryCreateUninitialized` | Entry Workflow Step Function |
| `SomethingWentWrongAIRule` | `SomethingWentWrong` | WebSocket Forward Lambda |
| `AITextStreamingChunkRule` | `AITextStreamingChunk` | WebSocket Forward Lambda |

#### From Other Services

| Rule | Source | Intent(s) | Target |
|------|--------|-----------|--------|
| `EntryCreateTempInviteAuthRule` | `auth.gateway.createTempUserClaims` | `EntryCreateTempInvite` | Entry Lambda |
| `ExistingDAUserMigratedExodusRule` | `ent.exodus` | `ExistingDAUserMigrated` | WebSocket Notifications Step Function |
| `ClassesSynchronizedExodusRule` | `ent.exodus` | `ClassesSynchronized` | WebSocket Notifications Step Function |
| `SomethingWentWrongExodusRule` | `ent.exodus` | `SomethingWentWrong` | WebSocket Notifications Step Function |
| `EntryBatchUpdateEdNotificationsRule` | `not.edNotifications` | `EntryBatchUpdate` | Entry Workflow Step Function |
| `UserDetails*Rule` | `use.details` | `UserDetailsCreated/Fetched/Updated/Deleted`, `SomethingWentWrong` | WebSocket Forward Lambda |

### Intent Resolution (generateEntryIntent)

The entries service transforms generic input intents into specific output intents based on the first entry's type. Defined in `services/entries/src/utils/generate-entry-intent.ts`:

| Input Intent | Entry Type | Output Intent |
|-------------|------------|---------------|
| `EntryCreate` | Assignment | `AssignmentCreated` |
| `EntryCreate` | LabReportUser / InvitedLabReportUser | `LabReportUserCreated` |
| `EntryCreate` | License | `LicenseCreated` |
| `EntryCreate` | (any other) | `EntryCreated` |
| `EntryUpdate` / `EntryBatchUpdate` | Assignment | `AssignmentUpdated` |
| `EntryUpdate` / `EntryBatchUpdate` | LabReportUser | `LabReportUserUpdated` |
| `EntryUpdate` / `EntryBatchUpdate` | (any other) | `EntryUpdated` |
| `EntryDelete` / `EntryDeepDelete` | Assignment | `AssignmentDeleted` |
| `EntryDelete` / `EntryDeepDelete` | (any other) | `EntryDeleted` |
| `EntryUndoDelete` | Assignment | `AssignmentUpdated` |
| `EntryUndoDelete` | (any other) | `EntryUpdated` |
| `EntryCopied` | Assignment + LMS context | `LMSVToSCEntryCopied` |
| `EntryCopied` | Assignment | `VToSCEntryCopied` |
| `EntryCopied` | LabReportUser + LMS context | `LMSInviteAccepted` |
| `EntryCopied` | LabReportUser | `InviteAccepted` |
| `EntryCopied` | (any other) | `VToSCEntryCopied` |

This mapping is critical because the specific output intents determine which EventBridge rules fire, and therefore which external services (Hubspot, Ed) receive notifications.

### Copy Types

The `CopyType` enum defines the types of copy operations:

| CopyType | Builder | Purpose |
|----------|---------|---------|
| `VToSCCopy` | `CopyVToSCInputBuilder` | Copy lesson version to student copies (uses `EntryCopyVToSC` intent → Step Function) |
| `LsnToCollCopy` | `ImportLessonToCollectionInputBuilder` | Import lesson into a collection |
| `AcceptInvite` | `AcceptInviteInputBuilder` | Accept lab report invitation |
| `SrcToVCopy` | `CopySrcToVersionInputBuilder` | Copy source to a new version (generates seeded pK) |
| `PromoteVersionToPrimary` | `PromoteVersionToPrimaryInputBuilder` | Promote version to primary |
| `CreateAuthorVersion` | `CreateAuthorVersionInputBuilder` | Create author version |
| `AddCourseToCurriculum` | `AddCourseToCurriculumInputBuilder` | Add course to curriculum |
| `ImportLessonToMyLessons` | `ImportLessonToMyLessonsInputBuilder` | Import lesson to user's library |
| `ImportCourseToMyLessons` | `ImportCourseToMyLessonsInputBuilder` | Import course to user's library |

Note: `VToSCCopy` uses the dedicated `EntryCopyVToSC` intent which routes to a Step Function (for orchestrating multi-step copy). All other copy types use the generic `EntryCopy` intent which routes to a direct Lambda invocation.

### WebSocket Service

The WebSocket service has two Lambda handlers:

1. **Notifications Lambda** (`notifications-lambda-actions.ts`):
   - `messageHandler` — processes entry lifecycle events (EntryCreated/Updated/Deleted/Copied, etc.), builds WebSocket subjects, sends to connections
   - `forward` — directly forwards events to WebSocket connections (SomethingWentWrong, EntryFetched, AITextStreamingChunk, UserDetails*, ScormUploaded)

2. **Notifications Step Function** (`notifications_workflow.asl.json`):
   - **Step 1: BuildSubjects** — parses event data, builds notification subjects. Uploads to S3 if payload > 200KB
   - **Step 2: HasError** — checks for errors, routes to error notification
   - **Step 3: NotifyComponents (Map)** — parallel notification for each component
   - **Step 4: NotifyComponent** — retrieves from S3 if needed, posts to WebSocket connections

The Step Function is used for entry mutation notifications (where payload may be large), while the direct Lambda is used for simple forwarding (fetched data, errors, streaming chunks).

### Notifications Service

Broadcasts events to external services:

**Hubspot** (`hubspot-notifications-lambda-actions.ts`):
- `VToSCEntryCopied` / `LMSVToSCEntryCopied` → Updates Hubspot with assignment info
- `LicenseCreated` → Updates Hubspot with license details
- `WSSNotifications` (user sign-in) → Updates Hubspot with user activity

**Ed (LMS)** (`ed-notifications-lambda-actions.ts`):
- `AssignmentUpdated` / `AssignmentDeleted` → Syncs assignment state to Ed
- `LabReportUserUpdated` → Syncs lab report user status
- `LMSVToSCEntryCopied` / `LMSInviteAccepted` → Creates records in Ed
- Note: Ed notifications can trigger `EntryBatchUpdate` back to the entries service

### Large Payload Handling

Events with large payloads are stored in S3:
- Backend services upload data via `s3JsonUploader.uploadJsonData()`
- The event contains an S3 reference instead of the full payload
- The WebSocket service (and frontend `WSMessageReceiverService`) fetch the full payload from S3 when processing

## Common Event Flow Examples

### User Creates an Entry

```
1. Component calls action
2. Action builds EntryCreateEventInputBuilder
3. EventAPIService decorator chain:
   a. SyncEnforcer adds uAt/uId
   b. PosthogSpy tracks analytics
   c. CopyEventInterceptor passes through (not a copy)
   d. AdvanceEntryState → entries set to "Awaiting"
   e. EventIdManager assigns eventId + clientId
   f. ChangeActive routes to WebSocket
4. WebSocket sends to API Gateway
5. API Gateway publishes to EventBridge (source: web.gateway.default, detail-type: EntryCreate)
6. EntryCreateRule routes to Entry Workflow Step Function
7. Step Function processes create, publishes EntryCreated (or AssignmentCreated, etc.)
8. EntryCreatedEntryRule routes to WebSocket Notifications Step Function
9. WebSocket Step Function builds subjects, posts to connections
10. Frontend receives WebSocket message
11. EntryMessageProcessor updates EntryStore
12. Entry state advanced to "Succeeded"
```

### User Copies Lesson to Students (VToSC)

```
1. Action builds CopyVToSCInputBuilder (eventType: EntryCopyVToSC)
2. Decorator chain processes (may intercept if delayed: true)
3. EventBridge routes to Entry Copy Workflow Step Function
4. Step Function orchestrates multi-step copy
5. generates VToSCEntryCopied or LMSVToSCEntryCopied intent
6. EventBridge routes to:
   a. WebSocket Notifications Step Function → notifies connected clients
   b. Hubspot Notifications Lambda → updates Hubspot
   c. Ed Notifications Lambda → updates Ed (if LMS)
```

### Error Handling

```
1. Backend service catches error
2. Publishes SomethingWentWrong event to EventBridge
3. Routes to WebSocket Forward Lambda
4. Frontend ErrorMessageProcessor receives error
5. If retryCount < 3 and event is retryable → retry
6. If retryCount >= 3 → advance entries to Failed state, show error dialog
```

## Key Source Files Reference

| File | Purpose |
|------|---------|
| `common/utils/src/models/api-messages.ts` | EventIntent enum, Event/Payload interfaces, CopyType, query types |
| `services/events/stacks/event-bus-rules.yaml` | All EventBridge routing rules (source → target mapping) |
| `services/app/src/app/services/event-api.service.ts` | EventAPIService interface, ProxyHandler, SendEventInput union |
| `services/app/src/app/services/events/event-core.ts` | EventType union (supported frontend intents), EventInput interface |
| `services/app/src/app/services/events/copy-events.ts` | All copy event input builders |
| `services/app/src/app/services/events/entry-events.ts` | Entry mutation event builders |
| `services/app/src/app/services/events/query-events.ts` | Query event builders |
| `services/app/src/app/services/events/ai-events.ts` | AI event builders |
| `services/app/src/app/utils/event-utils.ts` | intentsChangingState, intentsForQueries, type guards |
| `services/app/src/app/app.module.ts` (lines 155-183) | Decorator chain assembly |
| `services/app/src/app/services/service-decorator/` | All 6 decorator implementations |
| `services/app/src/app/services/websocket-message-processor/dispatcher.module.ts` | Message processor registry |
| `services/app/src/app/stores/active-event.store.ts` | Pending/completed event tracking |
| `services/entries/src/utils/generate-entry-intent.ts` | Input → output intent mapping by entry type |
| `services/entries/src/actions/entry-lambda-actions.ts` | Entry service Lambda handler |
| `services/websocket/src/actions/notifications-lambda-actions.ts` | WebSocket notification Lambda |
| `services/websocket/src/actions/notifications-step-function-actions.ts` | WebSocket notification Step Function |
| `services/websocket/stacks/notifications_workflow.asl.json` | Step Function state machine definition |
| `services/notifications/src/actions/hubspot-notifications-lambda-actions.ts` | Hubspot integration |
| `services/notifications/src/actions/ed-notifications-lambda-actions.ts` | Ed/LMS integration |

## Debugging Tips

### Tracing an event end-to-end

1. **Find the builder** — search for the `EventIntent` in `services/app/src/app/services/events/` to find which builder constructs it
2. **Find the EventBridge rule** — search `event-bus-rules.yaml` for the `detail-type` matching `EventIntent.{name}`
3. **Find the target handler** — the rule's `Target.Arn` tells you which Lambda or Step Function handles it
4. **Find the response routing** — search `event-bus-rules.yaml` for the service's source pattern to find how responses route back
5. **Find the message processor** — search `dispatcher.module.ts` for the response intent to find which processor handles it

### Common pitfalls

- **Event intent ordering**: Never reorder the `EventIntent` enum — numeric values are used in WebSocket topic subscriptions and user service updates
- **LMS vs non-LMS**: Copy events produce different intents based on LMS context (`lmsCId`/`lmsUId` presence). This affects which external services are notified
- **Step Function vs Lambda**: Entry mutations (Create, BatchUpdate, DeepDelete) and VToSC copies go through Step Functions. Simple operations (Read, Copy, UndoDelete) go to Lambda directly
- **S3 payload**: Large event payloads are stored in S3 — if debugging missing data, check whether the payload was S3-referenced
- **Delayed copies**: `CopyVToSCInputBuilder` with `delayed: true` is handled entirely client-side by `CopyEventInterceptorDecorator` — the event never reaches the backend
