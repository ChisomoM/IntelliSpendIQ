import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// RichText formatCurrency(dynamic value,
//     {Color? prefixColor, Color? valueColor}) {
//   // Convert the input to a double and format it to 2 decimal places
//   double numValue;
//   if (value is String) {
//     numValue = double.tryParse(value) ?? 0.0;
//   } else if (value is num) {
//     numValue = value.toDouble();
//   } else {
//     numValue = 0.0;
//   }
//   String formattedValue = numValue.toStringAsFixed(2);

//   return RichText(
//     text: TextSpan(
//       children: [
//         TextSpan(
//           text: 'ZMW ',
//           style: GoogleFonts.inter(
//             fontSize: 18,
//             color: prefixColor ?? const Color(0xFFFF7900),
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         TextSpan(
//           text: formattedValue,
//           style: GoogleFonts.inter(
//             fontSize: 18,
//             color: valueColor ?? const Color(0xFF4F008D),
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     ),
//   );
// }

class CurrencyText extends StatelessWidget {
  const CurrencyText({
    required this.value, super.key,
    this.prefixColor,
    this.valueColor,
  });
  final double value;
  final Color? prefixColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    // Convert the input to a double and format it to 2 decimal places
    double numValue;
    if (value is String) {
      numValue = value;
    } else {
      numValue = value;
    }

    final formattedValue = numValue.toStringAsFixed(2);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'ZMW ',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: prefixColor ?? Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: formattedValue,
            style: GoogleFonts.inter(
              fontSize: 18,
              color: valueColor ?? Colors.black12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
