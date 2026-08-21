/// Monotonic suffix so ids generated in a tight loop (e.g. creating 20 beds in
/// one batch) can never collide, even within the same microsecond.
int _sequence = 0;

String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
