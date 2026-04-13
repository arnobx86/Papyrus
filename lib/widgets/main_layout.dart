import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    
    int currentIndex = 0;
    if (location.startsWith('/kena-becha')) {
      currentIndex = 1;
    } else if (location.startsWith('/len-den')) {
      currentIndex = 2;
    } else if (location.startsWith('/ay-bay')) {
      currentIndex = 3;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/shop-home');
                break;
              case 1:
                context.go('/kena-becha');
                break;
              case 2:
                context.go('/len-den');
                break;
              case 3:
                context.go('/ay-bay');
                break;
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.layoutGrid),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.shoppingCart),
              label: 'কেনা বেচা',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.users),
              label: 'লেন দেন',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.wallet),
              label: 'আয় ব্যয়',
            ),
          ],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
