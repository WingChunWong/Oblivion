import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/remote_mod.dart';
import 'download_service.dart';
import 'curseforge_service.dart';
import 'game_service.dart' show DownloadFile;
import 'debug_logger.dart';

class ModSearchStorage {
  
  int curseForgeOffset = 0;
  int curseForgeTotal = -1; 
  
  
  int modrinthOffset = 0;
  int modrinthTotal = -1;
  
  
  List<RemoteMod> results = [];
  
  
  String? errorMessage;
  
  void reset() {
    curseForgeOffset = 0;
    curseForgeTotal = -1;
    modrinthOffset = 0;
    modrinthTotal = -1;
    results = [];
    errorMessage = null;
  }
  
  
  void resetSource(ModSourceType source) {
    if (source == ModSourceType.modrinth) {
      modrinthOffset = 0;
      modrinthTotal = -1;
    } else {
      curseForgeOffset = 0;
      curseForgeTotal = -1;
    }
    results = [];
    errorMessage = null;
  }
}

class ModSearchRequest {
  final ModSourceType source;
  final String query;
  final String? gameVersion;
  final String? category;
  final ModLoaderFilter? loader;
  final ModSortType sortType;
  final int pageSize;
  
  ModSearchRequest({
    required this.source,
    this.query = '',
    this.gameVersion,
    this.category,
    this.loader,
    this.sortType = ModSortType.downloads,
    this.pageSize = 20,
  });
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModSearchRequest &&
        other.source == source &&
        other.query == query &&
        other.gameVersion == gameVersion &&
        other.category == category &&
        other.loader == loader &&
        other.sortType == sortType;
  }
  
  @override
  int get hashCode => Object.hash(source, query, gameVersion, category, loader, sortType);
}

class ModDownloadService extends ChangeNotifier {
  
  
  static const String _modrinthOfficial = 'https://api.modrinth.com/v2';
  
  static const String _modrinthMirror = 'https://mod.mcimirror.top/modrinth/v2';
  
  final DownloadService _downloadService;
  late final CurseforgeService _curseforgeService;
  
  
  final ModSearchStorage _storage = ModSearchStorage();
  
  
  ModSearchRequest? _currentRequest;
  
  
  bool _isSearching = false;
  int _currentPage = 0;
  List<ModCategory> _categories = [];

