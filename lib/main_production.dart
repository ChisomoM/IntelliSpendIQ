import 'dart:async';

import 'package:intellispendiq/app/app.dart';
import 'package:intellispendiq/bootstrap.dart';

void main() {
  unawaited(
    bootstrap(
      (services) async => App(services: services),
      flavor: AppFlavor.production,
    ),
  );
}
