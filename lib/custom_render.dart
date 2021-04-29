
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/html_parser.dart';
import 'package:flutter_html/src/utils.dart';

typedef CustomRenderMatcher = bool Function(RenderContext context);

CustomRenderMatcher blockElementMatcher() => (context) {
  return context.tree.style.display == Display.BLOCK;
};

CustomRenderMatcher listElementMatcher() => (context) {
  return context.tree.style.display == Display.LIST_ITEM;
};

CustomRenderMatcher replacedElementMatcher() => (context) {
  return context.tree is ReplacedElement;
};

CustomRenderMatcher textContentElementMatcher() => (context) {
  return context.tree is TextContentElement;
};

CustomRenderMatcher interactableElementMatcher() => (context) {
  return context.tree is InteractableElement;
};

CustomRenderMatcher layoutElementMatcher() => (context) {
  return context.tree is LayoutElement;
};

CustomRenderMatcher verticalAlignMatcher() => (context) {
  return context.tree.style.verticalAlign != null
      && context.tree.style.verticalAlign != VerticalAlign.BASELINE;
};

CustomRenderMatcher fallbackMatcher() => (context) {
  return true;
};

class CustomRender {
  final InlineSpan Function(RenderContext, List<InlineSpan> Function())? inlineSpan;
  final Widget Function(RenderContext, List<InlineSpan> Function())? widget;

  CustomRender.fromInlineSpan({
    required this.inlineSpan,
  }) : widget = null;

  CustomRender.fromWidget({
    required this.widget,
  }) : inlineSpan = null;
}

CustomRender blockElementRender({
  Style? style,
  Widget? child,
  List<InlineSpan>? children}) =>
    CustomRender.fromInlineSpan(inlineSpan: (context, buildChildren) =>
        WidgetSpan(
          child: ContainerSpan(
            key: context.key,
            newContext: context,
            style: style ?? context.tree.style,
            shrinkWrap: context.parser.shrinkWrap,
            child: child,
            children: children ?? buildChildren.call(),
          ),
));

CustomRender listElementRender({
  Style? style,
  Widget? child,
  List<InlineSpan>? children}) =>
    CustomRender.fromInlineSpan(inlineSpan: (context, buildChildren) =>
        WidgetSpan(
          child: ContainerSpan(
            key: context.key,
            newContext: context,
            style: style ?? context.tree.style,
            shrinkWrap: context.parser.shrinkWrap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              textDirection: style?.direction ?? context.tree.style.direction,
              children: [
                (style?.listStylePosition ?? context.tree.style.listStylePosition) == ListStylePosition.OUTSIDE ?
                Padding(
                  padding: style?.padding ?? context.tree.style.padding
                      ?? EdgeInsets.only(left: (style?.direction ?? context.tree.style.direction) != TextDirection.rtl ? 10.0 : 0.0,
                          right: (style?.direction ?? context.tree.style.direction) == TextDirection.rtl ? 10.0 : 0.0),
                  child: Text(
                      "${style?.markerContent ?? context.style.markerContent}",
                      textAlign: TextAlign.right,
                      style: style?.generateTextStyle() ?? context.style.generateTextStyle()
                  ),
                ) : Container(height: 0, width: 0),
                Text("\t", textAlign: TextAlign.right),
                Expanded(
                    child: Padding(
                        padding: (style?.listStylePosition ?? context.tree.style.listStylePosition) == ListStylePosition.INSIDE ?
                          EdgeInsets.only(left: (style?.direction ?? context.tree.style.direction) != TextDirection.rtl ? 10.0 : 0.0,
                            right: (style?.direction ?? context.tree.style.direction) == TextDirection.rtl ? 10.0 : 0.0) : EdgeInsets.zero,
                        child: StyledText(
                          textSpan: TextSpan(
                            text: ((style?.listStylePosition ?? context.tree.style.listStylePosition) ==
                                ListStylePosition.INSIDE)
                                ? "${style?.markerContent ?? context.style.markerContent}"
                                : null,
                            children: _getListElementChildren(style?.listStylePosition ?? context.tree.style.listStylePosition, buildChildren),
                            style: style?.generateTextStyle() ?? context.style.generateTextStyle(),
                          ),
                          style: style ?? context.style,
                          renderContext: context,
                        )
                    )
                )
              ],
            ),
          ),
));

CustomRender replacedElementRender({PlaceholderAlignment? alignment, TextBaseline? baseline, Widget? child}) =>
    CustomRender.fromInlineSpan(inlineSpan: (context, buildChildren) => WidgetSpan(
  alignment: alignment ?? (context.tree as ReplacedElement).alignment,
  baseline: baseline ?? TextBaseline.alphabetic,
  child: child ?? (context.tree as ReplacedElement).toWidget(context)!,
));

