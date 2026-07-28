// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SocialUser _$SocialUserFromJson(Map<String, dynamic> json) => SocialUser(
      id: json['id'] as String?,
      provider: json['provider'] as String?,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      photo: json['photo'] as String?,
      phone: json['phone'] as String?,
      metaData: json['metaData'] as String?,
    );

Map<String, dynamic> _$SocialUserToJson(SocialUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'provider': instance.provider,
      'displayName': instance.displayName,
      'email': instance.email,
      'photo': instance.photo,
      'phone': instance.phone,
      'metaData': instance.metaData,
    };
