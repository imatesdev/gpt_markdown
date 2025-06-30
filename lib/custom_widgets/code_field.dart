import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that displays code with syntax highlighting and a copy button.
///
/// The [CodeField] widget takes a [name] parameter which is displayed as a language
/// above the code block, and a [codes] parameter containing the actual code text
/// to display.
///
/// Features:
/// - Displays code in a Material container with rounded corners
/// - Shows the code language/name as a label
/// - Provides a copy button to copy code to clipboard
/// - Visual feedback when code is copied
/// - Themed colors that adapt to light/dark mode
/// - Optional label displayed as a file path or title
/// - Customizable background color
class CodeField extends StatefulWidget {
  final String name;
  final String codes;
  final String label;
  final Color? backgroundColor;
  final bool showLineNumbers;

  const CodeField({
    super.key,
    required this.name,
    required this.codes,
    this.label = "",
    this.backgroundColor,
    this.showLineNumbers = false,
  });

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  bool _copied = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.codes));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = widget.label.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with label and copy button
                if (hasLabel)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: widget.backgroundColor ?? const Color(0xFF29334D),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.label,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _copyToClipboard,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _copied ? Icons.check : Icons.content_copy,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!hasLabel)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    alignment: Alignment.centerRight,
                    color: widget.backgroundColor ?? const Color(0xFF29334D),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _copyToClipboard,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied ? Icons.check : Icons.content_copy,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                // Code content with optional top-right copy button
                Stack(
                  children: [
                    Container(
                      color: widget.backgroundColor ?? const Color(0xFF0F172A),
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      child:
                          widget.showLineNumbers
                              ? _buildCodeWithLineNumbers(widget.codes)
                              : _buildFormattedCodeText(widget.codes),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Custom widget to handle special formatting for <^>text<^> patterns
  Widget _buildFormattedCodeText(String code) {
    // Regular expression to match <^>text<^> patterns
    final pattern = RegExp(r'<\^>(.*?)<\^>');
    final matches = pattern.allMatches(code);

    if (matches.isEmpty) {
      // If no special patterns, just return the text as is
      return SelectableText(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: Colors.white,
          height: 1.5,
        ),
      );
    }

    // Build rich text with highlighted spans
    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: code.substring(lastMatchEnd, match.start),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        );
      }

      // Add the highlighted text
      spans.add(
        TextSpan(
          text: match.group(1), // The text between <^> tags
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.5,
            backgroundColor: Color(0xFF334155), // Dark background color
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    // Add any remaining text after the last match
    if (lastMatchEnd < code.length) {
      spans.add(
        TextSpan(
          text: code.substring(lastMatchEnd),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: Colors.white,
            height: 1.5,
          ),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: Colors.white,
        height: 1.5,
      ),
    );
  }

  // Build code with line numbers
  Widget _buildCodeWithLineNumbers(String code) {
    final lines = code.split('\n');
    final lineCount = lines.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line numbers column
        Container(
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              lineCount,
              (index) => Container(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Color(0xFF64748B), // Slate-500 color
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Line separator
        Container(
          width: 1,
          height: lineCount * 21, // Approximate line height
          color: const Color(0xFF334155), // Slate-700 color
          margin: const EdgeInsets.only(right: 12),
        ),
        // Code content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              lineCount,
              (index) => Container(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: _buildFormattedCodeLine(lines[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Format a single line of code with highlighting
  Widget _buildFormattedCodeLine(String line) {
    // Regular expression to match <^>text<^> patterns
    final pattern = RegExp(r'<\^>(.*?)<\^>');
    final matches = pattern.allMatches(line);

    if (matches.isEmpty) {
      // If no special patterns, just return the text as is
      return Text(
        line,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: Colors.white,
          height: 1.5,
        ),
      );
    }

    // Build rich text with highlighted spans
    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: line.substring(lastMatchEnd, match.start),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        );
      }

      // Add the highlighted text
      spans.add(
        TextSpan(
          text: match.group(1), // The text between <^> tags
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            backgroundColor: Color(0xFF334155), // Dark background color
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    // Add any remaining text after the last match
    if (lastMatchEnd < line.length) {
      spans.add(
        TextSpan(
          text: line.substring(lastMatchEnd),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans), softWrap: true);
  }
}
