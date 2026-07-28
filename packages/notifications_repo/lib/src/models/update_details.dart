import 'package:equatable/equatable.dart';

part 'update_details.g.dart';

//// {@template update_details}
//// UpdateDetails description
//// {@template}
class UpdateDetails extends Equatable {
  //// {@macro update_details}
  const UpdateDetails({
    required this.versionNumber,
    required this.minVersionNumber,
    required this.versionName,
    required this.description,
    required this.platform,
  });

  //// Creates a UpdateDetails from Json map
  factory UpdateDetails.fromJson(Map<String, dynamic> data) =>
      _$UpdateDetailsFromJson(data);

  //// A description for version_number
  final int versionNumber;

  //// A description for min_version_number
  final int minVersionNumber;

  //// A description for versionName
  final String versionName;

  //// A description for description
  final String description;

  //// A description for platform
  final String platform;

  //// Creates a copy of the current UpdateDetails with property changes
  UpdateDetails copyWith({
    int? versionNumber,
    int? minVersionNumber,
    String? versionName,
    String? description,
    String? platform,
  }) {
    return UpdateDetails(
      versionNumber: versionNumber ?? this.versionNumber,
      minVersionNumber: minVersionNumber ?? this.minVersionNumber,
      versionName: versionName ?? this.versionName,
      description: description ?? this.description,
      platform: platform ?? this.platform,
    );
  }

  @override
  List<Object?> get props => [
        versionNumber,
        minVersionNumber,
        versionName,
        description,
        platform,
      ];

  //// Creates a Json map from a UpdateDetails
  Map<String, dynamic> toJson() => _$UpdateDetailsToJson(this);

  //// Creates a Json map from a UpdateDetails
  static Map<String, dynamic> filter(Map<String, dynamic> map) =>
      _$UpdateDetailsFilter(map);
}
