# Sort Keys & Entry Hierarchy

A reference guide for understanding DynamoDB primary keys, sort key structure, node IDs, entry types, and the entry hierarchy used across the PocketLab Notebook codebase.

## Primary Key Structure

DynamoDB uses a **composite primary key** consisting of:

| Component      | Property   | Length  | Description                              |
|----------------|------------|---------|------------------------------------------|
| Partition Key  | `entry.mId`| 8 chars | Master ID — shared by all entries in a tree |
| Sort Key       | `entry.sK` | variable| Encodes the entry's position in the hierarchy |

The combined `mId + sK` uniquely identifies every entry. A **primary key string (pK)** is the concatenation: `${mId}${sK}`.

```
pK = mId (8 chars) + sK (variable)
     ^^^^^^^^        ^^^^^^^^^^^^
     partition key   sort key
```

## Sort Key Format

```
sK = <revision{2}><nodeId_1{6}><nodeId_2{6}>...<nodeId_N{6}>
```

| Segment     | Length | Description                                     |
|-------------|--------|-------------------------------------------------|
| Revision    | 2 chars| Always `"00"` for new entries                   |
| NodeId(s)   | 6 chars each | One per level in the hierarchy           |

**Constants** (from `key-utils-pl2.ts`):

```typescript
nodeIdLength   = 4;  // random part of a node ID
nodeLength     = 6;  // type (2) + random (4)
revisionLength = 2;  // revision prefix
typeLength     = 2;  // entry type code
masterIdLength = 8;  // partition key length
```

### Node ID Structure

Each 6-character node ID encodes:

```
nodeId = <type{2}><random{4}>
         ^^^^^^^^ ^^^^^^^^^^^^
         EntryType  nanoid/seeded random chars
```

- **type{2}**: The 2-character `EntryType` code (see table below)
- **random{4}**: 4 random alphanumeric characters generated via `nanoid` or seeded random

### Reading a Sort Key

The sort key encodes the full path from root to the current entry. Each successive 6-char segment represents one level deeper in the hierarchy:

```
sK = "00" + node_root + node_child + node_grandchild + ...
      ^^    ^^^^^^^^^^   ^^^^^^^^^^   ^^^^^^^^^^^^^^^^^
      rev   level 1      level 2      level 3 (this entry)
```

- The **last** nodeId segment is this entry's own nodeId
- The **second-to-last** segment is the immediate parent's nodeId
- And so on up to the root

**Example — Class with Assignment and Student Copy:**

```
ClassEntry sK:         00 | 00abcd                           (level 1, type '00' = Class)
AssignmentEntry sK:    00 | 00abcd | 03efgh                  (level 2, type '03' = Assignment)
StudentCopyEntry sK:   00 | 00abcd | 03efgh | 02ijkl         (level 3, type '02' = StudentCopy)
TextSection sK:        00 | 00abcd | 03efgh | 02ijkl | 23mnop (level 4, type '23' = TextSection)
```

All entries in the same tree share the same `mId`.

## Entry Type Codes

### Top-Level Entries (TLE) — `'00'` to `'09'`

| Code | EntryType          | Description                        |
|------|--------------------|------------------------------------|
| `00` | Class              | A class container                  |
| `01` | LabReport          | A standalone lesson/investigation  |
| `02` | StudentCopy        | Student's copy of an assignment    |
| `03` | Assignment         | An assignment within a class       |
| `05` | ClassScope         | Class-wide scope for assignments   |
| `06` | IndividualScope    | Individual student scope           |
| `07` | Course             | A course within curriculum         |
| `08` | Curriculum         | A curriculum collection            |
| `09` | Playlist           | A playlist of lessons              |

### Special Negative TLE Types

| Code | EntryType          | Description                        |
|------|--------------------|------------------------------------|
| `-0` | LocalSubset        | Shared data objects in a lesson    |
| `-1` | ClassLocalSubset   | Shared data objects in a class     |
| `-2` | Module             | A module within a class            |

