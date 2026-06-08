@TestOn('browser')
import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:test/test.dart';
import 'package:web_file_system/web_file_system.dart';
import 'package:web_file_system/src/backend/idb_inode_service.dart';
import 'package:web_file_system/src/backend/opfs_block_store.dart';


void main() {
  late WebFileSystem fs;

  setUp(() async {
    // For unit testing in a persistent browser environment, concurrent tests might conflict.
    // Ideally we would mock the backend or use unique DB names.
    // For NOW, we use the default SINGLE DB implementation but try to use unique paths.
    fs = WebFileSystem();
  });

  group('Functional Correctness', () {
    test('Create and read text file', () async {
      final file = fs.file(
        '/hello_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.create(recursive: true);
      await file.writeAsString('Hello Hybrid FS');

      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), equals('Hello Hybrid FS'));
    });

    test('Directory creation and listing', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      await fs.directory('/assets_$uniqueId/images').create(recursive: true);
      await fs
          .file('/assets_$uniqueId/images/logo.png')
          .writeAsString('png-data');
      await fs.file('/assets_$uniqueId/readme.md').writeAsString('read me');

      final dir = fs.directory('/assets_$uniqueId');
      final entities = await dir.list(recursive: true).toList();

      expect(entities.length, equals(3)); // images, logo.png, readme.md
      // Note: order is not guaranteed usually, but CoW VFS might map order
      // Paths checking
      final paths = entities.map((e) => e.path).toList();
      expect(paths, contains('/assets_$uniqueId/images'));
      expect(paths, contains('/assets_$uniqueId/images/logo.png'));
      expect(paths, contains('/assets_$uniqueId/readme.md'));
    });

    test('Rename directory updates child paths', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final folder = '/folder_$uniqueId';
      final renamed = '/renamed_$uniqueId';

      await fs.directory(folder).create();
      await fs.file('$folder/file.txt').writeAsString('content');

      await fs.directory(folder).rename(renamed);

      expect(await fs.directory(folder).exists(), isFalse);
      expect(await fs.file('$folder/file.txt').exists(), isFalse);

      expect(await fs.directory(renamed).exists(), isTrue);
      expect(await fs.file('$renamed/file.txt').exists(), isTrue);

      expect(
        await fs.file('$renamed/file.txt').readAsString(),
        equals('content'),
      );
    });

    test('Symbolic Link creation and resolution', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '/target_$uniqueId.txt';
      final linkPath = '/link_$uniqueId';

      // Create target
      await fs.file(targetPath).writeAsString('target-content');

      // Create link
      await fs.link(linkPath).create(targetPath);

      // Verify link exists
      expect(await fs.link(linkPath).exists(), isTrue);
      expect(
        await fs.type(linkPath, followLinks: false),
        equals(FileSystemEntityType.link),
      );

      // Verify link resolves to target content
      expect(await fs.file(linkPath).readAsString(), equals('target-content'));

      // Verify target()
      expect(await fs.link(linkPath).target(), equals(targetPath));

      // Verify traversing through link (directory)
      final targetDir = '/dir_$uniqueId';
      final linkDir = '/link_dir_$uniqueId';
      await fs.directory(targetDir).create();
      await fs.file('$targetDir/child.txt').writeAsString('child-content');
      await fs.link(linkDir).create(targetDir);

      expect(
        await fs.file('$linkDir/child.txt').readAsString(),
        equals('child-content'),
      );
    });

    test('Streamed write records correct file size in inode', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final file = fs.file('/stream_size_$uniqueId.txt');
      final sink = file.openWrite();
      sink.add([1, 2, 3, 4, 5]);
      await sink.close();

      expect(await file.length(), equals(5));
    });

    test('Writing to file with nonexistent parent throws FileSystemException', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final file = fs.file('/nonexistent_$uniqueId/file.txt');

      expect(
        () => file.writeAsBytes([1, 2, 3]),
        throwsA(isA<FileSystemException>()),
      );

      final sink = file.openWrite();
      expect(
        () => sink.addStream(Stream.value([1, 2, 3])).then((_) => sink.close()),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('Directory list yields correct entity types based on followLinks', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final dir = '/list_test_$uniqueId';
      final file = '$dir/file.txt';
      final link = '$dir/link_to_file';

      await fs.directory(dir).create();
      await fs.file(file).writeAsString('data');
      await fs.link(link).create(file);

      // Listing with followLinks = false yields Link
      final listNoFollow = await fs.directory(dir).list(followLinks: false).toList();
      final linkEntity = listNoFollow.firstWhere((e) => e.path == link);
      expect(linkEntity, isA<Link>());

      // Listing with followLinks = true yields File
      final listFollow = await fs.directory(dir).list(followLinks: true).toList();
      final fileEntity = listFollow.firstWhere((e) => e.path == link);
      expect(fileEntity, isA<File>());
    });

    test('Listing a non-existent directory path throws FileSystemException', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final dir = fs.directory('/nonexistent_dir_$uniqueId');
      expect(
        () => dir.list().toList(),
        throwsA(isA<FileSystemException>().having((e) => e.message, 'message', contains('Directory not found'))),
      );
    });

    test('Recursive listing of a directory containing a symlink pointing to another directory with followLinks: true', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final root = '/root_$uniqueId';
      final targetDir = '/target_dir_$uniqueId';
      final file = '$targetDir/file.txt';
      final link = '$root/link_to_dir';

      await fs.directory(root).create();
      await fs.directory(targetDir).create();
      await fs.file(file).writeAsString('some data');
      await fs.link(link).create(targetDir);

      final list = await fs.directory(root).list(recursive: true, followLinks: true).toList();
      final paths = list.map((e) => e.path).toList();
      
      expect(paths, contains(link));
      expect(paths, contains('$link/file.txt'));

      final linkDirEntity = list.firstWhere((e) => e.path == link);
      expect(linkDirEntity, isA<Directory>());
    });

    test('Listing directory containing a broken symlink with followLinks: true yields WebLink', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final dir = '/broken_link_test_$uniqueId';
      final link = '$dir/broken_link';
      final nonexistentTarget = '/nonexistent_target_$uniqueId';

      await fs.directory(dir).create();
      await fs.link(link).create(nonexistentTarget);

      final list = await fs.directory(dir).list(followLinks: true).toList();
      expect(list.length, equals(1));
      expect(list.first.path, equals(link));
      expect(list.first, isA<Link>());
    });

    test('resolveSymbolicLinks resolves canonical path', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final dir = '/resolve_test_$uniqueId';
      final subDir = '$dir/subdir';
      final target = '$subDir/file.txt';
      final link = '$dir/link_to_file';

      await fs.directory(subDir).create(recursive: true);
      await fs.file(target).writeAsString('target');
      await fs.link(link).create(target);

      // Verify canonical link resolution
      expect(await fs.link(link).resolveSymbolicLinks(), equals(target));
      expect(await fs.file(link).resolveSymbolicLinks(), equals(target));

      // Verify canonical directory resolution
      final dirLink = '$dir/link_to_subdir';
      await fs.link(dirLink).create(subDir);
      expect(await fs.directory(dirLink).resolveSymbolicLinks(), equals(subDir));
    });

    test('IndexedDB concurrent database initialization does not fail or race', () async {
      final futures = <Future<bool>>[];
      for (int i = 0; i < 15; i++) {
        futures.add(WebFileSystem().file('/concurrent_$i.txt').exists());
      }
      final results = await Future.wait(futures);
      expect(results, hasLength(15));
      for (final result in results) {
        expect(result, isFalse);
      }
    });

    test('WebFile.create on existing file returns the file', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final file = fs.file('/create_existing_$uniqueId.txt');
      await file.create();
      expect(await file.exists(), isTrue);
      final sameFile = await file.create();
      expect(sameFile.path, equals(file.path));
    });

    test('WebFile.create recursive in nested directory structure', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final file = fs.file('/nested_$uniqueId/sub_$uniqueId/file.txt');
      await file.create(recursive: true);
      expect(await file.exists(), isTrue);
    });

    test('WebFile.writeAsBytes with FileMode.append throws UnsupportedError', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final file = fs.file('/append_test_$uniqueId.txt');
      await file.create();
      expect(
        () => file.writeAsBytes([1, 2], mode: FileMode.append),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('WebLink.create on existing link throws FileSystemException', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '/target_$uniqueId.txt';
      final linkPath = '/link_$uniqueId';

      await fs.file(targetPath).writeAsString('target-content');
      final link = fs.link(linkPath);
      await link.create(targetPath);

      expect(
        () => link.create(targetPath),
        throwsA(isA<FileSystemException>().having((e) => e.message, 'message', contains('Link already exists'))),
      );
    });

    test('WebLink.target on a non-link entity throws FileSystemException', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final filePath = '/file_$uniqueId.txt';
      await fs.file(filePath).writeAsString('some content');

      final link = fs.link(filePath);
      expect(
        () => link.target(),
        throwsA(isA<FileSystemException>().having((e) => e.message, 'message', contains('Not a link'))),
      );
    });

    test('Deep symbolic link chain throws ELOOP', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      await fs.directory('/dir0_$uniqueId').create();
      for (int i = 1; i <= 25; i++) {
        await fs.directory('/dir${i}_$uniqueId').create();
        await fs.link('/dir${i-1}_$uniqueId/link$i').create('/dir${i}_$uniqueId');
      }
      
      final pathParts = ['/dir0_$uniqueId'];
      for (int i = 1; i <= 25; i++) {
        pathParts.add('link$i');
      }
      final longPath = pathParts.join('/');
      
      expect(
        () => fs.file(longPath).readAsBytes(),
        throwsA(isA<FileSystemException>().having((e) => e.osError?.errorCode, 'errorCode', 40)),
      );
    });

    test('Relative symbolic link target resolution', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      await fs.directory('/dir_$uniqueId').create();
      await fs.file('/target_$uniqueId.txt').writeAsString('relative-target');
      await fs.link('/dir_$uniqueId/link_$uniqueId').create('../target_$uniqueId.txt');

      expect(
        await fs.file('/dir_$uniqueId/link_$uniqueId').readAsString(),
        equals('relative-target'),
      );
    });

    test('Treating file symlink as directory throws ENOTDIR', () async {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final filePath = '/file_$uniqueId.txt';
      final linkPath = '/link_$uniqueId';
      
      await fs.file(filePath).writeAsString('file-content');
      await fs.link(linkPath).create(filePath);

      expect(
        () => fs.file('$linkPath/child.txt').readAsBytes(),
        throwsA(isA<FileSystemException>().having((e) => e.osError?.errorCode, 'errorCode', 20)),
      );
    });

    test('resolveSymbolicLinks on root directory', () async {
      expect(await fs.resolveSymbolicLinks('/'), equals('/'));
    });
  });

  group('Benchmarks', () {
    test('BENCHMARK: Create 100 small files (Inode Stress)', () async {
      // Reduced from 1000 for CI stability in this environment
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final count = 100;
      final futures = <Future>[];

      await fs.directory('/bulk_$uniqueId').create();

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        futures.add(
          fs.file('/bulk_$uniqueId/file_$i.txt').writeAsString('small data $i'),
        );
      }
      await Future.wait(futures);
      stopwatch.stop();

      print('Created $count files in ${stopwatch.elapsedMilliseconds}ms');

      final listWatch = Stopwatch()..start();
      final files = await fs.directory('/bulk_$uniqueId').list().length;
      listWatch.stop();

      expect(files, equals(count));
      print('Listed $count files in ${listWatch.elapsedMilliseconds}ms');
    });

    test('BENCHMARK: Read/Write 10MB file (Streaming)', () async {
      // Reduced from 50MB to 10MB for quicker test cycle
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final chunkSize = 1024 * 1024;
      final chunk = Uint8List(chunkSize);
      for (int i = 0; i < chunkSize; i++) chunk[i] = i % 256;

      final file = fs.file('/video_$uniqueId.mp4');
      final sink = file.openWrite();

      final writeWatch = Stopwatch()..start();
      for (int i = 0; i < 10; i++) {
        // 10MB
        sink.add(chunk);
      }
      await sink.close();
      writeWatch.stop();

      print('Wrote 10MB in ${writeWatch.elapsedMilliseconds}ms');

      int totalBytes = 0;
      await for (final buffer in file.openRead()) {
        totalBytes += buffer.length;
      }

      expect(totalBytes, equals(10 * chunkSize));
    });
  });

  group('IdbInodeService Coverage', () {
    setUp(() {
      injectMockJS();
    });

    tearDown(() {
      setMockIDBOpenShouldFail(false);
      setMockIDBGetShouldFail(false);
      setMockIDBPutShouldFail(false);
      setMockIDBIndexGetShouldFail(false);
    });

    test('unique index violation triggers request.onerror', () async {
      final idb = fs.idb;
      // Ensure DB is ready
      await idb.getInode(IdbInodeService.rootId);

      // Create two different inodes with same parentId and name
      final inode1 = Inode(
        id: 'inode-1',
        parentId: IdbInodeService.rootId,
        name: 'duplicate-name',
        nodeType: 0,
        modified: DateTime.now().millisecondsSinceEpoch,
      );
      final inode2 = Inode(
        id: 'inode-2',
        parentId: IdbInodeService.rootId,
        name: 'duplicate-name',
        nodeType: 0,
        modified: DateTime.now().millisecondsSinceEpoch,
      );

      await idb.createInode(inode1);
      
      // The second one must throw Exception('IDB Error') due to unique index on (parentId, name)
      expect(
        () => idb.createInode(inode2),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('IDB Error'))),
      );
    });

    test('database open error triggers request.onerror', () async {
      setMockIDBOpenShouldFail(true);
      // Instantiate a new service so we call _init() again.
      final newService = IdbInodeService();
      expect(
        () => newService.getInode('some-id'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Failed to open IDB'))),
      );
    });

    test('_ensureRootExists failure triggers open request catchError', () async {
      setMockIDBGetShouldFail(true);
      setMockIDBPutShouldFail(true);
      final newService = IdbInodeService();
      expect(
        () => newService.getInode('some-id'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('IDB Error'))),
      );
    });

    test('getChild catches request.onerror and returns null', () async {
      final idb = fs.idb;
      // Ensure DB ready
      await idb.getInode(IdbInodeService.rootId);

      setMockIDBIndexGetShouldFail(true);
      final child = await idb.getChild(IdbInodeService.rootId, 'any-name');
      expect(child, isNull);
    });
  });

  group('OpfsBlockStore Coverage', () {
    test('writeBlob handles stream error and cleanup', () async {
      final store = OpfsBlockStore();
      final stream = Stream<List<int>>.error(Exception('Stream error'));
      expect(
        () => store.writeBlob(stream),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Stream error'))),
      );
    });

    test('readBlob rethrows exception on non-existent block', () async {
      final store = OpfsBlockStore();
      final nonExistentBlockId = '00000000-0000-0000-0000-000000000000';
      expect(
        () => store.readBlob(nonExistentBlockId).drain(),
        throwsA(anything),
      );
    });
  });
}

