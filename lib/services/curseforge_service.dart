import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/remote_mod.dart';
import 'download_service.dart';
import 'game_service.dart';
import 'debug_logger.dart';

class CurseforgeService extends ChangeNotifier {
  
  static const String _officialApi = 'https://api.curseforge.com/v1';
  
  static const String _mcimMirror = 'https://mod.mcimirror.top/curseforge/v1';
  
  
  String? _apiKey;
  
  final DownloadService _downloadService;
  
  List<RemoteMod> _searchResults = [];
  List<CurseforgeCategory> _categories = [];
  bool _isSearching = false;
  String _searchError = '';
  int _totalPages = 0;
  int _currentPage = 0;
  int _totalCount = 0;

  
  

  CurseforgeService(this._downloadService, {String? apiKey}) : _apiKey = apiKey;

  List<RemoteMod> get searchResults => _searchResults;
  List<CurseforgeCategory> get categories => _categories;
  bool get isSearching => _isSearching;
  String get searchError => _searchError;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;
  int get totalCount => _totalCount;

  void setApiKey(String? key) {
    _apiKey = key;
  }

  
  Map<String, String> _getHeaders(String baseUrl) {
    return {
      'Accept': 'application/json',
      'User-Agent': 'OblivionLauncher/1.0.0 (github.com/oblivion-launcher)',
      
      if (_apiKey != null && baseUrl == _officialApi) 'x-api-key': _apiKey!,
    };
  }

  
  
  
  Future<void> searchMods({
    String query = '',
    String? gameVersion,
    int? categoryId,
    ModLoaderType? loader,
    CurseforgeSortType sortType = CurseforgeSortType.popularity,
    int page = 0,
    int pageSize = 20,
  }) async {
    debugLog('[CurseForgeService] searchMods called: query="$query", gameVersion=$gameVersion, categoryId=$categoryId, page=$page');
    _isSearching = true;
    _searchError = '';
    _currentPage = page;
    notifyListeners();

    try {
      
      
      final params = <String, String>{
        'gameId': '432', 
        'classId': '6',  
        'pageSize': '$pageSize',
        'sortOrder': 'desc',
        'sortField': _convertSortType(sortType),
      };
      
      
      if (categoryId != null && categoryId > 0) {
        params['categoryId'] = '$categoryId';
      }
      
      
      if (page > 0) {
        params['index'] = '${page * pageSize}';
      }
      if (query.isNotEmpty) {
        params['searchFilter'] = query;
      }
      if (gameVersion != null && gameVersion.isNotEmpty) {
        params['gameVersion'] = gameVersion;
      }
      if (loader != null && loader != ModLoaderType.any) {
        params['modLoaderType'] = _getModLoaderTypeId(loader);
      }

      debugLog('[CurseForgeService] Built params: $params');

      
      
      final urls = _apiKey != null 
          ? [_mcimMirror, _mcimMirror, _officialApi]
          : [_mcimMirror, _mcimMirror];
      
      debugLog('[CurseForgeService] Will try URLs: $urls');
      
      http.Response? response;
      String? lastError;
      
      for (final baseUrl in urls) {
        try {
          final uri = Uri.parse('$baseUrl/mods/search').replace(queryParameters: params);
          debugLog('[CurseForgeService] Request: $uri');
          
          response = await http.get(
            uri, 
            headers: _getHeaders(baseUrl),
          ).timeout(Duration(seconds: baseUrl == _mcimMirror ? 10 : 15));
          
          debugLog('[CurseForgeService] Response status: ${response.statusCode}, body length: ${response.body.length}');

          if (response.statusCode == 200) {
            
            debugLog('[CurseForgeService] Got 200 response, breaking loop');
            break;
          }
          lastError = 'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}';
          debugLog('[CurseForgeService] Error: $lastError');
        } catch (e) {
          lastError = e.toString();
          debugLog('[CurseForgeService] Exception ($baseUrl): $e');
        }
      }

      if (response == null || response.statusCode != 200) {
        debugLog('[CurseForgeService] All requests failed: $lastError');
        throw Exception('CurseForge 搜索失败: $lastError');
      }

      debugLog('[CurseForgeService] Parsing response...');
      final data = jsonDecode(response.body);
      final mods = data['data'] as List? ?? [];
      final pagination = data['pagination'] as Map<String, dynamic>?;
      
      _totalCount = pagination?['totalCount'] ?? mods.length;
      _totalPages = (_totalCount / pageSize).ceil();
      
      debugLog('[CurseForgeService] Parsed ${mods.length} mods, totalCount: $_totalCount');
      
      _searchResults = mods.map((m) => RemoteMod.fromCurseforge(m)).toList();
      debugLog('[CurseForgeService] Converted to ${_searchResults.length} RemoteMod objects');
    } catch (e, stack) {
      _searchError = e.toString();
      debugLog('[CurseForgeService] Search error: $e\n$stack');
    }

    debugLog('[CurseForgeService] searchMods finished. Results: ${_searchResults.length}, Error: "$_searchError"');
    _isSearching = false;
    notifyListeners();
  }

  
  Future<RemoteMod?> getModDetails(int modId) async {
    final urls = _apiKey != null 
        ? [_mcimMirror, _mcimMirror, _officialApi]
        : [_mcimMirror, _mcimMirror];
    
    for (final baseUrl in urls) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/mods/$modId'),
          headers: _getHeaders(baseUrl),
        ).timeout(Duration(seconds: baseUrl == _mcimMirror ? 10 : 15));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return RemoteMod.fromCurseforge(data['data']);
        }
      } catch (e) {
        debugPrint('[CurseForge] Failed to get mod details from $baseUrl: $e');
      }
    }
    return null;
  }

  
  Future<List<CurseforgeFile>> getModFiles(int modId, {
    String? gameVersion,
    ModLoaderType? loader,
  }) async {
    final params = <String, String>{
      'pageSize': '10000', 
    };
    if (gameVersion != null) {
      params['gameVersion'] = gameVersion;
    }
    if (loader != null && loader != ModLoaderType.any) {
      params['modLoaderType'] = _getModLoaderTypeId(loader);
    }

    final urls = _apiKey != null 
        ? [_mcimMirror, _mcimMirror, _officialApi]
        : [_mcimMirror, _mcimMirror];
    
    for (final baseUrl in urls) {
      try {
        final uri = Uri.parse('$baseUrl/mods/$modId/files').replace(
          queryParameters: params.isNotEmpty ? params : null,
        );
        final response = await http.get(
          uri, 
          headers: _getHeaders(baseUrl),
        ).timeout(Duration(seconds: baseUrl == _mcimMirror ? 10 : 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final files = data['data'] as List;
          return files.map((f) => CurseforgeFile.fromJson(f)).toList();
        }
      } catch (e) {
        debugPrint('[CurseForge] Failed to get mod files from $baseUrl: $e');
      }
    }
    return [];
  }

  
  Future<void> loadCategories() async {
    final urls = _apiKey != null 
        ? [_mcimMirror, _officialApi]
        : [_mcimMirror];
    
    for (final baseUrl in urls) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/categories?gameId=432&classId=6'),
          headers: _getHeaders(baseUrl),
        ).timeout(Duration(seconds: baseUrl == _mcimMirror ? 10 : 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final cats = data['data'] as List;
          _categories = cats.map((c) => CurseforgeCategory.fromJson(c)).toList();
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('[CurseForge] Failed to load categories from $baseUrl: $e');
      }
    }
  }

  
  Future<bool> downloadModFile(CurseforgeFile file, String destPath, {
    void Function(double)? onProgress,
    void Function(String)? onStatus,
  }) async {
    
    return await _downloadService.downloadFilesInBackground(
      '模组: ${file.displayName}',
      [DownloadFile(
        url: file.downloadUrl ?? '',
        path: destPath,
        size: file.fileLength,
      )],
      1,
      onProgress: onProgress,
      onStatus: onStatus,
    );
  }

  
  
  String _convertSortType(CurseforgeSortType type) {
    switch (type) {
      case CurseforgeSortType.featured: return '1';
      case CurseforgeSortType.popularity: return '2';
      case CurseforgeSortType.lastUpdated: return '3';
      case CurseforgeSortType.name: return '4';
      case CurseforgeSortType.author: return '5';
      case CurseforgeSortType.totalDownloads: return '6';
    }
  }

  
  
  String _getModLoaderTypeId(ModLoaderType loader) {
    switch (loader) {
      case ModLoaderType.forge: return '1';
      case ModLoaderType.liteLoader: return '3';
      case ModLoaderType.fabric: return '4';
      case ModLoaderType.quilt: return '5';
      case ModLoaderType.neoForge: return '6';
      default: return '0';
    }
  }
}

