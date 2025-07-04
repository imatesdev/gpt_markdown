part of 'gpt_markdown.dart';

/// Markdown components
abstract class MarkdownComponent {
  static List<MarkdownComponent> get globalComponents => [
    OutputBlockMd(), // Move OutputBlockMd to the beginning of the list for priority
    CodeBlockMd(),
    LatexMathMultiLine(),
    NewLines(),
    BlockQuote(),
    TableMd(),
    HTag(),
    UnOrderedList(),
    OrderedList(),
    RadioButtonMd(),
    CheckBoxMd(),
    HrLine(),
    IndentMd(),
    UnderlineMd(),
    DirectUrlMd(), // Add DirectUrlMd to the components list
    CalloutMd(), // Add CalloutMd to the components list
    DetailsMd(), // Add DetailsMd to the components list
    YoutubeMd(), // Add YoutubeMd to the components list
  ];

  static final List<MarkdownComponent> inlineComponents = [
    CurrencyMd(),
    ImageMd(),
    ATagMd(),
    TableMd(),
    StrikeMd(),
    BoldMd(),
    UnderlineMd(), // Move UnderlineMd before ItalicMd
    ItalicMd(),
    LatexMath(),
    LatexMathMultiLine(),
    HighlightedText(),
    SourceTag(),
    DirectUrlMd(), // Add DirectUrlMd to the inlineComponents list
    CalloutMd(), // Add CalloutMd to the components list
  ];

  /// Generate widget for markdown widget
  static List<InlineSpan> generate(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
    bool includeGlobalComponents,
  ) {
    var components =
        includeGlobalComponents
            ? config.components ?? MarkdownComponent.globalComponents
            : config.inlineComponents ?? MarkdownComponent.inlineComponents;
    List<InlineSpan> spans = [];
    Iterable<String> regexes = components.map<String>((e) => e.exp.pattern);
    final combinedRegex = RegExp(
      regexes.join("|"),
      multiLine: true,
      dotAll: true,
    );
    text.splitMapJoin(
      combinedRegex,
      onMatch: (p0) {
        String element = p0[0] ?? "";
        for (var each in components) {
          var p = each.exp.pattern;
          var exp = RegExp(
            '^$p\$',
            multiLine: each.exp.isMultiLine,
            dotAll: each.exp.isDotAll,
          );
          if (exp.hasMatch(element)) {
            spans.add(each.span(context, element, config));
            return "";
          }
        }
        return "";
      },
      onNonMatch: (p0) {
        if (p0.isEmpty) {
          return "";
        }
        if (includeGlobalComponents) {
          var newSpans = generate(context, p0, config.copyWith(), false);
          spans.addAll(newSpans);
          return "";
        }
        spans.add(TextSpan(text: p0, style: config.style));
        return "";
      },
    );

    return spans;
  }

  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  );

  RegExp get exp;
  bool get inline;
}

/// Inline component
abstract class InlineMd extends MarkdownComponent {
  @override
  bool get inline => true;

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  );
}

/// Block component
abstract class BlockMd extends MarkdownComponent {
  @override
  bool get inline => false;

  @override
  RegExp get exp =>
      RegExp(r'^\ *?' + expString + r"$", dotAll: true, multiLine: true);

  String get expString;

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var matches = RegExp(r'^(?<spaces>\ \ +).*').firstMatch(text);
    var spaces = matches?.namedGroup('spaces');
    var length = spaces?.length ?? 0;
    var child = build(context, text, config);
    length = min(length, 4);
    if (length > 0) {
      child = UnorderedListView(
        spacing: length * 1.0,
        textDirection: config.textDirection,
        child: child,
      );
    }
    child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Flexible(child: child)],
    );
    return WidgetSpan(
      child: child,
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
    );
  }

  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  );
}

