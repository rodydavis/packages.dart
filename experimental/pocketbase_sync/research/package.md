# **Architectural Specification for a Generic Offline-First Synchronization Engine on PocketBase**

## **Executive Summary**

The transition from connected, state-dependent client-server architectures to offline-first distributed systems represents a fundamental shift in application reliability and user experience. While PocketBase provides a highly portable, SQLite-backed backend solution, its default interaction model is predicated on synchronous RESTful communication, rendering it susceptible to network partitioning. This report provides an exhaustive architectural specification for bridging this gap through a generic synchronization engine. The proposed solution is comprised of a server-side Go plugin and a client-side Flutter package, designed to operate agnostically across any PocketBase instance and schema.

The architecture necessitates a move from physical time to causal ordering via Hybrid Logical Clocks (HLC), the implementation of a distributed deletion strategy using a global tombstone registry, and the adoption of differential synchronization for text fields using the Myers Diff algorithm. By leveraging PocketBase’s extensible hook system—specifically OnRecordBeforeUpsert, OnRecordAfterDelete, and OnServe—this system injects statefulness into the mutation lifecycle without requiring invasive schema modifications. This document serves as a definitive guide for implementing this protocol, prioritizing data consistency, conflict resolution, and high availability in constrained network environments.

## **1\. Architectural Foundations of the Generic Synchronization Engine**

### **1.1 The Distributed Consistency Challenge**

In the domain of mobile computing, the network must be treated as a hostile environment. The fallacy that the network is reliable, with zero latency and infinite bandwidth, often leads to brittle application designs that fail catastrophically when a user enters an elevator or a tunnel. The CAP theorem dictates that in the presence of a network partition (P)—an unavoidable reality for mobile devices—a system must choose between Consistency (C) and Availability (A). For a user-facing mobile application, Availability is non-negotiable; the user must be able to read and write data regardless of connectivity status. Consequently, this architecture embraces Eventual Consistency.

The core challenge in adapting PocketBase for this paradigm lies in its default "Realtime" nature. PocketBase’s realtime subscriptions broadcast state changes as they happen, assuming the client is present to receive them. If a client is offline, it misses these ephemeral messages. An offline-first architecture must therefore shift from an ephemeral event stream to a persistent replication log. The synchronization engine must guarantee that every mutation generated on the Edge (the mobile device) eventually reaches the Origin (the server), and conversely, that the Origin's state converges with the Edge, regardless of the duration of the disconnection.1

### **1.2 The Dual-Store Repository Pattern**

To achieve high availability, the architecture enforces a strict decoupling of the UI from the network. The generic Flutter package acts as a Repository layer that mediates between the application logic and two distinct data stores:

1. **The Local Replica:** An embedded SQLite database on the device (managed via drift or sqflite in the Dart ecosystem). This store serves as the single source of truth for the UI, enabling instantaneous reads and writes (Optimistic UI).3  
2. **The Remote Authority:** The PocketBase server, which acts as the convergence point for all distributed clients.

The critical requirement of "generic application" means this Repository cannot be hardcoded for specific collections (e.g., "Users" or "Tasks"). Instead, it must dynamically inspect the PocketBase schema (fetched via the API) and provision corresponding local tables on the fly. This dynamic mapping capability allows the Flutter package to be dropped into any project, instantly providing offline capabilities for whatever collections exist on the backend.4

### **1.3 Leveraging PocketBase’s Extensibility**

PocketBase distinguishes itself from other BaaS providers through its "framework-as-a-library" model. Written in Go, it allows developers to compile their own binary that embeds the core PocketBase logic while injecting custom code. This capability is pivotal for our synchronization engine. We cannot rely solely on the external REST API because we need to intercept database transactions to inject synchronization metadata (Logical Clocks) and capture deletions (Tombstones) that would otherwise be lost to an offline client.

The Go plugin mechanism allows us to register hooks such as OnRecordBeforeCreateRequest and OnRecordBeforeUpdateRequest. These hooks provide access to the core.Record object *before* it is persisted to SQLite, allowing the plugin to validate causal ordering constraints and reject out-of-order updates before they corrupt the database state. Furthermore, the OnServe hook enables the registration of custom "Sync" endpoints that can perform batch operations—reading tombstones and active records in a single transaction—thereby reducing network round-trips and database lock contention.6

