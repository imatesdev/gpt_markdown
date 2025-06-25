part of 'gpt_markdown.dart';

/// Markdown components
abstract class MarkdownComponent {
  static List<MarkdownComponent> get globalComponents => [
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
  ];

  static final List<MarkdownComponent> inlineComponents = [
    CurrencyMd(),
    ImageMd(),
    ATagMd(),
    TableMd(),
    StrikeMd(),
    BoldMd(),
    ItalicMd(),
    UnderlineMd(),
    LatexMath(),
    LatexMathMultiLine(),
    HighlightedText(),
    SourceTag(),
    DirectUrlMd(), // Add DirectUrlMd to the inlineComponents list
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
        child: hasNestedContent 
          // For nested content, use MdWidget to process markdown within
          ? MdWidget(context, processedContent, true, config: config)
          // For simple content, use standard text processing
          : config.getRich(TextSpan(
              children: MarkdownComponent.generate(
                context, 
                processedContent, 
                config, 
                true
              )
            )),
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
  @override
  RegExp get exp => RegExp(r"`(?!`)(.+?)(?<!`)`(?!`)");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    var highlightedText = match?[1] ?? "";

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

    var style =
        config.style?.copyWith(
          fontWeight: FontWeight.bold,
          background:
              Paint()
                ..color = GptMarkdownTheme.of(context).highlightColor
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round,
        ) ??
        TextStyle(
          fontWeight: FontWeight.bold,
          background:
              Paint()
                ..color = GptMarkdownTheme.of(context).highlightColor
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round,
        );

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
  // Simplified regex pattern that better matches __text__ without conflicts
  RegExp get exp => RegExp(r"__([^_]+?)__");

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
    return TextSpan(
      text: match[1],
      style: underlineStyle,
    );
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
  RegExp get exp => RegExp(r"!\[(.*?)\]\((.*?)(\s*\{.*?\})?\)");

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
      final cleanAttributes = attributesText.trim().replaceAll(RegExp(r'^\s*\{|\}\s*$'), '');
      
      // Parse width, height, and alignment
      final widthMatch = RegExp(r'width\s*=\s*(\d+)').firstMatch(cleanAttributes);
      if (widthMatch != null) {
        width = double.tryParse(widthMatch.group(1) ?? '');
      }
      
      final heightMatch = RegExp(r'height\s*=\s*(\d+)').firstMatch(cleanAttributes);
      if (heightMatch != null) {
        height = double.tryParse(heightMatch.group(1) ?? '');
      }
      
      final alignMatch = RegExp(r'align\s*=\s*(\w+)').firstMatch(cleanAttributes);
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
        alignment: textAlign == TextAlign.left ? Alignment.centerLeft :
                 textAlign == TextAlign.right ? Alignment.centerRight :
                 Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: textAlign == TextAlign.left ? CrossAxisAlignment.start :
                             textAlign == TextAlign.right ? CrossAxisAlignment.end :
                             CrossAxisAlignment.center,
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
    
    return WidgetSpan(
      alignment: PlaceholderAlignment.bottom,
      child: image,
    );
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
        child: Table(
          textDirection: config.textDirection,
          defaultColumnWidth: CustomTableColumnWidth(),
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

                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: MdWidget(
                              context,
                              (e[index] ?? "").trim(),
                              false,
                              config: config,
                            ),
                          ),
                        );
                      }),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class CodeBlockMd extends BlockMd {
  @override
  String get expString => r"```(.*?)\n((.*?)(:?\n\s*?```)|(.*)(:?\n```)?)$";
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    String codes = this.exp.firstMatch(text)?[2] ?? "";
    String name = this.exp.firstMatch(text)?[1] ?? "";
    codes = codes.replaceAll(r"```", "").trim();
    bool closed = text.endsWith("```");

    return config.codeBuilder?.call(context, name, codes, closed) ??
        CodeField(name: name, codes: codes);
  }
}

/// Currency component
class CurrencyMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r'(?<!\\)([₹\$])(\d[\d,.]*)');

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    return TextSpan(
      text: "${match?[1]}${match?[2]}", // Combine currency symbol and amount
      style: config.style,
    );
  }
}