/// Indent component
class IndentMd extends BlockMd {
  @override
  String get expString => (r"^(\ \ +)([^\n]+)$");
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text);
    var conf = config.copyWith();
    return Directionality(
      textDirection: config.textDirection,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: config.getRich(
              TextSpan(
                children: MarkdownComponent.generate(
                  context,
                  match?[2] ?? "",
                  conf,
                  false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Heading component
class HTag extends BlockMd {
  @override
  String get expString => (r"(?<hash>#{1,6})\ (?<data>[^\n]+?)$");
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var theme = GptMarkdownTheme.of(context);
    var match = this.exp.firstMatch(text.trim());

    // Get the heading level (1-6)
    int headingLevel = match![1]!.length - 1;

    // Get the appropriate style based on heading level
    TextStyle? headingStyle;
    switch (headingLevel) {
      case 0:
        headingStyle = theme.h1;
      case 1:
        headingStyle = theme.h2;
      case 2:
        headingStyle = theme.h3;
      case 3:
        headingStyle = theme.h4;
      case 4:
        headingStyle = theme.h5;
      case 5:
        headingStyle = theme.h6;
      default:
        headingStyle = theme.h1;
    }

    // Ensure the heading style is applied correctly
    var conf = config.copyWith(
      style: headingStyle?.copyWith(
        color: headingStyle.color ?? config.style?.color,
        fontSize: headingStyle.fontSize,
        fontWeight: headingStyle.fontWeight,
        decoration: headingStyle.decoration,
        decorationColor: headingStyle.decorationColor,
        decorationThickness: headingStyle.decorationThickness,
        height: headingStyle.height,
      ),
    );

    return config.getRich(
      TextSpan(
        children: [
          ...(MarkdownComponent.generate(
            context,
            "${match.namedGroup('data')}",
            conf,
            false,
          )),
          if (match.namedGroup('hash')!.length == 1) ...[
            const TextSpan(
              text: "\n ",
              style: TextStyle(fontSize: 0, height: 0),
            ),
            WidgetSpan(
              child: CustomDivider(
                height: theme.hrLineThickness,
                color:
                    config.style?.color ??
                    Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NewLines extends InlineMd {
  @override
  RegExp get exp => RegExp(r"\n\n+");
  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    return TextSpan(
      text: "\n\n",
      style: TextStyle(
        fontSize: config.style?.fontSize ?? 14,
        height: 1.15,
        color: config.style?.color,
      ),
    );
  }
}

/// Horizontal line component
class HrLine extends BlockMd {
  @override
  String get expString => (r"⸻|((--)[-]+)$");
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var thickness = GptMarkdownTheme.of(context).hrLineThickness;
    var color = GptMarkdownTheme.of(context).hrLineColor;
    return CustomDivider(
      height: thickness,
      color: config.style?.color ?? color,
    );
  }
}

/// Checkbox component
class CheckBoxMd extends BlockMd {
  @override
  String get expString => (r"\[((?:\x|\ ))\]\ (\S[^\n]*?)$");

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text.trim());
    return CustomCb(
      value: ("${match?[1]}" == "x"),
      textDirection: config.textDirection,
      child: MdWidget(context, "${match?[2]}", false, config: config),
    );
  }
}

/// Radio Button component
class RadioButtonMd extends BlockMd {
  @override
  String get expString => (r"\(((?:\x|\ ))\)\ (\S[^\n]*)$");

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text.trim());
    return CustomRb(
      value: ("${match?[1]}" == "x"),
      textDirection: config.textDirection,
      child: MdWidget(context, "${match?[2]}", false, config: config),
    );
  }
}

/// Block quote component
class BlockQuote extends InlineMd {
  @override
  bool get inline => false;
  @override
  RegExp get exp => RegExp(
    r"(?:(?:^)\ *>[^\n]+)(?:(?:\n)\ *>[^\n]+)*",
    dotAll: true,
    multiLine: true,
  );

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text);
    if (match == null) {
      return TextSpan(text: text, style: config.style);
    }

    var m = match[0] ?? '';
    List<String> lines = m.split('\n');

    // Process the content to extract the actual text without '>' markers
    List<String> processedLines = [];
    bool hasNestedContent = false;

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      String trimmedLine = line.trimLeft();
      if (trimmedLine.startsWith('>')) {
        // Count the number of consecutive '>' characters
        int depth = 0;
        int i = 0;
        while (i < trimmedLine.length && trimmedLine[i] == '>') {
          depth++;
          i++;
          // Skip a space after '>' if present
          if (i < trimmedLine.length && trimmedLine[i] == ' ') {
            i++;
          }
        }

        if (depth > 1) {
          hasNestedContent = true;
          // For nested quotes, keep one level of nesting and process the rest
          processedLines.add('>' + trimmedLine.substring(i));
        } else {
          // For top-level quotes, just keep the content
          processedLines.add(trimmedLine.substring(i));
        }
      } else {
        processedLines.add(trimmedLine);
      }
    }

    String processedContent = processedLines.join('\n');

    // Create the blockquote widget
    Widget blockQuoteWidget = BlockQuoteWidget(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      direction: config.textDirection,
      width: 3,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8.0),
        child:
            hasNestedContent
                // For nested content, use MdWidget to process markdown within
                ? MdWidget(context, processedContent, true, config: config)
                // For simple content, use standard text processing
                : config.getRich(
                  TextSpan(
                    children: MarkdownComponent.generate(
                      context,
                      processedContent,
                      config,
                      true,
                    ),
                  ),
                ),
      ),
    );

    // Wrap in padding and directionality
    return WidgetSpan(
      child: Directionality(
        textDirection: config.textDirection,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: blockQuoteWidget,
        ),
      ),
    );
  }
}

/// Unordered list component
class UnOrderedList extends BlockMd {
  @override
  String get expString => (r"(?:\-|\*)\ ([^\n]+)$");

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text);

    var child = MdWidget(context, "${match?[1]?.trim()}", true, config: config);

    return config.unOrderedListBuilder?.call(
          context,
          child,
          config.copyWith(),
        ) ??
        UnorderedListView(
          bulletColor:
              (config.style?.color ?? DefaultTextStyle.of(context).style.color),
          padding: 7,
          spacing: 10,
          bulletSize:
              0.3 *
              (config.style?.fontSize ??
                  DefaultTextStyle.of(context).style.fontSize ??
                  kDefaultFontSize),
          textDirection: config.textDirection,
          child: child,
        );
  }
}

/// Ordered list component
class OrderedList extends BlockMd {
  @override
  String get expString => (r"([0-9]+)\.\ ([^\n]+)$");

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text.trim());

    var no = "${match?[1]}";

    var child = MdWidget(context, "${match?[2]?.trim()}", true, config: config);
    return config.orderedListBuilder?.call(
          context,
          no,
          child,
          config.copyWith(),
        ) ??
        OrderedListView(
          no: "$no.",
          textDirection: config.textDirection,
          style: (config.style ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w100,
          ),
          child: child,
        );
  }
}

class HighlightedText extends InlineMd {
  // Updated regex to better capture the <^> pattern
  @override
  RegExp get exp => RegExp(r"(`(?!`)(.+?)(?<!`)`(?!`))|(<\^>(.+?)<\^>)");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    if (match == null) return TextSpan(text: text);

    // Determine which pattern matched (backticks or <^> tags)
    String highlightedText = "";
    bool isSpecialHighlight = false;

    if (match[1] != null) {
      // Backtick pattern matched
      highlightedText = match[2] ?? "";
    } else if (match[3] != null) {
      // Variable pattern matched with <^> tags
      highlightedText = match[4] ?? "";
      isSpecialHighlight = true;
    }

    if (config.highlightBuilder != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: config.highlightBuilder!(
          context,
          highlightedText,
          config.style ?? const TextStyle(),
        ),
      );
    }

    // Create a highlighted style with a background color
    var style =
        config.style?.copyWith(
          fontWeight: FontWeight.bold,
          color: isSpecialHighlight ? Colors.white : Colors.black,
          background:
              Paint()
                ..color =
                    isSpecialHighlight
                        ? const Color(
                          0xFF334155,
                        ) // Darker background for <^> tags
                        : Theme.of(context).primaryColor.withOpacity(0.2)
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round,
        ) ??
        TextStyle(
          fontWeight: FontWeight.bold,
          color: isSpecialHighlight ? Colors.white : Colors.black,
          background:
              Paint()
                ..color =
                    isSpecialHighlight
                        ? const Color(
                          0xFF334155,
                        ) // Darker background for <^> tags
                        : Theme.of(context).primaryColor.withOpacity(0.2)
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round,
        );

    // Check if the highlighted text contains nested patterns
    if (highlightedText.contains("`") || highlightedText.contains("<^>")) {
      // Process nested markdown within the highlighted text
      var conf = config.copyWith(style: style);
      return TextSpan(
        children: MarkdownComponent.generate(
          context,
          highlightedText,
          conf,
          false,
        ),
        style: style,
      );
    }

    return TextSpan(text: highlightedText, style: style);
  }
}

