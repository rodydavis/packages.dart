# **Architecting a Resilient Offline-First Synchronization Engine for PocketBase and Dart**

## **1\. The Paradigm Shift: From Connected CRUD to Distributed Consistency**

The contemporary landscape of mobile and distributed application development has outgrown the traditional "Online-Only" CRUD (Create, Read, Update, Delete) model. In the conventional architecture, the server is the single source of truth, and the client is merely a transient viewer—a "dumb" terminal that renders state fetched over a reliable network connection. However, this assumption of reliability is fundamentally flawed in mobile environments where latency fluctuates, connections drop, and users expect seamless interactivity regardless of signal strength. To meet these demands, we must transition to an **Offline-First** architecture. In this paradigm, the client device becomes a primary replica of the dataset, capable of performing reads and writes against a local database, while a background synchronization engine ensures eventual consistency with the central server.

This report articulates the comprehensive design and implementation of a custom synchronization engine tailored for a specific, high-performance stack: a **Dart (Flutter)** client leveraging the **Drift** persistence library, and a **PocketBase** backend extended via **Go**. The architectural mandate includes rigorous requirements: the use of the **Myers Diff Algorithm** for granular text synchronization, the implementation of **Hybrid Logical Clocks (HLC)** to resolve causal ordering in the absence of reliable physical time, and the adoption of **UUIDv7** to mitigate identifier collisions in distributed generation.

### **1.1 The CAP Theorem and Local Autonomy**

In the context of the CAP Theorem (Consistency, Availability, Partition Tolerance), an offline-first mobile application effectively operates as a distributed system that prioritizes Availability and Partition Tolerance (AP) during disconnection, striving for Strong Eventual Consistency (SEC) upon reconnection. The synchronization engine is the mechanism that bridges the gap between the divergent local state (the "partitioned" node) and the server state.

Unlike simple caching strategies where local data is ephemeral, an offline-first architecture treats the local database (SQLite via Drift) as a persistent, authoritative store for the user's actions. This inversion of control introduces significant complexity. We are no longer simply sending HTTP POST requests; we are managing a distributed ledger of mutations that must be reconciled. This requires us to solve three fundamental problems:

1. **Identity:** How do we generate unique identifiers on the client without coordinating with the server?  
2. **Causality:** How do we order events when device clocks are unreliable, drifting, or maliciously altered?  
3. **Conflict Resolution:** How do we merge concurrent edits to the same data point without losing user intent?

The following sections dissect these challenges and propose a unified, robust solution.

## ---

**2\. The Crisis of Identity: Distributed ID Generation**

One of the most immediate challenges in decoupling the client from the server is the generation of primary keys. In a centralized system, the database (e.g., PostgreSQL sequences or auto-incrementing integers) issues IDs. In a distributed system, the client must generate the ID *before* the record is sent to the server to maintain local referential integrity and allow for immediate UI updates.

### **2.1 The Insufficiency of PocketBase Default IDs**

PocketBase, by default, utilizes a 15-character random alphanumeric string for record IDs. The alphabet typically consists of lowercase letters and numbers (a-z0-9), yielding a character set size of 36\. The total entropy space is $36^{15}$. While this provides a massive number of combinations, it poses two distinct problems in our specific architectural context:

1. **The Birthday Paradox in Distributed Environments:** The "Birthday Problem" dictates that the probability of a collision increases much faster than the number of records. While $36^{15}$ is large, the risk is non-zero, especially when relying on the pseudo-random number generators (PRNG) of diverse client devices (Android, iOS, Web), which may have varying degrees of entropy quality compared to a server-side crypto/rand. In a system designed for "Offline-First" robustness, a single ID collision during synchronization is catastrophic—it results in a merge conflict where two distinct entities are treated as the same, potentially overwriting data.  
2. **Database Page Fragmentation (The Hidden Performance Killer):** PocketBase runs on **SQLite**. SQLite tables (specifically ROWID tables or those with textual primary keys) are stored as B-Trees. When records are inserted with purely random IDs, they are distributed arbitrarily across the B-Tree leaf nodes. This random insertion pattern forces the database engine to frequently split pages and rebalance the tree, leading to high disk I/O overhead and significant fragmentation of the database file. In a high-throughput sync scenario (e.g., a client pushing 1,000 offline changes), random I/O can become a bottleneck.1

