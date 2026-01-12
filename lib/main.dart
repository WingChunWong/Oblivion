import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/config_service.dart';
import 'services/account_service.dart';
import 'services/game_service.dart';
import 'services/java_service.dart';
import 'services/download_service.dart';
import 'services/mod_download_service.dart';
import 'services/debug_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  
  await DebugLogger().init();
  debugLog('App starting...');
  
  final configService = ConfigService();
  await configService.load();
  debugLog('Config loaded');
  
  final downloadService = DownloadService();
  final modDownloadService = ModDownloadService(downloadService);
  
  
  final javaService = JavaService();
  javaService.init(); 
  
  debugLog('Services initialized, starting app...');
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => configService),
        ChangeNotifierProvider(create: (_) => downloadService),
        ChangeNotifierProvider(create: (_) => AccountService(configService)),
        ChangeNotifierProvider(create: (_) => GameService(configService)),
        ChangeNotifierProvider.value(value: javaService),
        ChangeNotifierProvider.value(value: modDownloadService),
      ],
      child: const OblivionApp(),
    ),
  );
}
