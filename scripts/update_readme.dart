import 'dart:io';

void main() async {
  final rootDir = Directory.current;
  final packagesDir = Directory('${rootDir.path}/packages');
  final readmeFile = File('${rootDir.path}/README.md');

  if (!packagesDir.existsSync()) {
    print('Error: packages directory not found at ${packagesDir.path}');
    return;
  }

  final packages = <_Package>[];

  await for (final entity in packagesDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('pubspec.yaml')) {
      // Skip if likely in a build or hidden folder (simple heuristic)
      if (entity.path.contains('/.') || entity.path.contains('/build/')) {
        continue;
      }

      final pubspecContent = await entity.readAsString();
      final name = _getValue(pubspecContent, 'name');
      final description = _getValue(pubspecContent, 'description');
      final version = _getValue(pubspecContent, 'version');
      final publishTo = _getValue(pubspecContent, 'publish_to');

      if (name != null && version != null && publishTo != 'none') {
        // Calculate relative path from root
        final relativePath = entity.parent.path.replaceFirst(rootDir.path, '.');

        packages.add(_Package(
          name: name,
          description: description ?? '',
          path: relativePath,
        ));
      }
    }
  }

  packages.sort((a, b) => a.name.compareTo(b.name));

  final sb = StringBuffer();
  sb.writeln('# packages.dart');
  sb.writeln();
  sb.writeln('A collection of Flutter packages maintained by @rodydavis.');
  sb.writeln();
  sb.writeln('## Packages');
  sb.writeln();
  sb.writeln('| Package | Description | Version |');
  sb.writeln('| :--- | :--- | :--- |');

  for (final pkg in packages) {
    sb.writeln(
        '| [${pkg.name}](${pkg.path}) | ${pkg.description} | [![Pub](https://img.shields.io/pub/v/${pkg.name}.svg?style=popout)](https://pub.dartlang.org/packages/${pkg.name}) |');
  }

  await readmeFile.writeAsString(sb.toString());
  print('README.md updated with ${packages.length} packages.');
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

  _Package({required this.name, required this.description, required this.path});
}