/// Bold text component
class BoldMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"(?<!\*)\*\*(?<!\s)(.+?)(?<!\s)\*\*(?!\*)");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    var conf = config.copyWith(
      style:
          config.style?.copyWith(fontWeight: FontWeight.bold) ??
          const TextStyle(fontWeight: FontWeight.bold),
    );
    return TextSpan(
      children: MarkdownComponent.generate(
        context,
        "${match?[1]}",
        conf,
        false,
      ),
      style: conf.style,
    );
  }
}

class StrikeMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"(?<!\*)\~\~(?<!\s)(.+?)(?<!\s)\~\~(?!\*)");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    var conf = config.copyWith(
      style:
          config.style?.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: config.style?.color,
          ) ??
          const TextStyle(decoration: TextDecoration.lineThrough),
    );
    return TextSpan(
      children: MarkdownComponent.generate(
        context,
        "${match?[1]}",
        conf,
        false,
      ),
      style: conf.style,
    );
  }
}

/// Italic text component
class ItalicMd extends InlineMd {
  @override
  RegExp get exp => RegExp(
    r"(?:(?<!\*)\*(?<!\s)(.+?)(?<!\s)\*(?!\*)|(?<!_)_(?<!\s)(.+?)(?<!\s)_(?!_))",
    dotAll: true,
  );

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    // Skip processing if this is an underline pattern
    if (text.trim().startsWith('__') && text.trim().endsWith('__')) {
      // Extract the text between the double underscores
      String content = text.trim();
      content = content.substring(2, content.length - 2);

      // Create a dedicated style for underline with explicit properties
      final underlineStyle = TextStyle(
        decoration: TextDecoration.underline,
        decorationColor: config.style?.color,
        decorationThickness: 1.5, // Increased thickness for better visibility
        decorationStyle: TextDecorationStyle.solid,
        color: config.style?.color,
        fontSize: config.style?.fontSize,
        fontFamily: config.style?.fontFamily,
        fontWeight: config.style?.fontWeight,
      );
      return TextSpan(text: content, style: underlineStyle);
    }

    var match = exp.firstMatch(text.trim());
    var data = match?[1] ?? match?[2];
    var conf = config.copyWith(
      style: (config.style ?? const TextStyle()).copyWith(
        fontStyle: FontStyle.italic,
      ),
    );
    return TextSpan(
      children: MarkdownComponent.generate(context, "$data", conf, false),
      style: conf.style,
    );
  }
}

class UnderlineMd extends InlineMd {
  @override
  // Improved regex pattern to better match __text__ without conflicts
  RegExp get exp => RegExp(r"__(.*?)__");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    if (match == null || match[1] == null) {
      return TextSpan(text: text, style: config.style);
    }

    // Create a dedicated style for underline with explicit properties
    final underlineStyle = TextStyle(
      decoration: TextDecoration.underline,
      decorationColor: config.style?.color,
      decorationThickness: 1.5, // Increased thickness for better visibility
      decorationStyle: TextDecorationStyle.solid,
      color: config.style?.color,
      fontSize: config.style?.fontSize,
      fontFamily: config.style?.fontFamily,
      fontWeight: config.style?.fontWeight,
    );

    // Apply the style directly to this TextSpan without further processing
    return TextSpan(text: match[1], style: underlineStyle);
  }
}

/// Latex math multi-line component
class LatexMathMultiLine extends BlockMd {
  @override
  String get expString => (r"\ *\\\[((?:.)*?)\\\]|(\ *\\begin.*?\\end{.*?})");
  // (r"\ *\\\[((?:(?!\n\n\n).)*?)\\\]|(\\begin.*?\\end{.*?})");
  @override
  RegExp get exp => RegExp(expString, dotAll: true, multiLine: true);

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var p0 = exp.firstMatch(text.trim());
    String mathText = p0?[1] ?? p0?[2] ?? '';
    var workaround = config.latexWorkaround ?? (String tex) => tex;

    var builder =
        config.latexBuilder ??
        (BuildContext context, String tex, TextStyle textStyle, bool inline) =>
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SelectableAdapter(
                selectedText: tex,
                child: Math.tex(
                  tex,
                  textStyle: textStyle,
                  mathStyle: MathStyle.display,
                  textScaleFactor: 1,
                  settings: const TexParserSettings(strict: Strict.ignore),
                  options: MathOptions(
                    sizeUnderTextStyle: MathSize.large,
                    color:
                        config.style?.color ??
                        Theme.of(context).colorScheme.onSurface,
                    fontSize:
                        config.style?.fontSize ??
                        Theme.of(context).textTheme.bodyMedium?.fontSize,
                    mathFontOptions: FontOptions(
                      fontFamily: "Main",
                      fontWeight: config.style?.fontWeight ?? FontWeight.normal,
                      fontShape: FontStyle.normal,
                    ),
                    textFontOptions: FontOptions(
                      fontFamily: "Main",
                      fontWeight: config.style?.fontWeight ?? FontWeight.normal,
                      fontShape: FontStyle.normal,
                    ),
                    style: MathStyle.display,
                  ),
                  onErrorFallback: (err) {
                    return Text(
                      workaround(mathText),
                      textDirection: config.textDirection,
                      style: textStyle.copyWith(
                        color:
                            (!kDebugMode)
                                ? null
                                : Theme.of(context).colorScheme.error,
                      ),
                    );
                  },
                ),
              ),
            );
    return builder(
      context,
      workaround(mathText),
      config.style ?? const TextStyle(),
      false,
    );
  }
}

