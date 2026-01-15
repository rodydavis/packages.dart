import 'dart:io';

void main() async {
  final rootDir = Directory.current;
  await _processDirectory(Directory('${rootDir.path}/packages'));
  await _processDirectory(Directory('${rootDir.path}/experimental'));
  await _processDirectory(Directory('${rootDir.path}/deprecated'));
  print('Done enforcing publish_to: none in example directories.');
}

Future<void> _processDirectory(Directory dir) async {
  if (!dir.existsSync()) return;

  await for (final entity in dir.list(recursive: true)) {
    if (entity is Directory) {
      final segments = entity.path.split(Platform.pathSeparator);
      if (segments.last == 'example' || segments.last == 'examples') {
        final pubspecFile = File('${entity.path}/pubspec.yaml');
        if (pubspecFile.existsSync()) {
          await _enforcePublishToNone(pubspecFile);
        }
      }
    }
  }
}

Future<void> _enforcePublishToNone(File pubspecFile) async {
  final lines = await pubspecFile.readAsLines();
  bool hasPublishTo = false;
  bool isModified = false;
  final newLines = <String>[];

  for (final line in lines) {
    if (line.trim().startsWith('publish_to:')) {
      hasPublishTo = true;
      if (!line.contains("'none'") && !line.contains('"none"') && !line.contains('none')) {
        newLines.add("publish_to: 'none'");
        isModified = true;
      } else {
        newLines.add(line);
      }
    } else {
      newLines.add(line);
    }
  }

  if (!hasPublishTo) {
     // Insert after version or description if possible, otherwise at end
     int insertIndex = -1;
     for (int i = 0; i < newLines.length; i++) {
        if (newLines[i].startsWith('version:') || newLines[i].startsWith('description:')) {
            insertIndex = i + 1;
        }
     }
     if (insertIndex != -1) {
         newLines.insert(insertIndex, "publish_to: 'none'");
     } else {
         newLines.add("publish_to: 'none'");
     }
     isModified = true;
  }

  if (isModified) {
    await pubspecFile.writeAsString(newLines.join('\n') + '\n');
    print('Updated ${pubspecFile.path}');
  }
}
