import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file/file.dart';
import 'package:web_file_system/src/backend/idb_inode_service.dart';
import '../web_file_system.dart';
import 'web_file.dart';
import 'web_link.dart';

class WebDirectory extends FileSystemEntity implements Directory {
  final WebFileSystem _fs;
  @override
  final String path;

  WebDirectory(this._fs, this.path);

  @override
  FileSystem get fileSystem => _fs;

  @override
  Uri get uri => Uri.parse(path);

  @override
  Future<Directory> create({bool recursive = false}) async {
    if (await exists()) return this;

    final parentPath = _fs.path.dirname(path);
    final name = _fs.path.basename(path);

    if (recursive) {
      await _createRecursiveSafe(path);
      return this;
    }

    // Validate parent exists (handled by resolvepath usually throwing, or we must check)
    // We assume parent must exist if not recursive.
    final parentInode = await _fs.resolvepath(parentPath); // throws if missing

    await _fs.idb.createInode(Inode(
      id: _fs.uuid.v4(),
      parentId: parentInode.id,
      name: name,
      nodeType: 1, // Directory
      modified: DateTime.now().millisecondsSinceEpoch,
    ));

    return this;
  }

  Future<void> _createRecursiveSafe(String p) async {
    if (p == '/' || p == '.') return;
    if (await _fs.type(p) != FileSystemEntityType.notFound) return;

    await _createRecursiveSafe(_fs.path.dirname(p));
    final parentVal = await _fs.resolvepath(_fs.path.dirname(p));
    await _fs.idb.createInode(Inode(
        id: _fs.uuid.v4(),
        parentId: parentVal.id,
        name: _fs.path.basename(p),
        nodeType: 1,
        modified: DateTime.now().millisecondsSinceEpoch));
  }

  @override
  void createSync({bool recursive = false}) {
    if (existsSync()) return;

    final parentPath = _fs.path.dirname(path);
    final parentType = _fs.typeSync(parentPath);
    if (parentType == FileSystemEntityType.notFound) {
      if (recursive) {
        _fs.directory(parentPath).createSync(recursive: true);
      } else {
        throw FileSystemException(
          'Cannot create directory, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
          path,
        );
      }
    } else if (parentType != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Cannot create directory, path = \'$path\' (OS Error: Not a directory, errno = 20)',
        path,
      );
    }

