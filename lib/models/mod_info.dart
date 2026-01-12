import 'game_version.dart';

class LocalMod {
  String filePath;
  String fileName;
  final String? modId;
  final String? name;
  final String? version;
  final String? description;
  final List<String> authors;
  final ModLoaderType loaderType;
  bool enabled;
  final int fileSize;

  LocalMod({
    required this.filePath,
    required this.fileName,
    this.modId,
    this.name,
    this.version,
    this.description,
    this.authors = const [],
    this.loaderType = ModLoaderType.none,
    this.enabled = true,
    this.fileSize = 0,
  });

  String get displayName => name ?? fileName;
}
