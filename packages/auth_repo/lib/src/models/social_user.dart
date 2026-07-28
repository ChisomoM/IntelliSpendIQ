// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'social_user.g.dart';

@JsonSerializable()
class SocialUser extends Equatable {
  const SocialUser({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.email,
    required this.photo,
    required this.phone,
    required this.metaData,
  });

  factory SocialUser.fromJson(Map<String, dynamic> json) =>
      _$SocialUserFromJson(json);

  final String? id;
  final String? provider;
  final String? displayName;
  final String? email;
  final String? photo;
  final String? phone;
  final String? metaData;

  SocialUser copyWith({
    String? id,
    String? provider,
    String? displayName,
    String? email,
    String? photo,
    String? phone,
    String? metaData,
  }) {
    return SocialUser(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photo: photo ?? this.photo,
      phone: phone ?? this.phone,
      metaData: metaData ?? this.metaData,
    );
  }

  Map<String, dynamic> toJson() => _$SocialUserToJson(this);

  @override
  String toString() {
    return '$id, $provider, $displayName, $email, $photo, $phone, $metaData, ';
  }

  @override
  List<Object?> get props => [
        id,
        provider,
        displayName,
        email,
        photo,
        phone,
        metaData,
      ];
}
