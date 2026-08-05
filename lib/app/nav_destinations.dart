import 'package:flutter/material.dart';

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
}

const navDestinations = <NavDestination>[
  NavDestination(
    path: '/home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
  ),
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
    path: '/songs',
    icon: Icons.music_note_outlined,
    selectedIcon: Icons.music_note,
    label: 'Songs',
  ),
  NavDestination(
    path: '/search',
    icon: Icons.search,
    selectedIcon: Icons.search,
    label: 'Search',
  ),
];

/// Index of the destination matching the current location, or 0.
int navIndexForLocation(String location) {
  for (var i = 0; i < navDestinations.length; i++) {
    if (location.startsWith(navDestinations[i].path)) return i;
  }
  return 0;
}
