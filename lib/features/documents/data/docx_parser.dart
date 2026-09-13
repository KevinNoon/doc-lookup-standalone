import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Parses a DOCX file's word/document.xml into paginated HTML, so it can be
/// rendered the same way as EPUB chapters (via HtmlWidget) instead of being
/// flattened to plain text. DOCX has no mature native Flutter renderer and a
/// real conversion pipeline (LibreOffice headless on a server, or a
/// third-party API) means paid hosting, which this project avoids — DOCX is
/// just a ZIP of OOXML, so this reads word/document.xml directly with the
/// same archive + xml packages used for EPUB.
///
/// Preserved: paragraphs, heading levels (styles named "HeadingN"), bold /
/// italic / underline / strikethrough runs, line breaks, bulleted lists,
/// inline images (embedded as base64 data URIs — resolved via
/// word/_rels/document.xml.rels), and tables (as real HTML `<table>`s).
///
/// Not modeled (accepted limitations — real engineering effort for
/// comparatively rare cases): ordered-list numbering (every list renders as
/// a bulleted `<ul>` regardless of its real numbering format), merged table
/// cells (each cell renders individually even if Word visually merges it),
/// floating image position/text-wrap (a floating image still renders, just
/// inline in reading order rather than at its anchored position), and
/// content wrapped in structured document tags (`w:sdt`, e.g. Word's Quick
/// Parts/content controls) — that content is skipped entirely since it
/// isn't a direct child of the document body.
///
/// [charsPerPage] paginates on plain-text length, same budget as the TXT
/// viewer, but never splits a paragraph, list, or table across pages — a
/// page ends at the closest preceding block boundary. Images and tables
/// with no text count as [_blockPseudoLength] toward that budget so a run of
/// them can't produce an unbounded page.
List<String> parseDocxPages(Uint8List bytes, {int charsPerPage = 3000}) {
  final archive = ZipDecoder().decodeBytes(bytes);

  final documentFile = archive.files.firstWhere(
    (f) => f.isFile && f.name == 'word/document.xml',
    orElse: () => throw const FormatException('Not a valid DOCX: missing word/document.xml'),
  );
  final xmlDoc = XmlDocument.parse(utf8.decode(documentFile.content as List<int>));
  final relationships = _parseRelationships(archive);

  final bodies = xmlDoc.findAllElements('w:body');
  if (bodies.isEmpty) {
    throw const FormatException('Not a valid DOCX: missing document body.');
  }

  final blocks = _buildBlocks(bodies.first, archive, relationships);
  if (blocks.isEmpty) {
    throw const FormatException('DOCX has no readable content.');
  }
  return _paginate(blocks, charsPerPage);
}

const _blockPseudoLength = 400;

class _Block {
  const _Block(this.html, this.textLength);
  final String html;
  final int textLength;
}

