import 'dart:convert';

import 'package:html/parser.dart';
import 'package:notus/notus.dart';
import 'package:notus/src/convert/html/src/notus_node.dart';

class NotusHtmlCodec extends Codec<NotusDocument, String> {
  const NotusHtmlCodec();

  @override
  Converter<String, NotusDocument> get decoder => _NotusHtmlDecoder();

  @override
  Converter<NotusDocument, String> get encoder => _NotusHtmlEncoder();
}

class _NotusHtmlEncoder extends Converter<NotusDocument, String> {
  @override
  String convert(NotusDocument input) {
    String html = '';
    for (int i = 0; i < input.root.children.length; i++) {
      List<NotusNode> notusDocLine = _getJsonLine(input.root.children.elementAt(i));
      if (input.root.children.elementAt(i).runtimeType == LineNode) {
        html = html + _decodeNotusLine(notusDocLine);
      } else if (input.root.children.elementAt(i).runtimeType == BlockNode) {
        html = html + _decodeNotusBlock(notusDocLine);
      }
    }
    return html;
  }

  static List<NotusNode> _getJsonLine(var node) {
    String childString = jsonEncode(node.toDelta());
    List<NotusNode> line = List<NotusNode>.from(jsonDecode(childString).map((i) => NotusNode.fromJson(i)));
    return line;
  }

  static List<String> _getLineAttributes(NotusNode notusModel) {
    if (notusModel.attributes == null) {
      return ['<p>', '</p>'];
    } else if (notusModel.attributes!.heading == 1) {
      return ['<h1>', '</h1>'];
    } else if (notusModel.attributes!.heading == 2) {
      return ['<h2>', '</h2>'];
    } else if (notusModel.attributes!.b == true) {
      return ['<b>', '</b>'];
    }
    return [];
  }

  static List<String> _getBlockAttributes(NotusNode notusModel) {
    if (notusModel.attributes!.block == 'ul') {
      return ['<ul>', '</ul>'];
    } else if (notusModel.attributes!.block == 'ol') {
      return ['<ol>', '</ol>'];
    }
    return [];
  }

  static String _decodeNotusLine(List<NotusNode> notusDocLine) {
    String html = '';
    List<String> attributes = _getLineAttributes(notusDocLine.elementAt(notusDocLine.length - 1));
    if (attributes.isEmpty) return html;
    html = attributes[0] + _decodeLineChildren(notusDocLine) + attributes[1];
    return html;
  }

  static String _decodeLineChildren(List<NotusNode> notusDocLine) {
    String html = '';
    for (int i = 0; i < notusDocLine.length; i++) {
      if (notusDocLine.elementAt(i).attributes == null) {
        html = html + notusDocLine.elementAt(i).insert!;
      } else if (notusDocLine.elementAt(i).attributes!.b == true) {
        html = html + '<b>' + notusDocLine.elementAt(i).insert! + '</b>';
      }
    }
    return html;
  }

  static String _decodeNotusBlock(List<NotusNode> notusDocLine) {
    String html = '';
    String childrenHtml = '';
    List<List<NotusNode>> blockLinesList = _splitBlockIntoLines(notusDocLine);

    List<String> attributes = _getBlockAttributes(notusDocLine.elementAt(notusDocLine.length - 1));
    if (attributes == []) return html;
    for (int i = 0; i < blockLinesList.length; i++) {
      childrenHtml = childrenHtml + '<li>' + _decodeNotusLine(blockLinesList.elementAt(i)) + '</li>';
    }

    html = attributes[0] + childrenHtml + attributes[1];
    return html;
  }

  static List<List<NotusNode>> _splitBlockIntoLines(List<NotusNode> notusDocLine) {
    List<List<NotusNode>> blockLinesList = [];
    List<int> sublistBreakPoints = [];

    for (int i = 0; i < notusDocLine.length; i++) {
      if (notusDocLine.elementAt(i).insert == '\n') {
        sublistBreakPoints.add(i);
      }
    }

    for (int i = 0; i < sublistBreakPoints.length; i++) {
      if (i == 0) {
        blockLinesList.add(notusDocLine.sublist(i, sublistBreakPoints.elementAt(i)));
      } else {
        if (i < sublistBreakPoints.length - 1) {
          blockLinesList.add(notusDocLine.sublist(sublistBreakPoints.elementAt(i - 1), sublistBreakPoints.elementAt(i)));
        } else {
          blockLinesList.add(notusDocLine.sublist(sublistBreakPoints.elementAt(i - 1), notusDocLine.length - 1));
        }
      }
    }
    return blockLinesList;
  }
}

class _NotusHtmlDecoder extends Converter<String, NotusDocument> {
  @override
  NotusDocument convert(String input) {
    final document = NotusDocument();
    var data = parse(input.toString()).body;
    if (data == null) {
      return document;
    }
    if (data.nodes.isEmpty) return document;
    document.replace(0, document.length, '');
    for (int i = 0; i < data.nodes.length; i++) {
      if (data.nodes[i].toString().contains('<html h1>')) {
        LineNode line = LineNode();
        line.add(LeafNode(data.nodes[i].text!.replaceAll('\n', '')));
        line.applyAttribute(NotusAttribute.h1);
        document.root.add(line);
      } else if (data.nodes[i].toString().contains('<html h2>')) {
        LineNode line = LineNode();
        line.add(LeafNode(data.nodes[i].text!.replaceAll('\n', '')));
        line.applyAttribute(NotusAttribute.h2);
        document.root.add(line);
      } else if (data.nodes[i].toString().contains('<html p>')) {
        LineNode line = LineNode();
        line = _formatParagraph(data.nodes[i]);
        document.root.add(line);
      } else if (data.nodes[i].toString().contains('<html ul>')) {
        BlockNode block = BlockNode();
        block = _formatBlock(data.nodes[i], NotusAttribute.block.bulletList);
        document.root.add(block);
      } else if (data.nodes[i].toString().contains('<html ol>')) {
        BlockNode block = BlockNode();
        block = _formatBlock(data.nodes[i], NotusAttribute.block.numberList);
        document.root.add(block);
      }
    }
    return document;
  }

  static LineNode _formatParagraph(var line) {
    LineNode lineNode = LineNode();
    for (int j = 0; j < line.nodes.length; j++) {
      LeafNode leaf = LeafNode(line.nodes[j].text.replaceAll('\n', ''));
      if (line.nodes[j].toString().contains('<html b>')) {
        leaf.applyAttribute(NotusAttribute.bold);
        lineNode.add(leaf);
      } else {
        lineNode.add(leaf);
      }
    }
    return lineNode;
  }

  static BlockNode _formatBlock(var line, NotusAttribute attribute) {
    BlockNode block = BlockNode();
    block.applyAttribute(attribute);
    for (int j = 0; j < line.nodes.length; j++) {
      if (line.nodes[j].toString().contains('<html li>')) {
        LineNode lineNode = LineNode();
        lineNode = _formatParagraph(line.nodes[j]);
        block.add(lineNode);
      }
    }
    return block;
  }
}
