import 'dart:async';
import 'dart:io';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:net_source/net_source.dart';
import 'package:notifications_repo/notifications_repo.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'app_event.dart';
part 'app_state.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc(
    AnalyticsRepo analyticsRepo,
    NotificationsRepo notificationsRepo,
  )   : _notificationsRepo = notificationsRepo,
        _analyticsRepo = analyticsRepo,
        super(const AppState()) {
    on<AppOpened>(_onAppOpened);
    on<AppEventTracked>(_onAppEventTracked);
    on<UserIdSet>(_onUserIdSet);
    on<UserPropertySet>(_onUserPropertySet);
    on<AppUpdatePrompted>(_onAppUpdatePrompted);
    on<AppNotificationReceived>(_onAppNotificationReceived);
    _notificationSubscription =
        _notificationsRepo.notification.listen(_notificationReceived);
  }

  final AnalyticsRepo _analyticsRepo;
  final NotificationsRepo _notificationsRepo;
  late StreamSubscription<JsonMap> _notificationSubscription;

  void _notificationReceived(JsonMap data) =>
      add(AppNotificationReceived(data));

  Future<void> _onAppOpened(AppOpened event, Emitter<AppState> emit) async {
    if (event.getNotifications) {
      final notificationData = await _notificationsRepo.getLastNotification();
      emit(
        state.copyWith(notificationData: notificationData),
      );
    }
  }

  Future<void> _onAppUpdatePrompted(
    AppUpdatePrompted event,
    Emitter<AppState> emit,
  ) async {
    final platform = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
            ? 'android'
            : 'unknown';

    final updateDetails = await _notificationsRepo.checkUpdate(platform);

    final packageInfo = await PackageInfo.fromPlatform();
    final version =
        (packageInfo.version, int.tryParse(packageInfo.buildNumber) ?? 1);
    emit(state.copyWith(updateDetails: updateDetails, version: version));
  }

  Future<void> _onAppNotificationReceived(
    AppNotificationReceived event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(notificationData: event.data));
  }

  FutureOr<void> _onUserIdSet(
    UserIdSet event,
    Emitter<AppState> emit,
  ) =>
      _analyticsRepo.setUserId(event.id);

  FutureOr<void> _onUserPropertySet(
    UserPropertySet event,
    Emitter<AppState> emit,
  ) =>
      _analyticsRepo.setUserProperty(event.name, event.value);

  FutureOr<void> _onAppEventTracked(
    AppEventTracked event,
    Emitter<AppState> emit,
  ) =>
      _analyticsRepo.track(event.event);

  @override
  Future<void> close() {
    _notificationSubscription.cancel();
    return super.close();
  }
}
