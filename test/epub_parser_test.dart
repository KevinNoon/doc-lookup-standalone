import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:doc_lookup/features/documents/data/epub_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _buildMinimalEpub() {
  final archive = Archive();

  void addTextFile(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  addTextFile('mimetype', 'application/epub+zip');
  addTextFile('META-INF/container.xml', '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''');
  addTextFile('OEBPS/content.opf', '''
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <manifest>
    <item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>
''');
  addTextFile('OEBPS/chapter1.xhtml', '<html><body><p>Hello serendipity.</p></body></html>');
  addTextFile('OEBPS/chapter2.xhtml', '<html><body><p>Second chapter text.</p></body></html>');

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('parseEpubChapters extracts chapters in spine order', () async {
    final bytes = _buildMinimalEpub();
    final chapters = await parseEpubChapters(bytes);

    expect(chapters, hasLength(2));
    expect(chapters[0].htmlContent, contains('Hello serendipity.'));
    expect(chapters[1].htmlContent, contains('Second chapter text.'));
  });

  test('stripHtmlToText removes tags and collapses whitespace', () {
    final text = stripHtmlToText('<p>Hello  <b>world</b>.</p>\n<p>Second   line.</p>');
    expect(text, 'Hello world . Second line.');
  });
}
