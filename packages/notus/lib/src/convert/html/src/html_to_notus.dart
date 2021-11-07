import 'package:html/parser.dart';
import 'package:notus/notus.dart';

class HtmlToNotus {
  static NotusDocument getNotusFromHtml(var text) {
    final document = NotusDocument();
    var data = parse(text.toString()).body;
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