### User Entries — `'10'` to `'19'`

| Code | EntryType              | Description                    |
|------|------------------------|--------------------------------|
| `11` | StudentUser            | Student in a class             |
| `12` | LabReportUser          | User in a lab report           |
| `13` | InvitedLabReportUser   | Invited user in a lab report   |
| `14` | UninvitedLabReportUser | Guest user in a lab report     |
| `15` | ScopeUser              | User in a scope                |

### Sections — `'20'` to `'39'`

| Code | EntryType                 | Description                     |
|------|---------------------------|---------------------------------|
| `20` | TrialSection              | Experimental trial              |
| `21` | VideoSection              | YouTube video embed             |
| `22` | ImageSection              | Image section                   |
| `23` | TextSection               | Rich text section               |
| `24` | DataAnalysisSection       | Data analysis/graphing          |
| `25` | QuestionSection           | Multiple choice/free response   |
| `26` | CollectDataSection        | Real-time data collection       |
| `27` | GoogleDriveSection        | Google Drive embed (deprecated) |
| `28` | SharedDataTableSection    | Collaborative data table        |
| `29` | IFrameSection             | Custom iframe                   |
| `30` | PhetSection               | PhET simulation                 |
| `32` | SharedDrawingSection      | Collaborative whiteboard        |
| `33` | DiscussionSection         | Discussion/forum                |
| `34` | SpeechToTextSection       | Voice input                     |
| `35` | SharedDragAndDropSection  | Collaborative drag-and-drop     |
| `36` | SharedLineMatchingSection | Line matching activity          |
| `37` | ScormSection              | SCORM content                   |

Note: Code `31` is unused/skipped.

### Section Children — `'40'` to `'49'`

| Code | EntryType      | Description               |
|------|----------------|---------------------------|
| `40` | AnswerSection  | Answer to a question      |
| `41` | Comment        | Feedback/comment on work  |
| `42` | Transcript     | Transcript of responses   |
| `43` | Revision       | Revision history entry    |

### Miscellaneous — `'50'+`

| Code | EntryType       | Description                |
|------|-----------------|----------------------------|
| `50` | GlobalResource  | Global resource library    |
| `51` | Trial           | Top-level trial data       |
| `#>` | Metadata        | Metadata container         |
| `53` | TeacherNotes    | Teacher notes              |
| `54` | License         | License entry              |
| `55` | ClassPermission | Class permission           |
| `56` | Rubric          | Grading rubric             |
| `57` | PlaylistItem    | Item in a playlist         |

### Type Range Utility Functions

```typescript
isTLEType(t)       // '00' <= t <= '09'  — top-level entries
isUserEntryType(t) // '10' <= t <= '19'  — user entries
isSectionType(t)   // '20' <= t <= '39'  — sections
isLocalSubsetType(t) // '-0', '-1', '-2' — local subset variants
```

## Entry Hierarchy

### Class Hierarchy (most common)

```
Class ('00')
├── Assignment ('03')
│   ├── StudentCopy ('02')          ← one per student
│   │   ├── [Sections] ('20'-'37')  ← student's section copies
│   │   │   ├── AnswerSection ('40')
│   │   │   ├── Comment ('41')
│   │   │   └── Transcript ('42')
│   │   ├── InvitedLabReportUser ('13')
│   │   └── UninvitedLabReportUser ('14')
│   ├── ClassScope ('05')           ← class-wide shared scope
│   │   ├── [Sections]
│   │   └── ScopeUser ('15')
│   ├── IndividualScope ('06')      ← per-student scope
│   │   ├── [Sections]
│   │   └── ScopeUser ('15')
│   ├── LocalSubset ('-0')          ← shared data objects
│   ├── TeacherNotes ('53')
│   ├── Rubric ('56')
│   └── Metadata ('#>')
├── StudentUser ('11')              ← students enrolled in the class
├── ClassLocalSubset ('-1')         ← class-level shared objects
├── Module ('-2')                   ← modules within the class
└── ClassPermission ('55')
```

