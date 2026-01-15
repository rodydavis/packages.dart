// Copyright 2017 Google Inc.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

import 'dart:async';

import '../generators/widget.dart';
import '../path_util.dart';
import 'command.dart';

/// Handles the `generate widget` ngflutter command.
class GenerateWidgetCommand extends NgDartCommand {
  static const _pathOption = 'path';

  String get name => 'widget';
  String get description => 'Generate Flutter Widget.';
  String get invocation => '${NgDartCommand.binaryName} generate widget '
      '<WidgetName> [--path <widget/file/path>]';

  String get _widgetPath => getNormalizedPath(argResults[_pathOption]);

  GenerateWidgetCommand() {
    argParser.addOption(_pathOption,
        abbr: 'p', help: 'Widget file path', defaultsTo: 'lib/ui/common');
  }

  Future run() async {
    await new WidgetGenerator(
            readArgAsEntityName('Widget name is needed.'), _widgetPath)
        .generate();
  }
}
