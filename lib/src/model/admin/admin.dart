import 'package:json_annotation/json_annotation.dart';

part 'admin.g.dart';

@JsonSerializable()
class Admin {
  final String id;
  final String email;
  final String username;
  @JsonKey(ignore: true)
  final String? password;
  final String role;
  final DateTime createdAt;

  Admin({
    required this.id,
    required this.email,
    required this.username,
    this.password,
    required this.role,
    required this.createdAt,
  });

  factory Admin.fromJson(Map<String, dynamic> json) => _$AdminFromJson(json);
  Map<String, dynamic> toJson() => _$AdminToJson(this);
} 