### Standalone LabReport Hierarchy

```
LabReport ('01')
├── [Sections] ('20'-'37')
│   ├── AnswerSection ('40')
│   ├── Comment ('41')
│   └── Transcript ('42')
│   ├── Rubric ('56')
│   ├── TeacherNotes ('53')
├── LabReportUser ('12')
├── LocalSubset ('-0')
└── Metadata ('#>')
```

### Curriculum Hierarchy

```
Curriculum ('08')
└── Course ('07')
    └── LabReport ('01')
        └── [Sections]
```

### Playlist Hierarchy

```
Playlist ('09')
└── PlaylistItem ('57')
```

### License Hierarchy

```
GroupLicense ('54')
└── AdminLicense ('54')
    └── PermissionLicense ('54')
```

## Key Generation

### Source Files

- `common/utils/src/key-generators/key-generators.ts` — Core generation functions
- `common/utils/src/utils/key-utils-pl2.ts` — Parsing, traversal, type detection
- `common/utils/src/index-managers/master-index-manager.ts` — Sets `mId`, `sK`, timestamps during creation

### How Keys Are Generated

**Root entry (no parent):**

```typescript
// key-generators.ts: generateRootPK()
mId = nanoid(8)                        // e.g. "a1b2c3d4"
sK  = "00" + type(2) + nanoid(4)      // e.g. "0000abcd"
pK  = mId + sK                         // e.g. "a1b2c3d40000abcd"
```

**Child entry (has parent):**

```typescript
// key-generators.ts: generateChildPK()
mId = parent.mId                       // inherited from parent
sK  = parent.sK + type(2) + nanoid(4) // parent sK + new nodeId
```

**Seeded generation:** When a `seed` is provided, `SeedRandomStringGenerator` (based on `seedrandom`) is used instead of `nanoid` to produce deterministic keys. This is used for synchronized class creation where the same seed produces the same keys.

### MasterIndexManager

The `MasterIndexManager` is the primary mechanism that sets index attributes on entries during creation:

```typescript
// For root entries (no parent.mId):
e.mId = generateMId(seed)
e.sK  = generateSortKey(null, type, seed)  // "00" + nodeId

// For child entries:
e.mId = parent.mId
e.sK  = generateSortKeyWithGenerator(parent.sK, type, generator)
```

It also sets: `uId` (creator), `cAt` (created at), `uAt` (updated at), `rC` (revision counter), and activates the entry.

## Sort Key Parsing & Traversal

### `parseSortKey(sk)` → `SortKey`

Parses a sort key string into a structured object:

```typescript
interface SortKey {
  r: string;          // revision (first 2 chars, usually "00")
  sK: string;         // original sort key string
  nodeIds: NodeId[];   // array of parsed node IDs in order
  pNodeId?: NodeId;    // parent's nodeId (second-to-last)
  nodeId: NodeId;      // this entry's nodeId (last)
  tleIdx: number;      // index of the last TLE-type node in nodeIds
}

interface NodeId {
  t?: EntryType;   // type code (first 2 chars)
  a?: string;      // arbitrary/random part (last 4 chars)
  id: string;      // full 6-char nodeId string
}
```

### Key Navigation Functions

| Function | Description |
|----------|-------------|
| `parentSortKey(sK)` | Remove last 6 chars → parent's sK (or null at root) |
| `parentPK(pK)` | Remove last 6 chars → parent's pK |
| `grandParentPK(pK)` | Remove last 12 chars → grandparent's pK |
| `greatGrandParentPK(pK)` | Remove last 18 chars |
| `ancestorParentPK(pK, n)` | Remove last `n * 6` chars |
| `findTLESK(sK)` | Find the sort key of the nearest TLE ancestor |
| `findParentTLESK(sK)` | Find the parent TLE's sort key |
| `findAncestorSKByType(sK, type)` | Find ancestor of a specific type |
| `getTLELineagePKs(pK)` | Get all TLE primary keys in the lineage |
| `rootEntrySK(sK)` | First 8 chars of sK (revision + first nodeId) |
| `rootEntryType(sK)` | EntryType of the root entry |
| `level(sK)` | `(sK.length - 2) / 6` — depth in the tree |
| `type(sKOrPK)` | EntryType from last 6 chars of string |