    _fs.makeSyncCall(5, utf8.encode(path));
  }

  @override
  Future<Directory> createTemp([String? prefix]) async {
    final name = (prefix ?? 'temp') + _fs.uuid.v4();
    final tempDir = _fs.path.join(path, name);
    // Ensure path exists
    if (!await exists()) {
      throw FileSystemException(
          'Directory does not exist', path, const OSError('ENOENT', 2));
    }
    final dir = WebDirectory(_fs, tempDir);
    await dir.create();
    return dir;
  }

  @override
  Directory createTempSync([String? prefix]) {
    if (!existsSync()) {
      throw FileSystemException(
          'Directory does not exist', path, const OSError('ENOENT', 2));
    }
    final name = (prefix ?? 'temp') + _fs.uuid.v4();
    final tempDir = _fs.path.join(path, name);
    final dir = WebDirectory(_fs, tempDir);
    dir.createSync();
    return dir;
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    final inode = await _fs.resolvepath(path);

    final children = await _fs.idb.listChildren(inode.id);
    if (children.isNotEmpty && !recursive) {
      throw FileSystemException(
          'Directory not empty', path, const OSError('ENOTEMPTY', 39));
    }

    if (recursive) {
      for (final child in children) {
        final childPath = _fs.path.join(path, child.name);
        if (child.nodeType == 1) {
          await _fs.directory(childPath).delete(recursive: true);
        } else {
          await _fs.file(childPath).delete();
        }
      }
    }

    await _fs.idb.deleteInode(inode.id);
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) {
    final type = _fs.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Cannot delete directory, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Cannot delete directory, path = \'$path\' (OS Error: Not a directory, errno = 20)',
        path,
      );
    }

    if (!recursive) {
      final children = listSync(recursive: false, followLinks: false);
      if (children.isNotEmpty) {
        throw FileSystemException(
          'Directory not empty',
          path,
          const OSError('ENOTEMPTY', 39),
        );
      }
    }

    _fs.makeSyncCall(6, utf8.encode(path));
  }

  @override
  Future<bool> exists() async {
    try {
      final inode = await _fs.resolvepath(path);
      return inode.nodeType == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  bool existsSync() {
    return _fs.typeSync(path, followLinks: false) == FileSystemEntityType.directory;
  }

  @override
  Stream<FileSystemEntity> list(
      {bool recursive = false, bool followLinks = true}) async* {
    if (!await exists()) {
      throw FileSystemException(
          'Directory not found', path, const OSError('ENOENT', 2));
    }

    final inode = await _fs.resolvepath(path);
    final children = await _fs.idb.listChildren(inode.id);

    for (final child in children) {
      final childPath = _fs.path.join(path, child.name);
      if (child.nodeType == 1) {
        final dir = WebDirectory(_fs, childPath);
        yield dir;
        if (recursive) {
          yield* dir.list(recursive: true, followLinks: followLinks);
        }
      } else if (child.nodeType == 2) {
        if (!followLinks) {
          yield WebLink(_fs, childPath);
        } else {
          try {
            final resolved =
                await _fs.resolvepath(childPath, followLinks: true);
            if (resolved.nodeType == 1) {
              final dir = WebDirectory(_fs, childPath);
              yield dir;
              if (recursive) {
                yield* dir.list(recursive: true, followLinks: true);
              }
            } else {
              yield WebFile(_fs, childPath);
            }
          } catch (_) {
            yield WebLink(_fs, childPath);
          }
        }
      } else {
        yield WebFile(_fs, childPath);
      }
    }
  }

  @override
  List<FileSystemEntity> listSync(
      {bool recursive = false, bool followLinks = true}) {
    if (!existsSync()) {
      throw FileSystemException(
          'Directory not found', path, const OSError('ENOENT', 2));
    }

    final respBytes = _fs.makeSyncCall(10, utf8.encode(path));
    final listJson = json.decode(utf8.decode(respBytes)) as List<dynamic>;
    
    final List<FileSystemEntity> results = [];
    for (final item in listJson) {
      final itemMap = item as Map<String, dynamic>;
      final childPath = itemMap['path'] as String;
      final typeStr = itemMap['type'] as String;
      
      if (typeStr == 'directory') {
        final dir = WebDirectory(_fs, childPath);
        results.add(dir);
        if (recursive) {
          results.addAll(dir.listSync(recursive: true, followLinks: followLinks));
        }
      } else if (typeStr == 'link') {
        if (!followLinks) {
          results.add(WebLink(_fs, childPath));
        } else {
          try {
            final resolvedType = _fs.typeSync(childPath, followLinks: true);
            if (resolvedType == FileSystemEntityType.directory) {
              final dir = WebDirectory(_fs, childPath);
              results.add(dir);
              if (recursive) {
                results.addAll(dir.listSync(recursive: true, followLinks: true));
              }
            } else if (resolvedType == FileSystemEntityType.notFound) {
              results.add(WebLink(_fs, childPath));
            } else {
              results.add(WebFile(_fs, childPath));
            }
          } catch (_) {
            results.add(WebLink(_fs, childPath));
          }
        }
      } else {
        results.add(WebFile(_fs, childPath));
      }
    }
    return results;
  }

  @override
  Future<Directory> rename(String newPath) async {
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
        modified: DateTime.now().millisecondsSinceEpoch);

    await _fs.idb.updateInode(updated);
    return WebDirectory(_fs, newPath);
  }

  @override
  Directory renameSync(String newPath) {
    final type = _fs.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Cannot rename directory, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
        path,
      );
    }
    final newParentDir = _fs.path.dirname(newPath);
    if (_fs.typeSync(newParentDir) != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Cannot rename directory, path = \'$path\' (OS Error: No such file or directory, errno = 2)',
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
    return WebDirectory(_fs, newPath);
  }

  @override
  String get basename => _fs.path.basename(path);

  @override
  String get dirname => _fs.path.dirname(path);

  @override
  Directory get parent => _fs.directory(dirname);

  @override
  bool get isAbsolute => _fs.path.isAbsolute(path);

  @override
  Directory get absolute => WebDirectory(_fs, _fs.path.absolute(path));

  @override
  Future<FileStat> stat() => _fs.stat(path);

  @override
  FileStat statSync() => _fs.statSync(path);

  @override
  Future<String> resolveSymbolicLinks() => _fs.resolveSymbolicLinks(path);

  @override
  String resolveSymbolicLinksSync() => _fs.resolveSymbolicLinksSync(path);

  @override
  Stream<FileSystemEvent> watch(
      {int events = FileSystemEvent.all, bool recursive = false}) {
    return const Stream.empty();
  }

  @override
  Directory childDirectory(String basename) =>
      _fs.directory(_fs.path.join(path, basename));

  @override
  File childFile(String basename) => _fs.file(_fs.path.join(path, basename));

  @override
  Link childLink(String basename) => _fs.link(_fs.path.join(path, basename));
}