@JS('eval')
external JSAny? jsEval(String code);

void injectMockJS() {
  jsEval('''
    window.mockIDBOpenShouldFail = false;
    window.mockIDBGetShouldFail = false;
    window.mockIDBPutShouldFail = false;
    window.mockIDBIndexGetShouldFail = false;

    if (!window.hasInjectedIDBMocks) {
      window.hasInjectedIDBMocks = true;

      const originalOpen = IDBFactory.prototype.open;
      IDBFactory.prototype.open = function(name, version) {
        if (window.mockIDBOpenShouldFail) {
          const mockRequest = {
            set onsuccess(fn) { this._onsuccess = fn; },
            set onerror(fn) { this._onerror = fn; },
            set onupgradeneeded(fn) { this._onupgradeneeded = fn; },
            get target() { return this; }
          };
          setTimeout(() => {
            if (mockRequest._onerror) {
              mockRequest._onerror({ target: mockRequest });
            }
          }, 0);
          return mockRequest;
        }
        return originalOpen.apply(this, arguments);
      };

      const originalGet = IDBObjectStore.prototype.get;
      IDBObjectStore.prototype.get = function(key) {
        if (window.mockIDBGetShouldFail) {
          const mockRequest = {
            set onsuccess(fn) { this._onsuccess = fn; },
            set onerror(fn) { this._onerror = fn; },
            get target() { return this; }
          };
          setTimeout(() => {
            if (mockRequest._onerror) {
              mockRequest._onerror({ target: mockRequest });
            }
          }, 0);
          return mockRequest;
        }
        return originalGet.apply(this, arguments);
      };

      const originalPut = IDBObjectStore.prototype.put;
      IDBObjectStore.prototype.put = function(value) {
        if (window.mockIDBPutShouldFail) {
          const mockRequest = {
            set onsuccess(fn) { this._onsuccess = fn; },
            set onerror(fn) { this._onerror = fn; },
            get target() { return this; }
          };
          setTimeout(() => {
            if (mockRequest._onerror) {
              mockRequest._onerror({ target: mockRequest });
            }
          }, 0);
          return mockRequest;
        }
        return originalPut.apply(this, arguments);
      };

      const originalIndexGet = IDBIndex.prototype.get;
      IDBIndex.prototype.get = function(key) {
        if (window.mockIDBIndexGetShouldFail) {
          const mockRequest = {
            set onsuccess(fn) { this._onsuccess = fn; },
            set onerror(fn) { this._onerror = fn; },
            get target() { return this; }
          };
          setTimeout(() => {
            if (mockRequest._onerror) {
              mockRequest._onerror({ target: mockRequest });
            }
          }, 0);
          return mockRequest;
        }
        return originalIndexGet.apply(this, arguments);
      };
    }
  ''');
}

void setMockIDBOpenShouldFail(bool value) {
  jsEval('window.mockIDBOpenShouldFail = $value;');
}
void setMockIDBGetShouldFail(bool value) {
  jsEval('window.mockIDBGetShouldFail = $value;');
}
void setMockIDBPutShouldFail(bool value) {
  jsEval('window.mockIDBPutShouldFail = $value;');
}
void setMockIDBIndexGetShouldFail(bool value) {
  jsEval('window.mockIDBIndexGetShouldFail = $value;');
}
