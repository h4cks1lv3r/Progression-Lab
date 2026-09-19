import 'package:flutter/material.dart';

import 'brand.dart';

/// The same left menu is a drawer on phones and a sidebar on larger screens.
class AppNavigation extends StatelessWidget {
  const AppNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onOpenWorkout,
    required this.onOpenIcons,
    required this.onOpenStrength,
    required this.onOpenFunctional,
    required this.onOpenExercises,
    this.onClose,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenWorkout;
  final VoidCallback onOpenIcons;
  final VoidCallback onOpenStrength;
  final VoidCallback onOpenFunctional;
  final VoidCallback onOpenExercises;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: BrandColors.inkRaised,
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          Row(
            children: [
              const LabMark(size: 36),
              const SizedBox(width: 10),
              const Expanded(child: BrandWordmark(compact: true)),
              if (onClose != null)
                IconButton(
                  tooltip: 'Close menu',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _page(0, 'Home', Icons.home_rounded),
          const _MenuHeading('Workouts'),
          _page(1, 'All workouts', Icons.grid_view_rounded),
          _route('Open Workout', Icons.add_rounded, onOpenWorkout),
          _route('Iconic Builds', Icons.stars_rounded, onOpenIcons),
          _route(
            'Year One Strength',
            Icons.fitness_center_rounded,
            onOpenStrength,
          ),
          _route(
            'Functional Training',
            Icons.directions_run_rounded,
            onOpenFunctional,
          ),
          _route('Exercise library', Icons.menu_book_rounded, onOpenExercises),
          const _MenuHeading('Your Lab'),
          _page(4, 'Lab', Icons.science_outlined),
          _page(3, 'Progress', Icons.query_stats_rounded),
          _page(2, 'Daily check-in', Icons.check_circle_outline_rounded),
          const SizedBox(height: 16),
          const Divider(),
          _page(5, 'Settings', Icons.settings_outlined),
        ],
      ),
    ),
  );

  Widget _page(int index, String title, IconData icon) => _item(
    title,
    icon,
    () => onSelect(index),
    selected: selectedIndex == index,
    key: ValueKey('menu-page-$index'),
  );

  Widget _route(String title, IconData icon, VoidCallback onTap) =>
      _item(title, icon, onTap);

  Widget _item(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool selected = false,
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: ListTile(
      key: key,
      selected: selected,
      selectedColor: BrandColors.white,
      selectedTileColor: BrandColors.violet.withValues(alpha: .18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(
        icon,
        size: 21,
        color: selected ? BrandColors.violet : BrandColors.muted,
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      minLeadingWidth: 22,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: onTap,
    ),
  );
}

class _MenuHeading extends StatelessWidget {
  const _MenuHeading(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 22, 12, 8),
    child: Text(
      title,
      style: const TextStyle(
        color: BrandColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
