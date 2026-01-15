import 'dart:io';

void main() async {
  final rootDir = Directory.current;
  final packagesDir = Directory('${rootDir.path}/packages');
  final experimentalDir = Directory('${rootDir.path}/experimental');
  final deprecatedDir = Directory('${rootDir.path}/deprecated');
  final readmeFile = File('${rootDir.path}/README.md');

  final submodules = await _loadSubmodules(rootDir);

  final packages = await _scanDirectory(packagesDir, submodules, rootDir);
  final experimental =
      await _scanDirectory(experimentalDir, submodules, rootDir);
  final deprecated = await _scanDirectory(deprecatedDir, submodules, rootDir);

  final sb = StringBuffer();
  sb.writeln('# packages.dart');
  sb.writeln();
  sb.writeln('A collection of Flutter packages maintained by @rodydavis.');
  sb.writeln();

  _writeSection(sb, 'Packages', packages);
  _writeSection(sb, 'Experimental', experimental);
  _writeSection(sb, 'Deprecated', deprecated);

  await readmeFile.writeAsString(sb.toString());
  print('README.md updated.');
}

void _writeSection(StringBuffer sb, String title, List<_Package> packages) {
  if (packages.isEmpty) return;
  sb.writeln('## $title');
  sb.writeln();
  sb.writeln('| Package | Description | Version |');
  sb.writeln('| :--- | :--- | :--- |');
  for (final pkg in packages) {
    final badge = pkg.isPublished
        ? '[![Pub](https://img.shields.io/pub/v/${pkg.name}.svg?style=popout)](https://pub.dartlang.org/packages/${pkg.name})'
        : '![Unpublished](https://img.shields.io/badge/pub-unpublished-inactive)';
    sb.writeln('| [${pkg.name}](${pkg.path}) | ${pkg.description} | $badge |');
  }
  sb.writeln();
}

Future<Map<String, String>> _loadSubmodules(Directory rootDir) async {
  final gitmodulesFile = File('${rootDir.path}/.gitmodules');
  final submodules = <String, String>{};

  if (gitmodulesFile.existsSync()) {
    final lines = await gitmodulesFile.readAsLines();
    String? currentPath;
    String? currentUrl;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('path = ')) {
        currentPath = trimmed.substring(7).trim();
      } else if (trimmed.startsWith('url = ')) {
        currentUrl = trimmed.substring(6).trim();
      }

      if (currentPath != null && currentUrl != null) {
        submodules[currentPath] = currentUrl;
        currentPath = null;
        currentUrl = null;
      }
    }
  }
  return submodules;
}

Future<List<_Package>> _scanDirectory(
    Directory dir, Map<String, String> submodules, Directory rootDir) async {
  if (!dir.existsSync()) {
    return [];
  }

  final packages = <_Package>[];

  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('pubspec.yaml')) {
      // Skip if likely in a build or hidden folder (simple heuristic)
      if (entity.path.contains('/.') || entity.path.contains('/build/')) {
        continue;
      }

      // Skip example directories
      if (entity.parent.path.split(Platform.pathSeparator).contains('example') ||
          entity.parent.path.split(Platform.pathSeparator).contains('examples')) {
        continue;
      }

      final pubspecContent = await entity.readAsString();
      final name = _getValue(pubspecContent, 'name');
      final description = _getValue(pubspecContent, 'description');
      final version = _getValue(pubspecContent, 'version');
      final publishTo = _getValue(pubspecContent, 'publish_to');

      if (name != null && version != null) {
        // Calculate relative path from root
        var relativePath = entity.parent.path.replaceFirst(rootDir.path, '.');
        if (relativePath.startsWith('./')) {
          relativePath = relativePath.substring(2);
        }

        // Check for submodule match
        String? linkPath;
        for (final entry in submodules.entries) {
          final subPath = entry.key;
          final subUrl = entry.value;
          if (relativePath.startsWith(subPath)) {
            // It is inside this submodule
            // Verify if it is exact match or subdir
            if (relativePath == subPath ||
                relativePath.startsWith('$subPath/')) {
              final remainder = relativePath.substring(subPath.length);
              // Remove leading slash if present
              final cleanRemainder = remainder.startsWith('/')
                  ? remainder.substring(1)
                  : remainder;

              // Construct URL
              // Assuming standard GitHub structure: url/tree/main/path
              // If cleanRemainder is empty, we link to root
              if (cleanRemainder.isEmpty) {
                linkPath = subUrl;
              } else {
                linkPath = '$subUrl/tree/main/$cleanRemainder';
              }
              break;
            }
          }
        }

        // Fallback to local relative path if not in submodule (add ./ back for consistency if desired, or keep as relative path string)
        if (linkPath == null) {
          linkPath = './$relativePath';
        }

        packages.add(_Package(
          name: name,
          description: description ?? '',
          path: linkPath,
          isPublished: publishTo != 'none',
        ));
      }
    }
  }

  packages.sort((a, b) => a.name.compareTo(b.name));
  return packages;
}

String? _getValue(String content, String key) {
  final regex = RegExp('^$key:\\s*(.*)\$', multiLine: true);
  final match = regex.firstMatch(content);
  var value = match?.group(1)?.trim();
  if (value != null) {
    if (value.startsWith("'") && value.endsWith("'")) {
      value = value.substring(1, value.length - 1);
    } else if (value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
  }
  return value;
}

class _Package {
  final String name;
  final String description;
  final String path;
  final bool isPublished;

  _Package({
    required this.name,
    required this.description,
    required this.path,
    required this.isPublished,
  });
}