| Feature | Standard PocketBase | Offline-First PocketBase |
| :---- | :---- | :---- |
| **Primary Data Source** | Remote Server (API) | Local SQLite Replica |
| **Consistency Model** | Immediate (on Request) | Eventual (on Sync) |
| **Time Source** | Server Wall Clock | Hybrid Logical Clock |
| **Deletion Handling** | Immediate Removal | Tombstone Retention |
| **Conflict Resolution** | Last-Request-Wins | Causal Ordering / Merge |

## **2\. Temporal Consistency: The Hybrid Logical Clock**

### **2.1 The Inadequacy of Physical Time**

A naive approach to synchronization relies on updated\_at timestamps generated by the system clock. In a distributed system of mobile devices, this approach is fundamentally flawed due to clock skew. A device with a clock set 10 minutes in the future will generate records that, under a standard Last-Write-Wins (LWW) policy, will overwrite any conflicting data generated by devices with accurate clocks for the next 10 minutes. Furthermore, physical clocks lack the precision to order events occurring within the same millisecond across different nodes.

To solve this, the generic architecture utilizes Hybrid Logical Clocks (HLC). The HLC provides a mechanism to capture the causality of events (if Event A causes Event B, the timestamp of B must be greater than A) while keeping the timestamp close to physical time to remain human-readable and useful for querying.

### **2.2 Mathematical Definition of HLC**

An HLC timestamp consists of three components: (l, c, id), where:

* $l$ is the physical component, representing the maximum wall-clock time observed by the node.  
* $c$ is the logical component, a counter incremented to distinguish events that occur at the same $l$.  
* $id$ is a unique node identifier (e.g., a UUID or hash of the device ID) used to break ties.

The generic Flutter package must maintain a local HLC state. Upon a local mutation (Create/Update), the package calculates the new timestamp $hlc\_{new}$ as follows:

$$l' \= \\max(l\_{old}, pt\_{now})$$

$$c' \= \\begin{cases} c\_{old} \+ 1 & \\text{if } l' \= l\_{old} \\\\ 0 & \\text{if } l' \> l\_{old} \\end{cases}$$  
Where $pt\_{now}$ is the device's current physical time. This algorithm ensures that the logical clock never moves backward, even if the device's physical clock is adjusted backward by the user or the OS.8

### **2.3 Serialization and Storage**

While HLCs are conceptually tuples, they must be stored in PocketBase's standard fields. PocketBase supports text, number, and date types. Storing the HLC as a strict, lexically sortable string is the most robust approach for a generic plugin.

**Format:** YYYY-MM-DDTHH:mm:ss.sssZ-CCCC-NODEID

* YYYY...Z: The physical component ($l$), ISO-8601 formatted.  
* CCCC: The logical counter ($c$), padded to 4 digits (hex or decimal).  
* NODEID: The truncated node ID.

This string format allows standard lexicographical comparison (string sorting) to be equivalent to chronological ordering. The Go plugin creates a custom field, nominally named \_hlc, on all synchronized collections. Since the architecture is "generic," the plugin automatically checks for this field's existence on OnBootstrap and creates it if missing, ensuring no manual setup is required by the user.

### **2.4 Drift Management and Security**

The Go server plugin acts as the guardian of time. When a client pushes a mutation with a specific HLC, the server must validate two conditions:

1. **Monotonicity:** The incoming HLC must be greater than the HLC currently stored on the record (if updating).  
2. **Bounded Drift:** The physical component $l$ of the incoming HLC cannot be significantly further in the future than the server's wall clock (e.g., MaxDrift \= 60000ms).

If a client sends a timestamp from the year 2050, the server rejects the generic sync request with a 400 Bad Request. This prevents a malicious or malfunctioning client from "poisoning" the timeline and making a record immutable to other clients.9

## **3\. Data Identification and Structural Integrity**

### **3.1 Distributed ID Generation**

In traditional web development, the database (e.g., via AUTO\_INCREMENT) assigns IDs. In an offline-first architecture, the client must generate the ID immediately upon creation to establish relationships between records (e.g., creating a Project and adding Tasks to it before syncing).

