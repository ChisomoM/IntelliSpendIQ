part of 'settings_cubit.dart';

enum SettingsStatus { initial, loaded }

class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.pinSet = false,
    this.biometricsAvailable = false,
    this.biometricsEnabled = false,
    this.anthropicApiKeyConfigured = false,
  });

  final SettingsStatus status;

  /// Whether an app-lock PIN is configured.
  final bool pinSet;

  /// Whether the device can do biometrics at all right now.
  final bool biometricsAvailable;

  /// Whether the user opted in.
  final bool biometricsEnabled;

  /// Whether an Anthropic API key is stored. The key itself never
  /// leaves Keystore into this state.
  final bool anthropicApiKeyConfigured;

  /// Biometrics are only offerable once a PIN exists — they are a
  /// shortcut past the PIN, never a replacement for having one.
  bool get canOfferBiometrics => pinSet && biometricsAvailable;

  SettingsState copyWith({
    SettingsStatus? status,
    bool? pinSet,
    bool? biometricsAvailable,
    bool? biometricsEnabled,
    bool? anthropicApiKeyConfigured,
  }) {
    return SettingsState(
      status: status ?? this.status,
      pinSet: pinSet ?? this.pinSet,
      biometricsAvailable: biometricsAvailable ?? this.biometricsAvailable,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      anthropicApiKeyConfigured:
          anthropicApiKeyConfigured ?? this.anthropicApiKeyConfigured,
    );
  }

  @override
  List<Object?> get props => [
    status,
    pinSet,
    biometricsAvailable,
    biometricsEnabled,
    anthropicApiKeyConfigured,
  ];
}
