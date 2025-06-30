import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that displays output messages with optional labels.
///
/// The [OutputField] widget can be used to display various types of output,
/// including error messages, warnings, and standard output. It supports:
/// - Primary and secondary labels
/// - Customizable background and text colors
/// - Copy functionality for output text
/// - Themed colors that adapt to light/dark mode
class OutputField extends StatefulWidget {
  /// The type of output message
  final String type;

  /// The actual output text to display
  final String output;

  /// Optional label to display (e.g., "Output", "Error", etc.)
  final String labelText;

  /// Background color for the output field
  final Color? backgroundColor;

  /// Text color for the output
  final Color? textColor;

  const OutputField({
    super.key,
    required this.type,
    required this.output,
    this.labelText = "",
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<OutputField> createState() => _OutputFieldState();
}

class _OutputFieldState extends State<OutputField> {
  bool _copied = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.output));
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

  Color _getBackgroundColor(BuildContext context) {
    if (widget.backgroundColor != null) {
      return widget.backgroundColor!;
    }

    // Default colors based on output type
    switch (widget.type.toLowerCase()) {
      case 'error':
      case 'error_label':
        return const Color(0xFF2D1A1A); // Dark red background for errors
      case 'warning':
      case 'warning_label':
        return const Color(0xFF2D261A); // Dark amber background for warnings
      case 'secondary_label':
      default:
        return const Color(0xFF1A1E2D); // Dark blue background
    }
  }

  Color _getLabelColor(BuildContext context) {
    // Label colors based on output type
    switch (widget.type.toLowerCase()) {
      case 'error':
      case 'error_label':
        return const Color(0xFFFF6B6B); // Light red for errors
      case 'warning':
      case 'warning_label':
        return const Color(0xFFFFD166); // Light amber for warnings
      case 'secondary_label':
      default:
        return const Color(0xFF63B3ED); // Light blue for secondary labels
    }
  }

  Color _getTextColor(BuildContext context) {
    if (widget.textColor != null) {
      return widget.textColor!;
    }

    // Default text color is white for all types
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor(context);
    final textColor = _getTextColor(context);
    final labelColor = _getLabelColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: backgroundColor,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label at the top
              if (widget.labelText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    widget.labelText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: labelColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Output text
              SelectableText(
                widget.output,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: textColor,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
