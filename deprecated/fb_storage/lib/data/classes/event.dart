import 'package:flutter/foundation.dart';

class FileUploadEvent {
  final String url;
  final String path;
  final String owner;
  final UploadType type;
  final bool loading;

  FileUploadEvent({
    @required this.url,
    @required this.path,
    @required this.owner,
    this.type = UploadType.file,
    @required this.loading,
  });
}

enum UploadType {
  file,
  image,
  video,
}
