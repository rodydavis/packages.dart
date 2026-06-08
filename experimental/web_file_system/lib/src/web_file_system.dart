import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:web_file_system/src/backend/idb_inode_service.dart';
import 'package:web_file_system/src/backend/opfs_block_store.dart';
import 'package:web_file_system/src/backend/sync_rpc_helper.dart';
import 'entities/web_directory.dart';
import 'entities/web_file.dart';
import 'entities/web_link.dart';

class WebFileSystem extends FileSystem {
  final IdbInodeService _idb = IdbInodeService();
  final OpfsBlockStore _opfs = OpfsBlockStore();
  final Uuid _uuid = Uuid();

  // Public matchers for internal use
  IdbInodeService get idb => _idb;
  OpfsBlockStore get opfs => _opfs;
  Uuid get uuid => _uuid;

  WebFileSystem();

  @override
  Directory directory(path) => WebDirectory(this, getPath(path));

  @override
  File file(path) => WebFile(this, getPath(path));

  @override
  Link link(path) => WebLink(this, getPath(path));

  @override
  p.Context get path => p.Context(style: p.Style.posix);

  @override
  Directory get currentDirectory => directory('/');

  @override
  set currentDirectory(dynamic path) {
    throw UnsupportedError('Changing CWD not supported on web');
  }

  @override
  Directory get systemTempDirectory => directory('/tmp');

  @override
  Future<FileSystemEntityType> type(
    String path, {
    bool followLinks = true,
  }) async {
    try {
      final inode = await resolvepath(path, followLinks: followLinks);
      if (inode.nodeType == 0) return FileSystemEntityType.file;
      if (inode.nodeType == 1) return FileSystemEntityType.directory;
      if (inode.nodeType == 2) return FileSystemEntityType.link;
      return FileSystemEntityType.notFound;
    } catch (e) {
      return FileSystemEntityType.notFound;
    }
  }

  static void registerWorkerProxy(dynamic worker, WebFileSystem fs) {
    SyncRpcHelper.registerWorkerProxy(worker as JSAny, fs as JSAny);
  }

  Uint8List makeSyncCall(int cmd, Uint8List request) {
    if (!SyncRpcHelper.isWorker) {
      throw UnsupportedError('Synchronous operations are only supported inside Web Workers.');
    }
    if (!SyncRpcHelper.isSharedArrayBufferSupported) {
      throw StateError('SharedArrayBuffer is not supported. Ensure your site is cross-origin isolated with COOP/COEP headers.');
    }
    return SyncRpcHelper.sendSyncRequest(cmd, request);
  }

  @override
  FileSystemEntityType typeSync(String path, {bool followLinks = true}) {
    if (!SyncRpcHelper.isWorker) {
      throw UnsupportedError('Synchronous operations are only supported inside Web Workers.');
    }
    if (!SyncRpcHelper.isSharedArrayBufferSupported) {
      throw StateError('SharedArrayBuffer is not supported. Ensure your site is cross-origin isolated with COOP/COEP headers.');
    }
    try {
      final pathBytes = utf8.encode(path);
      final payload = Uint8List(pathBytes.length + 1);
      payload[0] = followLinks ? 1 : 0;
      payload.setRange(1, payload.length, pathBytes);
      
      final respBytes = makeSyncCall(2, payload);
      final typeStr = utf8.decode(respBytes);
      if (typeStr == 'file') return FileSystemEntityType.file;
      if (typeStr == 'directory') return FileSystemEntityType.directory;
      if (typeStr == 'link') return FileSystemEntityType.link;
      return FileSystemEntityType.notFound;
    } catch (_) {
      return FileSystemEntityType.notFound;
    }
  }

  // Internal Resolution Logic
  Future<Inode> resolvepath(String pathStr, {bool followLinks = true}) async {
    final normalized = path.normalize(pathStr);
    final parts = path.split(normalized);
    // Root is '/'
    String currentId = IdbInodeService.rootId;
    Inode currentInode = await _idb.getInode(currentId);

    // Common recursion guard
    int linkDepth = 0;
    const maxLinkDepth = 20;

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty || part == '/' || part == '.') continue;

      // Lookup child
      final child = await _idb.getChild(currentId, part);
      if (child == null) {
        throw FileSystemException(
          'No such file or directory',
          pathStr,
          const OSError('ENOENT', 2),
        );
      }

      // If child is Link
      if (child.nodeType == 2) {
        // If we are at the last part, only follow if followLinks is true
        if (i == parts.length - 1 && !followLinks) {
          return child;
        }

        // Follow link
        if (child.blobId != null) {
          if (linkDepth++ > maxLinkDepth) {
            throw FileSystemException(
              'Too many levels of symbolic links',
              pathStr,
              const OSError('ELOOP', 40),
            );
          }

          // Read target
          final bytesList = await _opfs.readBlob(child.blobId!).toList();
          final bytes = bytesList.expand((x) => x).toList();
          final targetPath = utf8.decode(bytes);

          // Resolve target path
          // Standard: Relative to directory containing link if not absolute.
          String resolvedTarget;
          if (path.isAbsolute(targetPath)) {
            resolvedTarget = targetPath;
          } else {
            // Parent path relative to root
            final parentParts = parts.take(i).toList();
            // join behaves weirdly with context parts, ensure root if needed
            final parentStr = path.joinAll(['/', ...parentParts]);
            resolvedTarget = path.normalize(path.join(parentStr, targetPath));
          }

          // Resolve the target inode (ALWAYS follow links when resolving intermediate link targets)
          final targetInode = await resolvepath(
            resolvedTarget,
            followLinks: true,
          );

          // If we have more parts remaining in the original path, we must continue from this target
          if (i < parts.length - 1) {
            if (targetInode.nodeType != 1) {
              throw FileSystemException(
                'Not a directory',
                pathStr,
                const OSError('ENOTDIR', 20),
              );
            }
            currentId = targetInode.id;
            currentInode = targetInode;
            continue;
          } else {
            // End of path, return target
            return targetInode;
          }
        }
      }

