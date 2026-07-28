import 'dart:developer' as dev;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:c_template_app/utils/utils.dart';
import 'package:c_template_app/widgets/widgets.dart';

final money = NumberFormat('#,##0.00');

String formatMoney(
  dynamic amount, {
  String? currency = 'ZMW',
}) {
  return NumberFormat.currency(name: currency, decimalDigits: 2).format(amount);
}

Future<void> copyToClipBoard(BuildContext context, String text) async {
  try {
    await Clipboard.setData(
      ClipboardData(text: text),
    ).then((value) {
      if (context.mounted) {
        showInfoSnackBar(
          context,
          message: '$text copied',
          seconds: 2,
        );
      }
    });
  } on Exception catch (_) {}
}

String spacePan(String pan) {
  return pan.replaceAllMapped(
    RegExp('.{4}'),
    (match) => '${match.group(0)} ',
  );
}

String hidePan(String pan) {
  final hidden = pan.replaceAll(RegExp(r'(?<=.{2})\d(?=.{4})'), 'X');
  return spacePan(hidden);
}

String getFileSizeString(int bytes, [int decimals = 0]) {
  if (bytes <= 0) return '0 Bytes';
  const suffixes = [' Bytes', 'KB', 'MB', 'GB', 'TB'];
  final i = (log(bytes) / log(1024)).floor();
  return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + suffixes[i];
}

String addCharAtPosition(
  String s,
  String char,
  int position, {
  bool repeat = false,
}) {
  if (!repeat) {
    if (s.length < position) return s;

    final before = s.substring(0, position);
    final after = s.substring(position, s.length);
    return before + char + after;
  } else {
    if (position == 0) return s;

    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && i % position == 0) buffer.write(char);

      buffer.write(String.fromCharCode(s.runes.elementAt(i)));
    }
    return buffer.toString();
  }
}

String toSentenceCase(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

String toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text
      .split(' ')
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

String buildPlanString(String? sms, String? voice, String? data) {
  final parts = <String>[];

  if (sms != null) {
    parts.add('SMS');
  }
  if (voice != null) {
    parts.add('Voice');
  }
  if (data != null) {
    parts.add('Data');
  }

  return parts.isEmpty ? 'No information' : parts.join(', ');
}

Future<void> urlLaunch(String url, {UrlType urlType = UrlType.web}) async {
  var fullUrl = url;
  if (urlType == UrlType.email) {
    // Make sure the email address is used correctly in mailto links
    // URL components need to be encoded to handle special characters
    final encodedSubject = Uri.encodeComponent('Zicta Tariff Comparator');
    final encodedBody = Uri.encodeComponent('Zicta Tariff Comparator');
    fullUrl = 'mailto:$url?subject=$encodedSubject&body=$encodedBody';
  } else if (urlType == UrlType.phone) {
    fullUrl = 'tel:$url';
  } else if (urlType == UrlType.map) {
    fullUrl = 'https://maps.google.com/?q=${Uri.encodeComponent(url)}';
  }

  try {
    if (await canLaunchUrlString(fullUrl)) {
      await launchUrlString(fullUrl);
    } else {
      dev.log('Could not launch $fullUrl');
    }
  } catch (e) {
    dev.log('Error launching URL: $e');
  }
}
