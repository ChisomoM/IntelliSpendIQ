import 'package:flutter/material.dart';

class CarvedContainer extends StatelessWidget {
  const CarvedContainer({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  CarvedContainer copyWith({Widget? child, EdgeInsets? padding}) {
    return CarvedContainer(
      padding: padding ?? this.padding,
      child: child ?? this.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: child,
    );
  }
}

class BackgroundGradient extends StatelessWidget {
  const BackgroundGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        image: DecorationImage(
          alignment: Alignment.topCenter,
          image: AssetImage('assets/images/background_gradient.png'),
          fit: BoxFit.fitWidth,
        ),
      ),
    );
  }
}
