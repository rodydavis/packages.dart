import 'dart:js_interop';
import 'dart:typed_data';

@JS('eval')
external JSAny? _jsEval(String code);

@JS('globalThis.registerVFSWorkerProxy')
external void _registerVFSWorkerProxy(JSAny worker, JSAny asyncFS);

@JS('globalThis.initVFSSyncWorker')
external void _initVFSSyncWorker();

@JS('globalThis.sendVFSSyncRequest')
external JSUint8Array _sendVFSSyncRequest(int cmd, JSUint8Array requestBytes);

@JS('globalThis.isVFSSyncWorkerInitialized')
external bool? get _isVFSSyncWorkerInitialized;

@JS('globalThis.SharedArrayBuffer')
external JSAny? get _sharedArrayBufferClass;

class SyncRpcHelper {
  static bool get isSharedArrayBufferSupported {
    try {
      return _sharedArrayBufferClass != null;
    } catch (_) {
      return false;
    }
  }

  static bool get isWorker {
    // In a worker, globalThis.document is undefined and globalThis.importScripts is defined
    try {
      final isWorkerResult = _jsEval("typeof importScripts !== 'undefined'");
      return (isWorkerResult as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  static void injectHelperScripts() {
    _jsEval('''
      if (typeof globalThis.registerVFSWorkerProxy === 'undefined') {
        globalThis.registerVFSWorkerProxy = function(worker, asyncFS) {
          let sab;
          let statusArray;
          let payloadArray;

          worker.addEventListener('message', async function(e) {
            if (!e.data) return;
            if (e.data.type === 'INIT_SYNC_VFS') {
              sab = e.data.buffer;
              statusArray = new Int32Array(sab);
              payloadArray = new Uint8Array(sab);
              return;
            }
            if (e.data.type === 'SYNC_REQ') {
              const cmd = statusArray[1];
              const reqLen = statusArray[2];
              const decoder = new TextDecoder();
              const reqBytes = payloadArray.subarray(64, 64 + reqLen);
              
              try {
                let result;
                if (cmd === 1) { // exists
                  const path = decoder.decode(reqBytes);
                  const type = await asyncFS.type(path);
                  result = type.toString() !== 'FileSystemEntityType.notFound';
                  payloadArray[64] = result ? 1 : 0;
                  statusArray[3] = 1;
                } else if (cmd === 2) { // type
                  const followLinks = reqBytes[0] === 1;
                  const path = decoder.decode(reqBytes.subarray(1));
                  const type = await asyncFS.type(path, { followLinks });
                  const typeStr = type.toString().split('.').pop();
                  const typeBytes = new TextEncoder().encode(typeStr);
                  payloadArray.set(typeBytes, 64);
                  statusArray[3] = typeBytes.length;
                } else if (cmd === 3) { // readBytes
                  const path = decoder.decode(reqBytes);
                  const bytes = await asyncFS.file(path).readAsBytes();
                  payloadArray.set(bytes, 64);
                  statusArray[3] = bytes.length;
                } else if (cmd === 4) { // writeBytes
                  const view = new DataView(reqBytes.buffer, reqBytes.byteOffset, reqBytes.byteLength);
                  const pathLen = view.getUint32(0, true);
                  const path = decoder.decode(reqBytes.subarray(4, 4 + pathLen));
                  const content = reqBytes.subarray(4 + pathLen);
                  await asyncFS.file(path).writeAsBytes(content);
                  statusArray[3] = 0;
                } else if (cmd === 5) { // createDir
                  const path = decoder.decode(reqBytes);
                  await asyncFS.directory(path).create(recursive: true);
                  statusArray[3] = 0;
                } else if (cmd === 6) { // delete
                  const path = decoder.decode(reqBytes);
                  await asyncFS.file(path).delete(recursive: true);
                  statusArray[3] = 0;
                } else if (cmd === 7) { // createLink
                  const view = new DataView(reqBytes.buffer, reqBytes.byteOffset, reqBytes.byteLength);
                  const pathLen = view.getUint32(0, true);
                  const path = decoder.decode(reqBytes.subarray(4, 4 + pathLen));
                  const target = decoder.decode(reqBytes.subarray(4 + pathLen));
                  await asyncFS.link(path).create(target);
                  statusArray[3] = 0;
                } else if (cmd === 8) { // readLink
                  const path = decoder.decode(reqBytes);
                  const target = await asyncFS.link(path).target();
                  const targetBytes = new TextEncoder().encode(target);
                  payloadArray.set(targetBytes, 64);
                  statusArray[3] = targetBytes.length;
                } else if (cmd === 9) { // stat
                  const path = decoder.decode(reqBytes);
                  const stat = await asyncFS.stat(path);
                  const statData = {
                    type: stat.type.toString().split('.').pop(),
                    size: stat.size,
                    modified: stat.modified.millisecondsSinceEpoch
                  };
                  const statBytes = new TextEncoder().encode(JSON.stringify(statData));
                  payloadArray.set(statBytes, 64);
                  statusArray[3] = statBytes.length;
                } else if (cmd === 10) { // list
                  const path = decoder.decode(reqBytes);
                  const list = await asyncFS.directory(path).list(recursive: false, followLinks: false).toList();
                  const entities = list.map(e => ({
                    path: e.path,
                    type: e.runtimeType.toString().toLowerCase().replace('impl', '').replace('web', '')
                  }));
                  const listBytes = new TextEncoder().encode(JSON.stringify(entities));
                  payloadArray.set(listBytes, 64);
                  statusArray[3] = listBytes.length;
                } else if (cmd === 11) { // resolveSymbolicLinks
                  const path = decoder.decode(reqBytes);
                  const resolved = await asyncFS.resolveSymbolicLinks(path);
                  const resolvedBytes = new TextEncoder().encode(resolved);
                  payloadArray.set(resolvedBytes, 64);
                  statusArray[3] = resolvedBytes.length;
                } else if (cmd === 12) { // rename
                  const view = new DataView(reqBytes.buffer, reqBytes.byteOffset, reqBytes.byteLength);
                  const pathLen = view.getUint32(0, true);
                  const path = decoder.decode(reqBytes.subarray(4, 4 + pathLen));
                  const newPath = decoder.decode(reqBytes.subarray(4 + pathLen));
                  
                  const inode = await asyncFS.resolvepath(path);
                  const newParentDir = asyncFS.path.dirname(newPath);
                  const newName = asyncFS.path.basename(newPath);
                  const newParentInode = await asyncFS.resolvepath(newParentDir);
                  
                  inode.parentId = newParentInode.id;
                  inode.name = newName;
                  inode.modified = Date.now();
                  await asyncFS.idb.updateInode(inode);
                  statusArray[3] = 0;
                } else if (cmd === 13) { // updateLink
                  const view = new DataView(reqBytes.buffer, reqBytes.byteOffset, reqBytes.byteLength);
                  const pathLen = view.getUint32(0, true);
                  const path = decoder.decode(reqBytes.subarray(4, 4 + pathLen));
                  const target = decoder.decode(reqBytes.subarray(4 + pathLen));
                  await asyncFS.link(path).update(target);
                  statusArray[3] = 0;
                }
                
                Atomics.store(statusArray, 0, 2); // completed
              } catch (err) {
                console.error("VFS Proxy Error:", err);
                const errBytes = new TextEncoder().encode(err.toString());
                payloadArray.set(errBytes, 64);
                statusArray[3] = errBytes.length;
                Atomics.store(statusArray, 0, 3); // error
              }
              Atomics.notify(statusArray, 0);
            }
          });
        };
      }

      if (typeof globalThis.initVFSSyncWorker === 'undefined') {
        globalThis.isVFSSyncWorkerInitialized = false;
        globalThis.initVFSSyncWorker = function() {
          if (globalThis.isVFSSyncWorkerInitialized) return;
          const sab = new SharedArrayBuffer(1024 * 1024 * 10); // 10MB
          const statusArray = new Int32Array(sab);
          const payloadArray = new Uint8Array(sab);
          
          globalThis.postMessage({ type: 'INIT_SYNC_VFS', buffer: sab });
          
          globalThis.sendVFSSyncRequest = function(cmd, requestBytes) {
            while (Atomics.load(statusArray, 0) !== 0) {
              // Idle wait
            }
            statusArray[1] = cmd;
            statusArray[2] = requestBytes.length;
            payloadArray.set(requestBytes, 64);
            
            Atomics.store(statusArray, 0, 1);
            globalThis.postMessage({ type: 'SYNC_REQ' });
            
            Atomics.wait(statusArray, 0, 1);
            
            const status = Atomics.load(statusArray, 0);
            const respLen = statusArray[3];
            const respBytes = payloadArray.slice(64, 64 + respLen);
            
            Atomics.store(statusArray, 0, 0);
            
            if (status === 3) {
              throw new Error(new TextDecoder().decode(respBytes));
            }
            return respBytes;
          };
          globalThis.isVFSSyncWorkerInitialized = true;
        };
      }
    ''');
  }

  static void registerWorkerProxy(JSAny worker, JSAny asyncFS) {
    injectHelperScripts();
    _registerVFSWorkerProxy(worker, asyncFS);
  }

  static void initSyncWorker() {
    injectHelperScripts();
    _initVFSSyncWorker();
  }

  static Uint8List sendSyncRequest(int cmd, Uint8List requestBytes) {
    if (_isVFSSyncWorkerInitialized != true) {
      initSyncWorker();
    }
    return _sendVFSSyncRequest(cmd, requestBytes.toJS).toDart;
  }
}
