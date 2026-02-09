String turkishToUpper(String input) {
  // Dart's `toUpperCase()` is locale-insensitive; Turkish needs special casing for i/ı.
  final buffer = StringBuffer();
  for (final codeUnit in input.codeUnits) {
    final ch = String.fromCharCode(codeUnit);
    switch (ch) {
      case 'i':
        buffer.write('İ');
        break;
      case 'ı':
        buffer.write('I');
        break;
      default:
        buffer.write(ch.toUpperCase());
    }
  }
  return buffer.toString();
}