PocketBase uses 15-character random alphanumeric strings by default.11 While UUIDs (36 characters) are the industry standard for distributed ID generation, PocketBase's ecosystem is optimized for the shorter format. To maintain the requirement of working with "any PocketBase instance," the generic Flutter package should utilize NanoID (specifically a Dart implementation like nanoid) configured to match PocketBase's alphabet and length.

**Configuration:**

* **Alphabet:** 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ  
* **Length:** 15

The collision probability for a 15-character NanoID with this alphabet is extremely low (requiring millions of IDs per second to reach a 1% risk). However, the generic sync protocol must account for the theoretical possibility of a collision.

### **3.2 Collision Handling Protocol**

A collision occurs if Client A generates ID X offline, and Client B generates ID X and syncs it to the server before Client A comes online. When Client A attempts to push its record, the generic server plugin will return a unique constraint violation error.

The Flutter package must implement a **Provisional ID Mapping** strategy:

1. **Detection:** Catch the specific "Duplicate ID" error from the batch transaction.  
2. **Remediation:** Generate a new ID Y.  
3. **Refactoring:** Scan the local transaction queue and the local database for any Foreign Key references to X. Update them to point to Y.  
4. **Retry:** Resubmit the batch with the new ID.

This logic is encapsulated within the generic client's SyncManager class, ensuring the application code consuming the package does not need to handle ID remapping logic.13

### **3.3 The Schema Handshake**

Since the solution is generic, the client package does not know the server's schema at compile time. Upon initialization, the Flutter package performs a "Schema Handshake":

1. Client requests /api/collections from the server.  
2. Server returns the JSON description of all collections and fields.  
3. Client compares this schema hash against its local cached schema.  
4. **Divergence:** If the schema has changed (e.g., a developer renamed a field on the backend), the client enters a "Migration Mode."

In Migration Mode, the client must reconcile pending local mutations against the new schema. If a field description was renamed to bio, pending writes to description would fail. The generic package handles this by exposing a callback onSchemaChange(oldSchema, newSchema) where the developer can provide migration logic. If no callback is provided, the safe default is to drop mutations for fields that no longer exist to prevent the sync queue from becoming permanently stuck.15

## **4\. The Generic Synchronization Protocol**

The synchronization protocol is a bidirectional exchange of state, orchestrated by the generic Flutter package and served by the Go plugin. It operates in two phases: Push (Upstream) and Pull (Downstream).

### **4.1 Phase 1: The Push (Upstream) Strategy**

The client accumulates mutations in a persistent MutationQueue table in its local SQLite database. Each entry contains the collection name, record ID, operation type (CREATE, UPDATE, DELETE), the JSON payload, and the HLC timestamp.

When network connectivity is detected (via connectivity\_plus in Flutter), the client bundles these mutations into a **Transactional Batch**. PocketBase v0.23 introduced native support for batch requests, which is crucial for data integrity.16 Sending mutations individually would risk partial failures where a parent record creates successfully but its children fail, leaving the database in an inconsistent state.

**Batch Structure:**

JSON

{  
  "requests":  
}

The generic Go plugin intercepts this batch request using OnBatchRequest. It wraps the execution in a database transaction (app.RunInTransaction). It iterates through each operation, verifying that the incoming \_hlc is newer than the stored record's \_hlc. If a conflict is detected (e.g., incoming HLC \< stored HLC), the plugin resolves it (usually by rejecting the stale update or merging), ensuring that the server's state remains causally consistent.17

### **4.2 Phase 2: The Pull (Downstream) Strategy**

After a successful push, the client requests updates from the server. To remain generic, the client cannot request specific endpoints like /api/collections/users. Instead, it uses a custom "Sync" endpoint exposed by the Go plugin: /api/pocketbase\_sync/pull.

**Request Parameters:**

* since: The HLC of the last successful sync (last\_synced\_hlc).  
* limit: Pagination limit.

**Server Logic (Go Plugin):**

1. The plugin iterates through *all* collections registered in the app.  
2. For each collection, it queries for records where updated \> last\_synced\_hlc (optimization: using updated is faster for query filtering, but the client uses \_hlc for merging).  
3. It explicitly checks generic API rules (ViewRule) using app.CanAccessRecord. This step is critical; without it, the sync endpoint would become a backdoor bypassing the application's security model.  
4. It constructs a response grouping changed records by collection.

