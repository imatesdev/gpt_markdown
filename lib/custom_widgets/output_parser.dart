import 'package:flutter/material.dart';
import 'output_field.dart';

/// A parser for markdown output blocks with labels.
///
/// This class parses markdown text in the format:
/// ```
/// [secondary_label Output]
/// Could not connect to Redis at 127.0.0.1:6379: Connection refused
/// ```
///
/// It returns an OutputField widget with the appropriate styling based on the label type.
class OutputParser {
  /// Parses markdown text and returns an OutputField widget.
  ///
  /// The markdown format should be:
  /// ```
  /// [secondary_label Output]
  /// Could not connect to Redis at 127.0.0.1:6379: Connection refused
  /// ```
  static Widget parse(String markdown) {
    // First, check for the specific [secondary_label Output] format
    if (markdown.trim().startsWith('[secondary_label Output]')) {
      // Extract the content after the first line
      final parts = markdown.split('\n');
      if (parts.length > 1) {
        final outputText = parts.sublist(1).join('\n').trim();
        return OutputField(
          type: 'secondary_label',
          labelText: 'Output',
          output: outputText,
        );
      }
    }

    // Check for general label format
    final RegExp labelRegex = RegExp(
      r'^\[(\w+)_label\s+([^\]]+)\]\s*\n([\s\S]*)$',
    );
    final match = labelRegex.firstMatch(markdown);

    if (match != null) {
      final String labelType = '${match.group(1)}_label';
      final String labelText = match.group(2) ?? '';
      final String outputText = match.group(3) ?? '';

      return OutputField(
        type: labelType,
        labelText: labelText,
        output: outputText.trim(),
      );
    }

    // If no match, check for code blocks
    final RegExp codeBlockRegex = RegExp(r'```(?:\w*)\s*([\s\S]*?)\s*```');
    final codeMatches = codeBlockRegex.allMatches(markdown);

    if (codeMatches.isNotEmpty) {
      // If there are multiple code blocks, return a column of OutputFields
      if (codeMatches.length > 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              codeMatches.map((match) {
                final String codeText = match.group(1) ?? '';
                return OutputField(type: 'default', output: codeText.trim());
              }).toList(),
        );
      } else {
        // Single code block
        final String codeText = codeMatches.first.group(1) ?? '';
        return OutputField(type: 'default', output: codeText.trim());
      }
    }

    // If no code blocks or label format, return the raw text
    return OutputField(type: 'default', output: markdown.trim());
  }

  /// Parse markdown text and return a list of widgets.
  ///
  /// This method handles multiple output blocks in a single markdown string.
  /// Each output block should be enclosed in triple backticks (```).
  static List<Widget> parseBlocks(String markdown) {
    final List<Widget> widgets = [];

    // Match code blocks enclosed in triple backticks
    final RegExp codeBlockRegex = RegExp(
      r'```\s*\n([\s\S]*?)\n```',
      multiLine: true,
    );
    final matches = codeBlockRegex.allMatches(markdown);

    if (matches.isNotEmpty) {
      for (final match in matches) {
        final String blockContent = match.group(1) ?? '';
        widgets.add(parse(blockContent));
      }
    } else {
      // If no code blocks are found, parse the entire markdown as a single output
      widgets.add(parse(markdown));
    }

    return widgets;
  }
}
