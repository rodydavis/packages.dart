import 'dart:async';

import 'package:firebase/firebase.dart';
import 'package:firebase/firebase.dart' as fb;
import 'package:universal_html/prefer_universal/html.dart' as html;

import 'data/classes/event.dart';
import 'impl.dart';

class FbStorage implements FbStorageImpl {
  html.FileUploadInputElement _images, _videos, _files;
  FbStorage({
    this.owner = 'Guest',
    this.filesPath = 'files',
    this.imagesPath = 'images',
    this.videosPath = 'videos',
  }) {
    _images = html.FileUploadInputElement();
    _images.accept = "image/*";
    _images.onChange.listen((e) {
      html.File file = (e.target as dynamic).files[0];
      if (file != null) {
        _uploadFile(file, imagesPath, owner, UploadType.image);
      }
    });
    _videos = html.FileUploadInputElement();
    _videos.accept = "video/*";
    _videos.onChange.listen((e) {
      html.File file = (e.target as dynamic).files[0];
      if (file != null) {
        _uploadFile(file, videosPath, owner, UploadType.video);
      }
    });
    _files = html.FileUploadInputElement();
    _files.accept = "*";
    _files.onChange.listen((e) {
      html.File file = (e.target as dynamic).files[0];
      if (file != null) {
        _uploadFile(file, filesPath, owner, UploadType.file);
      }
    });
  }

  @override
  Future<String> uploadString(
    String data,
    String fileName, {
    String folder = 'files',
    String contentType = 'text/plain',
  }) async {
    try {
      final StorageReference ref = storage().ref('$folder');
      var customMetadata = {"owner": owner};
      var uploadTask = ref.child('$fileName').putString(
            data,
            StringFormat.RAW,
            UploadMetadata(
              contentType: contentType,
              customMetadata: customMetadata,
            ),
          );
      var snapshot = await uploadTask.future;
      final _url = await snapshot.ref.getDownloadURL();
      return _url.toString();
    } catch (e) {
      print(e);
    }
    return null;
  }

  @override
  void captureUploadPhoto() async {
    _images.click();
    return null;
  }

  @override
  void captureUploadVideo() async {
    _videos.click();
    return null;
  }

  @override
  void pickAndUploadFile() async {
    _files.click();
    return null;
  }

  @override
  void pickUploadPhoto() async {
    _images.click();
    return null;
  }

  @override
  void pickUploadVideo() async {
    _videos.click();
    return null;
  }

  void _uploadFile(
      html.File file, String path, String owner, UploadType type) async {
    print('Uploading File...');
    _controller.add(FileUploadEvent(
      url: '',
      owner: owner,
      path: path,
      type: type,
      loading: true,
    ));
    UploadTask uploadTask;
    try {
      var ref = fb
          .storage()
          .ref('$path/' + DateTime.now().millisecondsSinceEpoch.toString());
      uploadTask = ref.put(file);
    } catch (e) {
      throw 'Error Creating File';
    }
    UploadTaskSnapshot snapshot;
    try {
      snapshot = await uploadTask.future;
    } catch (e) {
      throw 'Error Uploading File';
    }
    try {
      final _url = await snapshot.ref.getDownloadURL();
      _controller.add(FileUploadEvent(
        url: _url ?? '',
        owner: owner,
        path: path,
        type: type,
        loading: false,
      ));
    } catch (e) {
      throw 'Error Getting Url';
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
