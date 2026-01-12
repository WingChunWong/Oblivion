import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'home_screen.dart';
import 'accounts_screen.dart';
import 'versions_screen.dart';
import 'downloads_screen.dart';
import 'mods_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  double _navWidth = 200;
  static const double _minNavWidth = 80;
  static const double _maxNavWidth = 280;

  final List<Widget> _screens = const [
    HomeScreen(),
    AccountsScreen(),
    VersionsScreen(),
    DownloadsScreen(),
    ModsScreen(),
    SettingsScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 600;

    final destinations = [
      _NavDestination(icon: Icons.home_outlined, selectedIcon: Icons.home, label: l10n.get('nav_home')),
      _NavDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: l10n.get('nav_accounts')),
      _NavDestination(icon: Icons.games_outlined, selectedIcon: Icons.games, label: l10n.get('nav_versions')),
      _NavDestination(icon: Icons.download_outlined, selectedIcon: Icons.download, label: l10n.get('nav_downloads')),
      _NavDestination(icon: Icons.extension_outlined, selectedIcon: Icons.extension, label: l10n.get('nav_mods')),
      _NavDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: l10n.get('nav_settings')),
      _NavDestination(icon: Icons.info_outline, selectedIcon: Icons.info, label: l10n.get('nav_about')),
    ];

    return Scaffold(
      body: Row(
        children: [
          if (isWide) ...[
            _buildNavigationRail(destinations),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _navWidth = (_navWidth + details.delta.dx).clamp(_minNavWidth, _maxNavWidth);
                  });
                },
                child: Container(
                  width: 4,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide ? null : NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: destinations.take(6).map((d) => NavigationDestination(
          icon: Icon(d.icon),
          selectedIcon: Icon(d.selectedIcon),
          label: d.label,
        )).toList(),
      ),
    );
  }

  Widget _buildNavigationRail(List<_NavDestination> destinations) {
    final isExtended = _navWidth > 140;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: _navWidth,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: destinations.length,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemBuilder: (context, index) {
                final dest = destinations[index];
                final isSelected = _selectedIndex == index;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: isSelected 
                        ? colorScheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                      onTap: () => setState(() => _selectedIndex = index),
                      borderRadius: BorderRadius.circular(28),
                      hoverColor: colorScheme.onSurface.withValues(alpha: 0.08),
                      child: Container(
                        height: 56,
                        padding: EdgeInsets.symmetric(horizontal: isExtended ? 16 : 0),
                        child: Row(
                          mainAxisAlignment: isExtended ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            Container(
                              width: isExtended ? 24 : 56,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: !isExtended && isSelected ? BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ) : null,
                              child: Icon(
                                isSelected ? dest.selectedIcon : dest.icon,
                                size: 24,
                                color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (isExtended) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  dest.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
