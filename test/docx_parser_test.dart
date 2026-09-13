import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:doc_lookup/features/documents/data/docx_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _buildDocx(String documentXml, {Map<String, List<int>> extraFiles = const {}}) {
  final archive = Archive();
  final bytes = utf8.encode(documentXml);
  archive.addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  extraFiles.forEach((path, content) {
    archive.addFile(ArchiveFile(path, content.length, content));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

const _relsNamespace = 'xmlns="http://schemas.openxmlformats.org/package/2006/relationships"';

const _wNamespace = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

void main() {
  test('renders a heading and a formatted paragraph, dropping empty paragraphs', () {
    final bytes = _buildDocx('''
<w:document $_wNamespace>
  <w:body>
    <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Chapter One</w:t></w:r></w:p>
    <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Bold</w:t></w:r><w:r><w:t xml:space="preserve"> and </w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t>italic</w:t></w:r><w:r><w:t>.</w:t></w:r></w:p>
    <w:p><w:r><w:t/></w:r></w:p>
  </w:body>
</w:document>
''');

    final pages = parseDocxPages(bytes);
    expect(pages, hasLength(1));
    expect(pages.first, '<h1>Chapter One</h1><p><b>Bold</b> and <i>italic</i>.</p>');
  });

  test('groups consecutive list items into a single <ul> and skips numbering type', () {
    final bytes = _buildDocx('''
<w:document $_wNamespace>
  <w:body>
    <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>First</w:t></w:r></w:p>
    <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Second</w:t></w:r></w:p>
    <w:p><w:r><w:t>Not a list item</w:t></w:r></w:p>
  </w:body>
</w:document>
''');

    final pages = parseDocxPages(bytes);
    expect(pages, hasLength(1));
    expect(pages.first, '<ul><li>First</li><li>Second</li></ul><p>Not a list item</p>');
  });

  test('escapes HTML-special characters and renders <w:br/> as a line break', () {
    final bytes = _buildDocx('''
<w:document $_wNamespace>
  <w:body>
    <w:p><w:r><w:t>Tom &amp; Jerry &lt;3</w:t></w:r><w:r><w:br/><w:t>next line</w:t></w:r></w:p>
  </w:body>
</w:document>
''');

    final pages = parseDocxPages(bytes);
    expect(pages.first, '<p>Tom &amp; Jerry &lt;3<br/>next line</p>');
  });

  test('paginates without splitting a paragraph across pages', () {
    final longWord = 'a' * 40;
    final documentXml = StringBuffer('<w:document $_wNamespace><w:body>');
    for (var i = 0; i < 5; i++) {
      documentXml.write('<w:p><w:r><w:t>$longWord</w:t></w:r></w:p>');
    }
    documentXml.write('</w:body></w:document>');

    final pages = parseDocxPages(_buildDocx(documentXml.toString()), charsPerPage: 100);

    expect(pages.length, greaterThan(1));
    for (final page in pages) {
      // Every page is a sequence of whole <p>...</p> blocks, never a partial one.
      expect(RegExp(r'^(<p>.*?</p>)+$').hasMatch(page), isTrue, reason: page);
    }
    expect(pages.join(), contains('<p>$longWord</p>' * 5));
  });

  test('renders a table as HTML with one <tr> per row and one <td> per cell', () {
    final bytes = _buildDocx('''
<w:document $_wNamespace>
  <w:body>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Role</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Ada</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Engineer</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
    <w:p><w:r><w:t>After the table</w:t></w:r></w:p>
  </w:body>
</w:document>
''');

    final pages = parseDocxPages(bytes);
    final html = pages.join();
    expect(html, contains('<table'));
    expect(html, contains('<td style="border: 1px solid #999; padding: 4px;">Name</td>'));
    expect(html, contains('<td style="border: 1px solid #999; padding: 4px;">Engineer</td>'));
    expect(html.indexOf('</table>'), lessThan(html.indexOf('After the table')));
  });

  test('embeds an inline image as a base64 data URI resolved via relationships', () {
    final imageBytes = [1, 2, 3, 4, 5, 250, 251, 252];
    final documentXml = '''
<w:document $_wNamespace xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    <w:p><w:r><w:drawing>
      <wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData>
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:blipFill><a:blip r:embed="rId1"/></pic:blipFill>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing></w:r></w:p>
  </w:body>
</w:document>
''';
    final relsXml = '''
<Relationships $_relsNamespace>
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
</Relationships>
''';

    final bytes = _buildDocx(
      documentXml,
      extraFiles: {
        'word/_rels/document.xml.rels': utf8.encode(relsXml),
        'word/media/image1.png': imageBytes,
      },
    );

    final html = parseDocxPages(bytes).join();
    expect(html, contains('<img src="data:image/png;base64,${base64Encode(imageBytes)}"'));
  });

  test('skips an image whose relationship target is missing from the archive', () {
    final documentXml = '''
<w:document $_wNamespace xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    <w:p><w:r><w:t>Caption</w:t></w:r><w:r><w:drawing>
      <wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData>
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:blipFill><a:blip r:embed="rIdMissing"/></pic:blipFill>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing></w:r></w:p>
  </w:body>
</w:document>
''';

    final bytes = _buildDocx(documentXml);
    final html = parseDocxPages(bytes).join();
    expect(html, '<p>Caption</p>');
    expect(html, isNot(contains('<img')));
  });
}