enum CurseforgeSortType {
  featured,
  popularity,
  lastUpdated,
  name,
  author,
  totalDownloads,
}

enum ModLoaderType {
  any,
  forge,
  cauldron,
  liteLoader,
  fabric,
  quilt,
  neoForge,
}

class CurseforgeCategory {
  final int id;
  final String name;
  final String slug;
  final String? iconUrl;
  final int? parentCategoryId;

  CurseforgeCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
    this.parentCategoryId,
  });

  factory CurseforgeCategory.fromJson(Map<String, dynamic> json) {
    return CurseforgeCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      iconUrl: json['iconUrl'],
      parentCategoryId: json['parentCategoryId'],
    );
  }
}

class CurseforgeFile {
  final int id;
  final int modId;
  final String displayName;
  final String fileName;
  final DateTime? fileDate;
  final int fileLength;
  final String? downloadUrl;
  final List<String> gameVersions;
  final List<int> sortableGameVersions;
  final int releaseType; 

  CurseforgeFile({
    required this.id,
    required this.modId,
    required this.displayName,
    required this.fileName,
    this.fileDate,
    required this.fileLength,
    this.downloadUrl,
    this.gameVersions = const [],
    this.sortableGameVersions = const [],
    this.releaseType = 1,
  });

  factory CurseforgeFile.fromJson(Map<String, dynamic> json) {
    return CurseforgeFile(
      id: json['id'] ?? 0,
      modId: json['modId'] ?? 0,
      displayName: json['displayName'] ?? '',
      fileName: json['fileName'] ?? '',
      fileDate: json['fileDate'] != null ? DateTime.tryParse(json['fileDate']) : null,
      fileLength: json['fileLength'] ?? 0,
      downloadUrl: json['downloadUrl'],
      gameVersions: List<String>.from(json['gameVersions'] ?? []),
      sortableGameVersions: List<int>.from(json['sortableGameVersions'] ?? []),
      releaseType: json['releaseType'] ?? 1,
    );
  }

  String get releaseTypeName {
    switch (releaseType) {
      case 1: return 'Release';
      case 2: return 'Beta';
      case 3: return 'Alpha';
      default: return 'Unknown';
    }
  }
}
