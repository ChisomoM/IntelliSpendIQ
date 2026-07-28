// utils.dart
import 'package:intl/intl.dart';

String generateIdempotencyKey(String transactionType) {
  const prefix = 'ZED';

  // Get current date and time
  final now = DateTime.now();
  final date = DateFormat('yyMMdd').format(now);
  final time = DateFormat('HHmmss').format(now);

  // Generate sequential number
  var sequentialNumber = 0;
  sequentialNumber = (sequentialNumber + 1) % 1000000;
  final sequentialPart =
      '''${String.fromCharCode(65 + sequentialNumber ~/ 1000000)}${sequentialNumber.toString().padLeft(6, '0')}''';

  return '$prefix:$transactionType$date.$time.$sequentialPart';
}