**Response Structure:**

JSON

{  
  "todos": \[... records... \],  
  "users": \[... records... \],  
  "\_offline\_tombstones": \[... deleted record markers... \],  
  "new\_cursor": "2023-10-27T11:00:00Z-0000-S"  
}

The client receives this payload, updates its local SQLite replica, and advances its last\_synced\_hlc cursor.

## **5\. Distributed Deletion Management: The Tombstone Pattern**

### **5.1 The Deletion Visibility Problem**

In a standard SQL database, a DELETE operation removes the row physically. For a client that is offline, this removal is invisible. When the client later asks for "changes since T," the deleted record is simply absent from the result set. The client, seeing no change, assumes its local copy is still valid, leading to "Zombie Records" that reappear or persist indefinitely on the device.

To support "Any PocketBase Instance," we cannot mandate that users change their schema to add a deleted boolean column (Soft Delete) to every table. This violates the ease-of-use principle. Instead, the Go plugin implements a **Global Tombstone Registry**.

### **5.2 The Global Tombstone Collection**

Upon initialization, the Go plugin checks for a system collection named \_offline\_tombstones. If absent, it creates it programmatically using the core.Collection model.

**Schema:**

* collection: String (Target collection name)  
* record\_id: String (Target record ID)  
* \_hlc: String (Timestamp of deletion)

### **5.3 Hook-Based Interception**

The plugin registers a global OnRecordAfterDeleteRequest hook. This hook fires whenever a record is deleted via the API (including from the Admin UI).

Go

app.OnRecordAfterDeleteRequest().Add(func(e \*core.RecordDeleteEvent) error {  
    // Avoid recursion  
    if e.Collection.Name \== "\_offline\_tombstones" {  
        return nil  
    }

    tombstone := core.NewRecord(app.FindCollectionByNameOrId("\_offline\_tombstones"))  
    tombstone.Set("collection", e.Collection.Name)  
    tombstone.Set("record\_id", e.Record.Id)  
    tombstone.Set("\_hlc", NewHLC()) // Generate current HLC

    // Persist tombstone in the same transaction context if possible,   
    // or as a separate save.  
    return app.Save(tombstone)  
})

This ensures that every deletion leaves a trace. During the Pull phase of synchronization, the generic client explicitly requests records from \_offline\_tombstones created after last\_synced\_hlc. It iterates through these tombstones and performs corresponding DELETE operations on its local SQLite database.19

### **5.4 The Reaper: Garbage Collection**

Tombstones cannot accumulate indefinitely. The Go plugin must register a cron job (app.OnCron) to "reap" old tombstones.

* **Schedule:** Daily.  
* **Policy:** Delete tombstones older than SYNC\_retention\_period (default: 30 days).

**Implication:** If a device remains offline for longer than the retention period (e.g., 31 days), it will miss the tombstone. Upon reconnection, it might re-upload the deleted record (Resurrection). To mitigate this, the client package checks the age of its last\_synced\_hlc. If it exceeds the retention period, the client declares "Bankruptcy": it wipes its local database and performs a fresh full sync from the server.21

## **6\. Conflict Resolution and Differential Synchronization**

### **6.1 Last-Write-Wins (LWW) via HLC**

For scalar data types (booleans, numbers, dates), the LWW strategy is the industry standard for generic synchronization. However, "Last" is defined by the HLC, not the wall clock.

When the generic server plugin processes a batch update:

1. It fetches the current record from the DB.  
2. It compares incoming\_batch\_record.\_hlc vs db\_record.\_hlc.  
3. **If Incoming \> DB:** The update is applied.  
4. **If Incoming \< DB:** The update is discarded (the client is trying to overwrite newer data with older data). The server returns a success response (idempotency) but does not apply the change. The client will eventually receive the newer server state in the next Pull phase.

### **6.2 Differential Synchronization: Myers Diff**

For text and editor (HTML) fields, LWW is destructive. If User A corrects a typo in paragraph 1, and User B adds a sentence to paragraph 2, LWW will blindly overwrite one user's contribution. To solve this, the Generic Architecture implements Differential Synchronization using the Myers Diff Algorithm.

