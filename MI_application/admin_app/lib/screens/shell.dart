import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'home/home_screen.dart';
import 'cows/cows_screen.dart';
import 'eleveurs/eleveurs_screen.dart';
import 'more/more_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, this.onLogout});

  final Future<void> Function()? onLogout;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, children: [
          HomeScreen(onOpenCows: (_) => setState(() => _i = 1)),
          const CowsScreen(),
          const _Soon('Mangeoires', Icons.sensors_rounded),
          const EleveursScreen(),
          MoreScreen(onLogout: widget.onLogout),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Vaches'),
            NavigationDestination(icon: Icon(Icons.sensors_outlined), selectedIcon: Icon(Icons.sensors_rounded), label: 'Mangeoires'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Éleveurs'),
            NavigationDestination(icon: Icon(Icons.more_horiz_rounded), selectedIcon: Icon(Icons.more_horiz_rounded), label: 'Plus'),
          ],
        ),
      );
}

class _Soon extends StatelessWidget {
  final String title;
  final IconData icon;
  const _Soon(this.title, this.icon);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: AppTheme.accent),
            const SizedBox(height: 10),
            const Text('Cet écran arrive dans la prochaine étape.', style: TextStyle(color: AppTheme.textGrey)),
          ]),
        ),
      );
}
