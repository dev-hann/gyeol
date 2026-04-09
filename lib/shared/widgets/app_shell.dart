import 'package:flutter/material.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/features/dashboard/pages/dashboard_page.dart';
import 'package:gyeol/features/layers/pages/layers_page.dart';
import 'package:gyeol/features/monitoring/pages/monitoring_page.dart';
import 'package:gyeol/features/settings/pages/settings_page.dart';
import 'package:gyeol/features/workers/pages/workers_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static final _pages = <Widget>[
    const DashboardPage(),
    const MonitoringPage(),
    const LayersPage(),
    const WorkersPage(),
    const SettingsPage(),
  ];

  static final _navItems = [
    const _NavItem(Icons.dashboard_outlined, 'Dashboard'),
    const _NavItem(Icons.show_chart, 'Monitoring'),
    const _NavItem(Icons.layers_outlined, 'Layers'),
    const _NavItem(Icons.memory, 'Workers'),
    const _NavItem(Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 224,
      color: AppColors.card,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gyeol',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'AI Multi-Layer Worker',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...List.generate(
            _navItems.length,
            (i) =>
                _NavItem(_navItems[i].icon, _navItems[i].label, index: i).build(
                  context,
                  isActive: i == _currentIndex,
                  onTap: () => setState(() => _currentIndex = i),
                ),
          ),
          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text(
                  'Run Scheduler',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label, {this.index});
  final IconData icon;
  final String label;
  final int? index;

  Widget build(
    BuildContext context, {
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: isActive ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive
                      ? AppColors.primaryForeground
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive
                        ? AppColors.primaryForeground
                        : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
