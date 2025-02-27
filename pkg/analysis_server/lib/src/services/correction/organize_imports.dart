// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/utilities/strings.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/ignore_comments/ignore_info.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart'
    hide AnalysisError, Element;

/// Organizer of imports (and other directives) in the [unit].
class ImportOrganizer {
  final String initialCode;

  final CompilationUnit unit;

  final List<AnalysisError> errors;

  final bool removeUnused;

  String code;

  String endOfLine = '\n';

  bool hasUnresolvedIdentifierError = false;

  ImportOrganizer(this.initialCode, this.unit, this.errors,
      {this.removeUnused = true})
      : code = initialCode {
    endOfLine = getEOL(code);
    hasUnresolvedIdentifierError = errors.any((error) {
      return error.errorCode.isUnresolvedIdentifier;
    });
  }

  /// Return the [SourceEdit]s that organize imports in the [unit].
  List<SourceEdit> organize() {
    _organizeDirectives();
    // prepare edits
    var edits = <SourceEdit>[];
    if (code != initialCode) {
      var suffixLength = findCommonSuffix(initialCode, code);
      var edit = SourceEdit(0, initialCode.length - suffixLength,
          code.substring(0, code.length - suffixLength));
      edits.add(edit);
    }
    return edits;
  }

  bool _isUnusedImport(UriBasedDirective directive) {
    for (var error in errors) {
      if ((error.errorCode == HintCode.DUPLICATE_IMPORT ||
              error.errorCode == HintCode.UNUSED_IMPORT) &&
          directive.uri.offset == error.offset) {
        return true;
      }
    }
    return false;
  }

  /// Organize all [Directive]s.
  void _organizeDirectives() {
    var lineInfo = unit.lineInfo ?? LineInfo.fromContent(code);
    var hasLibraryDirective = false;
    var directives = <_DirectiveInfo>[];
    for (var directive in unit.directives) {
      if (directive is LibraryDirective) {
        hasLibraryDirective = true;
      }
      if (directive is UriBasedDirective) {
        var priority = getDirectivePriority(directive);
        if (priority != null) {
          var offset = directive.offset;
          var end = directive.end;

          final leadingComment = getLeadingComment(unit, directive, lineInfo);
          final trailingComment =
              getTrailingComment(unit, directive, lineInfo, end);

          String? leadingCommentText;
          if (leadingComment != null) {
            leadingCommentText =
                code.substring(leadingComment.offset, directive.offset);
            offset = leadingComment.offset;
          }
          String? trailingCommentText;
          if (trailingComment != null) {
            trailingCommentText =
                code.substring(directive.end, trailingComment.end);
            end = trailingComment.end;
          }
          String? documentationText;
          var documentationComment = directive.documentationComment;
          if (documentationComment != null) {
            documentationText = code.substring(
                documentationComment.offset, documentationComment.end);
          }
          String? annotationText;
          var beginToken = directive.metadata.beginToken;
          var endToken = directive.metadata.endToken;
          if (beginToken != null && endToken != null) {
            annotationText = code.substring(beginToken.offset, endToken.end);
          }
          var text = code.substring(
              directive.firstTokenAfterCommentAndMetadata.offset,
              directive.end);
          var uriContent = directive.uri.stringValue ?? '';
          directives.add(
            _DirectiveInfo(
              directive,
              priority,
              leadingCommentText,
              documentationText,
              annotationText,
              uriContent,
              trailingCommentText,
              offset,
              end,
              text,
            ),
          );
        }
      }
    }
    // nothing to do
    if (directives.isEmpty) {
      return;
    }
    var firstDirectiveOffset = directives.first.offset;
    var lastDirectiveEnd = directives.last.end;

    // Without a library directive, the library comment is the comment of the
    // first directive.
    _DirectiveInfo? libraryDocumentationDirective;
    if (!hasLibraryDirective && directives.isNotEmpty) {
      libraryDocumentationDirective = directives.first;
    }

    // sort
    directives.sort();
    // append directives with grouping
    String directivesCode;
    {
      var sb = StringBuffer();
      if (libraryDocumentationDirective != null &&
          libraryDocumentationDirective.documentationText != null) {
        sb.write(libraryDocumentationDirective.documentationText);
        sb.write(endOfLine);
      }
      var currentPriority = directives.first.priority;
      for (var directiveInfo in directives) {
        if (!hasUnresolvedIdentifierError) {
          var directive = directiveInfo.directive;
          if (removeUnused && _isUnusedImport(directive)) {
            continue;
          }
        }
        if (currentPriority != directiveInfo.priority) {
          sb.write(endOfLine);
          currentPriority = directiveInfo.priority;
        }
        if (directiveInfo.leadingCommentText != null) {
          sb.write(directiveInfo.leadingCommentText);
        }
        if (directiveInfo != libraryDocumentationDirective &&
            directiveInfo.documentationText != null) {
          sb.write(directiveInfo.documentationText);
          sb.write(endOfLine);
        }
        if (directiveInfo.annotationText != null) {
          sb.write(directiveInfo.annotationText);
          sb.write(endOfLine);
        }
        sb.write(directiveInfo.text);
        if (directiveInfo.trailingCommentText != null) {
          sb.write(directiveInfo.trailingCommentText);
        }
        sb.write(endOfLine);
      }
      directivesCode = sb.toString();
      directivesCode = directivesCode.trimRight();
    }
    // prepare code
    var beforeDirectives = code.substring(0, firstDirectiveOffset);
    var afterDirectives = code.substring(lastDirectiveEnd);
    code = beforeDirectives + directivesCode + afterDirectives;
  }

