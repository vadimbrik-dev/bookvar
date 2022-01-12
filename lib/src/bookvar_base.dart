import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

typedef Chapter = List<Element>;
typedef Book = List<Chapter>;

abstract class Element {}

abstract class TextElement extends Element {
  final String content;

  TextElement({required this.content}) : super();
}

abstract class BlockElement extends Element {
  final double aspectRatio;

  BlockElement({required this.aspectRatio});
}

class Header extends TextElement {
  Header(String content) : super(content: content);
}

class Paragraph extends TextElement {
  Paragraph(String content) : super(content: content);
}

abstract class Image extends BlockElement {
  final List<int> buffer;

  Image({
    required this.buffer,
    required double aspectRatio,
  }) : super(aspectRatio: aspectRatio);

  factory Image.from(List<int> buffer) {
    if (PngImage._hasPngSignature(buffer)) {
      return PngImage(buffer);
    }
    return UniversalImage(buffer);
  }
}

class UniversalImage extends Image {
  UniversalImage(List<int> buffer) : super(buffer: buffer, aspectRatio: 1);
}

class PngImage extends Image {
  PngImage(List<int> buffer)
      : super(buffer: buffer, aspectRatio: _calculateAspectRatio(buffer));

  static const int widthBytesOffset = 16;
  static const int heightBytesOffset = 20;

  static bool _hasPngSignature(List<int> buffer) =>
      String.fromCharCodes(buffer.sublist(1, 4)) == 'PNG';

  static double _calculateAspectRatio(List<int> buffer) {
    final typedList = Uint8List.fromList(buffer);
    final view = ByteData.view(typedList.buffer);

    final width = view.getUint32(widthBytesOffset);
    final height = view.getUint32(heightBytesOffset);

    return width / height;
  }
}

class ImageRecord {
  final List<int> buffer;
  final String filename;

  ImageRecord({required this.buffer, required this.filename});
}

List<Element> parse(String content, List<ImageRecord> images) {
  final document = html.parse(content);
  final selector = _formatSelector(_visibleElements);
  final nodes = document.querySelectorAll(selector);
  final elements = <Element>[];

  for (final node in nodes) {
    if (_isImage(node)) {
      final source = node.attributes['src'];

      if (source == null) {
        continue;
      }

      final record =
      images.firstWhere((element) => source.contains(element.filename));

      elements.add(Image.from(record.buffer));
    }

    if (_isEmpty(node)) {
      continue;
    } else if (_isHeader(node)) {
      elements.add(Header(node.text));
    } else if (_isParagraph(node)) {
      elements.add(Paragraph(node.text));
    }
  }

  return elements;
}

//region private

const _visibleElements = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'img'];

String _formatSelector(List<String> elements) {
  return elements.join(', ');
}

bool _isEmpty(dom.Element element) {
  return element.text.trim().isEmpty;
}

bool _isHeader(dom.Element element) {
  return ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].contains(element.localName);
}

bool _isTextNode(dom.Element element) {
  return _isHeader(element) || _isParagraph(element);
}

bool _isParagraph(dom.Element element) {
  return element.localName == 'p';
}

bool _isImage(dom.Element element) {
  return element.localName == 'img';
}

//endregion
