import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file/file.dart';
import 'package:web_file_system/src/backend/idb_inode_service.dart';
import '../web_file_system.dart';

class WebLink extends FileSystemEntity implements Link {
  final WebFileSystem _fs;
  @override
  final String path;

  WebLink(this._fs, this.path);

  @override
  FileSystem get fileSystem => _fs;

  @override
  Future<Link> create(String target, {bool recursive = false}) async {
    if (await exists()) {
      // Should throw if exists? Standard create throws if already exists usually unless overwrite logic applied?
      // create(recursive) usually implies ensuring parent exists.
      throw FileSystemException(
        'Link already exists',
        path,
        const OSError('EEXIST', 17),
      );
    }

    if (recursive) {
      final parentDir = _fs.path.dirname(path);
      if (await _fs.type(parentDir) == FileSystemEntityType.notFound) {
        await _fs.directory(parentDir).create(recursive: true);
      }
    }

    // Write target path string to OPFS blob
    final stream = Stream.value(utf8.encode(target));
    final (blobId, _) = await _fs.opfs.writeBlob(stream);

    final parentPath = _fs.path.dirname(path);
    final parentInode = await _fs.resolvepath(parentPath);

    await _fs.idb.createInode(
      Inode(
        id: _fs.uuid.v4(),
        parentId: parentInode.id,
        name: _fs.path.basename(path),
        nodeType: 2, // Link
        blobId: blobId,
        size: target.length,
        modified: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    return this;
  }

  @override
  void createSync(String target, {bool recursive = false}) {
    if (existsSync()) {
      throw FileSystemException(
        'Link already exists',
        path,
        const OSError('EEXIST', 17),
      );
    }

    final parentPath = _fs.path.dirname(path);
    final parentType = _fs.typeSync(parentPath);
    if (parentType == FileSystemEntityType.notFound) {
      if (recursive) {
        _fs.directory(parentPath).createSync(recursive: true);
      } else {
        throw FileSystemException(
          'Cannot create link, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
          path,
        );
      }
    } else if (parentType != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Cannot create link, path = \'$path\' (OS Error: Not a directory, errno = 20)',
        path,
      );
    }

    final pathBytes = utf8.encode(path);
    final targetBytes = utf8.encode(target);
    final request = Uint8List(4 + pathBytes.length + targetBytes.length);
    final bd = ByteData.sublistView(request);
    bd.setUint32(0, pathBytes.length, Endian.little);
    request.setRange(4, 4 + pathBytes.length, pathBytes);
    request.setRange(4 + pathBytes.length, request.length, targetBytes);

    _fs.makeSyncCall(7, request);
  }

  @override
  Future<Link> update(String target) async {
    final inode = await _fs.resolvepath(path, followLinks: false);

    // Write new blob
    final stream = Stream.value(utf8.encode(target));
    final (blobId, _) = await _fs.opfs.writeBlob(stream);

    await _fs.idb.updateInode(
      Inode(
        id: inode.id,
        parentId: inode.parentId,
        name: inode.name,
        nodeType: 2,
        blobId: blobId,
        size: target.length,
        modified: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    return this;
  }

  @override
  void updateSync(String target) {
    final type = _fs.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Cannot update link, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }
    if (type != FileSystemEntityType.link) {
      throw FileSystemException(
        'Not a link',
        path,
        const OSError('EINVAL', 22),
      );
    }

    final pathBytes = utf8.encode(path);
    final targetBytes = utf8.encode(target);
    final request = Uint8List(4 + pathBytes.length + targetBytes.length);
    final bd = ByteData.sublistView(request);
    bd.setUint32(0, pathBytes.length, Endian.little);
    request.setRange(4, 4 + pathBytes.length, pathBytes);
    request.setRange(4 + pathBytes.length, request.length, targetBytes);

    _fs.makeSyncCall(13, request);
  }

  @override
  Future<String> target() async {
    final inode = await _fs.resolvepath(path, followLinks: false);
    if (inode.nodeType != 2) {
      throw FileSystemException(
        'Not a link',
        path,
        const OSError('EINVAL', 22),
      );
    }
    if (inode.blobId == null) return '';

    final bytesList = await _fs.opfs.readBlob(inode.blobId!).toList();
    final bytes = bytesList.expand((x) => x).toList();
    return utf8.decode(bytes);
  }

  @override
  String targetSync() {
    final type = _fs.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Cannot read link, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }
    if (type != FileSystemEntityType.link) {
      throw FileSystemException(
        'Not a link',
        path,
        const OSError('EINVAL', 22),
      );
    }
    final respBytes = _fs.makeSyncCall(8, utf8.encode(path));
    return utf8.decode(respBytes);
  }

  @override
  Future<Link> rename(String newPath) async {
    final inode = await _fs.resolvepath(path, followLinks: false);
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
    return WebLink(_fs, newPath);
  }

  @override
  Link renameSync(String newPath) {
    final type = _fs.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Cannot rename link, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }
    final newParentDir = _fs.path.dirname(newPath);
    if (_fs.typeSync(newParentDir) != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Cannot rename link, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
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
    return WebLink(_fs, newPath);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    final inode = await _fs.resolvepath(path, followLinks: false);
    await _fs.idb.deleteInode(inode.id);
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) {
    final type = _fs.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Cannot delete link, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }
    _fs.makeSyncCall(6, utf8.encode(path));
  }

  @override
  Future<bool> exists() async {
    try {
      final inode = await _fs.resolvepath(path, followLinks: false);
      return inode.nodeType == 2;
    } catch (_) {
      return false;
    }
  }

  @override
  bool existsSync() {
    return _fs.typeSync(path, followLinks: false) == FileSystemEntityType.link;
  }

  @override
  Future<FileStat> stat() async => (await _fs.stat(path));

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
  Link get absolute => WebLink(_fs, _fs.path.absolute(path));

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
