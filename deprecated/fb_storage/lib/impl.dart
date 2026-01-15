import 'data/classes/event.dart';

abstract class FbStorageImpl {
  final String imagesPath, filesPath, videosPath;
  final String owner;

  FbStorageImpl({
    this.owner,
    this.imagesPath,
    this.filesPath,
    this.videosPath,
  });

  Future<String> uploadString(
    String data,
    String fileName, {
    String folder = 'files',
    String contentType = 'text/plain',
  });

  void captureUploadPhoto();

  void captureUploadVideo();

  void pickUploadPhoto();

  void pickUploadVideo();

  void pickAndUploadFile();

  Stream<FileUploadEvent> get fileUploadedStream;

  void dispose();
}
