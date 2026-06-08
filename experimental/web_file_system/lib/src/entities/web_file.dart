import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file/file.dart';
import 'package:web_file_system/src/backend/idb_inode_service.dart';
import '../web_file_system.dart';

class WebFile extends FileSystemEntity implements File {
  final WebFileSystem _fs;
  @override
  final String path;

  WebFile(this._fs, this.path);

  @override
  FileSystem get fileSystem => _fs;

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) async {
    if (await exists()) {
      if (exclusive) {
        throw FileSystemException(
          'File already exists',
          path,
          const OSError('EEXIST', 17),
        );
      }
      return this;
    }

    if (recursive) {
      final parentDir = _fs.path.dirname(path);
      if (await _fs.type(parentDir) == FileSystemEntityType.notFound) {
        await _fs.directory(parentDir).create(recursive: true);
      }
    }

    final parentPath = _fs.path.dirname(path);
    final parentInode = await _fs.resolvepath(parentPath);

    await _fs.idb.createInode(
      Inode(
        id: _fs.uuid.v4(),
        parentId: parentInode.id,
        name: _fs.path.basename(path),
        nodeType: 0,
        modified: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    return this;
  }

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    if (existsSync()) {
      if (exclusive) {
        throw FileSystemException(
          'File already exists',
          path,
          const OSError('EEXIST', 17),
        );
      }
      return;
    }

    final parentPath = _fs.path.dirname(path);
    final parentType = _fs.typeSync(parentPath);
    if (parentType == FileSystemEntityType.notFound) {
      if (recursive) {
        _fs.directory(parentPath).createSync(recursive: true);
      } else {
        throw FileSystemException(
          'Cannot create file, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
          path,
        );
      }
    } else if (parentType != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Cannot create file, path = \'$path\' (OS Error: Not a directory, errno = 20)',
        path,
      );
    }

    writeAsBytesSync([]);
  }

  @override
  Future<File> copy(String newPath) async {
    final inode = await _fs.resolvepath(path);
    final newParent = await _fs.resolvepath(_fs.path.dirname(newPath));

    await _fs.idb.createInode(
      Inode(
        id: _fs.uuid.v4(),
        parentId: newParent.id,
        name: _fs.path.basename(newPath),
        nodeType: 0,
        blobId: inode.blobId,
        size: inode.size,
        modified: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    return WebFile(_fs, newPath);
  }

  @override
  File copySync(String newPath) {
    final bytes = readAsBytesSync();
    _fs.file(newPath).writeAsBytesSync(bytes);
    return WebFile(_fs, newPath);
  }

  @override
  Future<int> length() async {
    final inode = await _fs.resolvepath(path);
    return inode.size;
  }

  @override
  int lengthSync() => statSync().size;

  @override
  Future<DateTime> lastModified() async {
    final inode = await _fs.resolvepath(path);
    return DateTime.fromMillisecondsSinceEpoch(inode.modified);
  }

  @override
  DateTime lastModifiedSync() => statSync().modified;

  @override
  Future<DateTime> lastAccessed() async {
    return lastModified();
  }

  @override
  DateTime lastAccessedSync() => statSync().accessed;

  @override
  Future<dynamic> setLastAccessed(DateTime time) async {}

  @override
  void setLastAccessedSync(DateTime time) =>
      throw UnsupportedError('Sync not supported');

  @override
  Future<dynamic> setLastModified(DateTime time) async {
    final inode = await _fs.resolvepath(path);
    await _fs.idb.updateInode(
      Inode(
        id: inode.id,
        parentId: inode.parentId,
        name: inode.name,
        nodeType: inode.nodeType,
        blobId: inode.blobId,
        size: inode.size,
        modified: time.millisecondsSinceEpoch,
      ),
    );
  }

  @override
  void setLastModifiedSync(DateTime time) =>
      throw UnsupportedError('Sync not supported');

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    throw UnsupportedError(
      'RandomAccessFile not supported on web (use streams)',
    );
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) =>
      throw UnsupportedError('Sync not supported');

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    final stream = Stream.value(bytes);
    final (newBlobId, _) = await _fs.opfs.writeBlob(stream);

    Inode inode;
    try {
      inode = await _fs.resolvepath(path);
      if (mode == FileMode.append) {
        throw UnsupportedError('Append not yet optimized');
      }
    } on FileSystemException catch (_) {
      final parentPath = _fs.path.dirname(path);
      if (await _fs.type(parentPath) != FileSystemEntityType.directory) {
        throw FileSystemException(
          'Cannot open file, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
          path,
        );
      }
      await create(recursive: false);
      inode = await _fs.resolvepath(path);
    }

    await _fs.idb.updateInode(
      Inode(
        id: inode.id,
        parentId: inode.parentId,
        name: inode.name,
        nodeType: inode.nodeType,
        blobId: newBlobId,
        size: bytes.length,
        modified: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    return this;
  }

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    if (mode == FileMode.append) {
      throw UnsupportedError('Append not yet optimized');
    }
    
    final parentPath = _fs.path.dirname(path);
    if (_fs.typeSync(parentPath) != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Cannot open file, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }

    final pathBytes = utf8.encode(path);
    final pathLen = pathBytes.length;
    final request = Uint8List(4 + pathLen + bytes.length);
    final bd = ByteData.sublistView(request);
    bd.setUint32(0, pathLen, Endian.little);
    request.setRange(4, 4 + pathLen, pathBytes);
    request.setRange(4 + pathLen, request.length, bytes);

    _fs.makeSyncCall(4, request);
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    return writeAsBytes(encoding.encode(contents), mode: mode, flush: flush);
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    writeAsBytesSync(encoding.encode(contents), mode: mode, flush: flush);
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    final inode = await _fs.resolvepath(path);
    if (inode.blobId == null) return;

    yield* _fs.opfs.readBlob(inode.blobId!);
  }

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    final controller = StreamController<List<int>>();

    // Start background write but keep future to await in close()
    final writeFuture = _handleWrite(controller.stream, encoding, mode);
    writeFuture.catchError((Object _) {});

    return _WebIOSink(controller, writeFuture, encoding);
  }

  Future<void> _handleWrite(
    Stream<List<int>> stream,
    Encoding encoding,
    FileMode mode,
  ) async {
    try {
      final parentPath = _fs.path.dirname(path);
      if (await _fs.type(parentPath) != FileSystemEntityType.directory) {
        throw FileSystemException(
          'Cannot open file, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
          path,
        );
      }

      final (newId, size) = await _fs.opfs.writeBlob(stream);

      Inode inode;
      try {
        inode = await _fs.resolvepath(path);
      } catch (_) {
        // Create if missing
        await create(recursive: false);
        inode = await _fs.resolvepath(path);
      }

      await _fs.idb.updateInode(
        Inode(
          id: inode.id,
          parentId: inode.parentId,
          name: inode.name,
          nodeType: 0,
          blobId: newId,
          size: size,
          modified: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (e) {
      throw FileSystemException('Write failed: $e', path);
    }
  }

  @override
  Future<Uint8List> readAsBytes() async {
    final chunks = await openRead().toList();
    return Uint8List.fromList(chunks.expand((x) => x).toList());
  }

  @override
  Uint8List readAsBytesSync() {
    final type = _fs.typeSync(path);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Cannot open file, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }
    if (type == FileSystemEntityType.directory) {
      throw FileSystemException(
        'Cannot open file, path = \'$path\' (OS Error: Is a directory, errno = 21)',
        path,
      );
    }
    return _fs.makeSyncCall(3, utf8.encode(path));
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async {
    final bytes = await readAsBytes();
    return encoding.decode(bytes);
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    return encoding.decode(readAsBytesSync());
  }

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) async {
    final str = await readAsString(encoding: encoding);
    return const LineSplitter().convert(str);
  }

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    final str = readAsStringSync(encoding: encoding);
    return const LineSplitter().convert(str);
  }

  @override
  Future<bool> exists() async {
    try {
      final inode = await _fs.resolvepath(path);
      return inode.nodeType == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  bool existsSync() {
    return _fs.typeSync(path, followLinks: false) == FileSystemEntityType.file;
  }

  @override
  Future<File> rename(String newPath) async {
    final inode = await _fs.resolvepath(path);
    final newParentDir = _fs.path.dirname(newPath);
    final newName = _fs.path.basename(newPath);
    final newParentInode = await _fs.resolvepath(newParentDir);

    final updated = Inode(
      id: inode.id,
      parentId: newParentInode.id,
      name: newName,
      nodeType: inode.nodeType,
      blobId: inode.blobId,
      size: inode.size,
      modified: DateTime.now().millisecondsSinceEpoch,
    );

    await _fs.idb.updateInode(updated);
    return WebFile(_fs, newPath);
  }

  @override
  File renameSync(String newPath) {
    final type = _fs.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Cannot rename file, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }
    final newParentDir = _fs.path.dirname(newPath);
    if (_fs.typeSync(newParentDir) != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Cannot rename file, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }

    final pathBytes = utf8.encode(path);
    final newPathBytes = utf8.encode(newPath);
    final request = Uint8List(4 + pathBytes.length + newPathBytes.length);
    final bd = ByteData.sublistView(request);
    bd.setUint32(0, pathBytes.length, Endian.little);
    request.setRange(4, 4 + pathBytes.length, pathBytes);
    request.setRange(4 + pathBytes.length, request.length, newPathBytes);

    _fs.makeSyncCall(12, request);
    return WebFile(_fs, newPath);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    final inode = await _fs.resolvepath(path);
    await _fs.idb.deleteInode(inode.id);
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) {
    final type = _fs.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Cannot delete file, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }
    _fs.makeSyncCall(6, utf8.encode(path));
  }

  @override
  Future<FileStat> stat() => _fs.stat(path);

  @override
  FileStat statSync() => _fs.statSync(path);

  @override
  Uri get uri => Uri.parse(path);
  @override
  String get basename => _fs.path.basename(path);
  @override
  String get dirname => _fs.path.dirname(path);
  @override
  Directory get parent => _fs.directory(dirname);
  @override
  bool get isAbsolute => _fs.path.isAbsolute(path);
  @override
  File get absolute => WebFile(_fs, _fs.path.absolute(path));

  @override
  Future<String> resolveSymbolicLinks() => _fs.resolveSymbolicLinks(path);

  @override
  String resolveSymbolicLinksSync() => _fs.resolveSymbolicLinksSync(path);

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) {
    return const Stream.empty();
  }
}

class _WebIOSink implements IOSink {
  final StreamController<List<int>> _controller;
  final Future<void> _writeFuture;
  Encoding _encoding;

  _WebIOSink(this._controller, this._writeFuture, this._encoding);

  @override
  Encoding get encoding => _encoding;

  @override
  set encoding(Encoding value) => _encoding = value;

  @override
  void add(List<int> data) {
    if (_controller.isClosed) return;
    _controller.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_controller.isClosed) return;
    _controller.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    return Future.any([
      _controller.addStream(stream),
      _writeFuture,
    ]);
  }

  @override
  Future close() async {
    await _controller.close();
    await _writeFuture;
  }

  @override
  Future get done => Future.any([
        _controller.done,
        _writeFuture,
      ]);

  @override
  Future flush() async {}

  @override
  void write(Object? object) {
    add(encoding.encode(object.toString()));
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    add([charCode]);
  }

  @override
  void writeln([Object? object = ""]) {
    write(object);
    write('\n');
  }
}