### Type Detection from Keys

The `type()` function extracts the entry type from any key string by reading 2 chars starting at `length - 6`:

```typescript
// For a sort key "0000abcd03efgh":
//                              ^^
//                              type = '03' (Assignment)

// For a primary key "a1b2c3d40000abcd03efgh02ijkl":
//                                             ^^
//                                             type = '02' (StudentCopy)
```

## EntryContainer (Hierarchical Tree Structure)

### Interface

```typescript
interface EntryContainer {
  e: Partial<AnyEntry>;        // the entry itself
  c?: Array<EntryContainer>;   // child containers (recursive)
  seed?: string;               // optional seed for deterministic generation
}
```

### Building Containers from Flat Entry Arrays

The `ContainerBuilder` (`common/utils/src/utils/container-utils.ts`) reconstructs the tree from a flat array of entries sorted by primary key:

1. Entries must be sorted by `pK` (which sorts by `sK` within the same `mId`)
2. DynamoDB's sort key design ensures parent entries come before children (shorter sK = higher in tree)
3. The builder maintains a `_history` array where index = depth relative to root
4. For each entry, it parses the sort key, determines the depth, and attaches it as a child of the entry at `depth - 1`

```typescript
// Simplified logic from ContainerBuilder._placeEntry():
const nodes = sortKey.nodeIds.slice(rootNodeIdx);
if (i === 0) {
  history[0] = {e, c: []};               // root
} else {
  history[nodes.length - 2].c.push(eCont); // attach to parent
  history[nodes.length - 1] = eCont;       // register at this depth
}
```

### Walking Containers

The `ContainerWalk` (`common/utils/src/entry-container/container-walk.ts`) uses a visitor pattern to traverse the tree. The `IndexManagerVisitor` is the primary visitor used during entry creation — it walks the container tree and calls `MasterIndexManager.setIndexAttributes()` on each entry, maintaining a parent stack to generate correct sort keys.

## Entry Attribute Initialization

The `EntryIndexAttributeInitializer` (deprecated name, now `EntryAttributeInitializer`) at `common/utils/src/entry-container/entry-index-attribute-initializer.ts` orchestrates entry creation:

1. Takes an `EntryCreateRequest` containing the parent sort key (`pSK`), master ID (`mId`), and an array of `EntryContainer`s
2. Creates an `IndexManagerVisitor` with parent context
3. Walks each container tree, letting the visitor set `mId`, `sK`, `uId`, `cAt`, `uAt`, `rC` on every entry
4. Returns both the flat entry array and the root entries (first entry of each container)

## Index Entries (Secondary Indexes)

Entries carry additional index attributes for DynamoDB GSI/LSI queries:

| Index Attribute | Interface          | Description                                      |
|-----------------|--------------------|--------------------------------------------------|
| `aSK`           | `AuthIdxEntry`     | Auth sort key — for authorization queries        |
| `dSK`           | `DashboardIdxEntry`| Dashboard sort key (deprecated)                  |
| `cSK`           | `ClassIdxEntry`    | Class sort key — for class membership queries    |
| `uLEId`         | `UserLibraryEntryIdxEntry` | `${userId}_${type}` — user's entries by type |

**Auth sort key (`aSK`) rules:**
- Class TLE: `aSK = mId`
- LabReport TLE: `aSK = mId`
- StudentCopy TLE: `aSK = ${mId}${ScSK}` (includes scope sort key)

