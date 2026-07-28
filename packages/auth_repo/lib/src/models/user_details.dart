// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_details.g.dart';

@JsonSerializable()
class UserDetails extends Equatable {
  const UserDetails({
    required this.id,
    required this.hasPassword,
    required this.hasPreferences,
  });

  ///
  factory UserDetails.fromJson(Map<String, dynamic> json) =>
      _$UserDetailsFromJson(json);
  factory UserDetails.fromDbJson(Map<String, dynamic> json) =>
      _$UserDetailsFromDbJson(json);

  final String? id;
  final bool? hasPassword;
  final bool? hasPreferences;

  UserDetails copyWith({
    String? id,
    bool? hasPassword,
    bool? hasPreferences,
  }) {
    return UserDetails(
      id: id ?? this.id,
      hasPassword: hasPassword ?? this.hasPassword,
      hasPreferences: hasPreferences ?? this.hasPreferences,
    );
  }

  ///
  Map<String, dynamic> toJson() => _$UserDetailsToJson(this);

  ///installing in db
  Map<String, dynamic> toJsonDb() => _$UserDetailsToJsonDb(this);

  @override
  String toString() {
    return '$id, $hasPassword, $hasPreferences, ';
  }

  @override
  List<Object?> get props => [
        id,
        hasPassword,
        hasPreferences,
      ];
}

Map<String, dynamic> _$UserDetailsToJsonDb(UserDetails instance) =>
    <String, dynamic>{
      'id': instance.id,
      'hasPassword': instance.hasPassword ?? false ? 1 : 0,
      'hasPreferences': instance.hasPreferences ?? false ? 1 : 0,
    };
UserDetails _$UserDetailsFromDbJson(Map<String, dynamic> json) => UserDetails(
      id: json['id'] as String? ?? '',
      hasPassword: json['hasPassword'] == 1,
      hasPreferences: json['hasPreferences'] == 1,
    );
