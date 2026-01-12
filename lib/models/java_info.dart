import 'dart:io';
import 'package:path/path.dart' as p;

enum JavaBrandType {
  eclipseTemurin,
  bellsoft,
  azulZulu,
  amazonCorretto,
  microsoft,
  ibmSemeru,
  oracle,
  dragonwell,
  tencentKona,
  openJDK,
  graalVmCommunity,
  jetBrains,
  unknown,
}

class JavaInfo {
  final String path;
  final String version;
  final int majorVersion;
  final JavaBrandType brand;
  final String vendor;
  final bool is64Bit;
  final String architecture;
  final bool isJre;

  JavaInfo({
    required this.path,
    required this.version,
    required this.majorVersion,
    required this.brand,
    required this.vendor,
    required this.is64Bit,
    required this.architecture,
    this.isJre = false,
  });

  String get displayName => 'Java $majorVersion ($version) - ${is64Bit ? "64-bit" : "32-bit"}';
  
  String get brandDisplayName => _brandToDisplayName(brand);

  static String _brandToDisplayName(JavaBrandType brand) {
    switch (brand) {
      case JavaBrandType.eclipseTemurin: return 'Eclipse Temurin';
      case JavaBrandType.bellsoft: return 'BellSoft Liberica';
      case JavaBrandType.azulZulu: return 'Azul Zulu';
      case JavaBrandType.amazonCorretto: return 'Amazon Corretto';
      case JavaBrandType.microsoft: return 'Microsoft';
      case JavaBrandType.ibmSemeru: return 'IBM Semeru';
      case JavaBrandType.oracle: return 'Oracle';
      case JavaBrandType.dragonwell: return 'Alibaba Dragonwell';
      case JavaBrandType.tencentKona: return 'Tencent Kona';
      case JavaBrandType.openJDK: return 'OpenJDK';
      case JavaBrandType.graalVmCommunity: return 'GraalVM';
      case JavaBrandType.jetBrains: return 'JetBrains';
      case JavaBrandType.unknown: return 'Unknown';
    }
  }

  
  static final Map<String, JavaBrandType> _brandMap = {
    'Eclipse': JavaBrandType.eclipseTemurin,
    'Temurin': JavaBrandType.eclipseTemurin,
    'Adoptium': JavaBrandType.eclipseTemurin,
    'Bellsoft': JavaBrandType.bellsoft,
    'Liberica': JavaBrandType.bellsoft,
    'Microsoft': JavaBrandType.microsoft,
    'Amazon': JavaBrandType.amazonCorretto,
    'Corretto': JavaBrandType.amazonCorretto,
    'Azul': JavaBrandType.azulZulu,
    'Zulu': JavaBrandType.azulZulu,
    'IBM': JavaBrandType.ibmSemeru,
    'Semeru': JavaBrandType.ibmSemeru,
    'Oracle': JavaBrandType.oracle,
    'Tencent': JavaBrandType.tencentKona,
    'Kona': JavaBrandType.tencentKona,
    'OpenJDK': JavaBrandType.openJDK,
    'Alibaba': JavaBrandType.dragonwell,
    'Dragonwell': JavaBrandType.dragonwell,
    'GraalVM': JavaBrandType.graalVmCommunity,
    'JetBrains': JavaBrandType.jetBrains,
  };

  
  static JavaBrandType _determineBrandFromString(String? text) {
    if (text == null || text.isEmpty) return JavaBrandType.unknown;
    for (final entry in _brandMap.entries) {
      if (text.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return JavaBrandType.unknown;
  }

  
  static JavaBrandType _determineBrandFromPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.contains('temurin') || lowerPath.contains('adoptium') || lowerPath.contains('adoptopenjdk')) {
      return JavaBrandType.eclipseTemurin;
    } else if (lowerPath.contains('zulu') || lowerPath.contains('azul')) {
      return JavaBrandType.azulZulu;
    } else if (lowerPath.contains('corretto') || lowerPath.contains('amazon')) {
      return JavaBrandType.amazonCorretto;
    } else if (lowerPath.contains('microsoft')) {
      return JavaBrandType.microsoft;
    } else if (lowerPath.contains('bellsoft') || lowerPath.contains('liberica')) {
      return JavaBrandType.bellsoft;
    } else if (lowerPath.contains('oracle')) {
      return JavaBrandType.oracle;
    } else if (lowerPath.contains('graalvm')) {
      return JavaBrandType.graalVmCommunity;
    } else if (lowerPath.contains('jetbrains')) {
      return JavaBrandType.jetBrains;
    } else if (lowerPath.contains('dragonwell') || lowerPath.contains('alibaba')) {
      return JavaBrandType.dragonwell;
    } else if (lowerPath.contains('semeru') || lowerPath.contains('ibm')) {
      return JavaBrandType.ibmSemeru;
    } else if (lowerPath.contains('kona') || lowerPath.contains('tencent')) {
      return JavaBrandType.tencentKona;
    }
    return JavaBrandType.unknown;
  }

  
  