  static _DirectivePriority? getDirectivePriority(UriBasedDirective directive) {
    var uriContent = directive.uri.stringValue ?? '';
    if (directive is ImportDirective) {
      if (uriContent.startsWith('dart:')) {
        return _DirectivePriority.IMPORT_SDK;
      } else if (uriContent.startsWith('package:')) {
        return _DirectivePriority.IMPORT_PKG;
      } else if (uriContent.contains('://')) {
        return _DirectivePriority.IMPORT_OTHER;
      } else {
        return _DirectivePriority.IMPORT_REL;
      }
    }
    if (directive is ExportDirective) {
      if (uriContent.startsWith('dart:')) {
        return _DirectivePriority.EXPORT_SDK;
      } else if (uriContent.startsWith('package:')) {
        return _DirectivePriority.EXPORT_PKG;
      } else if (uriContent.contains('://')) {
        return _DirectivePriority.EXPORT_OTHER;
      } else {
        return _DirectivePriority.EXPORT_REL;
      }
    }
    if (directive is PartDirective) {
      return _DirectivePriority.PART;
    }
    return null;
  }

  /// Return the EOL to use for [code].
  static String getEOL(String code) {
    if (code.contains('\r\n')) {
      return '\r\n';
    } else {
      return '\n';
    }
  }

  /// Gets the first comment token considered to be the leading comment for this
  /// directive.
  ///
  /// Leading comments for the first directive in a file are considered library
  /// comments and not returned unless they contain blank lines, in which case
  /// only the last part of the comment will be returned (unless it is a
  /// language directive comment, in which case it will also be skipped) or an
  /// '// ignore:' comment which should always be treated as attached to the
  /// import.
  static Token? getLeadingComment(
      CompilationUnit unit, UriBasedDirective directive, LineInfo lineInfo) {
    if (directive.beginToken.precedingComments == null) {
      return null;
    }

    Token? firstComment = directive.beginToken.precedingComments;
    var comment = firstComment;
    var nextComment = comment?.next;
    // Don't connect comments that have a blank line between them
    while (comment != null && nextComment != null) {
      var currentLine = lineInfo.getLocation(comment.offset).lineNumber;
      var nextLine = lineInfo.getLocation(nextComment.offset).lineNumber;
      if (nextLine - currentLine > 1) {
        firstComment = nextComment;
      }
      comment = nextComment;
      nextComment = comment.next;
    }

    // Language version tokens should never be attached so skip over.
    if (firstComment is LanguageVersionToken) {
      firstComment = firstComment.next;
    }

    // If the comment is the first comment in the document then whether we
    // consider it the leading comment depends on whether it's an ignore comment
    // or not.
    if (firstComment != null &&
        firstComment == unit.beginToken.precedingComments) {
      return _isIgnoreComment(firstComment) ? firstComment : null;
    }

    // Skip over any comments on the same line as the previous directive
    // as they will be attached to the end of it.
    var previousDirectiveLine =
        lineInfo.getLocation(directive.beginToken.previous!.end).lineNumber;
    comment = firstComment;
    while (comment != null &&
        previousDirectiveLine ==
            lineInfo.getLocation(comment.offset).lineNumber) {
      comment = comment.next;
    }
    return comment;
  }

