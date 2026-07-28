import 'package:flutter/material.dart';
import 'package:c_template_app/utils/utils.dart';
import 'package:c_template_app/widgets/pippy.dart';

class ActionSheet extends StatelessWidget {
  const ActionSheet({
    required this.actions,
    super.key,
    this.title = 'Select an option',
    this.subtitle,
  });

  final List<Widget> actions;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      shrinkWrap: true,
      children: [
        const Pippy(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
        ),
        for (final action in actions) ...[
          action,
          SizedBox(height: hp(8)),
        ],
        SizedBox(height: hp(16)),
      ],
    );
  }
}
