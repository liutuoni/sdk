// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

/// A long [Timeout] is provided for tests that start a process on
/// `bin/dartdev.dart` as the command is not compiled ahead of time, and each
/// invocation requires the VM to compile the entire dependency graph.
const Timeout longTimeout = Timeout(Duration(minutes: 5));

/// This version of dart is the last guaranteed pre-null safety language
/// version:
const String dartVersionFilePrefix2_9 = '// @dart = 2.9\n';

TestProject project(
        {String mainSrc,
        String analysisOptions,
        bool logAnalytics = false,
        String name = TestProject._defaultProjectName,
        VersionConstraint sdkConstraint,
        Map<String, dynamic> pubspec}) =>
    TestProject(
        mainSrc: mainSrc,
        analysisOptions: analysisOptions,
        logAnalytics: logAnalytics,
        sdkConstraint: sdkConstraint,
        pubspec: pubspec);

class TestProject {
  static const String _defaultProjectName = 'dartdev_temp';

  Directory dir;

  String get dirPath => dir.path;

  String get mainPath => path.join(dirPath, relativeFilePath);

  final String name;

  String get relativeFilePath => 'lib/main.dart';

  final bool logAnalytics;

  final VersionConstraint sdkConstraint;

  final Map<String, dynamic> pubspec;

  TestProject(
      {String mainSrc,
      String analysisOptions,
      this.name = _defaultProjectName,
      this.logAnalytics = false,
      this.sdkConstraint,
      this.pubspec}) {
    dir = Directory.systemTemp.createTempSync('a');
    file(
        'pubspec.yaml',
        pubspec == null
            ? '''
name: $name
environment:
  sdk: '${sdkConstraint ?? '>=2.10.0 <3.0.0'}'

dev_dependencies:
  test: any
'''
            : json.encode(pubspec));
    if (analysisOptions != null) {
      file('analysis_options.yaml', analysisOptions);
    }
    if (mainSrc != null) {
      file(relativeFilePath, mainSrc);
    }
  }

  void file(String name, String contents) {
    var file = File(path.join(dir.path, name));
    file.parent.createSync();
    file.writeAsStringSync(contents);
  }

  void deleteFile(String name) {
    var file = File(path.join(dir.path, name));
    assert(file.existsSync());
    file.deleteSync();
  }

  void dispose() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  ProcessResult runSync(
    List<String> arguments, {
    String workingDir,
  }) {
    return Process.runSync(
        Platform.resolvedExecutable,
        [
          '--no-analytics',
          ...arguments,
        ],
        workingDirectory: workingDir ?? dir.path,
        environment: {if (logAnalytics) '_DARTDEV_LOG_ANALYTICS': 'true'},
        stdoutEncoding: utf8);
  }

  Future<Process> start(
    List<String> arguments, {
    String workingDir,
  }) {
    return Process.start(
        Platform.resolvedExecutable,
        [
          '--no-analytics',
          ...arguments,
        ],
        workingDirectory: workingDir ?? dir.path,
        environment: {if (logAnalytics) '_DARTDEV_LOG_ANALYTICS': 'true'});
  }

  String _sdkRootPath;

  /// Return the root of the SDK.
  String get sdkRootPath {
    if (_sdkRootPath == null) {
      // Assumes the script importing this one is somewhere under the SDK.
      String current = path.canonicalize(Platform.script.toFilePath());
      do {
        String tryDir = path.dirname(current);
        if (File(path.join(tryDir, 'pkg', 'dartdev', 'bin', 'dartdev.dart'))
            .existsSync()) {
          _sdkRootPath = tryDir;
          return _sdkRootPath;
        }
        current = tryDir;
      } while (path.dirname(current) != current);
      throw StateError('can not find SDK repository root');
    }
    return _sdkRootPath;
  }

  String get absolutePathToDartdevFile =>
      path.join(sdkRootPath, 'pkg', 'dartdev', 'bin', 'dartdev.dart');

  Directory findDirectory(String name) {
    var directory = Directory(path.join(dir.path, name));
    return directory.existsSync() ? directory : null;
  }

  File findFile(String name) {
    var file = File(path.join(dir.path, name));
    return file.existsSync() ? file : null;
  }
}
