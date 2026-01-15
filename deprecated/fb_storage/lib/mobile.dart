import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'data/classes/event.dart';
import 'impl.dart';

class FbStorage implements FbStorageImpl {
  FbStorage({
    this.owner = 'Guest',
    this.filesPath = 'files',
    this.imagesPath = 'images',
    this.videosPath = 'videos',
  });

  @override
  void captureUploadPhoto() async {
    final _file = await ImagePicker.pickImage(source: ImageSource.camera);
    if (_file != null) {
      await _uploadFile(_file, imagesPath, owner, UploadType.image);
    }
    return null;
  }

  @override
  void captureUploadVideo() async {
    final _file = await ImagePicker.pickVideo(source: ImageSource.camera);
    if (_file != null) {
      await _uploadFile(_file, videosPath, owner, UploadType.video);
    }
    return null;
  }

  @override
  void pickAndUploadFile() async {
    final _file = await FilePicker.getFile();
    if (_file != null) {
      await _uploadFile(_file, filesPath, owner, UploadType.file);
    }
    return null;
  }

  @override
  void pickUploadPhoto() async {
    final _file = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (_file != null) {
      await _uploadFile(_file, imagesPath, owner, UploadType.image);
    }
    return null;
  }

  @override
  void pickUploadVideo() async {
    final _file = await ImagePicker.pickVideo(source: ImageSource.gallery);
    if (_file != null) {
      await _uploadFile(_file, videosPath, owner, UploadType.video);
    }
    return null;
  }

  @override
  Future<String> uploadString(
    String data,
    String fileName, {
    String folder = 'files',
    String contentType = 'text/plain',
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(data);
    final _storage = FirebaseStorage.instance;
    final StorageReference ref = _storage.ref();
    var customMetadata = {"owner": owner};
    var uploadTask = ref.child('$folder').putFile(
          file,
          StorageMetadata(
            contentType: contentType,
            customMetadata: customMetadata,
          ),
        );
    try {
      var snapshot = await uploadTask.onComplete;
      final _url = await snapshot.ref.getDownloadURL();
      return _url.toString();
    } catch (e) {
      print(e);
    }
    return null;
  }

  Future _uploadFile(
      File _file, String path, String owner, UploadType type) async {
    _controller.add(FileUploadEvent(
      url: '',
      owner: owner,
      path: path,
      type: type,
      loading: true,
    ));
    final _storage = FirebaseStorage.instance;
    final StorageReference ref = _storage.ref();
    var customMetadata = {"owner": owner};
    var uploadTask = ref
        .child('$path/' + DateTime.now().millisecondsSinceEpoch.toString())
        .putFile(
          _file,
          StorageMetadata(
            customMetadata: customMetadata,
          ),
        );
    try {
      var snapshot = await uploadTask.onComplete;
      final _url = await snapshot.ref.getDownloadURL();
      _controller.add(FileUploadEvent(
        url: _url ?? '',
        owner: owner,
        path: path,
        type: type,
        loading: false,
      ));
    } catch (e) {
      print(e);
    }
    return null;
  }

  @override
  final String owner;

  @override
  final String filesPath;

  @override
  final String imagesPath;

  @override
  final String videosPath;

  @override
  Stream<FileUploadEvent> get fileUploadedStream => _controller.stream;

  final _controller = StreamController<FileUploadEvent>();

  @override
  void dispose() {
    _controller.close();
  }
}