/// Italic text component
class LatexMath extends InlineMd {
  @override
  RegExp get exp => RegExp(
    [
      r"\\\((.*?)\\\)",
      // r"(?<!\\)\$((?:\\.|[^$])*?)\$(?!\\)",
    ].join("|"),
    dotAll: true,
  );

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var p0 = exp.firstMatch(text.trim());
    p0?.group(0);
    String mathText = p0?[1]?.toString() ?? "";
    var workaround = config.latexWorkaround ?? (String tex) => tex;
    var builder =
        config.latexBuilder ??
        (BuildContext context, String tex, TextStyle textStyle, bool inline) =>
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SelectableAdapter(
                selectedText: tex,
                child: Math.tex(
                  tex,
                  textStyle: textStyle,
                  mathStyle: MathStyle.display,
                  textScaleFactor: 1,
                  settings: const TexParserSettings(strict: Strict.ignore),
                  options: MathOptions(
                    sizeUnderTextStyle: MathSize.large,
                    color:
                        config.style?.color ??
                        Theme.of(context).colorScheme.onSurface,
                    fontSize:
                        config.style?.fontSize ??
                        Theme.of(context).textTheme.bodyMedium?.fontSize,
                    mathFontOptions: FontOptions(
                      fontFamily: "Main",
                      fontWeight: config.style?.fontWeight ?? FontWeight.normal,
                      fontShape: FontStyle.normal,
                    ),
                    textFontOptions: FontOptions(
                      fontFamily: "Main",
                      fontWeight: config.style?.fontWeight ?? FontWeight.normal,
                      fontShape: FontStyle.normal,
                    ),
                    style: MathStyle.display,
                  ),
                  onErrorFallback: (err) {
                    return Text(
                      workaround(mathText),
                      textDirection: config.textDirection,
                      style: textStyle.copyWith(
                        color:
                            (!kDebugMode)
                                ? null
                                : Theme.of(context).colorScheme.error,
                      ),
                    );
                  },
                ),
              ),
            );
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: builder(
        context,
        workaround(mathText),
        config.style ?? const TextStyle(),
        true,
      ),
    );
  }
}

/// source text component
class SourceTag extends InlineMd {
  @override
  RegExp get exp => RegExp(r"(?:【.*?)?\[(\d+?)\]");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    var content = match?[1];
    if (content == null) {
      return const TextSpan();
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child:
            config.sourceTagBuilder?.call(
              context,
              content,
              const TextStyle(),
            ) ??
            SizedBox(
              width: 20,
              height: 20,
              child: Material(
                color: Theme.of(context).colorScheme.onInverseSurface,
                shape: const OvalBorder(),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    content,
                    // style: (style ?? const TextStyle()).copyWith(),
                    textDirection: config.textDirection,
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

/// Link text component
class ATagMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"\[[^\[\]]*\]\([^\s]*\)");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    // First try to find the basic pattern
    final basicMatch = RegExp(r'\[([^\[\]]*)\]\(').firstMatch(text.trim());
    if (basicMatch == null) {
      return const TextSpan();
    }

    final linkText = basicMatch.group(1) ?? '';
    final urlStart = basicMatch.end;

    // Now find the balanced closing parenthesis
    int parenCount = 0;
    int urlEnd = urlStart;

    for (int i = urlStart; i < text.length; i++) {
      final char = text[i];

      if (char == '(') {
        parenCount++;
      } else if (char == ')') {
        if (parenCount == 0) {
          // This is the closing parenthesis of the link
          urlEnd = i;
          break;
        } else {
          parenCount--;
        }
      }
    }

    if (urlEnd == urlStart) {
      // No closing parenthesis found
      return const TextSpan();
    }

    final url = text.substring(urlStart, urlEnd).trim();

    var builder = config.linkBuilder;

    // Process the link text for any inline code or variable patterns
    List<InlineSpan> processedLinkText = [];
    if (linkText.contains('`') || linkText.contains('<^>')) {
      // Create a new config with link styling
      var linkStyle =
          config.style?.copyWith(
            color: GptMarkdownTheme.of(context).linkColor,
            decoration: TextDecoration.underline,
          ) ??
          TextStyle(
            color: GptMarkdownTheme.of(context).linkColor,
            decoration: TextDecoration.underline,
          );

      var linkConfig = config.copyWith(style: linkStyle);

      processedLinkText = MarkdownComponent.generate(
        context,
        linkText,
        linkConfig,
        false,
      );
    }

    // Use custom builder if provided
    if (builder != null) {
      return WidgetSpan(
        child: GestureDetector(
          onTap: () => config.onLinkTap?.call(url, linkText),
          child: builder(
            context,
            linkText,
            url,
            config.style ?? const TextStyle(),
          ),
        ),
      );
    }

    // Default rendering
    var theme = GptMarkdownTheme.of(context);

    // If we have processed link text with formatting, use it
    if (processedLinkText.isNotEmpty) {
      return WidgetSpan(
        child: GestureDetector(
          onTap: () => config.onLinkTap?.call(url, linkText),
          child: RichText(
            text: TextSpan(
              children: processedLinkText,
              style: TextStyle(
                color: theme.linkColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      );
    }

    // Otherwise use the standard LinkButton
    return WidgetSpan(
      child: LinkButton(
        hoverColor: theme.linkHoverColor,
        color: theme.linkColor,
        onPressed: () {
          config.onLinkTap?.call(url, linkText);
        },
        text: linkText,
        config: config,
      ),
    );
  }
}

/// Direct URL component
class DirectUrlMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"<(https?:\/\/[^\s>]+)>");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    if (match?[1] == null) {
      return const TextSpan();
    }

    final url = match?[1] ?? "";
    var builder = config.linkBuilder;

    // Use custom builder if provided
    if (builder != null) {
      return WidgetSpan(
        child: GestureDetector(
          onTap: () => config.onLinkTap?.call(url, url),
          child: builder(context, url, url, config.style ?? const TextStyle()),
        ),
      );
    }

    // Default rendering
    var theme = GptMarkdownTheme.of(context);
    return WidgetSpan(
      child: LinkButton(
        hoverColor: theme.linkHoverColor,
        color: theme.linkColor,
        onPressed: () {
          config.onLinkTap?.call(url, url);
        },
        text: url,
        config: config,
      ),
    );
  }
}

/// Image component
class ImageMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"!\[(.*?)\]\((.*?)\)(\s*\{[^}]*\})?");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    if (match == null || match.groupCount < 2) {
      return TextSpan(text: text, style: config.style);
    }

