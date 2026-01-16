import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  final rootDir = Directory.current;
  final licenseFile = File(path.join(rootDir.path, 'LICENSE'));

  if (!licenseFile.existsSync()) {
    print('Error: Root LICENSE file not found at ${licenseFile.path}');
    exit(1);
  }

  final licenseContent = await licenseFile.readAsString();
  final targetDirs = ['experimental', 'packages', 'deprecated'];

  int count = 0;

  for (final targetName in targetDirs) {
    final targetDir = Directory(path.join(rootDir.path, targetName));

    if (!targetDir.existsSync()) {
      print('Skipping $targetName: Directory not found.');
      continue;
    }

    await for (final entity in targetDir.list()) {
      if (entity is Directory) {
        // Skip hidden directories (starting with .)
        if (path.basename(entity.path).startsWith('.')) continue;

        final destLicenseFile = File(path.join(entity.path, 'LICENSE'));

        try {
          await destLicenseFile.writeAsString(licenseContent);
          print('Copied LICENSE to ${entity.path}');
          count++;
        } catch (e) {
          print('Error copying LICENSE to ${entity.path}: $e');
        }
      }
    }
  }

  print('\nSuccessfully copied LICENSE to $count packages.');
}
