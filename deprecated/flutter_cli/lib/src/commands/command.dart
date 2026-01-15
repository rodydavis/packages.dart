// Copyright 2017 Google Inc.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:recase/recase.dart';

/// Base class for commands for ngflutter executable.
abstract class NgDartCommand extends Command {
  static const binaryName = 'ngflutter';
  ArgParser get argParser => _argParser;
  final _argParser = new ArgParser(allowTrailingOptions: true);

  /// Reads argument for current command.
  String readArg(String errorMessage) {
    var args = argResults.rest;

    if (args == null || args.length == 0) {
      // Usage is provided by command runner.
      throw new UsageException(errorMessage, '');
    }

    var arg = args.first;
    args = args.skip(1).toList();

    if (args.length > 0) {
      throw new UsageException('Unexpected argument $args', '');
    }

    return arg;
  }

  /// Reads argument for current command and create an EntityName.
  ReCase readArgAsEntityName(String errorMessage) =>
      getEntityName(readArg(errorMessage));

  ReCase getEntityName(String entity) {
    ReCase entityName;

    try {
      entityName = new ReCase(entity);
    } on ArgumentError catch (error) {
      throw new UsageException(error.message, '');
    }

    return entityName;
  }
}
