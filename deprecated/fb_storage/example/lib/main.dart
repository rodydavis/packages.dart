import 'package:fb_storage/fb_storage.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FbStorage _storage = FbStorage();
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _storage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Unify Connect Admin'),
        ),
        body: StreamBuilder<FileUploadEvent>(
            stream: _storage.fileUploadedStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data.loading) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.data.url.isEmpty) {
                  return Center(
                    child: Text('No Url'),
                  );
                }
                return Center(
                  child: Text(snapshot.data.url),
                );
              }
              return Center(
                child: Text('Upload a File'),
              );
            }),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.file_upload),
          onPressed: () {
            _uploadFile();
          },
        ),
      ),
    );
  }

  void _uploadImage() {
    _storage.pickUploadPhoto();
  }

  void _uploadVideo() {
    _storage.pickUploadVideo();
  }

  void _uploadFile() {
    _storage.pickAndUploadFile();
  }

  void _uploadString() {
    _storage.uploadString('{}', 'test.json').then((data) {});
  }
}
