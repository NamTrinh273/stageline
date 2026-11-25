/// Thrown when a `.concert`, `.lrc`, `.txt`, or QR payload is malformed or unsupported.
class ConcertFormatException implements Exception {
  const ConcertFormatException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'ConcertFormatException: $message'
      : 'ConcertFormatException: $message ($cause)';
}

/// Thrown when a single compressed song exceeds the safe static QR character cap.
class QrPayloadTooLargeException implements Exception {
  const QrPayloadTooLargeException({
    required this.encodedLength,
    required this.maxLength,
  });

  final int encodedLength;
  final int maxLength;

  @override
  String toString() =>
      'QrPayloadTooLargeException: encoded length $encodedLength exceeds '
      'safe QR limit of $maxLength characters. Export a .concert file instead.';
}
