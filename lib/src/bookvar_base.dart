import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

typedef Chapter = List<Element>;
typedef Book = List<Chapter>;

abstract class Element {
  final int reference;

  Element({required this.reference});
}

abstract class TextElement extends Element {
  final String content;

  TextElement({required this.content, required int reference}) : super(reference: reference);
}

abstract class BlockElement extends Element {
  final double aspectRatio;

  BlockElement({required this.aspectRatio, required int reference}) : super(reference: reference);
}

class Header extends TextElement {
  Header(String content, {required int reference}) : super(content: content, reference: reference);
}

class Paragraph extends TextElement {
  Paragraph(String content, {required int reference}) : super(content: content, reference: reference);
}

abstract class Image extends BlockElement {
  final List<int> buffer;

  Image({
    required this.buffer,
    required double aspectRatio,
    required int reference
  }) : super(aspectRatio: aspectRatio, reference: reference);

  factory Image.from(List<int> buffer, {required int reference}) {
    if (PngImage._hasPngSignature(buffer)) {
      return PngImage(buffer, reference: reference);
    }
    return UniversalImage(buffer, reference: reference);
  }
}

class UniversalImage extends Image {
  UniversalImage(List<int> buffer, {required int reference}) : super(buffer: buffer, aspectRatio: 1, reference: reference);
}

class PngImage extends Image {
  PngImage(List<int> buffer, {required int reference})
      : super(buffer: buffer, aspectRatio: _calculateAspectRatio(buffer), reference: reference);

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

  var index = 0;

  for (final node in nodes) {
    if (_isImage(node)) {
      final source = node.attributes['src'];

      if (source == null) {
        continue;
      }

      final record =
      images.firstWhere((element) => source.contains(element.filename));

      elements.add(Image.from(record.buffer, reference: index++));
    }

    if (_isEmpty(node)) {
      continue;
    } else if (_isHeader(node)) {
      elements.add(Header(node.text, reference: index++));
    } else if (_isParagraph(node)) {
      elements.add(Paragraph(node.text, reference: index++));
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
