// Copyright 2017 Google Inc.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:recase/recase.dart';

import '../generator.dart';

/// Generator for Flutter Widget.
class WidgetGenerator extends Generator {
  static const _templateFolder = 'widgets';
  static const List<String> _templateFileNames = const [
    'widget.dart.mustache',
  ];

  /// Class name of this Widget.
  final String className;

  final String selector;

  /// Widget file name without extension.
  final String targetName;

  WidgetGenerator._(
      this.className, this.selector, this.targetName, String destinationFolder)
      : super(destinationFolder);

  factory WidgetGenerator(
    ReCase classEntityName,
    String destinationFolder,
  ) {
    return new WidgetGenerator._(
        classEntityName.pascalCase,
        classEntityName.paramCase,
        classEntityName.snakeCase,
        destinationFolder);
  }

  // Gets a map from template file name to target file name.
  Map<String, String> _getTemplateTargetPaths() {
    var results = <String, String>{};
    for (String templateFileName in _templateFileNames) {
      final _template = path.join(_templateFolder, templateFileName);
      final _path = '$targetName.${templateFileName.split('.')[1]}';
      print('Path: $_template -> $_path');
      results[_template] = _path;
    }

    return results;
  }

  @override
  Future generate() async {
    await renderAndWriteTemplates(_getTemplateTargetPaths());
  }

  @override
  Map<String, String> toMap() {
    return {
      "className": className,
      "selector": selector,
      "targetName": targetName,
    };
  }
}
