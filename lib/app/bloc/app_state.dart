part of 'app_bloc.dart';

/// {@template app_state}
/// AppState description
/// {@endtemplate}
class AppState extends Equatable {
  /// {@macro app_state}
  const AppState({
    this.version = ('1.0.0', 1),
     this.notificationData = const {},
     this.updateDetails,
  });

  //// A description for version
  final (String, int) version;
final JsonMap notificationData;
  final UpdateDetails? updateDetails;

    bool get hasUpdate {
    return version.$2 < (updateDetails?.versionNumber ?? 1);
  }
  String get appVersion => 'v${version.$1}.${version.$2}';
  @override
  List<Object?> get props => [notificationData, updateDetails, version  ];

  /// Creates a copy of the current AppState with property changes
  AppState copyWith({
    (String, int)? version,
    JsonMap? notificationData,
    UpdateDetails? updateDetails,
  }) {
    return AppState(
      version: version ?? this.version,
      notificationData: notificationData ?? this.notificationData,
      updateDetails: updateDetails ?? this.updateDetails,
    );
  }
}

/// {@template app_initial}
/// The initial state of AppState
/// {@endtemplate}
class AppInitial extends AppState {
  /// {@macro app_initial}
  const AppInitial() : super();
}