  ModDownloadService(this._downloadService) {
    _curseforgeService = CurseforgeService(_downloadService);
  }

  
  List<RemoteMod> get searchResults => _storage.results;
  List<ModCategory> get categories => _categories;
  bool get isSearching => _isSearching;
  String get searchError => _storage.errorMessage ?? '';
  int get currentPage => _currentPage;
  int get totalHits {
    if (_currentRequest == null) return 0;
    if (_currentRequest!.source == ModSourceType.modrinth) {
      return _storage.modrinthTotal > 0 ? _storage.modrinthTotal : 0;
    } else {
      return _storage.curseForgeTotal > 0 ? _storage.curseForgeTotal : 0;
    }
  }
  int get totalPages {
    final total = totalHits;
    if (total <= 0) return 0;
    return (total / (_currentRequest?.pageSize ?? 20)).ceil();
  }
  ModSourceType get currentSource => _currentRequest?.source ?? ModSourceType.modrinth;
  CurseforgeService get curseforgeService => _curseforgeService;
  bool get hasSearched => _currentRequest != null;

  
  void setSource(ModSourceType source) {
    debugLog('[ModDownload] setSource: $source (current: ${_currentRequest?.source})');
    if (_currentRequest?.source == source) return;
    
    
    final newRequest = ModSearchRequest(
      source: source,
      query: _currentRequest?.query ?? '',
      gameVersion: _currentRequest?.gameVersion,
      category: _currentRequest?.category,
      loader: _currentRequest?.loader,
      sortType: _currentRequest?.sortType ?? ModSortType.downloads,
    );
    
    debugLog('[ModDownload] New request: query="${newRequest.query}", gameVersion=${newRequest.gameVersion}');
    
    
    _storage.reset();  
    _currentPage = 0;
    _currentRequest = newRequest;
    notifyListeners();
  }

  
  Future<void> searchMods({
    String query = '',
    String? gameVersion,
    String? category,
    ModLoaderFilter? loader,
    ModSortType sortType = ModSortType.downloads,
    int page = 0,
    int pageSize = 20,
  }) async {
    debugLog('[ModDownload] searchMods called: query="$query", page=$page, gameVersion=$gameVersion, category=$category, loader=$loader');
    
    
    if (_isSearching) {
      debugLog('[ModDownload] Already searching, skipping...');
      return;
    }
    
    final source = _currentRequest?.source ?? ModSourceType.modrinth;
    
    final newRequest = ModSearchRequest(
      source: source,
      query: query,
      gameVersion: gameVersion,
      category: category,
      loader: loader,
      sortType: sortType,
      pageSize: pageSize,
    );
    
    debugLog('[ModDownload] searchMods: source=$source, query="$query", page=$page, gameVersion=$gameVersion, category=$category, loader=$loader');
    
    _currentRequest = newRequest;
    _currentPage = page;
    
    _isSearching = true;
    _storage.errorMessage = null;
    _storage.results = [];  
    notifyListeners();
    
    try {
      
      final offset = page * pageSize;
      debugLog('[ModDownload] Calculated offset: $offset');
      
      if (source == ModSourceType.modrinth) {
        _storage.modrinthOffset = offset;
        debugLog('[ModDownload] Calling _searchModrinth...');
        await _searchModrinth(newRequest);
      } else {
        _storage.curseForgeOffset = offset;
        debugLog('[ModDownload] Calling _searchCurseForge...');
        await _searchCurseForge(newRequest);
      }
      
      debugLog('[ModDownload] Search completed: ${_storage.results.length} results, error: ${_storage.errorMessage}');
    } catch (e, stack) {
      _storage.errorMessage = e.toString();
      debugLog('[ModDownload] Search error: $e');
      debugLog('[ModDownload] Stack: $stack');
    } finally {
      _isSearching = false;
      debugLog('[ModDownload] Search finished, notifying listeners. Results: ${_storage.results.length}');
      notifyListeners();
    }
  }

  
  Future<void> _searchModrinth(ModSearchRequest request) async {
    debugLog('[Modrinth] _searchModrinth started');
    
    
    final facets = <String>[];
    facets.add('["project_type:mod"]');  
    
    if (request.gameVersion != null && request.gameVersion!.isNotEmpty) {
      facets.add('["versions:\'${request.gameVersion}\'"]');  
    }
    if (request.category != null && request.category!.isNotEmpty) {
      facets.add('["categories:\'${request.category}\'"]');  
    }
    if (request.loader != null) {
      facets.add('["categories:\'${request.loader!.name}\'"]');  
    }

    
    final params = <String, String>{
      'limit': '${request.pageSize}',
      'index': _convertSortType(request.sortType),
    };
    
    if (request.query.isNotEmpty) {
      params['query'] = request.query;
    }
    if (_storage.modrinthOffset > 0) {
      params['offset'] = '${_storage.modrinthOffset}';
    }
    if (facets.isNotEmpty) {
      params['facets'] = '[${facets.join(",")}]';
    }

    debugLog('[Modrinth] Params: $params');
    debugLog('[Modrinth] Facets: ${params['facets']}');

    
    
    final urls = [
      _modrinthMirror,
      _modrinthMirror,  
      _modrinthOfficial,
    ];
    
    http.Response? response;
    String? lastError;
    
    for (final baseUrl in urls) {
      try {
        final uri = Uri.parse('$baseUrl/search').replace(queryParameters: params);
        debugLog('[Modrinth] Request: $uri');
        
        response = await http.get(uri, headers: {
          'User-Agent': 'OblivionLauncher/1.0.0 (github.com/oblivion-launcher)',
          'Accept': 'application/json',
        }).timeout(Duration(seconds: baseUrl == _modrinthMirror ? 10 : 15));

        debugLog('[Modrinth] Response status: ${response.statusCode}');
        debugLog('[Modrinth] Response body length: ${response.body.length}');
        
        if (response.statusCode == 200) {
          debugLog('[Modrinth] Got 200 response, breaking loop');
          break;
        }
        lastError = 'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}';
        debugLog('[Modrinth] Error: $lastError');
      } catch (e) {
        lastError = e.toString();
        debugLog('[Modrinth] Exception ($baseUrl): $e');
        
        if (baseUrl == _modrinthMirror) continue;
      }
    }

    if (response == null || response.statusCode != 200) {
      debugLog('[Modrinth] All requests failed: $lastError');
      throw Exception('Modrinth 搜索失败: $lastError');
    }

    debugLog('[Modrinth] Parsing response...');
    final data = jsonDecode(response.body);
    final hits = data['hits'] as List;
    _storage.modrinthTotal = data['total_hits'] as int;
    debugLog('[Modrinth] Parsed ${hits.length} hits, total: ${_storage.modrinthTotal}');
    
    _storage.results = hits.map((hit) => RemoteMod.fromModrinthSearch(hit)).toList();
    
    debugLog('[Modrinth] Converted to ${_storage.results.length} RemoteMod objects');
  }

  
  Future<void> _searchCurseForge(ModSearchRequest request) async {
    debugLog('[CurseForge] _searchCurseForge started');
    
    ModLoaderType? cfLoader;
    if (request.loader != null) {
      cfLoader = switch (request.loader!) {
        ModLoaderFilter.fabric => ModLoaderType.fabric,
        ModLoaderFilter.forge => ModLoaderType.forge,
        ModLoaderFilter.quilt => ModLoaderType.quilt,
        ModLoaderFilter.neoforge => ModLoaderType.neoForge,
      };
    }

    
    final page = _storage.curseForgeOffset ~/ request.pageSize;
    
    debugLog('[CurseForge] Searching: query="${request.query}", page=$page, gameVersion=${request.gameVersion}');

    await _curseforgeService.searchMods(
      query: request.query,
      gameVersion: request.gameVersion,
      loader: cfLoader,
      page: page,
      pageSize: request.pageSize,
    );

    debugLog('[CurseForge] CurseforgeService returned: ${_curseforgeService.searchResults.length} results, error: "${_curseforgeService.searchError}"');

    _storage.results = _curseforgeService.searchResults;
    _storage.curseForgeTotal = _curseforgeService.totalCount;
    
    if (_curseforgeService.searchError.isNotEmpty) {
      _storage.errorMessage = _curseforgeService.searchError;
    }
    
    debugLog('[CurseForge] Found ${_storage.results.length} results, total: ${_storage.curseForgeTotal}');
  }

  
  Future<void> loadPopularMods({String? gameVersion, int page = 0}) async {
    await searchMods(
      gameVersion: gameVersion,
      sortType: ModSortType.downloads,
      page: page,
    );
  }

  
  Future<void> loadModrinthCategories() async {
    final urls = [_modrinthMirror, _modrinthOfficial];
    
    for (final baseUrl in urls) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/tag/category'),
          headers: {
            'User-Agent': 'OblivionLauncher/1.0.0 (github.com/oblivion-launcher)',
            'Accept': 'application/json',
          },
        ).timeout(Duration(seconds: baseUrl == _modrinthMirror ? 10 : 15));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          _categories = data
              .where((c) => c['project_type'] == 'mod')
              .map((c) => ModCategory(
                    id: c['name'],
                    name: c['name'],
                    icon: c['icon'],
                  ))
              .toList();
          notifyListeners();
          return;
        }
      } catch (e) {
        debugLog('[Modrinth] Failed to load categories from $baseUrl: $e');
      }
    }
  }

  
  Future<RemoteMod?> getModDetails(String projectId) async {
    final urls = [_modrinthMirror, _modrinthOfficial];
    
    for (final baseUrl in urls) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/project/$projectId'),
          headers: {
            'User-Agent': 'OblivionLauncher/1.0.0 (github.com/oblivion-launcher)',
            'Accept': 'application/json',
          },
        ).timeout(Duration(seconds: baseUrl == _modrinthMirror ? 10 : 15));
        
        if (response.statusCode == 200) {
          return RemoteMod.fromModrinthProject(jsonDecode(response.body));
        }
      } catch (e) {
        debugLog('[Modrinth] Failed to get mod details from $baseUrl: $e');
      }
    }
    return null;
  }

  
  Future<List<ModVersion>> getModVersions(String projectId, {
    String? gameVersion,
    ModLoaderFilter? loader,
  }) async {
    debugLog('[ModDownload] getModVersions: projectId=$projectId, gameVersion=$gameVersion, loader=$loader');
    
    final params = <String, String>{};
    
    if (gameVersion != null && gameVersion.isNotEmpty) {
      params['game_versions'] = '["$gameVersion"]';
    }
    if (loader != null) {
      params['loaders'] = '["${loader.name}"]';
    }
    
    debugLog('[ModDownload] getModVersions params: $params');

    final urls = [_modrinthMirror, _modrinthOfficial];
    
    for (final baseUrl in urls) {
      try {
        var url = '$baseUrl/project/$projectId/version';
        if (params.isNotEmpty) {
          url = Uri.parse(url).replace(queryParameters: params).toString();
        }
        
        debugLog('[ModDownload] getModVersions request: $url');

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'OblivionLauncher/1.0.0 (github.com/oblivion-launcher)',
            'Accept': 'application/json',
          },
        ).timeout(Duration(seconds: baseUrl == _modrinthMirror ? 10 : 15));

        debugLog('[ModDownload] getModVersions response: ${response.statusCode}, body length: ${response.body.length}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          debugLog('[ModDownload] getModVersions parsed ${data.length} versions');
          return data.map((v) => ModVersion.fromModrinth(v)).toList();
        }
      } catch (e) {
        debugLog('[Modrinth] Failed to get mod versions from $baseUrl: $e');
      }
    }
    debugLog('[ModDownload] getModVersions returning empty list');
    return [];
  }

  
  Future<bool> downloadMod(ModVersion version, String destPath, {
    void Function(double)? onProgress,
    void Function(String)? onStatus,
  }) async {
    if (version.files.isEmpty) return false;
    
    final file = version.files.first;
    final fileName = destPath.split('/').last.split('\\').last;
    
    
    return await _downloadService.downloadFilesInBackground(
      '模组: $fileName',
      [DownloadFile(
        url: file.url,
        path: destPath,
        sha1: file.hashes['sha1'],
        size: file.size,
      )],
      1,
      onProgress: onProgress,
      onStatus: onStatus,
    );
  }

  String _convertSortType(ModSortType type) {
    return switch (type) {
      ModSortType.relevance => 'relevance',
      ModSortType.downloads => 'downloads',
      ModSortType.follows => 'follows',
      ModSortType.newest => 'newest',
      ModSortType.updated => 'updated',
    };
  }
}

enum ModSortType { relevance, downloads, follows, newest, updated }
enum ModLoaderFilter { fabric, forge, quilt, neoforge }

class ModCategory {
  final String id;
  final String name;
  final String? icon;

  ModCategory({required this.id, required this.name, this.icon});
}
