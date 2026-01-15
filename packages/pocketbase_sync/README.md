# PocketBase Sync

A robust, offline-first synchronization library for [PocketBase](https://pocketbase.io) and Flutter.

This package provides a `PocketBaseSyncManager` that handles the complexities of syncing local data with a PocketBase backend, including conflict resolution, bandwidth optimization, and remote deletion support.

## Features

*   **Offline-First**: Read and write data locally (e.g., using Drift or Hive) and sync when online.
*   **3-Way Merge Strategy**: Automatically resolves conflicts. Server changes win on collision, but non-conflicting local changes are preserved.
*   **Remote Deletion**: Detects records deleted on the server and removes them locally during sync.
*   **Bandwidth Optimized**:
    *   **Incremental Pull**: Only fetches records updated since the last sync.
    *   **Differential Push**: Uses `HybridDiffer` (Myers diff) to send only changed fields to the server.
*   **Tombstones**: Handles local deletions by marking records as deleted and removing them from the server during sync.
*   **Auto-Cleanup**: Automatically cleans up expired tombstones to keep the local database tidy.

## Installation

Add `pocketbase_sync` to your `pubspec.yaml`:

```yaml
dependencies:
  pocketbase_sync: ^0.0.1
  pocketbase: ^0.18.0
```

## Usage

### 1. Implement SyncRepository

You need to implement the `SyncRepository` interface to tell the manager how to store and retrieve data locally. This is typically done with a local database like Drift or Hive.

```dart
class MyRepository implements SyncRepository<MyModel> {
  // ... implement CRUD operations ...
  
  @override
  Future<List<SyncRecord<MyModel>>> getAll() async {
    // Return all records (including deleted/messy ones)
  }

  @override
  Future<DateTime> getLastSyncTime() async {
    // Return stored last sync timestamp
  }

  @override
  Future<void> setLastSyncTime(DateTime time) async {
    // Persist new sync timestamp
  }
}
```

### 2. Initialize the Manager

Create an instance of `PocketBaseSyncManager`, providing your PocketBase client, collection name, and repository.

```dart
final pb = PocketBase('https://my-app.pockethost.io');
final repository = MyRepository();

final manager = PocketBaseSyncManager<MyModel>(
  pb: pb,
  collection: 'notes',
  repository: repository,
  // Mappers to convert between your Model and JSON
  fromJson: (json) => MyModel.fromJson(json),
  toJson: (model) => model.toJson(),
);
```

### 3. Perform Operations

Use the manager to perform operations instead of writing directly to your local DB or SDK. The manager ensures changes are tracked for sync.

```dart
// Create
await manager.create(
  manager.generateId(), 
  MyModel(content: 'Hello World')
);

// Update
await manager.update('RECORD_ID', updatedModel);

// Delete
await manager.delete('RECORD_ID');
```

### 4. Sync

Call `sync()` to push local changes and pull remote updates. You can do this on an interval, on app start, or manually.

```dart
try {
  await manager.sync();
  print('Sync completed successfully');
} catch (e) {
  print('Sync failed: $e');
}
```

## How it Works

### Push (Local to Remote)
1.  Iterates through local records marked as `isDirty`.
2.  If `isDeleted` is true, deletes the record on the server.
3.  Otherwise, calculates a diff between the current data and the `baseData` (state at last sync).
4.  Sends a PATCH request with only the changed fields.

### Pull (Remote to Local)
1.  Fetches records from PocketBase updated `updated >= lastSyncTime`.
2.  **Reconciliation**: Fetches a list of **all** IDs from the server to detect deletions.
3.  **Merge**:
    *   If a record exists locally and remotely, it performs a 3-way merge.
    *   If server data conflicts with local changes, server wins.
    *   If no conflict, updates are applied.
4.  Updates the local `baseData` and clears the `isDirty` flag for synced records.

## License

MIT
