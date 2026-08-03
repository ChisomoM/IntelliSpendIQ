import 'package:flutter/material.dart';
import 'package:intellispendiq/review/review_detail_target.dart';
import 'package:intellispendiq/review/view/review_details_page.dart';

/// Opens [ReviewDetailsPage] without forcing call sites to import the
/// page directly — keeps Edit entry free of a hard cycle with Review.
Future<bool?> openReviewDetails(
  BuildContext context,
  ReviewDetailTarget target,
) {
  return Navigator.of(context).push<bool>(ReviewDetailsPage.route(target));
}