### **2.2 The Solution: UUIDv7**

To address both the collision risk and the database performance constraints, we mandate the adoption of **UUIDv7** (Universally Unique Identifier Version 7), enabling a move away from purely random identifiers to **k-sortable** identifiers.

#### **2.2.1 Mechanism and Entropy**

UUIDv7 is a 128-bit identifier designed specifically for database locality. Its structure is composed of:

* **Unix Timestamp (48 bits):** Encodes the millisecond precision timestamp.  
* **Version & Variant (6 bits):** Metadata identifying the format.  
* **Random Data (74 bits):** Entropy to ensure uniqueness within the same millisecond.3

This structure offers a guarantee that IDs generated at different milliseconds are strictly ordered. For IDs generated within the same millisecond, the 74 bits of entropy provide a collision resistance that far exceeds the user's current 15-character alphanumeric solution.

#### **2.2.2 Impact on SQLite Performance**

The most profound advantage of UUIDv7 in this architecture is its impact on the SQLite B-Tree. Because UUIDv7 is monotonic (values increase over time), new records are almost always appended to the right side of the B-Tree. This "sequential insertion" pattern drastically reduces the need for page splitting and tree rebalancing. It optimizes the Write-Ahead Log (WAL) performance and ensures that the database remains compact and performant even as the dataset grows into millions of rows. For a synchronization engine processing batches of inserts, this can result in a write throughput increase of orders of magnitude compared to random IDs.1

### **2.3 Implementation Strategy**

#### **2.3.1 Client-Side (Dart)**

The Dart client must take responsibility for generating these IDs. We utilize the uuid package, which supports the proposed RFC 9562 standard for UUIDv7.6

Dart

import 'package:uuid/uuid.dart';

class IdGenerator {  
  static const Uuid \_uuid \= Uuid();

  /// Generates a time-ordered, collision-resistant UUIDv7.  
  static String next() {  
    return \_uuid.v7();  
  }  
}

This ID is assigned to the record immediately upon creation in the local Drift database. This allows the client to build relations (foreign keys) between new offline records (e.g., creating a Post and a Comment offline) without waiting for the server to assign IDs.

#### **2.3.2 Server-Side (Go/PocketBase)**

The server must accept these client-generated IDs but also enforce validation to prevent malformed data from corrupting the index. We extend PocketBase using its Go framework hooks, specifically OnRecordBeforeCreateRequest.7

