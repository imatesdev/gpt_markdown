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

  const CodeField({
    Key? key,
    required this.name,
    required this.codes,
    this.label = "",
    this.backgroundColor,
  }) : super(key: key);

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
                      vertical: 12,
                    ),
                    color: const Color(0xFF1E293B),
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
                        ElevatedButton(
                          onPressed: _copyToClipboard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _copied ? Icons.check : Icons.content_copy,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(_copied ? 'Copied' : 'Copy'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Code content
                Container(
                  color: widget.backgroundColor ?? const Color(0xFF0F172A),
                  padding: const EdgeInsets.all(16),
                  child: _buildFormattedCodeText(widget.codes),
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
        spans.add(TextSpan(
          text: code.substring(lastMatchEnd, match.start),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: Colors.white,
            height: 1.5,
          ),
        ));
      }

      // Add the highlighted text
      spans.add(TextSpan(
        text: match.group(1), // The text between <^> tags
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.5,
          backgroundColor: Color(0xFF334155), // Dark background color
        ),
      ));

      lastMatchEnd = match.end;
    }

    // Add any remaining text after the last match
    if (lastMatchEnd < code.length) {
      spans.add(TextSpan(
        text: code.substring(lastMatchEnd),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: Colors.white,
          height: 1.5,
        ),
      ));
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
}