    final altText = match.group(1) ?? '';
    final urlWithPossibleTitle = match.group(2) ?? '';
    final attributesText = match.group(3) ?? '';

    // Parse URL and optional title with a simpler approach
    String url = urlWithPossibleTitle;
    String title = '';

    // Simple parsing: URL is everything before the first space,
    // title is everything between quotes after that
    final spaceIndex = urlWithPossibleTitle.indexOf(' ');
    if (spaceIndex > 0) {
      url = urlWithPossibleTitle.substring(0, spaceIndex);
      final remaining = urlWithPossibleTitle.substring(spaceIndex).trim();

      // Look for title in double quotes
      final doubleQuoteMatch = RegExp(r'"([^"]*)"').firstMatch(remaining);
      if (doubleQuoteMatch != null) {
        title = doubleQuoteMatch.group(1) ?? '';
      }
      // Or look for title in single quotes
      else {
        final singleQuoteMatch = RegExp(r"'([^']*)'").firstMatch(remaining);
        if (singleQuoteMatch != null) {
          title = singleQuoteMatch.group(1) ?? '';
        }
      }
    }

    // Parse dimensions from alt text if present
    double? width;
    double? height;
    TextAlign? textAlign;

    // First check for dimensions in alt text (legacy support)
    if (altText.isNotEmpty) {
      final sizeMatch = RegExp(r"^(\d+)?x?(\d+)?").firstMatch(altText.trim());
      if (sizeMatch != null) {
        final widthStr = sizeMatch.group(1);
        final heightStr = sizeMatch.group(2);
        width = widthStr != null ? double.tryParse(widthStr) : null;
        height = heightStr != null ? double.tryParse(heightStr) : null;
      }
    }

    // Parse attributes from curly braces if present
    if (attributesText.isNotEmpty) {
      // Remove curly braces and trim
      final cleanAttributes = attributesText.trim().replaceAll(
        RegExp(r'^\s*\{|\}\s*$'),
        '',
      );

      // Parse width, height, and alignment
      final widthMatch = RegExp(
        r'width\s*=\s*(\d+)',
      ).firstMatch(cleanAttributes);
      if (widthMatch != null) {
        width = double.tryParse(widthMatch.group(1) ?? '');
      }

      final heightMatch = RegExp(
        r'height\s*=\s*(\d+)',
      ).firstMatch(cleanAttributes);
      if (heightMatch != null) {
        height = double.tryParse(heightMatch.group(1) ?? '');
      }

      final alignMatch = RegExp(
        r'align\s*=\s*(\w+)',
      ).firstMatch(cleanAttributes);
      if (alignMatch != null) {
        final alignValue = alignMatch.group(1)?.toLowerCase() ?? '';
        switch (alignValue) {
          case 'left':
            textAlign = TextAlign.left;
            break;
          case 'right':
            textAlign = TextAlign.right;
            break;
          case 'center':
            textAlign = TextAlign.center;
            break;
        }
      }
    }

