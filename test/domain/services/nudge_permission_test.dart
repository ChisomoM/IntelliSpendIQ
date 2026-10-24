import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/domain/models/nudge_settings.dart';
import 'package:intellispendiq/domain/services/nudge_permission.dart';

import '../../support/test_harness.dart';

class _FakeReminders extends NoopReminderService {
  _FakeReminders({this.enabled = false});

  bool enabled;
  var prompts = 0;

  @override
  Future<bool> areNotificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    prompts++;
    return enabled;
  }
}

void main() {
  late AppServices services;
  late _FakeReminders reminders;
  late NudgePermission permission;

  setUp(() async {
    services = await createTestServices();
    reminders = _FakeReminders();
    permission = NudgePermission(
      settings: services.settings,
      nudgeSettings: services.nudgeSettings,
      reminders: reminders,
    );
  });

  tearDown(() => services.dispose());

  test('asks once when nudging is on and notifications are off', () async {
    expect(await permission.requestOnce(), isTrue);
    expect(reminders.prompts, 1);

    expect(await permission.requestOnce(), isFalse);
    expect(reminders.prompts, 1, reason: 'never a second prompt');
  });

  test('does not ask when the user turned nudging off', () async {
    await services.nudgeSettings.save(const NudgeSettings(enabled: false));

    expect(await permission.requestOnce(), isFalse);
    expect(reminders.prompts, 0);
  });

  test('does not ask when notifications are already allowed', () async {
    reminders.enabled = true;

    expect(await permission.requestOnce(), isFalse);
    expect(reminders.prompts, 0);
  });
}