This feature requires the Flutter package to use the diff\_match\_patch library (Dart) and the Go plugin to use the corresponding Go port.23

#### **6.2.1 The Diff Protocol**

1. **Snapshotting:** The client stores a "Shadow Copy" of the text field as it was at the time of the last sync.  
2. **Diff Generation:** When the client modifies the text, it computes the delta (patches) between the Shadow Copy and the Current Text using diff\_match\_patch.patch\_make().  
3. **Transmission:** The client sends the patches (serialized as string) instead of the full text, along with the \_hlc of the Shadow Copy (the Base Version).  
4. **Server Application:**  
   * The Go plugin detects that a patch payload is being sent.  
   * It retrieves the current text from the database.  
   * It applies the patch using diff\_match\_patch.patch\_apply().  
   * **Fuzzy Patching:** The Myers algorithm allows "fuzzy" application. Even if the server text has changed slightly (someone else edited a different paragraph), the algorithm attempts to locate the context for the patch and apply it non-destructively.25  
5. **Rejection:** If the text has diverged so significantly that the patch cannot be applied (fuzziness threshold exceeded), the server rejects the specific field update, forcing the client to pull the latest version and manually resolve.

This strategy allows high-concurrency collaboration on text fields without the complexity of Operational Transformation (OT) or CRDTs, which would require specialized data structures incompatible with PocketBase's standard SQLite columns.

## **7\. Server-Side Implementation Detail (Go Plugin)**

### **7.1 Plugin Initialization and Routes**

The generic plugin is designed to be imported into main.go. It encapsulates all logic to avoid polluting the main application scope.

Go

package offline\_sync

import (  
    "github.com/pocketbase/pocketbase/core"  
    "github.com/pocketbase/pocketbase/tools/cron"  
)

type SyncPlugin struct {  
    app core.App  
}

func New(app core.App) \*SyncPlugin {  
    return \&SyncPlugin{app: app}  
}

func (p \*SyncPlugin) Register() {  
    p.registerHooks()  
    p.registerRoutes()  
    p.registerCron()  
}

func (p \*SyncPlugin) registerRoutes() {  
    // Generic Pull Endpoint  
    p.app.OnServe().BindFunc(func(e \*core.ServeEvent) error {  
        e.Router.GET("/api/sync/pull", p.handlePull)  
        return e.Next()  
    })  
}

### **7.2 Dynamic Schema Handling**

The handlePull function demonstrates the "generic" capability. It does not use hardcoded struct definitions. Instead, it uses PocketBase's dynamic models.Record and dao methods.

Go

func (p \*SyncPlugin) handlePull(c \*core.RequestEvent) error {  
    since := c.Request.URL.Query().Get("since")  
    // 1\. Get all collections  
    collections, \_ := p.app.Dao().FindCollections()  
      
    response := make(map\[string\]map\[string\]any)

    for \_, col := range collections {  
        // 2\. Query dynamically  
        records, \_ := p.app.Dao().FindRecordsByExpr(col.Name,   
            dbx.NewExp("\_hlc \> {:since}", dbx.Params{"since": since}))  
          
        // 3\. Filter by ACL (Security)  
        visibleRecords :=map\[string\]any{}  
        for \_, rec := range records {  
            if p.app.CanAccessRecord(rec, c.RequestInfo(), rule.ViewRule) {  
                visibleRecords \= append(visibleRecords, rec.PublicExport())  
            }  
        }  
        response\[col.Name\] \= visibleRecords  
    }  
    return c.JSON(200, response)  
}

*Note: This code snippet simplifies error handling for brevity. Real implementation must handle errors robustly.*

This implementation ensures that if a user adds a Projects collection to their PocketBase instance, the sync engine immediately supports it without code changes.

### **7.3 Batch Transaction Processing**

The most critical server-side component is the transaction wrapper. When OnBatchRequest is triggered (or a custom batch endpoint is used), the plugin must ensure atomicity.

Go

