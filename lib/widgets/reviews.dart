import 'package:flutter/material.dart';

class ReviewItem extends StatelessWidget {
  const ReviewItem({
    required this.name,
    required this.rating,
    required this.timestamp,
    required this.review,
    super.key,
  });
  final String name;
  final int rating;
  final String timestamp;
  final String review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                timestamp,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < rating ? Icons.star : Icons.star,
                color: index < rating ? Colors.amber : Colors.grey[350],
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            review,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
