// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/protocol_server.dart'
    show CompletionSuggestion, RuntimeCompletionExpression, SourceEdit;
import 'package:analysis_server/src/services/completion/dart/completion_manager.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/util/performance/operation_performance.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

class RuntimeCompletionComputer {
  final OverlayResourceProvider resourceProvider;
  final AnalysisDriver analysisDriver;

  final String code;
  final int offset;

  final String contextPath;
  final int contextOffset;

  RuntimeCompletionComputer(this.resourceProvider, this.analysisDriver,
      this.code, this.offset, this.contextPath, this.contextOffset);

  Future<RuntimeCompletionResult> compute() async {
    var contextResult = await analysisDriver.getResult(contextPath);
    if (contextResult is! ResolvedUnitResult) {
      return RuntimeCompletionResult([], []);
    }

    var session = contextResult.session;

    const codeMarker = '__code_\_';

    // Insert the code being completed at the context offset.
    var changeBuilder = ChangeBuilder(session: session);
    var nextImportPrefixIndex = 0;
    await changeBuilder.addDartFileEdit(contextPath, (builder) {
      builder.addInsertion(contextOffset, (builder) {
        builder.writeln('{');

        // TODO(scheglov) Use variables.

        builder.write(codeMarker);
        builder.writeln(';');

        builder.writeln('}');
      });
    }, importPrefixGenerator: (uri) => '__prefix${nextImportPrefixIndex++}');

    // Compute the patched context file content.
    var targetCode = SourceEdit.applySequence(
      contextResult.content,
      changeBuilder.sourceChange.edits[0].edits,
    );

    // Insert the code being completed.
    var targetOffset = targetCode.indexOf(codeMarker) + offset;
    targetCode = targetCode.replaceAll(codeMarker, code);

    // Update the context file content to include the code being completed.
    // Then resolve it, and restore the file to its initial state.
    var targetResult = await _withContextFileContent(targetCode, () async {
      return await analysisDriver.getResult(contextPath);
    });
    if (targetResult is! ResolvedUnitResult) {
      return RuntimeCompletionResult([], []);
    }

    var dartRequest = DartCompletionRequest.from(
      resolvedUnit: targetResult,
      offset: targetOffset,
    );

    var suggestions = await DartCompletionManager().computeSuggestions(
      dartRequest,
      OperationPerformanceImpl('<root>'),
    );

    // Remove completions with synthetic import prefixes.
    suggestions.removeWhere((s) => s.completion.startsWith('__prefix'));

    // TODO(scheglov) Add support for expressions.
    var expressions = <RuntimeCompletionExpression>[];
    return RuntimeCompletionResult(expressions, suggestions);
  }

  Future<R> _withContextFileContent<R>(
      String newContent, Future<R> Function() f) async {
    if (resourceProvider.hasOverlay(contextPath)) {
      var contextFile = resourceProvider.getFile(contextPath);
      var prevOverlayContent = contextFile.readAsStringSync();
      var prevOverlayStamp = contextFile.modificationStamp;
      try {
        resourceProvider.setOverlay(
          contextPath,
          content: newContent,
          modificationStamp: 0,
        );
        analysisDriver.changeFile(contextPath);
        return await f();
      } finally {
        resourceProvider.setOverlay(
          contextPath,
          content: prevOverlayContent,
          modificationStamp: prevOverlayStamp,
        );
        analysisDriver.changeFile(contextPath);
      }
    } else {
      try {
        resourceProvider.setOverlay(
          contextPath,
          content: newContent,
          modificationStamp: 0,
        );
        analysisDriver.changeFile(contextPath);
        return await f();
      } finally {
        resourceProvider.removeOverlay(contextPath);
        analysisDriver.changeFile(contextPath);
      }
    }
  }
}

/// The result of performing runtime completion.
class RuntimeCompletionResult {
  final List<RuntimeCompletionExpression> expressions;
  final List<CompletionSuggestion> suggestions;

  RuntimeCompletionResult(this.expressions, this.suggestions);
}