func (p \*SyncPlugin) handleBatchPush(c \*core.RequestEvent) error {  
    // Parse batch payload...  
      
    return p.app.Dao().RunInTransaction(func(txDao \*dao.Dao) error {  
        for \_, op := range operations {  
            // Validate HLC ordering  
            existing, err := txDao.FindRecordById(op.Collection, op.Id)  
            if err \== nil {  
                if op.HLC \< existing.GetString("\_hlc") {  
                    continue // Ignore stale update (LWW)  
                }  
            }  
              
            // Apply diffs or updates  
            record := models.NewRecord(op.Collection)  
            record.Load(op.Data)  
            if err := txDao.SaveRecord(record); err\!= nil {  
                return err // Rollback entire batch  
            }  
        }  
        return nil  
    })  
}

This ensures that the client's view of the data remains consistent. Either all offline changes are accepted, or none are (triggering a retry), preventing partial sync states.27

## **8\. Client-Side Implementation Detail (Flutter Package)**

### **8.1 The Generic Repository**

The Flutter package (pocketbase\_offline) exposes a PocketBaseOffline client that wraps the standard SDK.

Dart

class PocketBaseOffline {  
  final PocketBase client;  
  final Database localDb; // Drift database

  Future\<void\> init() async {  
    // 1\. Fetch remote schema  
    final collections \= await client.collections.getFullList();  
    // 2\. Migrate local SQLite to match remote schema dynamically  
    await \_schemaManager.migrate(localDb, collections);  
  }

  // Generic Save  
  Future\<RecordModel\> save(String collectionName, Map\<String, dynamic\> body) async {  
    // 1\. Assign HLC  
    body\['\_hlc'\] \= \_hlcManager.now().toString();  
      
    // 2\. Save to Local DB (Optimistic)  
    await localDb.table(collectionName).insertOnConflictUpdate(body);  
      
    // 3\. Queue for Sync  
    await \_syncQueue.add(Mutation(collection: collectionName, body: body));  
      
    // 4\. Trigger Background Sync  
    \_syncService.trigger();  
      
    return RecordModel(data: body);  
  }  
}

### **8.2 Background Sync with Isolates**

Flutter runs on a single thread (Main Isolate). Heavy JSON parsing and diffing during sync can cause UI jank. The generic package must perform the synchronization logic in a separate Isolate or utilize compute.

The package should leverage workmanager for Android/iOS background execution, allowing sync to happen even if the app is closed. This background worker initializes its own generic PocketBase client, connects to the local SQLite (which must be concurrency-safe, e.g., using WAL mode in SQLite via drift), and performs the Push/Pull cycle.1

### **8.3 Handling Large Binaries**

Synchronization of large files (images/videos) via the batch JSON payload is inefficient and prone to timeouts. The generic architecture uses a **Reference-Based Sync**.

1. **Upload:** Binary files are uploaded immediately to the file storage endpoint (or queued in a separate UploadQueue if offline).  
2. **Reference:** The file upload returns a filename (string).  
3. **Sync:** The JSON record containing the filename string is synced via the standard protocol.  
4. **Retrieval:** The generic client intercepts record.getList calls. For fields of type file, it checks a local cache (flutter\_cache\_manager). If missing, it downloads the file from the server using the filename reference.

## **9\. Insights and Future Implications**

### **9.1 Second-Order Insight: The Soft Delete Ripple Effect**

Implementing a global tombstone collection (\_offline\_tombstones) introduces complexity regarding **Cascading Deletes**. In standard PocketBase, deleting a User may cascade to delete their Posts.

* *Observation:* If the Go plugin captures the User deletion via hook, the Posts might be deleted by the database engine's internal foreign key triggers. These internal SQL deletes often **do not fire** application-level hooks.  
* *Implication:* The generic plugin would generate a tombstone for the User, but *not* for the Posts. The offline client would delete the User but keep the orphaned Posts.  
* *Solution:* The generic Go plugin must enforce "Application-Level Cascades." It should disable DB-level ON DELETE CASCADE and instead recursively find and delete child records using the API/DAO. This ensures OnRecordAfterDelete fires for every single deleted record, generating the necessary tombstones for the client to maintain referential integrity.

### **9.2 Third-Order Insight: Schema Evolution and Client Versioning**

The "Generic" requirement creates a vulnerability regarding schema changes. If a developer renames a field status to state on the server, offline clients will still have mutations targeting status in their queue.

