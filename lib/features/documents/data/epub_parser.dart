import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../highlights/domain/highlight.dart';

class EpubChapter {
  const EpubChapter({required this.title, required this.htmlContent});

  final String title;
  final String htmlContent;
}

/// Parses the chapters of an EPUB file, in reading order, without relying on
/// a dedicated EPUB package (avoids a hard version conflict between epubx
/// and syncfusion_flutter_pdf over the `xml` package). EPUB is just a ZIP
/// archive containing an OPF manifest/spine and XHTML content files, so this
/// reads that structure directly:
///   1. META-INF/container.xml points at the root OPF file.
///   2. The OPF's `<manifest>` maps ids to file paths (relative to the OPF).
///   3. The OPF's `<spine>` lists those ids in reading order.
Future<List<EpubChapter>> parseEpubChapters(Uint8List bytes) async {
  final archive = ZipDecoder().decodeBytes(bytes);

  final containerFile = _findFile(archive, 'META-INF/container.xml');
  if (containerFile == null) {
    throw const FormatException('Not a valid EPUB: missing META-INF/container.xml');
  }
  final containerXml = XmlDocument.parse(utf8.decode(containerFile.content as List<int>));
  final opfPath = containerXml
      .findAllElements('rootfile')
      .first
      .getAttribute('full-path');
  if (opfPath == null) {
    throw const FormatException('Not a valid EPUB: container.xml has no rootfile.');
  }

  final opfFile = _findFile(archive, opfPath);
  if (opfFile == null) {
    throw FormatException('Not a valid EPUB: OPF file "$opfPath" not found.');
  }
  final opfXml = XmlDocument.parse(utf8.decode(opfFile.content as List<int>));
  final opfDir = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';

  final manifest = <String, String>{};
  for (final item in opfXml.findAllElements('item')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id != null && href != null) {
      manifest[id] = _resolvePath(opfDir, href);
    }
  }

  final chapters = <EpubChapter>[];
  for (final itemRef in opfXml.findAllElements('itemref')) {
    final idRef = itemRef.getAttribute('idref');
    final path = manifest[idRef];
    if (path == null) continue;
    final contentFile = _findFile(archive, path);
    if (contentFile == null) continue;
    final html = utf8.decode(contentFile.content as List<int>, allowMalformed: true);
    chapters.add(EpubChapter(title: 'Chapter ${chapters.length + 1}', htmlContent: html));
  }

  if (chapters.isEmpty) {
    throw const FormatException('EPUB has no readable chapters.');
  }
  return chapters;
}

ArchiveFile? _findFile(Archive archive, String path) {
  final normalized = path.replaceFirst(RegExp(r'^/'), '');
  for (final file in archive.files) {
    if (file.isFile && file.name.replaceFirst(RegExp(r'^/'), '') == normalized) {
      return file;
    }
  }
  return null;
}

String _resolvePath(String baseDir, String relativePath) {
  if (relativePath.startsWith('/')) return relativePath.substring(1);
  final segments = ('$baseDir$relativePath').split('/');
  final resolved = <String>[];
  for (final segment in segments) {
    if (segment == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
    } else if (segment != '.' && segment.isNotEmpty) {
      resolved.add(segment);
    }
  }
  return resolved.join('/');
}

/// Rough plain-text extraction from chapter HTML, used as AI lookup context.
/// Not a full HTML parser — just strips tags, which is good enough for
/// giving the model surrounding prose to disambiguate a word.
String stripHtmlToText(String html) {
  final withoutTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  final unescaped = withoutTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return unescaped.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Wraps the first literal occurrence of each highlight's text in [html]
/// with a colored `<span>`, so highlighted chapters render with visible
/// markup via HtmlWidget. Best-effort: a highlight is only wrapped if its
/// text appears verbatim in the raw HTML — i.e. the original selection
/// didn't cross a tag boundary (like spanning into a `<b>` run). EPUB has no
/// per-character DOM offset model to anchor against more precisely, so a
/// highlight that can't be matched this way is silently skipped rather than
/// rendered incorrectly.
String applyHighlightsToHtml(String html, List<Highlight> highlights) {
  var result = html;
  for (final highlight in highlights) {
    if (highlight.text.isEmpty) continue;
    final index = result.indexOf(highlight.text);
    if (index == -1) continue;
    final before = result.substring(0, index);
    final after = result.substring(index + highlight.text.length);
    result = '$before<span style="background-color: ${highlight.colorHex}">${highlight.text}</span>$after';
  }
  return result;
}
