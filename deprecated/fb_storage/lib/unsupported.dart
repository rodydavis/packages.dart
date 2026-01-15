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
  final String owner;

  @override
  final String filesPath;

  @override
  final String imagesPath;

  @override
  final String videosPath;

  @override
  void captureUploadPhoto() {
    throw 'Platform Not Supported';
  }

  @override
  void captureUploadVideo() {
    throw 'Platform Not Supported';
  }

  @override
  void pickAndUploadFile() {
    throw 'Platform Not Supported';
  }

  @override
  void pickUploadPhoto() {
    throw 'Platform Not Supported';
  }

  @override
  void pickUploadVideo() {
    throw 'Platform Not Supported';
  }

  @override
  Future<String> uploadString(
    String data,
    String fileName, {
    String folder = 'files',
    String contentType = 'text/plain',
  }) {
    throw 'Platform Not Supported';
  }

  @override
  Stream<FileUploadEvent> get fileUploadedStream => null;

  @override
  void dispose() {}
}