We intercept the create request. If the client provides an ID, we validate it against the UUIDv7 regex. If the ID is missing (which shouldn't happen in our protocol, but might in direct API usage), we generate one.

Go

package main

import (  
    "log"  
    "regexp"

    "github.com/pocketbase/pocketbase"  
    "github.com/pocketbase/pocketbase/core"  
    "github.com/gofrs/uuid/v5" // Using a Go UUID library  
)

func main() {  
    app := pocketbase.New()

    // Regex for UUID validation (simplified)  
    uuidRegex := regexp.MustCompile(\`^\[0-9a-fA-F\]{8}-\[0-9a-fA-F\]{4}-7\[0-9a-fA-F\]{3}-\[0-9a-fA-F\]{3}-\[0-9a-fA-F\]{12}$\`)

    app.OnRecordBeforeCreateRequest("todos", "notes").BindFunc(func(e \*core.RecordRequestEvent) error {  
        // 1\. Validation: Ensure ID is a valid UUIDv7 if provided  
        if e.Record.Id\!= "" {  
            if\!uuidRegex.MatchString(e.Record.Id) {  
                // Reject invalid formats to protect DB locality  
                return e.BadRequestError("Invalid ID format. Must be UUIDv7.", nil)  
            }  
        } else {  
            // 2\. Fallback: Generate UUIDv7 if missing  
            id, err := uuid.NewV7()  
            if err\!= nil {  
                return err  
            }  
            e.Record.SetId(id.String())  
        }  
        return e.Next()  
    })

    if err := app.Start(); err\!= nil {  
        log.Fatal(err)  
    }  
}

This implementation explicitly overrides PocketBase's default ID generator, solving the user's duplication issue and aligning the storage engine for high-performance synchronization.8

## ---

**3\. Temporal Truth: The Hybrid Logical Clock (HLC)**

In distributed systems, physical time (wall-clock time) is a treacherous metric. Devices drift, batteries die, and users manually change clocks to "cheat" in games or bypass software trials. If a synchronization engine relies solely on updated\_at timestamps derived from the system clock, it falls prey to anomalies: a change made "tomorrow" (due to a bad clock) could become immutable, locking out all legitimate subsequent edits.

To maintain causality—the property that if event A causes event B, A is ordered before B—we require **Logical Clocks**. However, pure logical clocks (like Lamport counters) lose the relationship to physical time, making it hard to query "changes since 5 minutes ago." The **Hybrid Logical Clock (HLC)** is the synthesis of these two concepts, providing the best of both worlds: causal strictness and physical proximity.9

### **3.1 The HLC Algorithm**

The HLC is a tuple (l, c, node), where:

* l (logical time): The maximum physical time the node has seen (either from its own clock or incoming messages).  
* c (counter): A strictly increasing counter used to order events that occur within the same millisecond or when the physical clock regresses.  
* node: A unique tie-breaker (e.g., a hash of the device ID).

The core rules for the HLC are:

1. **Monotonicity:** The clock never moves backward. If the physical clock rewinds, the HLC continues forward using the logical component.  
2. **Causality:** When a message is received with timestamp T\_remote, the local clock updates to max(T\_local, T\_remote, T\_physical). This ensures the local event appears to happen *after* the remote event that triggered it.  
3. **Bounded Drift:** The logical time l tracks closely with the physical time pt. It does not grow unboundedly into the future unless the physical clock itself is wrong or the message frequency exceeds the counter capacity (which is rare).12

### **3.2 HLC Serialization for SQLite**

PocketBase and SQLite do not have a native "HLC" data type. To perform efficient synchronization queries (e.g., "Give me all records changed since HLC\_X"), we must store the HLC in a format that preserves its sort order when compared as a primitive type.

We will serialize the HLC as a **lexically sortable string**. This allows us to use standard SQL comparison operators (\>, \<) and leverage B-Tree indexes for range scans.14

**Format:** \<Physical\>-\<Logical\>-\<NodeID\>

* **Physical:** 48-bit integer (milliseconds), formatted as a 12-char hexadecimal string (zero-padded).  
* **Logical:** 16-bit integer (counter), formatted as a 4-char hexadecimal string.  
* **NodeID:** Fixed-length hexadecimal string (e.g., 10 chars).

**Example:**

* Timestamp: 1678886400000 $\\rightarrow$ 0186E5B64800  
* Counter: 42 $\\rightarrow$ 002A  
* Node: ClientA  
* **Serialized:** 0186E5B64800-002A-ClientA

This string format guarantees that HLC\_A \> HLC\_B in a SQL query corresponds exactly to the causal ordering of the clocks.

### **3.3 Implementation in Dart and Go**

Dart Implementation:  
We implement a singleton HlcProvider that maintains the local clock state. Every time a local write occurs (Create/Update/Delete), the provider increments the clock. Every time a sync payload is received from the server, the provider merges the remote HLC into the local state.

Dart

class Hlc implements Comparable\<Hlc\> {  
  final int millis;  
  final int counter;  
  final String nodeId;

  Hlc(this.millis, this.counter, this.nodeId);

  // Lexical serialization for SQLite  
  @override  
  String toString() \=\>   
      '${millis.toRadixString(16).padLeft(12, "0")}\-'  
      '${counter.toRadixString(16).padLeft(4, "0")}\-'  
      '$nodeId';

  // The 'Receive' Logic (Merge)  
  static Hlc receive(Hlc local, Hlc remote) {  
    final now \= DateTime.now().millisecondsSinceEpoch;  
      
    // The new time is the max of physical, local logical, and remote logical  
    final newMillis \= \[local.millis, remote.millis, now\].reduce(max);  
      
    int newCounter;  
    if (newMillis \== local.millis && newMillis \== remote.millis) {  
      newCounter \= max(local.counter, remote.counter) \+ 1;  
    } else if (newMillis \== local.millis) {  
      newCounter \= local.counter \+ 1;  
    } else if (newMillis \== remote.millis) {  
      newCounter \= remote.counter \+ 1;  
    } else {  
      newCounter \= 0;  
    }  
      
    return Hlc(newMillis, newCounter, local.nodeId);  
  }  
}

Ref: 9

Server Storage:  
In PocketBase, we define a custom field hlc (type: Text) for every synced collection. Crucially, we add a database index on this field.  
CREATE INDEX idx\_collection\_hlc ON collection(hlc);  
This index is the cornerstone of the sync performance, allowing the server to calculate the "delta" of changes for a client in $O(\\log N)$ time rather than scanning the entire table.17

## ---

**4\. Algorithmic Resolution: Myers Diff and Differential Sync**

The requirement to use the **Myers Diff Algorithm** indicates a need for high-fidelity text synchronization. Standard "Last Write Wins" (LWW) is acceptable for scalar values (like a "Status" dropdown), but it is destructive for text. If User A fixes a typo in the first paragraph and User B adds a sentence to the second paragraph while offline, LWW would discard one of these changes. Myers Diff allows us to merge them.

### **4.1 The Theoretical Basis: 3-Way Merge**

To correctly merge concurrent edits, we cannot simply compare the Client's version and the Server's version. We need a reference point: the **Base** version (also known as the Common Ancestor). This creates a 3-way merge scenario 19:

1. **Base:** The state of the record when the client *last* synced.  
2. **Theirs (Server):** The current state on the server (potentially modified by other clients).  
3. **Yours (Client):** The current state on the client (with offline edits).

The Myers algorithm operates by finding the Shortest Edit Script (SES) that transforms Base into Yours. This script is a sequence of insertions and deletions.

### **4.2 The Differential Synchronization Protocol**

We adopt a protocol similar to the one used by Google Docs (specifically the Google Diff-Match-Patch library implementation).21

1. **Client Diff:** The client calculates Diff(Base, Yours). This generates a patch.  
2. **Transmission:** The client sends this patch to the server.  
3. **Server Patch:** The server attempts to apply this patch to Theirs.  
   * NewServerState \= PatchApply(Patch, Theirs)  
   * The PatchApply function is robust; it uses the context (surrounding text) to locate the correct insertion point even if the text has shifted due to other edits. This is "Fuzzy Patching."  
4. **Confirmation:** If successful, the server saves NewServerState and updates the HLC.

### **4.3 Why Myers?**

The Myers algorithm is an $O(ND)$ greedy algorithm that optimizes for the "longest common subsequence".24 Its strength lies in its human-centric output. It tends to group changes into logical blocks (e.g., deleting a whole word) rather than fracturing them into atomized character edits, which makes the resulting patches more likely to apply cleanly against a modified target. Furthermore, diff-match-patch includes a semantic cleanup phase that realigns diffs to boundaries (like newlines or words), preventing the "wrong end" problem where identical characters are mismatched.26

## ---

**5\. Client-Side Implementation: The Drift Architecture**

The client side is responsible for persistence, queueing, and UI reactivity. **Drift** is the chosen ORM for Flutter because of its compile-time safety and deep SQLite integration.27

### **5.1 The Shadow Table Pattern**

To support the 3-way merge required by Myers diff, the client must store *two* copies of every record:

1. **The Application Table (todos):** This is the live data the user sees and edits.  
2. **The Shadow Table (todos\_shadow):** This serves as the "Base" for the diff. It represents the exact state of the record as it was last confirmed by the server.

**Schema Design (Drift):**

Dart

// The main table visible to the UI  
class Todos extends Table {  
  TextColumn get id \=\> text().withLength(min: 36, max: 36)(); // UUIDv7  
  TextColumn get content \=\> text()();  
  TextColumn get hlc \=\> text()(); // The HLC of the last write  
  BoolColumn get deleted \=\> boolean().withDefault(const Constant(false))();  
    
  @override  
  Set\<Column\> get primaryKey \=\> {id};  
}

// The Shadow Table  
class TodosShadow extends Table {  
  TextColumn get id \=\> text().withLength(min: 36, max: 36)();  
  TextColumn get content \=\> text()(); // The "Base" text  
  TextColumn get hlc \=\> text()(); // The server HLC at last sync  
    
  @override  
  Set\<Column\> get primaryKey \=\> {id};  
}

// The Sync Queue  
class SyncQueue extends Table {  
  IntColumn get id \=\> integer().autoIncrement()();  
  TextColumn get recordId \=\> text()();  
  TextColumn get collection \=\> text()();  
  TextColumn get operation \=\> text()(); // INSERT, UPDATE, DELETE  
  TextColumn get payload \=\> text()(); // JSON: { "patches": "...", "hlc": "..." }  
  IntColumn get status \=\> integer()(); // 0: Pending, 1: In-Flight  
}

### **5.2 The Write Lifecycle**

1. **User Edit:** The user types in a text field.  
2. **Local Persist:** The app writes the new text to Todos. The local HLC is incremented.  
3. **Queue Logic:**  
   * The sync engine (running in a background Isolate) detects the change.  
   * It fetches Todos.content (Yours) and TodosShadow.content (Base).  
   * It computes diff \= myers\_diff(Base, Yours).  
   * It writes a SyncQueue entry containing the patch and the *Base HLC*.  
   * *Optimization:* If a queue entry already exists for this record (user typed twice while offline), the engine squashes the updates by re-computing the diff against the immutable Shadow.

### **5.3 Offline Tolerance**

This architecture is inherently offline-tolerant. The SyncQueue simply accumulates patches. The UI remains responsive because it binds to the Todos table, which reflects local state immediately ("Optimistic UI").29 When the network restores, the engine processes the queue FIFO (First-In, First-Out) or batched, attempting to push changes to the server.

## ---

**6\. Server-Side Implementation: Extending PocketBase**

PocketBase's standard API is insufficient for this logic. The standard update endpoint performs a generic UPDATE SET..., which would overwrite concurrent changes. We must implement a custom sync endpoint using Go.

### **6.1 The Custom Sync Endpoint**

We register a route POST /api/sync that accepts a batch of operations. This entire batch processing must happen inside a database transaction to ensure atomicity—either all patches apply, or we rollback (in case of critical system failure, though typically we handle per-record errors gracefully).

**Route Registration:**

Go

app.OnServe().BindFunc(func(se \*core.ServeEvent) error {  
    se.Router.POST("/api/sync", func(e \*core.RequestEvent) error {  
        return handleSync(app, e)  
    })  
    return se.Next()  
})

Ref: 30

### **6.2 Transactional Logic and Conflict Resolution**

The handleSync function performs the heavy lifting.

**Algorithm:**

1. **Batch Start:** tx, \_ := app.Dao().DB().Begin()  
2. **Iterate Operations:** For each incoming patch:  
   * **Lock Record:** SELECT \* FROM todos WHERE id \=? (Use appropriate locking if using Postgres, but for SQLite, the single-writer WAL mode inherently serializes this 32).  
   * **HLC Check:** Compare Incoming.BaseHLC with ServerRecord.HLC.  
     * **Case A (Idempotent):** Incoming.HLC \<= ServerRecord.HLC. The client is sending an old update. We acknowledge success but do nothing.  
     * **Case B (Fast-Forward):** Incoming.BaseHLC \== ServerRecord.HLC. The server hasn't changed. We apply the patch directly.  
     * **Case C (Conflict):** Incoming.BaseHLC \< ServerRecord.HLC. The server has moved forward. We must use dmp.PatchApply.  
   * **Patch Application:**  
     * patches, \_ := dmp.PatchFromText(Incoming.PatchString)  
     * newText, results := dmp.PatchApply(patches, ServerRecord.Content)  
     * **Check Results:** If results contains failures (the fuzzy match failed because the context was too different), we have a "Hard Conflict".  
   * **Resolution:**  
     * *Soft Conflict (Patch Succeeded):* Save newText. Update ServerRecord.HLC to New(Max(Local, Remote)).  
     * *Hard Conflict (Patch Failed):* We cannot merge. The standard strategy here is "Server Wins" or "Error". We return an error code to the client indicating "Rebase Required". The client must then pull the new server state, update its Shadow, and try to re-apply its local edits (or show a diff UI to the user).  
3. **Commit:** If all critical operations succeed, commit the transaction.

### **6.3 Performance Considerations: SQLite WAL**

PocketBase uses SQLite in **Write-Ahead Log (WAL)** mode. This allows multiple readers and one writer.

* **Implication:** The POST /sync transaction blocks other writes. It is crucial to keep the transaction logic CPU-efficient.  
* **Myers Diff Cost:** Calculating diffs is expensive ($O(ND)$). However, *applying* patches is relatively cheap ($O(N)$). By offloading the diff calculation to the client (distributed computing), the server only bears the cost of the application, maximizing throughput.5

## ---

**7\. The Sync Loop Protocol**

The synchronization engine operates in a continuous loop, managed by the client.

### **7.1 Push Phase (Client \-\> Server)**

1. Client selects PENDING items from SyncQueue.  
2. Bundles them into a JSON payload.  
3. Sends POST /api/sync.  
4. **Server Response:** Returns a list of { "id": "...", "server\_hlc": "..." } for successfully synced items.  
5. **Client Finalization:**  
   * For each success, the client updates TodosShadow to match the current Todos (establishing a new Base).  
   * Updates Todos.hlc to the returned server\_hlc.  
   * Deletes the SyncQueue entry.

### **7.2 Pull Phase (Server \-\> Client)**

1. Client tracks a local variable last\_pull\_hlc (persisted in SharedPreferences or a meta table).  
2. Client sends GET /api/sync?since=last\_pull\_hlc.  
3. **Server Query:** SELECT \* FROM todos WHERE hlc \>?. Thanks to the HLC index and lexical sortability, this is a highly efficient range query.17  
4. **Client Merge:**  
   * For each incoming record:  
   * Check if there is a pending local change in SyncQueue.  
   * **No Pending Change:** Simply update Todos and TodosShadow.  
   * **Pending Change Exists:** We have a conflict locally.  
     * Update TodosShadow to the *new* incoming server text.  
     * *Rebase:* Re-calculate the diff between the *new* Shadow and the current Todos. Update the SyncQueue entry. This effectively "floats" the user's local changes on top of the incoming server changes.

## ---

**8\. Conclusion**

The architecture defined in this report satisfies the rigorous requirements of a modern, offline-first application. By replacing standard PocketBase IDs with **UUIDv7**, we ensure distributed collision resistance and SQLite performance. By implementing **Hybrid Logical Clocks** serialized as sortable strings, we solve the problem of unreliable time and enable efficient delta queries. Finally, by integrating the **Myers Diff algorithm** into a **Shadow Table** synchronization pattern, we achieve a system that preserves user intent during concurrent text editing.

This system is not merely a theoretical construct; it is built upon the specific capabilities of **Drift**, **Go**, and **SQLite's WAL mode**, leveraging the strengths of each component to create a synchronization engine that is robust, scalable, and tolerant of the chaotic nature of mobile networks. The use of a custom Go extension for PocketBase is the linchpin, moving logic from the fragile client-side layer to a transactional, authoritative server environment.

### **Summary of Data Structures**

| Component | Format/Type | Purpose |
| :---- | :---- | :---- |
| **ID** | UUIDv7 (36-char string) | Collision-free, k-sortable, B-Tree friendly. |
| **Clock** | HLC (HexTime-HexCount-Node) | Causal ordering, physical proximity, range queries. |
| **Sync Payload** | JSON (Patches) | Bandwidth efficiency, merge capability. |
| **Client DB** | SQLite (Drift) | Shadow tables for 3-way merge base. |
| **Server DB** | SQLite (PocketBase) | Authoritative store, indexed HLC for fast pulls. |

#### **Works cited**

1. UUID vs CUID vs NanoID: Choosing the Right ID Generator for Your Application \- Wisp CMS, accessed December 22, 2025, [https://www.wisp.blog/blog/uuid-vs-cuid-vs-nanoid-choosing-the-right-id-generator-for-your-application](https://www.wisp.blog/blog/uuid-vs-cuid-vs-nanoid-choosing-the-right-id-generator-for-your-application)  
2. Best practices for SQLite performance | App quality \- Android Developers, accessed December 22, 2025, [https://developer.android.com/topic/performance/sqlite-performance-best-practices](https://developer.android.com/topic/performance/sqlite-performance-best-practices)  
3. Understanding UUID v4, UUID v7, Snowflake ID, and Nano ID, GUID, ULID, KSUID — In Simple Terms | by Dinesh Arney | Medium, accessed December 22, 2025, [https://medium.com/@dinesharney/understanding-uuid-v4-uuid-v7-snowflake-id-and-nano-id-in-simple-terms-c50acf185b00](https://medium.com/@dinesharney/understanding-uuid-v4-uuid-v7-snowflake-id-and-nano-id-in-simple-terms-c50acf185b00)  
4. uuidv7 \- NPM, accessed December 22, 2025, [https://www.npmjs.com/package/uuidv7](https://www.npmjs.com/package/uuidv7)  
5. SQLite Optimizations For Ultra High-Performance \- PowerSync, accessed December 22, 2025, [https://www.powersync.com/blog/sqlite-optimizations-for-ultra-high-performance](https://www.powersync.com/blog/sqlite-optimizations-for-ultra-high-performance)  
6. uuidv7 | Dart package \- Pub.dev, accessed December 22, 2025, [https://pub.dev/packages/uuidv7](https://pub.dev/packages/uuidv7)  
7. Extend with Go \- Event hooks \- Docs \- PocketBase, accessed December 22, 2025, [https://pocketbase.io/docs/go-event-hooks/](https://pocketbase.io/docs/go-event-hooks/)  
8. How to automatically generate UUIDv7 as record IDs \#7383 \- GitHub, accessed December 22, 2025, [https://github.com/pocketbase/pocketbase/discussions/7383](https://github.com/pocketbase/pocketbase/discussions/7383)  
9. Hybrid Logical Clock implementation in TypeScript \- typeonce.dev, accessed December 22, 2025, [https://www.typeonce.dev/snippet/hybrid-logical-clock-implementation-typescript](https://www.typeonce.dev/snippet/hybrid-logical-clock-implementation-typescript)  
10. Hybrid Logical Clocks | Kevin Sookocheff, accessed December 22, 2025, [https://sookocheff.com/post/time/hybrid-logical-clocks/](https://sookocheff.com/post/time/hybrid-logical-clocks/)  
11. Hybrid logical clock \- Andy Matuschak's notes, accessed December 22, 2025, [https://notes.andymatuschak.org/Hybrid\_logical\_clock](https://notes.andymatuschak.org/Hybrid_logical_clock)  
12. Hybrid Logical Clocks \- Murat Buffalo, accessed December 22, 2025, [http://muratbuffalo.blogspot.com/2014/07/hybrid-logical-clocks.html](http://muratbuffalo.blogspot.com/2014/07/hybrid-logical-clocks.html)  
13. Hybrid Logical Clocks \- Bartosz Sypytkowski, accessed December 22, 2025, [https://www.bartoszsypytkowski.com/hybrid-logical-clocks/](https://www.bartoszsypytkowski.com/hybrid-logical-clocks/)  
14. Database File Format \- SQLite, accessed December 22, 2025, [https://www.sqlite.org/fileformat.html](https://www.sqlite.org/fileformat.html)  
15. Try Case-Insensitive Unicode Sorting in SQLite with Pre-collated Strings \- Atomic Spin, accessed December 22, 2025, [https://spin.atomicobject.com/case-insensitive-unicode-sqlite/](https://spin.atomicobject.com/case-insensitive-unicode-sqlite/)  
16. hlc\_dart | Dart package \- Pub.dev, accessed December 22, 2025, [https://pub.dev/packages/hlc\_dart](https://pub.dev/packages/hlc_dart)  
17. SQLite BETWEEN Operator By Practical Examples, accessed December 22, 2025, [https://www.sqlitetutorial.net/sqlite-between/](https://www.sqlitetutorial.net/sqlite-between/)  
18. Feature suggestion: Support SQLite json\_extract function · Issue \#423 \- GitHub, accessed December 22, 2025, [https://github.com/pocketbase/pocketbase/issues/423](https://github.com/pocketbase/pocketbase/issues/423)  
19. Three-Way Merge \- Revision Control, accessed December 22, 2025, [https://tonyg.github.io/revctrl.org/ThreeWayMerge.html](https://tonyg.github.io/revctrl.org/ThreeWayMerge.html)  
20. Three-Way Merging Algorithm for Structured Data \- IEEE Xplore, accessed December 22, 2025, [https://ieeexplore.ieee.org/iel8/6287639/10820123/11045384.pdf](https://ieeexplore.ieee.org/iel8/6287639/10820123/11045384.pdf)  
21. Diff Match Patch \- Dart API docs \- Pub.dev, accessed December 22, 2025, [https://pub.dev/documentation/diff\_match\_patch/latest/](https://pub.dev/documentation/diff_match_patch/latest/)  
22. GerHobbelt/google-diff-match-patch: Diff, Match and Patch Library (original at http://google.com/p/google-diff-match-patch) \- GitHub, accessed December 22, 2025, [https://github.com/GerHobbelt/google-diff-match-patch](https://github.com/GerHobbelt/google-diff-match-patch)  
23. Differential Synchronization \- Google Research, accessed December 22, 2025, [https://research.google.com/pubs/archive/35605.pdf](https://research.google.com/pubs/archive/35605.pdf)  
24. Implementation of the Myers diff algorithm with O(ND) complexity, multiple output formats, and benchmarking suite. \- GitHub, accessed December 22, 2025, [https://github.com/NeaByteLab/Myers-Diff](https://github.com/NeaByteLab/Myers-Diff)  
25. The Myers diff algorithm: part 1 \- The If Works, accessed December 22, 2025, [https://blog.jcoglan.com/2017/02/12/the-myers-diff-algorithm-part-1/](https://blog.jcoglan.com/2017/02/12/the-myers-diff-algorithm-part-1/)  
26. Avoiding the Myers Diff Algorithm "Wrong-End" Problem \- Stack Overflow, accessed December 22, 2025, [https://stackoverflow.com/questions/79322411/avoiding-the-myers-diff-algorithm-wrong-end-problem](https://stackoverflow.com/questions/79322411/avoiding-the-myers-diff-algorithm-wrong-end-problem)  
27. pocketbase\_drift \- Dart API docs \- Pub.dev, accessed December 22, 2025, [https://pub.dev/documentation/pocketbase\_drift/latest/](https://pub.dev/documentation/pocketbase_drift/latest/)  
28. drift | Dart package \- Pub.dev, accessed December 22, 2025, [https://pub.dev/packages/drift](https://pub.dev/packages/drift)  
29. Offline-First Flutter: Implementation Blueprint for Real-World Apps \- GeekyAnts, accessed December 22, 2025, [https://geekyants.com/blog/offline-first-flutter-implementation-blueprint-for-real-world-apps](https://geekyants.com/blog/offline-first-flutter-implementation-blueprint-for-real-world-apps)  
30. Extend with Go \- Routing \- Docs \- PocketBase, accessed December 22, 2025, [https://pocketbase.io/docs/go-routing/](https://pocketbase.io/docs/go-routing/)  
31. Introduction \- Extending PocketBase \- Docs, accessed December 22, 2025, [https://pocketbase.io/docs/use-as-framework/](https://pocketbase.io/docs/use-as-framework/)  
32. Extend with Go \- Overview \- Docs \- PocketBase, accessed December 22, 2025, [https://pocketbase.io/docs/go-overview/](https://pocketbase.io/docs/go-overview/)