* *Observation:* When the client pushes, the server will reject the unknown field status (or ignore it, leading to data loss).  
* *Implication:* The protocol requires versioning. The server plugin should hash the current schema configuration.  
* *Solution:* The sync handshake must exchange this SchemaHash. If they mismatch, the client package must trigger a MigrationStrategy. Since the package is generic, it cannot know how to migrate specific data. It should expose a callback onMigrationNeeded(localData) to the Flutter developer, allowing them to map status \-\> state before the generic sync queue processes the pending mutations.

### **9.3 Performance at Scale**

While Go and SQLite are performant, the OnServe hook interception adds overhead. The system's bottleneck is the SQLite write lock.

* *Recommendation:* The generic plugin should aggressively use WAL mode (PRAGMA journal\_mode=WAL).27  
* *Optimization:* The "Pull" endpoint logic involves iterating all collections. As the number of collections grows, this becomes slow. The plugin should maintain a \_sync\_metadata table that indexes the \_hlc of all records across all collections, effectively creating a unified oplog. This trades write performance (updating the index on every save) for significantly faster read performance during sync (querying one table instead of N tables).

## **Conclusion**

This report defines a comprehensive, generic architecture for enabling offline-first capabilities in PocketBase. By decoupling the synchronization logic into a Go server plugin (handling HLCs, Tombstones, and Batching) and a Flutter client package (handling Local Replica, Queues, and Optimistic UI), developers can retrofit any PocketBase instance with robust offline support. The architecture prioritizes data integrity through the use of Hybrid Logical Clocks and Myers Diff, ensuring that even in the most hostile network environments, the system converges to a consistent, correct state without manual intervention in the database schema. This transforms PocketBase from a realtime-only backend into a versatile engine capable of powering mission-critical field applications.

#### **Works cited**

