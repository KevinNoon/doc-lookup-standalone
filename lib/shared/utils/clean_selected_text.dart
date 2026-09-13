/// Strips leading/trailing punctuation (quotes, commas, periods, dashes,
/// parens, etc.) that text selection often drags in along with the actual
/// word — e.g. selecting inside a quoted phrase can capture "reformation',"
/// instead of "reformation". Only trims from the edges, so internal
/// punctuation that's part of the word itself (the hyphen in "well-known",
/// the apostrophe in "don't") is preserved.
String cleanSelectedText(String raw) {
  return raw.trim().replaceAll(RegExp(r"^[^\w]+|[^\w]+$"), '');
}