## Mandatory Entry Attributes

Every entry must have:

| Attribute | Description               |
|-----------|---------------------------|
| `mId`     | Master ID (partition key) |
| `sK`      | Sort key                  |
| `t`       | Entry type                |
| `uId`     | Creator user ID           |
| `cAt`     | Created at (ISO timestamp)|
| `uAt`     | Updated at (ISO timestamp)|
| `rC`      | Revision counter          |

## Typed Key System

The `KeysPL2` namespace (`common/utils/src/models/keys-pl2.ts`) defines branded string types that encode the valid parent-child relationships at the TypeScript level:

```typescript
ClassKey       = GenerateKey<'Class'>                    // root
AssignmentKey  = GenerateKey<'Assignment', ClassKey>     // child of Class
StudentCopyKey = GenerateKey<'StudentCopy', AssignmentKey> // child of Assignment
LocalSubsetKey = GenerateKey<'LocalSubset', AssignmentKey>
ClassScopeKey  = GenerateKey<'ClassScope', AssignmentKey>
StudentUserKey = GenerateKey<'StudentUser', ClassKey>
ModuleKey      = GenerateKey<'Module', ClassKey>
LabReportKey   = GenerateKey<'LabReport'>                // standalone root
CourseKey      = GenerateKey<'Course'>                   // standalone root
CurriculumKey  = GenerateKey<'Curriculum'>               // standalone root
```

These types enforce at compile time that e.g. an `AssignmentKey` can only exist under a `ClassKey`.

## Key Source Files Reference

| File | Purpose |
|------|---------|
| `common/utils/src/key-generators/key-generators.ts` | Sort key and mId generation (nanoid + seeded) |
| `common/utils/src/utils/key-utils-pl2.ts` | Sort key parsing, traversal, type detection |
| `common/utils/src/models/models-pl2.ts` | `EntryType` enum, `SortKey`/`NodeId`/`EntryId` interfaces, all entry model interfaces |
| `common/utils/src/models/keys-pl2.ts` | Branded TypeScript key types encoding valid parent-child relationships |
| `common/utils/src/models/api-messages.ts` | `EntryContainer` interface, request/response types |
| `common/utils/src/utils/container-utils.ts` | `ContainerBuilder` — builds entry tree from flat sorted array |
| `common/utils/src/entry-container/container-walk.ts` | `ContainerWalk` + `Visitor` — tree traversal pattern |
| `common/utils/src/entry-container/entry-index-attribute-initializer.ts` | Orchestrates entry creation with index managers |
| `common/utils/src/entry-container/index-manager-visitor.ts` | Visitor that sets index attributes during tree walk |
| `common/utils/src/index-managers/master-index-manager.ts` | Core index manager: generates `mId`, `sK`, sets timestamps |
| `common/utils/src/utils/entry-utils-pl2.ts` | Entry utility functions, mandatory attributes |
| `services/app/src/app/stores/entry.store.ts` | Frontend entry state management |

## Common Debugging Patterns

### Decoding a primary key string

Given a pK like `a1b2c3d40000abcd03efgh02ijkl23mnop`:

```
a1b2c3d4  | 00    | 00abcd | 03efgh | 02ijkl | 23mnop
^^^^^^^^    ^^      ^^^^^^   ^^^^^^   ^^^^^^   ^^^^^^
mId (8)     rev(2)  Class    Assign   StCopy   TextSec
                    node1    node2    node3    node4
```

This is a **TextSection** inside a **StudentCopy** inside an **Assignment** inside a **Class**.

### Finding an entry's parent

Remove the last 6 characters from the sK (or pK) to get the parent's key.

### Finding the root entry

Take `sK.substring(0, 8)` (revision + first nodeId) to get the root entry's sort key.

### Determining hierarchy depth

`level = (sK.length - 2) / 6`

### Checking if two entries share a parent

Compare their sort keys minus the last 6 characters. If equal, they are siblings.
