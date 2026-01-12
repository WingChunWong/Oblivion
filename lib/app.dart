import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'services/config_service.dart';
import 'l10n/app_localizations.dart';

class OblivionApp extends StatelessWidget {
  const OblivionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    final themeMode = configService.settings.themeMode;
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    
    final locale = configService.settings.language == 'zh' 
        ? const Locale('zh') 
        : const Locale('en');

    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    return MaterialApp(
      title: 'Oblivion Launcher',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: colorScheme.surfaceContainerHigh,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: colorScheme.surfaceContainerHigh,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: colorScheme.primaryContainer,
          selectedIconTheme: IconThemeData(color: colorScheme.onPrimaryContainer),
          unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
          labelType: NavigationRailLabelType.all,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