      currentId = child.id;
      currentInode = child;
    }
    return currentInode;
  }

  String getPath(dynamic path) {
    if (path is String) return path;
    if (path is FileSystemEntity) return path.path;
    if (path is Uri) return path.toFilePath();
    throw ArgumentError('Path must be a String, Uri, or FileSystemEntity');
  }

  @override
  Future<FileStat> stat(String path) async {
    try {
      final inode = await resolvepath(path, followLinks: true);
      return FileStatImpl(inode.modified, inode.size, _getType(inode.nodeType));
    } catch (e) {
      return FileStatImpl(0, 0, FileSystemEntityType.notFound);
    }
  }

  @override
  FileStat statSync(String path) {
    if (!SyncRpcHelper.isWorker) {
      throw UnsupportedError('Synchronous operations are only supported inside Web Workers.');
    }
    if (!SyncRpcHelper.isSharedArrayBufferSupported) {
      throw StateError('SharedArrayBuffer is not supported. Ensure your site is cross-origin isolated with COOP/COEP headers.');
    }
    try {
      final respBytes = makeSyncCall(9, utf8.encode(path));
      final statMap = json.decode(utf8.decode(respBytes)) as Map<String, dynamic>;
      final typeStr = statMap['type'] as String;
      final size = statMap['size'] as int;
      final modified = statMap['modified'] as int;
      
      FileSystemEntityType type;
      if (typeStr == 'file') {
        type = FileSystemEntityType.file;
      } else if (typeStr == 'directory') {
        type = FileSystemEntityType.directory;
      } else if (typeStr == 'link') {
        type = FileSystemEntityType.link;
      } else {
        type = FileSystemEntityType.notFound;
      }
      
      return FileStatImpl(modified, size, type);
    } catch (_) {
      return FileStatImpl(0, 0, FileSystemEntityType.notFound);
    }
  }

  FileSystemEntityType _getType(int nodeType) {
    if (nodeType == 0) return FileSystemEntityType.file;
    if (nodeType == 1) return FileSystemEntityType.directory;
    if (nodeType == 2) return FileSystemEntityType.link;
    return FileSystemEntityType.notFound;
  }

  @override
  bool isFileSync(String path) =>
      typeSync(path) == FileSystemEntityType.file;

  @override
  bool isDirectorySync(String path) =>
      typeSync(path) == FileSystemEntityType.directory;

  @override
  bool isLinkSync(String path) =>
      typeSync(path, followLinks: false) == FileSystemEntityType.link;

  @override
  Future<bool> isFile(String path) async =>
      (await type(path)) == FileSystemEntityType.file;

  @override
  Future<bool> isDirectory(String path) async =>
      (await type(path)) == FileSystemEntityType.directory;

  @override
  Future<bool> isLink(String path) async =>
      (await type(path, followLinks: false)) == FileSystemEntityType.link;

  bool get isWatchSupported => false;

  @override
  Future<bool> identical(String path1, String path2) async {
    final s1 = await stat(path1);
    final s2 = await stat(path2);
    if (s1.type == FileSystemEntityType.notFound ||
        s2.type == FileSystemEntityType.notFound)
      return false;

    final i1 = await resolvepath(path1);
    final i2 = await resolvepath(path2);
    return i1.id == i2.id;
  }

  @override
  bool identicalSync(String path1, String path2) {
    try {
      final r1 = resolveSymbolicLinksSync(path1);
      final r2 = resolveSymbolicLinksSync(path2);
      return r1 == r2;
    } catch (_) {
      return false;
    }
  }

  Future<String> resolveSymbolicLinks(String pathStr) async {
    final inode = await resolvepath(pathStr, followLinks: true);
    final List<String> segments = [];
    Inode current = inode;
    while (current.id != IdbInodeService.rootId) {
      segments.add(current.name);
      current = await _idb.getInode(current.parentId);
    }
    if (segments.isEmpty) return '/';
    return '/' + segments.reversed.join('/');
  }

  String resolveSymbolicLinksSync(String pathStr) {
    final respBytes = makeSyncCall(11, utf8.encode(pathStr));
    return utf8.decode(respBytes);
  }
}

class FileStatImpl implements FileStat {
  final int _modified;
  final int _size;
  final FileSystemEntityType _type;

  FileStatImpl(this._modified, this._size, this._type);

  @override
  DateTime get accessed => DateTime.fromMillisecondsSinceEpoch(_modified);

  @override
  DateTime get changed => DateTime.fromMillisecondsSinceEpoch(_modified);

  @override
  int get mode => 0;

  @override
  DateTime get modified => DateTime.fromMillisecondsSinceEpoch(_modified);

  @override
  int get size => _size;

  @override
  FileSystemEntityType get type => _type;

  @override
  String modeString() => 'rwxrwxrwx';
}
