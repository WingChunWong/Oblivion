
class RemoteMod {
  final String id;
  final String slug;
  final String title;
  final String description;
  final String? author;
  final List<String> categories;
  final String? iconUrl;
  final String? pageUrl;
  final int downloads;
  final DateTime? dateCreated;
  final DateTime? dateModified;
  final ModSourceType source;

  RemoteMod({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    this.author,
    this.categories = const [],
    this.iconUrl,
    this.pageUrl,
    this.downloads = 0,
    this.dateCreated,
    this.dateModified,
    this.source = ModSourceType.modrinth,
  });

  factory RemoteMod.fromModrinthSearch(Map<String, dynamic> json) {
    return RemoteMod(
      id: json['project_id'] ?? '',
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      author: json['author'],
      categories: List<String>.from(json['categories'] ?? []),
      iconUrl: json['icon_url'],
      pageUrl: 'https://modrinth.com/mod/${json['slug']}',
      downloads: json['downloads'] ?? 0,
      dateCreated: json['date_created'] != null 
          ? DateTime.tryParse(json['date_created']) 
          : null,
      dateModified: json['date_modified'] != null 
          ? DateTime.tryParse(json['date_modified']) 
          : null,
      source: ModSourceType.modrinth,
    );
  }

  factory RemoteMod.fromModrinthProject(Map<String, dynamic> json) {
    return RemoteMod(
      id: json['id'] ?? '',
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      categories: List<String>.from(json['categories'] ?? []),
      iconUrl: json['icon_url'],
      pageUrl: 'https://modrinth.com/mod/${json['slug']}',
      downloads: json['downloads'] ?? 0,
      dateCreated: json['published'] != null 
          ? DateTime.tryParse(json['published']) 
          : null,
      dateModified: json['updated'] != null 
          ? DateTime.tryParse(json['updated']) 
          : null,
      source: ModSourceType.modrinth,
    );
  }

  factory RemoteMod.fromCurseforge(Map<String, dynamic> json) {
    
    
    final data = json.containsKey('id') ? json : (json['data'] ?? json);
    return RemoteMod(
      id: '${data['id']}',
      slug: data['slug'] ?? '',
      title: data['name'] ?? '',
      description: data['summary'] ?? '',
      author: (data['authors'] as List?)?.isNotEmpty == true 
          ? data['authors'][0]['name'] 
          : null,
      categories: (data['categories'] as List?)
          ?.map((c) => c['name'] as String)
          .toList() ?? [],
      iconUrl: data['logo']?['url'],
      pageUrl: data['links']?['websiteUrl'],
      downloads: data['downloadCount'] ?? 0,
      dateCreated: data['dateCreated'] != null 
          ? DateTime.tryParse(data['dateCreated']) 
          : null,
      dateModified: data['dateModified'] != null 
          ? DateTime.tryParse(data['dateModified']) 
          : null,
      source: ModSourceType.curseforge,
    );
  }
}

class ModVersion {
  final String id;
  final String projectId;
  final String name;
  final String versionNumber;
  final String? changelog;
  final DateTime? datePublished;
  final ModVersionType versionType;
  final List<ModFile> files;
  final List<String> gameVersions;
  final List<String> loaders;
  final List<ModDependency> dependencies;

  ModVersion({
    required this.id,
    required this.projectId,
    required this.name,
    required this.versionNumber,
    this.changelog,
    this.datePublished,
    this.versionType = ModVersionType.release,
    this.files = const [],
    this.gameVersions = const [],
    this.loaders = const [],
    this.dependencies = const [],
  });

  factory ModVersion.fromModrinth(Map<String, dynamic> json) {
    ModVersionType type;
    switch (json['version_type']) {
      case 'release':
        type = ModVersionType.release;
        break;
      case 'beta':
        type = ModVersionType.beta;
        break;
      case 'alpha':
        type = ModVersionType.alpha;
        break;
      default:
        type = ModVersionType.release;
    }

    return ModVersion(
      id: json['id'] ?? '',
      projectId: json['project_id'] ?? '',
      name: json['name'] ?? '',
      versionNumber: json['version_number'] ?? '',
      changelog: json['changelog'],
      datePublished: json['date_published'] != null 
          ? DateTime.tryParse(json['date_published']) 
          : null,
      versionType: type,
      files: (json['files'] as List?)
          ?.map((f) => ModFile.fromModrinth(f))
          .toList() ?? [],
      gameVersions: List<String>.from(json['game_versions'] ?? []),
      loaders: List<String>.from(json['loaders'] ?? []),
      dependencies: (json['dependencies'] as List?)
          ?.map((d) => ModDependency.fromModrinth(d))
          .toList() ?? [],
    );
  }
}

class ModFile {
  final String url;
  final String filename;
  final int size;
  final Map<String, String> hashes;
  final bool primary;

  ModFile({
    required this.url,
    required this.filename,
    this.size = 0,
    this.hashes = const {},
    this.primary = false,
  });

  factory ModFile.fromModrinth(Map<String, dynamic> json) {
    return ModFile(
      url: json['url'] ?? '',
      filename: json['filename'] ?? '',
      size: json['size'] ?? 0,
      hashes: Map<String, String>.from(json['hashes'] ?? {}),
      primary: json['primary'] ?? false,
    );
  }
}

class ModDependency {
  final String? versionId;
  final String? projectId;
  final ModDependencyType type;

  ModDependency({
    this.versionId,
    this.projectId,
    this.type = ModDependencyType.required,
  });

  factory ModDependency.fromModrinth(Map<String, dynamic> json) {
    ModDependencyType type;
    switch (json['dependency_type']) {
      case 'required':
        type = ModDependencyType.required;
        break;
      case 'optional':
        type = ModDependencyType.optional;
        break;
      case 'incompatible':
        type = ModDependencyType.incompatible;
        break;
      case 'embedded':
        type = ModDependencyType.embedded;
        break;
      default:
        type = ModDependencyType.optional;
    }

    return ModDependency(
      versionId: json['version_id'],
      projectId: json['project_id'],
      type: type,
    );
  }
}

enum ModSourceType { modrinth, curseforge }
enum ModVersionType { release, beta, alpha }
enum ModDependencyType { required, optional, incompatible, embedded }
