import 'package:flutter/material.dart';
import 'package:flax/l10n/app_localizations.dart';

/// One top-level destination, shared by the desktop sidebar and the mobile
/// bottom bar so the two cannot drift out of sync.
class NavDestination {
  const NavDestination({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return label;
    switch (path) {
      case '/artists':
        return l10n.navArtists;
      case '/albums':
        return l10n.navAlbums;
      case '/search':
        return l10n.navSearch;
      case '/settings':
        return l10n.navSettings;
      case '/downloads':
        return l10n.navDownloads;
      case '/playlists':
        return l10n.navPlaylists;
      case '/now-playing':
        return l10n.nowPlaying;
      default:
        return label;
    }
  }
}

/// Core library navigation destinations (used in desktop sidebar).
const navDestinations = <NavDestination>[
  NavDestination(
    path: '/artists',
    icon: Icons.people_outlined,
    selectedIcon: Icons.people,
    label: 'Artists',
  ),
  NavDestination(
    path: '/albums',
    icon: Icons.album_outlined,
    selectedIcon: Icons.album,
    label: 'Albums',
  ),
  NavDestination(
    path: '/search',
    icon: Icons.search,
    selectedIcon: Icons.search,
    label: 'Search',
  ),
];

const settingsNavDestination = NavDestination(
  path: '/settings',
  icon: Icons.settings_outlined,
  selectedIcon: Icons.settings,
  label: 'Settings',
);

/// Mobile bottom bar destinations: Artists, Albums, Search, Settings.
const mobileNavDestinations = <NavDestination>[
  ...navDestinations,
  settingsNavDestination,
];

/// Index of the destination matching [location] in desktop navDestinations, or null when
/// the route is not one of them (e.g. Now Playing or Settings).
int? navDestinationIndex(String location) {
  for (var i = 0; i < navDestinations.length; i++) {
    if (location.startsWith(navDestinations[i].path)) return i;
  }
  return null;
}

/// Index of the destination matching [location] in mobile bottom bar, or 0.
int navIndexForLocation(String location) {
  for (var i = 0; i < mobileNavDestinations.length; i++) {
    if (location.startsWith(mobileNavDestinations[i].path)) return i;
  }
  return 0;
}