  static Future<Map<String, String>> _getFileVersionInfo(String filePath) async {
    final result = <String, String>{};
    
    if (!Platform.isWindows) return result;
    
    try {
      
      final escapedPath = filePath.replaceAll("'", "''");
      
      
      final psResult = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-Command',
        '[System.Diagnostics.FileVersionInfo]::GetVersionInfo(\'$escapedPath\') | Select-Object CompanyName,FileDescription,ProductName,FileVersion | ConvertTo-Json'
      ], runInShell: true).timeout(const Duration(seconds: 5));
      
      if (psResult.exitCode == 0) {
        final output = psResult.stdout.toString().trim();
        if (output.isNotEmpty && output.startsWith('{')) {
          
          final lines = output.replaceAll('\r', '').split('\n');
          for (final line in lines) {
            if (line.contains(':')) {
              final colonIndex = line.indexOf(':');
              final key = line.substring(0, colonIndex).replaceAll('"', '').trim();
              var value = line.substring(colonIndex + 1).replaceAll('"', '').replaceAll(',', '').trim();
              if (value.isNotEmpty && value != 'null') {
                result[key] = value;
              }
            }
          }
        }
      }
    } catch (e) {
      
    }
    
    return result;
  }

  
  static Future<JavaInfo?> fromPath(String javaPath) async {
    try {
      final file = File(javaPath);
      if (!await file.exists()) return null;

      
      String? companyName;
      String? fileVersion;
      String? fileDescription;
      String? productName;
      
      final versionInfo = await _getFileVersionInfo(javaPath);
      companyName = versionInfo['CompanyName'];
      fileDescription = versionInfo['FileDescription'];
      productName = versionInfo['ProductName'];
      fileVersion = versionInfo['FileVersion'];

      
      final result = await Process.run(javaPath, ['-version'], runInShell: true);
      final output = result.stderr.toString();
      if (output.isEmpty) return null;

      String version = '';
      int majorVersion = 0;
      bool is64Bit = output.contains('64-Bit');

      final versionMatch = RegExp(r'version "([^"]+)"').firstMatch(output);
      if (versionMatch != null) {
        version = versionMatch.group(1)!;
        final majorMatch = RegExp(r'^(\d+)').firstMatch(version);
        if (majorMatch != null) {
          final major = int.parse(majorMatch.group(1)!);
          
          majorVersion = major == 1 ? 8 : major;
        }
      }
      
      
      if (version.isEmpty && fileVersion != null && fileVersion.isNotEmpty) {
        version = fileVersion;
      }

      
      
      JavaBrandType brand = JavaBrandType.unknown;
      
      
      if (companyName != null) {
        if (companyName.contains('Oracle') || companyName == 'N/A') {
          
          final desc = fileDescription ?? productName ?? '';
          if (desc.contains('Java(TM)')) {
            brand = JavaBrandType.oracle;
          } else {
            brand = JavaBrandType.openJDK;
          }
        } else {
          brand = _determineBrandFromString(companyName);
        }
      }
      
      
      if (brand == JavaBrandType.unknown) {
        brand = _determineBrandFromString(fileDescription);
      }
      if (brand == JavaBrandType.unknown) {
        brand = _determineBrandFromString(productName);
      }
      
      
      if (brand == JavaBrandType.unknown) {
        brand = _determineBrandFromString(output);
      }
      
      
      if (brand == JavaBrandType.unknown) {
        brand = _determineBrandFromPath(javaPath);
      }
      
      
      final javaDir = p.dirname(javaPath);
      final isJre = !await File(p.join(javaDir, 'javac.exe')).exists();

      return JavaInfo(
        path: javaPath,
        version: version,
        majorVersion: majorVersion,
        brand: brand,
        vendor: _brandToDisplayName(brand),
        is64Bit: is64Bit,
        architecture: is64Bit ? 'x64' : 'x86',
        isJre: isJre,
      );
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'version': version,
    'majorVersion': majorVersion,
    'brand': brand.name,
    'vendor': vendor,
    'is64Bit': is64Bit,
    'architecture': architecture,
    'isJre': isJre,
  };
}
