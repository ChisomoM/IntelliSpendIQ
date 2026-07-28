// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDetails _$UserDetailsFromJson(Map<String, dynamic> json) => UserDetails(
      id: json['id'] as String?,
      hasPassword: json['hasPassword'] as bool?,
      hasPreferences: json['hasPreferences'] as bool?,
    );

Map<String, dynamic> _$UserDetailsToJson(UserDetails instance) =>
    <String, dynamic>{
      'id': instance.id,
      'hasPassword': instance.hasPassword,
      'hasPreferences': instance.hasPreferences,
    };