    // Create the image widget
    final Widget image;
    if (config.imageBuilder != null) {
      image = config.imageBuilder!(context, url);
    } else {
      image = Container(
        constraints: BoxConstraints(
          maxWidth: width ?? double.infinity,
          maxHeight: height ?? double.infinity,
        ),
        width: width,
        height: height,
        alignment:
            textAlign == TextAlign.left
                ? Alignment.centerLeft
                : textAlign == TextAlign.right
                ? Alignment.centerRight
                : Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              textAlign == TextAlign.left
                  ? CrossAxisAlignment.start
                  : textAlign == TextAlign.right
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center,
          children: [
            Image(
              image: NetworkImage(url),
              width: width,
              height: height,
              loadingBuilder: (
                BuildContext context,
                Widget child,
                ImageChunkEvent? loadingProgress,
              ) {
                if (loadingProgress == null) {
                  return child;
                }
                return CustomImageLoading(
                  progress:
                      loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : 1,
                );
              },
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print("Image error: $error for URL: $url");
                return CustomImageError();
              },
            ),
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: (config.style?.fontSize ?? 14) * 0.9,
                    color: config.style?.color?.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: textAlign ?? TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    return WidgetSpan(alignment: PlaceholderAlignment.bottom, child: image);
  }
}

/// Table component
class TableMd extends BlockMd {
  @override
  String get expString =>
      (r"(((\|[^\n\|]+\|)((([^\n\|]+\|)+)?)\ *)(\n\ *(((\|[^\n\|]+\|)(([^\n\|]+\|)+)?))\ *)+)$");
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    final List<Map<int, String>> value =
        text
            .split('\n')
            .map<Map<int, String>>(
              (e) =>
                  e
                      .trim()
                      .split('|')
                      .where((element) => element.isNotEmpty)
                      .toList()
                      .asMap(),
            )
            .toList();
    bool heading = RegExp(
      r"^\|.*?\|\n\|-[-\\ |]*?-\|$",
      multiLine: true,
    ).hasMatch(text.trim());
    int maxCol = 0;
    for (final each in value) {
      if (maxCol < each.keys.length) {
        maxCol = each.keys.length;
      }
    }
    if (maxCol == 0) {
      return Text("", style: config.style);
    }
    final controller = ScrollController();
    return Scrollbar(
      controller: controller,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Set minimum width but no maximum to allow scrolling
            minWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: Table(
            textDirection: config.textDirection,
            defaultColumnWidth: TableColumnWidthWrapping(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.all(
              width: 1,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            children:
                value
                    .asMap()
                    .entries
                    .map<TableRow>(
                      (entry) => TableRow(
                        decoration:
                            (heading)
                                ? BoxDecoration(
                                  color:
                                      (entry.key == 0)
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest
                                          : null,
                                )
                                : null,
                        children: List.generate(maxCol, (index) {
                          var e = entry.value;
                          String data = e[index] ?? "";
                          if (RegExp(r"^:?--+:?$").hasMatch(data.trim()) ||
                              data.trim().isEmpty) {
                            return const SizedBox();
                          }

                          // Process HTML tags like <br> before passing to MdWidget
                          String processedData = _processHtmlTags(data.trim());

                          // Use Align with centerLeft for first column, Center for others
                          return index == 0
                              ? Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Container(
                                    width:
                                        index < 2
                                            ? MediaQuery.of(
                                                  context,
                                                ).size.width /
                                                2.5
                                            : MediaQuery.of(
                                                  context,
                                                ).size.width /
                                                3.5,
                                    alignment: Alignment.centerLeft,
                                    child: MdWidget(
                                      context,
                                      processedData,
                                      false,
                                      config: config.copyWith(
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              : Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Container(
                                    width:
                                        index < 2
                                            ? MediaQuery.of(
                                                  context,
                                                ).size.width /
                                                2.5
                                            : MediaQuery.of(
                                                  context,
                                                ).size.width /
                                                3.5,
                                    alignment: Alignment.centerRight,
                                    child: MdWidget(
                                      context,
                                      processedData,
                                      false,
                                      config: config.copyWith(
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                        }),
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }

  // Helper method to process HTML tags in table cell content
  String _processHtmlTags(String text) {
    // Replace <br> tags with actual newlines
    String processed = text.replaceAll(
      RegExp(r'<br\s*\/?>', caseSensitive: false),
      '\n',
    );

    // Handle escaped characters like \$, \*, \_, etc.
    processed = processed.replaceAllMapped(
      RegExp(r'\\([\$\*\_\~\`\|\[\]\(\)\#\+\-\.\!\>\<])', caseSensitive: true),
      (match) => match.group(1) ?? '',
    );

    // Normalize spacing between currency symbols and numbers
    processed = processed.replaceAllMapped(
      RegExp(r'([\$₹€£¥])(\s+)(\d)'),
      (match) => '${match.group(1)}${match.group(3)}',
    );

    // Handle other common HTML tags if needed
    // processed = processed.replaceAll(...);

    return processed;
  }
}

class TableColumnWidthWrapping extends TableColumnWidth {
  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double result = 0.0;
    for (final RenderBox cell in cells) {
      result = math.max(result, cell.getMaxIntrinsicWidth(double.infinity));
    }
    return result;
  }

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double result = 0.0;
    for (final RenderBox cell in cells) {
      // Use a reasonable minimum width to ensure text wrapping works
      result = math.max(
        result,
        math.min(cell.getMinIntrinsicWidth(double.infinity), 150.0),
      );
    }
    return result;
  }
}

class CodeBlockMd extends BlockMd {
  @override
  String get expString => r"```(.*?)\n((.*?)(:?\n\s*?```)|(.*)(:?\n```)?)$";

  // Secondary label regex pattern
  final RegExp secondaryLabelRegex = RegExp(
    r'^\[secondary_label\s+([^\]]+)\]',
    multiLine: true,
  );

  bool canProcess(String text) {
    // Check if this is a secondary_label output block
    if (text.trim().startsWith('[secondary_label')) {
      return true;
    }

    // Otherwise check if it's a regular code block
    return text.contains('```') && this.exp.hasMatch(text);
  }

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    // First process as a normal code block to extract the code content
    String codes = this.exp.firstMatch(text)?[2] ?? "";
    String name = this.exp.firstMatch(text)?[1] ?? "";

    // Now check if the code content itself contains a secondary_label pattern
    if (codes.trim().startsWith('[secondary_label')) {
      // Extract the label text
      final match = secondaryLabelRegex.firstMatch(codes);

      if (match != null) {
        // Extract the label text (e.g., "Output", "Topic", etc.)
        final String labelText = match.group(1) ?? '';

        // Extract the content after the label line
        final parts = codes.split('\n');
        var outputText =
            parts.length > 1 ? parts.sublist(1).join('\n').trim() : '';

        // Remove trailing triple backticks if present
        if (outputText.endsWith('```')) {
          outputText = outputText.substring(0, outputText.length - 3).trim();
        }

        // Return the OutputField widget
        return OutputField(
          type: 'secondary_label',
          labelText: labelText,
          output: outputText,
        );
      }
    }

    // If the text itself starts with secondary_label (not inside code block)
    if (text.trim().startsWith('[secondary_label')) {
      // Extract the label text
      final match = secondaryLabelRegex.firstMatch(text);

      if (match != null) {
        // Extract the label text (e.g., "Output", "Topic", etc.)
        final String labelText = match.group(1) ?? '';

        // Extract the content after the label line
        final parts = text.split('\n');
        var outputText =
            parts.length > 1 ? parts.sublist(1).join('\n').trim() : '';

        // Remove trailing triple backticks if present
        if (outputText.endsWith('```')) {
          outputText = outputText.substring(0, outputText.length - 3).trim();
        }

        // Return the OutputField widget
        return OutputField(
          type: 'secondary_label',
          labelText: labelText,
          output: outputText,
        );
      }
    }

    // Continue with normal code block processing
    // Parse label and custom properties from the name field
    String label = "";
    String language = "";
    Color? backgroundColor;
    bool showLineNumbers = false;

    // Check for line_numbers parameter
    if (name.contains("line_numbers")) {
      showLineNumbers = true;
      name = name.replaceAll("line_numbers", "").trim();
      // Remove leading comma if present
      if (name.startsWith(",")) {
        name = name.substring(1).trim();
      }
    }

    // First check if the label is in the code content itself (first line)
    final labelInCodeRegex = RegExp(
      r'^\s*\[label\s+(.*?)\]\s*$',
      multiLine: true,
    );
    final labelInCodeMatch = labelInCodeRegex.firstMatch(codes);
    if (labelInCodeMatch != null) {
      label = labelInCodeMatch.group(1)?.trim() ?? "";
      // Remove the label line from the code
      codes = codes.replaceFirst(labelInCodeRegex, '').trim();
    }
    // Then check if the label is in the language specifier
    else if (name.contains("[label")) {
      final labelMatch = RegExp(r"\[label\s+(.*?)\]").firstMatch(name);
      if (labelMatch != null) {
        label = labelMatch.group(1)?.trim() ?? "";
        name = name.replaceAll(labelMatch.group(0) ?? "", "").trim();
      }
    }

    // Extract custom background color property
    if (name.contains("background=")) {
      final colorMatch = RegExp(r"background=([#\w]+)").firstMatch(name);
      if (colorMatch != null) {
        final colorValue = colorMatch.group(1);
        if (colorValue != null) {
          try {
            if (colorValue.startsWith('#')) {
              backgroundColor = Color(
                int.parse('0xFF${colorValue.substring(1)}'),
              );
            } else {
              // Handle named colors
              final namedColors = {
                'red': Colors.red,
                'blue': Colors.blue,
                'green': Colors.green,
                'yellow': Colors.yellow,
                'purple': Colors.purple,
                'orange': Colors.orange,
                'black': Colors.black,
                'white': Colors.white,
                'grey': Colors.grey,
                'gray': Colors.grey,
              };
              backgroundColor = namedColors[colorValue.toLowerCase()];
            }
          } catch (e) {
            debugPrint('Error parsing color: $e');
          }
        }
        name = name.replaceAll(colorMatch.group(0) ?? "", "").trim();
      }
    }

    language = name; // The remaining text is the language
    codes = codes.replaceAll(r"```", "").trim();
    bool closed = text.endsWith("```");

    // Process highlighted text in the code content
    codes = _processHighlightedText(codes);

    // Remove trailing triple backticks if present
    if (codes.endsWith('```')) {
      codes = codes.substring(0, codes.length - 3).trim();
    }

    return config.codeBuilder?.call(context, language, codes, closed) ??
        CodeField(
          name: language,
          codes: codes,
          label: label,
          backgroundColor: backgroundColor,
          showLineNumbers: showLineNumbers,
        );
  }

  // Helper method to process highlighted text patterns
  String _processHighlightedText(String code) {
    // Replace <^>text<^> with a custom span that will be styled with dark background
    final highlightPattern = RegExp(r'<\^>(.*?)<\^>');

    // We don't actually transform the text here, as the HighlightedText class
    // will handle the rendering with proper styling. We just ensure the pattern
    // is preserved correctly.

    // If we need to do any preprocessing of the pattern, we would do it here
    return code;
  }
}

/// Currency component
class CurrencyMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r'(?<!\\)([$₹])(\d[\d,.]*)');

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    if (match == null) {
      // Check if this is an escaped currency symbol
      var escapedMatch = RegExp(r'\\([$₹])(\d[\d,.]*)').firstMatch(text.trim());
      if (escapedMatch != null) {
        // For escaped currency symbols, just display the symbol and amount without the backslash
        return TextSpan(
          text: "${escapedMatch[1]}${escapedMatch[2]}",
          style: config.style,
        );
      }
      return TextSpan(text: text, style: config.style);
    }
    return TextSpan(
      text: "${match[1]}${match[2]}", // Combine currency symbol and amount
      style: config.style,
    );
  }
}

/// Callout component
class CalloutMd extends BlockMd {
  @override
  RegExp get exp => RegExp(
    r'<\$>\[(note|warning|info|draft)\]([\s\S]*?)<\$>',
    multiLine: true,
  );

  @override
  String get expString => r'<\$>\[(note|warning|info|draft)\]([\s\S]*?)<\$>';

  // Define callout colors based on type
  Map<String, Color> getCalloutColors(
    BuildContext context,
    GptMarkdownConfig config,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Get custom colors from config if available
    final configColors = config.calloutColors;
    if (configColors != null && configColors.isNotEmpty) {
      return configColors;
    }

    // Default colors
    return {
      'note': isDarkMode ? const Color(0xFF1E4620) : const Color(0xFFE8F5E9),
      'warning': isDarkMode ? const Color(0xFF4E342E) : const Color(0xFFFFCDD2),
      'info': isDarkMode ? const Color(0xFF0D47A1) : const Color(0xFFE3F2FD),
      'draft': isDarkMode ? const Color(0xFF4A148C) : const Color(0xFFE1BEE7),
    };
  }

  // Define icons based on type
  IconData getCalloutIcon(String type) {
    switch (type) {
      case 'note':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'info':
        return Icons.lightbulb_outline;
      case 'draft':
        return Icons.edit_note_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    // Try both patterns without string replacements

    // Pattern for unescaped syntax: <$>[type]content<$>
    final RegExp pattern = RegExp(
      r'<\$>\[(note|warning|info|draft)\]([\s\S]*?)<\$>',
      multiLine: true,
    );

    // Pattern for escaped syntax: <\$>[type]content<\$>
    final RegExp escapedPattern = RegExp(
      r'<\\\$>\[(note|warning|info|draft)\]([\s\S]*?)<\\\$>',
      multiLine: true,
    );

    // Check for escaped pattern first
    final escapedMatch = escapedPattern.firstMatch(text);
    if (escapedMatch != null) {
      final type = escapedMatch.group(1) ?? 'note';
      final content = escapedMatch.group(2)?.trim() ?? '';

      final calloutColors = getCalloutColors(context, config);
      final backgroundColor = calloutColors[type] ?? calloutColors['note']!;

      // Capitalize the type for display
      final displayType =
          type.substring(0, 1).toUpperCase() + type.substring(1);

      return _buildCalloutWidget(
        context,
        displayType,
        content,
        backgroundColor,
        type,
        config,
      );
    }

    // Then check for unescaped pattern
    final match = pattern.firstMatch(text);
    if (match == null) {
      return const SizedBox.shrink();
    }

    final type = match.group(1) ?? 'note';
    final content = match.group(2)?.trim() ?? '';

    final calloutColors = getCalloutColors(context, config);
    final backgroundColor = calloutColors[type] ?? calloutColors['note']!;

    // Capitalize the type for display
    final displayType = type.substring(0, 1).toUpperCase() + type.substring(1);

    return _buildCalloutWidget(
      context,
      displayType,
      content,
      backgroundColor,
      type,
      config,
    );
  }

  String getDisplayText(String displayType, String mainContent) {
    // Checks for "**Note:**", "Note:", "**Note:** ", etc.
    final typePattern = RegExp(
      r'^\s*(\*\*|__)?' + RegExp.escape(displayType) + r":?(\*\*|__)?",
      caseSensitive: false,
    );
    if (typePattern.hasMatch(mainContent)) {
      return mainContent;
    } else {
      return "$displayType: $mainContent";
    }
  }

  // Helper method to build the callout widget
  Widget _buildCalloutWidget(
    BuildContext context,
    String displayType,
    String content,
    Color backgroundColor,
    String type,
    GptMarkdownConfig config,
  ) {
    // Check if content contains a label section
    final RegExp labelPattern = RegExp(
      r'^\s*\[label\s+(.*?)\]\s*\n',
      multiLine: true,
    );
    final labelMatch = labelPattern.firstMatch(content);

    String labelText = '';
    String mainContent = content;

    if (labelMatch != null) {
      // Extract the label text and the remaining content
      labelText = labelMatch.group(1) ?? '';
      mainContent = content.substring(labelMatch.end).trim();

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: backgroundColor, width: 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label with markdown support
              RichText(
                text: TextSpan(
                  children: MarkdownComponent.generate(
                    context,
                    labelText,
                    config,
                    true,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              // Main content
              SelectableText.rich(
                TextSpan(
                  children: MarkdownComponent.generate(
                    context,
                    mainContent,
                    config,
                    true,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // No label, just render the content with the type
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: backgroundColor, width: 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SelectableText.rich(
            TextSpan(
              children: MarkdownComponent.generate(
                context,
                getDisplayText(displayType, mainContent),
                config,
                true,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }
  }
}

/// Details component for expandable content
class DetailsMd extends BlockMd {
  @override
  String get expString =>
      (r"\[details(?:\s+(open|closed))?\s+(.*?)\n([\s\S]*?)\]");

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    final exp = RegExp(expString);
    final match = exp.firstMatch(text);
    if (match == null) {
      return const SizedBox.shrink();
    }

    final isOpenByDefault = match.group(1) == 'open';
    final summaryText = match.group(2)?.trim() ?? '';
    final content = match.group(3)?.trim() ?? '';

    return DetailsWidget(
      isOpenByDefault: isOpenByDefault,
      summaryText: summaryText,
      content: content,
      config: config,
    );
  }
}

/// Widget to display expandable details/summary content
class DetailsWidget extends StatefulWidget {
  final bool isOpenByDefault;
  final String summaryText;
  final String content;
  final GptMarkdownConfig config;

  const DetailsWidget({
    Key? key,
    required this.isOpenByDefault,
    required this.summaryText,
    required this.content,
    required this.config,
  }) : super(key: key);

  @override
  State<DetailsWidget> createState() => _DetailsWidgetState();
}

class _DetailsWidgetState extends State<DetailsWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isOpenByDefault;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color:
            theme.brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SelectableText.rich(
                      TextSpan(
                        children: MarkdownComponent.generate(
                          context,
                          widget.summaryText,
                          widget.config,
                          true,
                        ),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
              child: SelectableText.rich(
                TextSpan(
                  children: MarkdownComponent.generate(
                    context,
                    widget.content,
                    widget.config,
                    true,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// YouTube embed component
class YoutubeMd extends BlockMd {
  @override
  String get expString =>
      r'\[youtube\s+([a-zA-Z0-9_-]+)(?:\s+(\d+))?(?:\s+(\d+))?\]';

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    final exp = RegExp(expString);
    final match = exp.firstMatch(text);
    if (match == null) {
      return const SizedBox.shrink();
    }

    final videoId = match.group(1) ?? '';
    // Default height is 270, width is 480 if not specified
    final height = int.tryParse(match.group(2) ?? '') ?? 270;
    final width = int.tryParse(match.group(3) ?? '') ?? 480;

    return YoutubeEmbed(videoId: videoId, height: height, width: width);
  }
}

/// Widget to display YouTube embeds
class YoutubeEmbed extends StatelessWidget {
  final String videoId;
  final int height;
  final int width;

  const YoutubeEmbed({
    Key? key,
    required this.videoId,
    required this.height,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create a thumbnail with play button that opens the video when tapped
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/0.jpg';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      constraints: BoxConstraints(
        maxWidth: width.toDouble(),
        maxHeight: height.toDouble(),
      ),
      child: AspectRatio(
        aspectRatio: width / height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail image
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                image: DecorationImage(
                  image: NetworkImage(thumbnailUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Play button overlay
            Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
            // Clickable area
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Open YouTube video in browser
                  final url = Uri.parse(
                    'https://www.youtube.com/watch?v=$videoId',
                  );
                  _launchURL(url);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to launch URLs
  void _launchURL(Uri url) async {
    try {
      final canLaunch = await url_launcher.canLaunchUrl(url);
      if (canLaunch) {
        await url_launcher.launchUrl(
          url,
          mode: url_launcher.LaunchMode.externalApplication,
        );
      } else {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error checking if URL can be launched: $e');
    }
  }
}

// URL launcher functions
Future<bool> canLaunchUrl(Uri url) async {
  try {
    return await url_launcher.canLaunchUrl(url);
  } catch (e) {
    debugPrint('Error checking if URL can be launched: $e');
    return false;
  }
}

Future<bool> launchUrl(Uri url) async {
  try {
    return await url_launcher.launchUrl(url);
  } catch (e) {
    debugPrint('Error launching URL: $e');
    return false;
  }
}

/// Output block component for rendering labeled output blocks
///
/// This component handles markdown in the format:
/// ```
/// [secondary_label Output]
/// Could not connect to Redis at 127.0.0.1:6379: Connection refused
/// ```
class OutputBlockMd extends BlockMd {
  @override
  String get expString => r'\[secondary_label\s+([^\]]+)\][\s\S]*?';

  @override
  RegExp get exp => RegExp(
    r'\[secondary_label\s+([^\]]+)\][\s\S]*?',
    multiLine: true,
    dotAll: true,
  );

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    // Extract the label and content from the markdown
    final RegExp labelRegex = RegExp(r'\[secondary_label\s+([^\]]+)\]');
    final match = labelRegex.firstMatch(text);

    if (match != null) {
      // Extract the label text (e.g., "Output", "Topic", etc.)
      final String labelText = match.group(1) ?? '';

      // Extract the content after the [secondary_label X] line
      final parts = text.split('\n');
      var outputText =
          parts.length > 1 ? parts.sublist(1).join('\n').trim() : '';

      // Remove trailing triple backticks if present
      if (outputText.endsWith('```')) {
        outputText = outputText.substring(0, outputText.length - 3).trim();
      }

      // Create the OutputField with the extracted label
      return OutputField(
        type: 'secondary_label',
        labelText: labelText,
        output: outputText,
      );
    }

    // Fallback if there's no match
    return Text(text);
  }
}
