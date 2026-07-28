part of 'app_bloc.dart';

abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object> get props => [];
}
class AppOpened extends AppEvent {
  const AppOpened({this.getNotifications = true});

  final bool getNotifications;

  @override
  List<Object> get props => [getNotifications];
}
class AppUpdatePrompted extends AppEvent {}
class AppNotificationReceived extends AppEvent {
  const AppNotificationReceived(this.data);

  final JsonMap data;

  @override
  List<Object> get props => [data];
}
class AppEventTracked extends AppEvent {
  const AppEventTracked(this.event);

  final AnalyticsEvent event;

  @override
  List<Object> get props => [event];
}

class UserIdSet extends AppEvent {
  const UserIdSet([this.id = '']);

  final String id;

  @override
  List<Object> get props => [id];
}

class UserPropertySet extends AppEvent {
  const UserPropertySet(this.name, this.value);

  final String name;
  final String value;

  @override
  List<Object> get props => [name, value];
}
