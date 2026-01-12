import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import '../models/mod_info.dart';
import '../models/game_version.dart';

class ModService extends ChangeNotifier {
  final String _gameDir;
  List<LocalMod> _mods = [];
  bool _isLoading = false;

  ModService(this._gameDir);

  List<LocalMod> get mods => List.unmodifiable(_mods);
  bool get isLoading => _isLoading;

  String getModsDir(String? versionId) {
    if (versionId != null) {
      return p.join(_gameDir, 'versions', versionId, 'mods');
    }
    return p.join(_gameDir, 'mods');
  }

  Future<void> loadMods(String? versionId) async {
    _isLoading = true;
    notifyListeners();

    _mods.clear();
    final modsDir = Directory(getModsDir(versionId));
    
    if (!await modsDir.exists()) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    await for (final entity in modsDir.list()) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (ext == '.jar' || ext == '.disabled') {
          final mod = await _parseMod(entity);
          if (mod != null) _mods.add(mod);
        }
      }
    }

    _mods.sort((a, b) => a.displayName.compareTo(b.displayName));
    _isLoading = false;
    notifyListeners();
  }

  Future<LocalMod?> _parseMod(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final stat = await file.stat();
      final fileName = p.basename(file.path);
      final enabled = !fileName.endsWith('.disabled');

      
      final fabricJson = archive.findFile('fabric.mod.json');
      if (fabricJson != null) {
        return _parseFabricMod(file.path, fileName, fabricJson, stat.size, enabled);
      }

      
      final quiltJson = archive.findFile('quilt.mod.json');
      if (quiltJson != null) {
        return _parseQuiltMod(file.path, fileName, quiltJson, stat.size, enabled);
      }

      
      final modsToml = archive.findFile('META-INF/mods.toml');
      if (modsToml != null) {
        return _parseForgeModToml(file.path, fileName, modsToml, stat.size, enabled);
      }

      
      final mcmodInfo = archive.findFile('mcmod.info');
      if (mcmodInfo != null) {
        return _parseMcmodInfo(file.path, fileName, mcmodInfo, stat.size, enabled);
      }

      
      return LocalMod(
        filePath: file.path,
        fileName: fileName,
        enabled: enabled,
        fileSize: stat.size,
      );
    } catch (e) {
      debugPrint('Failed to parse mod: ${file.path} - $e');
      return null;
    }
  }

  LocalMod _parseFabricMod(String path, String fileName, ArchiveFile file, int size, bool enabled) {
    final json = jsonDecode(utf8.decode(file.content as List<int>));
    
    List<String> authors = [];
    if (json['authors'] != null) {
      for (final author in json['authors']) {
        if (author is String) {
          authors.add(author);
        } else if (author is Map && author['name'] != null) {
          authors.add(author['name']);
        }
      }
    }

    return LocalMod(
      filePath: path,
      fileName: fileName,
      modId: json['id'],
      name: json['name'],
      version: json['version'],
      description: json['description'],
      authors: authors,
      loaderType: ModLoaderType.fabric,
      enabled: enabled,
      fileSize: size,
    );
  }

  LocalMod _parseQuiltMod(String path, String fileName, ArchiveFile file, int size, bool enabled) {
    final json = jsonDecode(utf8.decode(file.content as List<int>));
    final loader = json['quilt_loader'];
    final metadata = loader?['metadata'];

    List<String> authors = [];
    if (metadata?['contributors'] != null) {
      authors = (metadata['contributors'] as Map).keys.cast<String>().toList();
    }

    return LocalMod(
      filePath: path,
      fileName: fileName,
      modId: loader?['id'],
      name: metadata?['name'],
      version: loader?['version'],
      description: metadata?['description'],
      authors: authors,
      loaderType: ModLoaderType.quilt,
      enabled: enabled,
      fileSize: size,
    );
  }

  LocalMod _parseForgeModToml(String path, String fileName, ArchiveFile file, int size, bool enabled) {
    
    final content = utf8.decode(file.content as List<int>);
    
    String? modId, name, version, description;
    final lines = content.split('\n');
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('modId')) {
        modId = _extractTomlValue(trimmed);
      } else if (trimmed.startsWith('displayName')) {
        name = _extractTomlValue(trimmed);
      } else if (trimmed.startsWith('version')) {
        version = _extractTomlValue(trimmed);
      } else if (trimmed.startsWith('description')) {
        description = _extractTomlValue(trimmed);
      }
    }

    return LocalMod(
      filePath: path,
      fileName: fileName,
      modId: modId,
      name: name,
      version: version,
      description: description,
      loaderType: ModLoaderType.forge,
      enabled: enabled,
      fileSize: size,
    );
  }

  String? _extractTomlValue(String line) {
    final match = RegExp(r'=\s*"([^"]*)"').firstMatch(line);
    return match?.group(1);
  }

  LocalMod _parseMcmodInfo(String path, String fileName, ArchiveFile file, int size, bool enabled) {
    try {
      var content = utf8.decode(file.content as List<int>);
      
      final json = jsonDecode(content);
      
      Map<String, dynamic>? modInfo;
      if (json is List && json.isNotEmpty) {
        modInfo = json[0];
      } else if (json is Map) {
        if (json['modList'] != null && (json['modList'] as List).isNotEmpty) {
          modInfo = json['modList'][0];
        } else {
          modInfo = json as Map<String, dynamic>;
        }
      }

      if (modInfo == null) {
        return LocalMod(filePath: path, fileName: fileName, enabled: enabled, fileSize: size);
      }

      return LocalMod(
        filePath: path,
        fileName: fileName,
        modId: modInfo['modid'],
        name: modInfo['name'],
        version: modInfo['version'],
        description: modInfo['description'],
        authors: List<String>.from(modInfo['authorList'] ?? modInfo['authors'] ?? []),
        loaderType: ModLoaderType.forge,
        enabled: enabled,
        fileSize: size,
      );
    } catch (e) {
      return LocalMod(filePath: path, fileName: fileName, enabled: enabled, fileSize: size);
    }
  }

  Future<void> toggleMod(LocalMod mod) async {
    final file = File(mod.filePath);
    String newPath;
    
    if (mod.enabled) {
      
      newPath = '${mod.filePath}.disabled';
    } else {
      
      newPath = mod.filePath.replaceAll('.disabled', '');
    }

    await file.rename(newPath);
    mod.filePath = newPath;
    mod.fileName = p.basename(newPath);
    mod.enabled = !mod.enabled;
    notifyListeners();
  }

  Future<void> deleteMod(LocalMod mod) async {
    final file = File(mod.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    _mods.remove(mod);
    notifyListeners();
  }

  Future<void> addMod(String sourcePath, String? versionId) async {
    final modsDir = Directory(getModsDir(versionId));
    if (!await modsDir.exists()) {
      await modsDir.create(recursive: true);
    }

    final sourceFile = File(sourcePath);
    final fileName = p.basename(sourcePath);
    final destPath = p.join(modsDir.path, fileName);
    
    await sourceFile.copy(destPath);
    
    final mod = await _parseMod(File(destPath));
    if (mod != null) {
      _mods.add(mod);
      _mods.sort((a, b) => a.displayName.compareTo(b.displayName));
      notifyListeners();
    }
  }

  Future<void> openModsFolder(String? versionId) async {
    final modsDir = Directory(getModsDir(versionId));
    if (!await modsDir.exists()) {
      await modsDir.create(recursive: true);
    }
    
    if (Platform.isWindows) {
      await Process.run('explorer', [modsDir.path]);
    }
  }
}