CustomRender textContentElementRender({String? text}) =>
    CustomRender.fromInlineSpan(inlineSpan: (context, buildChildren) =>
      TextSpan(text: text ?? (context.tree as TextContentElement).text));

CustomRender interactableElementRender({List<InlineSpan>? children}) =>
    CustomRender.fromInlineSpan(inlineSpan: (context, buildChildren) => TextSpan(
  children: children ?? (context.tree as InteractableElement).children
      .map((tree) => context.parser.parseTree(context, tree))
      .map((childSpan) {
    return _getInteractableChildren(context, context.tree as InteractableElement, childSpan,
        context.style.generateTextStyle().merge(childSpan.style));
  }).toList(),
));

CustomRender layoutElementRender({Widget? child}) =>
  CustomRender.fromInlineSpan(inlineSpan: (context, buildChildren) => WidgetSpan(
    child: child ?? (context.tree as LayoutElement).toWidget(context)!,
));

CustomRender verticalAlignRender({
  double? verticalOffset,
  Style? style,
  List<InlineSpan>? children}) =>
    CustomRender.fromInlineSpan(inlineSpan: (context, buildChildren) => WidgetSpan(
  child: Transform.translate(
    key: context.key,
    offset: Offset(0, verticalOffset ?? _getVerticalOffset(context.tree)),
    child: StyledText(
      textSpan: TextSpan(
        style: style?.generateTextStyle() ?? context.style.generateTextStyle(),
        children: children ?? buildChildren.call(),
      ),
      style: context.style,
      renderContext: context,
    ),
  ),
));

CustomRender fallbackRender({Style? style, List<InlineSpan>? children}) =>
    CustomRender.fromInlineSpan(inlineSpan: (context, buildChildren) => TextSpan(
  style: style?.generateTextStyle() ?? context.style.generateTextStyle(),
  children: children ?? buildChildren.call(),
));

final Map<CustomRenderMatcher, CustomRender> defaultRenders = {
  blockElementMatcher(): blockElementRender(),
  listElementMatcher(): listElementRender(),
  textContentElementMatcher(): textContentElementRender(),
  replacedElementMatcher(): replacedElementRender(),
  interactableElementMatcher(): interactableElementRender(),
  layoutElementMatcher(): layoutElementRender(),
  verticalAlignMatcher(): verticalAlignRender(),
  fallbackMatcher(): fallbackRender(),
};

List<InlineSpan> _getListElementChildren(ListStylePosition? position, Function() buildChildren) {
  InlineSpan tabSpan = WidgetSpan(child: Text("\t", textAlign: TextAlign.right));
  List<InlineSpan> children = buildChildren.call();
  if (position == ListStylePosition.INSIDE) {
    children.insert(0, tabSpan);
  }
  return children;
}

InlineSpan _getInteractableChildren(RenderContext context, InteractableElement tree, InlineSpan childSpan, TextStyle childStyle) {
  if (childSpan is TextSpan) {
    return TextSpan(
      text: childSpan.text,
      children: childSpan.children
          ?.map((e) => _getInteractableChildren(context, tree, e, childStyle.merge(childSpan.style)))
          .toList(),
      style: context.style.generateTextStyle().merge(
          childSpan.style == null
              ? childStyle
              : childStyle.merge(childSpan.style)),
      semanticsLabel: childSpan.semanticsLabel,
      recognizer: TapGestureRecognizer()
        ..onTap =
          context.parser.onAnchorTap != null ?
              () => context.parser.onAnchorTap!(tree.href, context, tree.attributes, tree.element)
              : null,
    );
  } else {
    return WidgetSpan(
      child: RawGestureDetector(
        key: context.key,
        gestures: {
          MultipleTapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<MultipleTapGestureRecognizer>(
                () => MultipleTapGestureRecognizer(),
                (instance) {
                  instance
                    ..onTap = context.parser.onAnchorTap != null
                        ? () => context.parser.onAnchorTap!(tree.href, context, tree.attributes, tree.element)
                        : null;
            },
          ),
        },
        child: (childSpan as WidgetSpan).child,
      ),
    );
  }
}

double _getVerticalOffset(StyledElement tree) {
  switch (tree.style.verticalAlign) {
    case VerticalAlign.SUB:
      return tree.style.fontSize!.size! / 2.5;
    case VerticalAlign.SUPER:
      return tree.style.fontSize!.size! / -2.5;
    default:
      return 0;
  }
}