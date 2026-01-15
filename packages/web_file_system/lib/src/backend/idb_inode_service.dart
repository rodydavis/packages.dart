import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

extension type InodeJS._(JSObject _) implements JSObject {
  external String get id;
  external set id(String value);

  external String get parentId;
  external set parentId(String value);

  external String get name;
  external set name(String value);

  external int get nodeType;
  external set nodeType(int value);

  external String? get blobId;
  external set blobId(String? value);

  external int get size;
  external set size(int value);

  external int get modified;
  external set modified(int value);

  factory InodeJS({
    required String id,
    required String parentId,
    required String name,
    required int nodeType,
    String? blobId,
    int size = 0,
    required int modified,
  }) {
    final obj = JSObject() as InodeJS;
    obj.id = id;
    obj.parentId = parentId;
    obj.name = name;
    obj.nodeType = nodeType;
    obj.blobId = blobId;
    obj.size = size;
    obj.modified = modified;
    return obj;
  }
}

class Inode {
  final String id;
  final String parentId;
  final String name;
  final int nodeType;
  final String? blobId;
  final int size;
  final int modified;

  Inode({
    required this.id,
    required this.parentId,
    required this.name,
    required this.nodeType,
    this.blobId,
    this.size = 0,
    required this.modified,
  });

  InodeJS toJS() {
    return InodeJS(
      id: id,
      parentId: parentId,
      name: name,
      nodeType: nodeType,
      blobId: blobId,
      size: size,
      modified: modified,
    );
  }

  static Inode fromJS(InodeJS js) {
    return Inode(
      id: js.id,
      parentId: js.parentId,
      name: js.name,
      nodeType: js.nodeType,
      blobId: js.blobId,
      size: js.size,
      modified: js.modified,
    );
  }
}

class IdbInodeService {
  static const String _dbName = 'WebFileSystemDB';
  static const int _version = 1;
  static const String _storeName = 'inodes';

  web.IDBDatabase? _db;
  final Completer<void> _initCompleter = Completer<void>();
  static const String rootId = '00000000-0000-0000-0000-000000000000';

  Future<void> _ensureReady() async {
    if (_db != null) return;
    if (_initCompleter.isCompleted) return _initCompleter.future;

    final request = web.window.indexedDB.open(_dbName, _version);

    request.onupgradeneeded = (web.IDBVersionChangeEvent event) {
      final db =
          (event.target as web.IDBOpenDBRequest).result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        final store = db.createObjectStore(
          _storeName,
          web.IDBObjectStoreParameters(keyPath: 'id'.toJS),
        );
        store.createIndex(
            'parentId', 'parentId'.toJS, web.IDBIndexParameters(unique: false));
        store.createIndex('parent_name', ['parentId'.toJS, 'name'.toJS].toJS,
            web.IDBIndexParameters(unique: true));
      }
    }.toJS;

    final completer = Completer<void>();

    request.onsuccess = (web.Event event) {
      _db = (event.target as web.IDBOpenDBRequest).result as web.IDBDatabase;
      _ensureRootExists().then((_) {
        if (!_initCompleter.isCompleted) completer.complete();
      }).catchError((e) {
        if (!_initCompleter.isCompleted) completer.completeError(e);
      });
    }.toJS;

    request.onerror = (web.Event event) {
      if (!_initCompleter.isCompleted)
        completer.completeError(Exception('Failed to open IDB'));
    }.toJS;

    return completer.future;
  }

  Future<void> _ensureRootExists() async {
    try {
      await getInode(rootId);
    } catch (_) {
      await createInode(Inode(
        id: rootId,
        parentId: 'null',
        name: '',
        nodeType: 1,
        modified: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  Future<void> createInode(Inode inode) async {
    if (_db == null) await _ensureReady();
    final transaction = _db!.transaction(
        _storeName.toJS, 'readwrite'.toJS as web.IDBTransactionMode);
    final store = transaction.objectStore(_storeName);
    final request = store.put(inode.toJS());
    await _requestToFuture(request);
  }

  Future<void> updateInode(Inode inode) async {
    await createInode(inode);
  }

  Future<void> deleteInode(String id) async {
    await _ensureReady();
    final transaction = _db!.transaction(
        _storeName.toJS, 'readwrite'.toJS as web.IDBTransactionMode);
    final store = transaction.objectStore(_storeName);
    final request = store.delete(id.toJS);
    await _requestToFuture(request);
  }

  Future<Inode> getInode(String id) async {
    if (_db == null) await _ensureReady();

    final transaction = _db!.transaction(
        _storeName.toJS, 'readonly'.toJS as web.IDBTransactionMode);
    final store = transaction.objectStore(_storeName);
    final request = store.get(id.toJS);
    final result = await _requestToFuture(request);
    if (result == null) throw Exception('Inode $id not found');

    return Inode.fromJS(result as InodeJS);
  }

  Future<Inode?> getChild(String parentId, String name) async {
    await _ensureReady();
    final transaction = _db!.transaction(
        _storeName.toJS, 'readonly'.toJS as web.IDBTransactionMode);
    final store = transaction.objectStore(_storeName);
    final index = store.index('parent_name');
    final key = JSArray();
    key.add(parentId.toJS);
    key.add(name.toJS);

    final request = index.get(key);

    try {
      final result = await _requestToFuture(request);
      if (result == null) return null;
      return Inode.fromJS(result as InodeJS);
    } catch (e) {
      return null;
    }
  }

  Future<List<Inode>> listChildren(String parentId) async {
    await _ensureReady();
    final transaction = _db!.transaction(
        _storeName.toJS, 'readonly'.toJS as web.IDBTransactionMode);
    final store = transaction.objectStore(_storeName);
    final index = store.index('parentId');
    final request = index.getAll(parentId.toJS);

    final result = await _requestToFuture(request);
    final list = (result as JSArray).toDart;
    return list.map((item) => Inode.fromJS(item as InodeJS)).toList();
  }

  Future<dynamic> _requestToFuture(web.IDBRequest request) {
    final completer = Completer<dynamic>();
    request.onsuccess = (web.Event e) {
      completer.complete((e.target as web.IDBRequest).result);
    }.toJS;
    request.onerror = (web.Event e) {
      completer.completeError(Exception('IDB Error'));
    }.toJS;
    return completer.future;
  }
}