1. Offline-first support \- Flutter documentation, accessed December 22, 2025, [https://docs.flutter.dev/app-architecture/design-patterns/offline-first](https://docs.flutter.dev/app-architecture/design-patterns/offline-first)  
2. Implementing Efficient Data Synchronization for Offline-First Mobile Applications, accessed December 22, 2025, [https://dev.to/dowerdev/implementing-efficient-data-synchronization-for-offline-first-mobile-applications-525c](https://dev.to/dowerdev/implementing-efficient-data-synchronization-for-offline-first-mobile-applications-525c)  
3. pocketbase\_drift \- Dart API docs \- Pub.dev, accessed December 22, 2025, [https://pub.dev/documentation/pocketbase\_drift/latest/](https://pub.dev/documentation/pocketbase_drift/latest/)  
4. pocketbase library \- Dart API \- Pub.dev, accessed December 22, 2025, [https://pub.dev/documentation/pocketbase/latest/pocketbase](https://pub.dev/documentation/pocketbase/latest/pocketbase)  
5. PocketBase Dart SDK \- GitHub, accessed December 22, 2025, [https://github.com/pocketbase/dart-sdk](https://github.com/pocketbase/dart-sdk)  
6. Extend with Go \- Routing \- Docs \- PocketBase, accessed December 22, 2025, [https://pocketbase.io/docs/go-routing/](https://pocketbase.io/docs/go-routing/)  
7. Extend with Go \- Record operations \- Docs \- PocketBase, accessed December 22, 2025, [https://pocketbase.io/docs/go-records/](https://pocketbase.io/docs/go-records/)  
8. Hybrid logical clock \- Andy Matuschak's notes, accessed December 22, 2025, [https://notes.andymatuschak.org/Hybrid\_logical\_clock](https://notes.andymatuschak.org/Hybrid_logical_clock)  
9. Hybrid Logical Clock implementation in TypeScript \- typeonce.dev, accessed December 22, 2025, [https://www.typeonce.dev/snippet/hybrid-logical-clock-implementation-typescript](https://www.typeonce.dev/snippet/hybrid-logical-clock-implementation-typescript)  
10. @dldc/hybrid-logical-clock \- JSR, accessed December 22, 2025, [https://jsr.io/@dldc/hybrid-logical-clock](https://jsr.io/@dldc/hybrid-logical-clock)  
11. Will there be an option for a custom ID? \#2518 \- GitHub, accessed December 22, 2025, [https://github.com/pocketbase/pocketbase/discussions/2518](https://github.com/pocketbase/pocketbase/discussions/2518)  
12. Feature request: Customizable id field · Issue \#2727 \- GitHub, accessed December 22, 2025, [https://github.com/pocketbase/pocketbase/issues/2727](https://github.com/pocketbase/pocketbase/issues/2727)  
13. Introduction \- How to use PocketBase \- Docs, accessed December 22, 2025, [https://pocketbase.io/docs/how-to-use/](https://pocketbase.io/docs/how-to-use/)  
14. Custom own Record ID from client side \#3173 \- GitHub, accessed December 22, 2025, [https://github.com/pocketbase/pocketbase/discussions/3173](https://github.com/pocketbase/pocketbase/discussions/3173)  
15. Id generation in migrations · pocketbase pocketbase · Discussion \#3912 \- GitHub, accessed December 22, 2025, [https://github.com/pocketbase/pocketbase/discussions/3912](https://github.com/pocketbase/pocketbase/discussions/3912)  
16. Creating records with relationships in a single PocketBase operation? \- Reddit, accessed December 22, 2025, [https://www.reddit.com/r/pocketbase/comments/1gywun9/creating\_records\_with\_relationships\_in\_a\_single/](https://www.reddit.com/r/pocketbase/comments/1gywun9/creating_records_with_relationships_in_a_single/)  
17. Atomically insert records inside transactions (extend with go)? \#7322 \- GitHub, accessed December 22, 2025, [https://github.com/pocketbase/pocketbase/discussions/7322](https://github.com/pocketbase/pocketbase/discussions/7322)  
18. Creating a related row inside a transaction in a JS hook \#6292 \- GitHub, accessed December 22, 2025, [https://github.com/pocketbase/pocketbase/discussions/6292](https://github.com/pocketbase/pocketbase/discussions/6292)  
19. Extend with Go \- Event hooks \- Docs \- PocketBase, accessed December 22, 2025, [https://pocketbase.io/docs/go-event-hooks/](https://pocketbase.io/docs/go-event-hooks/)  
20. An alternative approach to soft deletion using hooks \#2694 \- GitHub, accessed December 22, 2025, [https://github.com/pocketbase/pocketbase/discussions/2694](https://github.com/pocketbase/pocketbase/discussions/2694)  
21. Removing Documents \- Ditto, accessed December 22, 2025, [https://docs.ditto.live/sdk/v5/crud/delete](https://docs.ditto.live/sdk/v5/crud/delete)  
22. Kafka not deleting key with tombstone \- Stack Overflow, accessed December 22, 2025, [https://stackoverflow.com/questions/46632713/kafka-not-deleting-key-with-tombstone](https://stackoverflow.com/questions/46632713/kafka-not-deleting-key-with-tombstone)  
23. Diff Match Patch \- Dart API docs \- Pub.dev, accessed December 22, 2025, [https://pub.dev/documentation/diff\_match\_patch/latest/](https://pub.dev/documentation/diff_match_patch/latest/)  
24. sergi/go-diff: Diff, match and patch text in Go \- GitHub, accessed December 22, 2025, [https://github.com/sergi/go-diff](https://github.com/sergi/go-diff)  
25. Myers diff — MoonBit v0.6.33 documentation, accessed December 22, 2025, [https://docs.moonbitlang.com/en/latest/example/myers-diff/myers-diff.html](https://docs.moonbitlang.com/en/latest/example/myers-diff/myers-diff.html)  
26. Myers diff in linear space: theory \- The If Works \- James Coglan, accessed December 22, 2025, [https://blog.jcoglan.com/2017/03/22/myers-diff-in-linear-space-theory/](https://blog.jcoglan.com/2017/03/22/myers-diff-in-linear-space-theory/)  
27. Extend with Go \- Overview \- Docs \- PocketBase, accessed December 22, 2025, [https://pocketbase.io/docs/go-overview/](https://pocketbase.io/docs/go-overview/)  
28. Offline-First Mobile App Architecture: Syncing, Caching, and Conflict Resolution, accessed December 22, 2025, [https://dev.to/odunayo\_dada/offline-first-mobile-app-architecture-syncing-caching-and-conflict-resolution-518n](https://dev.to/odunayo_dada/offline-first-mobile-app-architecture-syncing-caching-and-conflict-resolution-518n)