  /// Gets the last comment token considered to be the trailing comment for this
  /// directive.
  ///
  /// To be considered a trailing comment, the comment must be on the same line
  /// as the directive.
  static Token? getTrailingComment(CompilationUnit unit,
      UriBasedDirective directive, LineInfo lineInfo, int end) {
    var line = lineInfo.getLocation(end).lineNumber;
    Token? comment = directive.endToken.next!.precedingComments;
    while (comment != null) {
      if (lineInfo.getLocation(comment.offset).lineNumber == line) {
        return comment;
      }
      comment = comment.next;
    }
    return null;
  }

  /// Returns whether this token is a '// ignore:' comment (but not an
  /// '// ignore_for_file:' comment).
  static bool _isIgnoreComment(Token token) =>
      IgnoreInfo.IGNORE_MATCHER.matchAsPrefix(token.lexeme) != null;
}

class _DirectiveInfo implements Comparable<_DirectiveInfo> {
  final UriBasedDirective directive;
  final _DirectivePriority priority;
  final String? leadingCommentText;
  final String? documentationText;
  final String? annotationText;
  final String uri;
  final String? trailingCommentText;

  /// The offset of the first token, usually the keyword but may include leading comments.
  final int offset;

  /// The offset after the last token, including the end-of-line comment.
  final int end;

  /// The text excluding comments, documentation and annotations.
  final String text;

  _DirectiveInfo(
    this.directive,
    this.priority,
    this.leadingCommentText,
    this.documentationText,
    this.annotationText,
    this.uri,
    this.trailingCommentText,
    this.offset,
    this.end,
    this.text,
  );

  @override
  int compareTo(_DirectiveInfo other) {
    if (priority == other.priority) {
      return _compareUri(uri, other.uri);
    }
    return priority.ordinal - other.priority.ordinal;
  }

  @override
  String toString() => '(priority=$priority; text=$text)';

  /// Should keep these in sync! Copied from
  /// https://github.com/dart-lang/linter/blob/658f497eef/lib/src/rules/directives_ordering.dart#L380-L387
  /// Consider finding a way to share this code!
  static int _compareUri(String a, String b) {
    var indexA = a.indexOf('/');
    var indexB = b.indexOf('/');
    if (indexA == -1 || indexB == -1) return a.compareTo(b);
    var result = a.substring(0, indexA).compareTo(b.substring(0, indexB));
    if (result != 0) return result;
    return a.substring(indexA + 1).compareTo(b.substring(indexB + 1));
  }
}

class _DirectivePriority {
  static const IMPORT_SDK = _DirectivePriority('IMPORT_SDK', 0);
  static const IMPORT_PKG = _DirectivePriority('IMPORT_PKG', 1);
  static const IMPORT_OTHER = _DirectivePriority('IMPORT_OTHER', 2);
  static const IMPORT_REL = _DirectivePriority('IMPORT_REL', 3);
  static const EXPORT_SDK = _DirectivePriority('EXPORT_SDK', 4);
  static const EXPORT_PKG = _DirectivePriority('EXPORT_PKG', 5);
  static const EXPORT_OTHER = _DirectivePriority('EXPORT_OTHER', 6);
  static const EXPORT_REL = _DirectivePriority('EXPORT_REL', 7);
  static const PART = _DirectivePriority('PART', 8);

  final String name;
  final int ordinal;

  const _DirectivePriority(this.name, this.ordinal);

  @override
  String toString() => name;
}