/// Maps relationship ids (e.g. "rId4") to their target path, resolved
/// relative to word/ — e.g. "media/image1.png" -> "word/media/image1.png".
Map<String, String> _parseRelationships(Archive archive) {
  final relationships = <String, String>{};
  final relsFile = _findArchiveFile(archive, 'word/_rels/document.xml.rels');
  if (relsFile == null) return relationships;

  final relsXml = XmlDocument.parse(utf8.decode(relsFile.content as List<int>));
  for (final rel in relsXml.findAllElements('Relationship')) {
    final id = rel.getAttribute('Id');
    final target = rel.getAttribute('Target');
    if (id != null && target != null) {
      relationships[id] = 'word/${target.replaceFirst(RegExp(r'^\.?/*'), '')}';
    }
  }
  return relationships;
}

ArchiveFile? _findArchiveFile(Archive archive, String path) {
  final normalized = path.replaceFirst(RegExp(r'^/'), '');
  for (final file in archive.files) {
    if (file.isFile && file.name.replaceFirst(RegExp(r'^/'), '') == normalized) {
      return file;
    }
  }
  return null;
}

List<_Block> _buildBlocks(XmlElement body, Archive archive, Map<String, String> relationships) {
  final blocks = <_Block>[];
  final listItems = StringBuffer();
  var listTextLength = 0;

  void flushList() {
    if (listItems.isNotEmpty) {
      blocks.add(_Block('<ul>$listItems</ul>', listTextLength));
      listItems.clear();
      listTextLength = 0;
    }
  }

  for (final child in body.children.whereType<XmlElement>()) {
    switch (child.name.qualified) {
      case 'w:p':
        final runsHtml = _renderRuns(child, archive, relationships);
        if (runsHtml.isEmpty) {
          flushList();
          continue;
        }
        final plainText = _paragraphPlainText(child);
        final length = plainText.trim().isEmpty ? _blockPseudoLength : plainText.length;
        if (_isListItem(child)) {
          listItems.write('<li>$runsHtml</li>');
          listTextLength += length;
        } else {
          flushList();
          final tag = _headingTag(child) ?? 'p';
          blocks.add(_Block('<$tag>$runsHtml</$tag>', length));
        }
      case 'w:tbl':
        flushList();
        final table = _renderTable(child, archive, relationships);
        if (table != null) blocks.add(table);
      default:
        break; // w:sectPr and anything else not modeled.
    }
  }
  flushList();
  return blocks;
}

_Block? _renderTable(XmlElement table, Archive archive, Map<String, String> relationships) {
  final rowsHtml = StringBuffer();
  var textLength = 0;
  var hasContent = false;

  for (final row in table.findElements('w:tr')) {
    final cellsHtml = StringBuffer();
    for (final cell in row.findElements('w:tc')) {
      final cellContent = StringBuffer();
      for (final paragraph in cell.findElements('w:p')) {
        final runsHtml = _renderRuns(paragraph, archive, relationships);
        if (runsHtml.isEmpty) continue;
        if (cellContent.isNotEmpty) cellContent.write('<br/>');
        cellContent.write(runsHtml);
        textLength += _paragraphPlainText(paragraph).length;
        hasContent = true;
      }
      cellsHtml.write('<td style="border: 1px solid #999; padding: 4px;">$cellContent</td>');
    }
    rowsHtml.write('<tr>$cellsHtml</tr>');
  }

  if (!hasContent) return null;
  return _Block(
    '<table style="border-collapse: collapse; width: 100%;">$rowsHtml</table>',
    textLength == 0 ? _blockPseudoLength : textLength,
  );
}

List<String> _paginate(List<_Block> blocks, int charsPerPage) {
  final pages = <String>[];
  final buffer = StringBuffer();
  var currentLength = 0;
  for (final block in blocks) {
    if (currentLength > 0 && currentLength + block.textLength > charsPerPage) {
      pages.add(buffer.toString());
      buffer.clear();
      currentLength = 0;
    }
    buffer.write(block.html);
    currentLength += block.textLength;
  }
  if (buffer.isNotEmpty) pages.add(buffer.toString());
  return pages;
}

XmlElement? _firstChild(XmlElement? parent, String name) {
  if (parent == null) return null;
  final matches = parent.findElements(name);
  return matches.isEmpty ? null : matches.first;
}

bool _isListItem(XmlElement paragraph) {
  final pPr = _firstChild(paragraph, 'w:pPr');
  return _firstChild(pPr, 'w:numPr') != null;
}

String? _headingTag(XmlElement paragraph) {
  final pPr = _firstChild(paragraph, 'w:pPr');
  final styleVal = _firstChild(pPr, 'w:pStyle')?.getAttribute('w:val');
  if (styleVal == null) return null;
  final match = RegExp(r'^Heading(\d)$', caseSensitive: false).firstMatch(styleVal);
  if (match == null) return null;
  final level = int.parse(match.group(1)!).clamp(1, 6);
  return 'h$level';
}

String _paragraphPlainText(XmlElement paragraph) {
  final buffer = StringBuffer();
  for (final t in paragraph.findAllElements('w:t')) {
    buffer.write(t.innerText);
  }
  return buffer.toString();
}

String _renderRuns(XmlElement paragraph, Archive archive, Map<String, String> relationships) {
  final buffer = StringBuffer();
  for (final run in paragraph.findElements('w:r')) {
    buffer.write(_renderRun(run, archive, relationships));
  }
  return buffer.toString();
}

String _renderRun(XmlElement run, Archive archive, Map<String, String> relationships) {
  final content = StringBuffer();
  for (final child in run.children.whereType<XmlElement>()) {
    switch (child.name.qualified) {
      case 'w:t':
        content.write(_escapeHtml(child.innerText));
      case 'w:tab':
        content.write('&nbsp;&nbsp;&nbsp;&nbsp;');
      case 'w:br':
        content.write('<br/>');
      case 'w:drawing':
        final img = _renderImage(child, archive, relationships);
        if (img != null) content.write(img);
    }
  }
  if (content.isEmpty) return '';

  var html = content.toString();
  final rPr = _firstChild(run, 'w:rPr');
  if (_hasToggleProperty(rPr, 'w:b')) html = '<b>$html</b>';
  if (_hasToggleProperty(rPr, 'w:i')) html = '<i>$html</i>';
  if (_hasUnderline(rPr)) html = '<u>$html</u>';
  if (_hasToggleProperty(rPr, 'w:strike')) html = '<s>$html</s>';
  return html;
}

/// Resolves a `<w:drawing>` (covers both inline `wp:inline` and floating
/// `wp:anchor` images — both just wrap an `a:blip` the same way) to an
/// `<img>` tag with the source image embedded as a base64 data URI.
String? _renderImage(XmlElement drawing, Archive archive, Map<String, String> relationships) {
  final blips = drawing.findAllElements('a:blip');
  if (blips.isEmpty) return null;
  final rId = blips.first.getAttribute('r:embed');
  if (rId == null) return null;

  final path = relationships[rId];
  if (path == null) return null;
  final imageFile = _findArchiveFile(archive, path);
  if (imageFile == null) return null;

  final mimeType = _mimeTypeForPath(path);
  if (mimeType == null) return null;

  final base64Data = base64Encode(imageFile.content as List<int>);
  return '<img src="data:$mimeType;base64,$base64Data" style="max-width: 100%; height: auto;" />';
}

String? _mimeTypeForPath(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'bmp' => 'image/bmp',
    'webp' => 'image/webp',
    _ => null,
  };
}

bool _hasToggleProperty(XmlElement? rPr, String tagName) {
  final element = _firstChild(rPr, tagName);
  if (element == null) return false;
  final val = element.getAttribute('w:val');
  return val == null || (val != 'false' && val != '0');
}

bool _hasUnderline(XmlElement? rPr) {
  final underline = _firstChild(rPr, 'w:u');
  final val = underline?.getAttribute('w:val');
  return val != null && val != 'none';
}

String _escapeHtml(String text) {
  return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
