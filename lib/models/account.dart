import 'dart:convert';
import 'package:crypto/crypto.dart';

enum AccountType { offline, microsoft, authlibInjector }

class Account {
  final String id;
  final AccountType type;
  final String username;
  final String uuid;
  String accessToken;
  String refreshToken;
  String? skinUrl;
  String? authlibServer;
  DateTime lastUsed;

  Account({
    required this.id,
    required this.type,
    required this.username,
    required this.uuid,
    this.accessToken = '',
    this.refreshToken = '',
    this.skinUrl,
    this.authlibServer,
    DateTime? lastUsed,
  }) : lastUsed = lastUsed ?? DateTime.now();

  factory Account.offline(String username) {
    return Account(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: AccountType.offline,
      username: username,
      uuid: _generateOfflineUUID(username),
      accessToken: DateTime.now().millisecondsSinceEpoch.toRadixString(16),
    );
  }

  static String _generateOfflineUUID(String username) {
    final bytes = utf8.encode('OfflinePlayer:$username');
    final hash = md5.convert(bytes).bytes;
    final modified = List<int>.from(hash);
    modified[6] = (modified[6] & 0x0f) | 0x30;
    modified[8] = (modified[8] & 0x3f) | 0x80;
    return modified.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'username': username,
    'uuid': uuid,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'skinUrl': skinUrl,
    'authlibServer': authlibServer,
    'lastUsed': lastUsed.toIso8601String(),
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'],
    type: AccountType.values[json['type']],
    username: json['username'],
    uuid: json['uuid'],
    accessToken: json['accessToken'] ?? '',
    refreshToken: json['refreshToken'] ?? '',
    skinUrl: json['skinUrl'],
    authlibServer: json['authlibServer'],
    lastUsed: DateTime.tryParse(json['lastUsed'] ?? '') ?? DateTime.now(),
  );
}
