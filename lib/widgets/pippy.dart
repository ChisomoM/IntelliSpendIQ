import 'package:flutter/material.dart';

class Pippy extends StatelessWidget {
  const Pippy({
    super.key,
    this.width = 32,
    this.height = 4,
    this.radius = 4,
    this.color,
  });

  final double width;
  final double height;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color ??
              Theme.of(context).colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
