part of 'update_details.dart';

UpdateDetails _$UpdateDetailsFromJson(Map<String, dynamic> json) =>
    UpdateDetails(
      versionNumber: int.tryParse(json['version_number'].toString()) ?? 1,
      minVersionNumber:
          int.tryParse(json['min_version_number'].toString()) ?? 1,
      versionName: json['version_name'] as String,
      description: json['description'] as String,
      platform: json['platform'] as String,
    );

Map<String, dynamic> _$UpdateDetailsToJson(UpdateDetails instance) =>
    <String, dynamic>{
      'version_number': instance.versionNumber,
      'min_version_number': instance.minVersionNumber,
      'version_name': instance.versionName,
      'description': instance.description,
      'platform': instance.platform,
    };

Map<String, dynamic> _$UpdateDetailsFilter(Map<String, dynamic> instance) =>
    <String, dynamic>{
      'version_number': instance['version_number'],
      'min_version_number': instance['min_version_number'],
      'version_name': instance['version_name'],
      'description': instance['description'],
      'platform': instance['platform'],
    };
