import 'package:flutter/material.dart';
import 'package:c_template_app/utils/config.dart';

export 'constants.dart';
export 'default_widgets.dart';
export 'enums.dart';
export 'functions.dart';
export 'reusable_animations.dart';
export 'screen_size.dart';

const kAppStoreId = '1609047449';

// const baseUrl = 'http://95.179.210.39'; // production
// String baseUrl = 'http://${Config.dev().host}'; // uat
Config? config;
// final socket = SocketSource.init(config!.socketUrl, alwaysConnected: true);

String baseUrl = 'http://${Config.dev().host}'; // uat
const kAppCornerRadius = 12.0;
const kPrimaryColor = Color(0xFF288840);
const kSecondaryColor = Color(0xFF54B065);

InputDecoration kInputDecoration(BuildContext context) => InputDecoration(
  floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
  focusedBorder: UnderlineInputBorder(
    borderSide: BorderSide(
      color: Theme.of(context).colorScheme.primary,
      width: 2,
    ),
  ),
);
