import 'package:dynamic_tabs/dynamic_tabs.dart';
import 'package:flutter/material.dart';

class MaterialView extends StatelessWidget {
  const MaterialView({
    Key? key,
    required this.routes,
    required this.adaptive,
    required this.moreTabAccentColor,
    required this.moreTabPrimaryColor,
    required this.selectedColor,
    required this.maxTabs,
    required this.backgroundColor,
    required this.type,
    required this.breakpoint,
    required this.masterDetailOnMoreTab,
  }) : super(key: key);

  final bool adaptive;
  final Color? backgroundColor;
  final int maxTabs;
  final Color? moreTabAccentColor;
  final Color? moreTabPrimaryColor;
  final Map? routes;
  final Color? selectedColor;
  final BottomNavigationBarType type;
  final bool masterDetailOnMoreTab;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final model = TabProvider.of(context)!.state;
        return Scaffold(
          body: ContentView(
            routes: routes as Map<String, Widget Function(BuildContext)>?,
            adaptive: adaptive,
            breakpoint: breakpoint,
            masterDetailOnMoreTab: masterDetailOnMoreTab,
            moreTabAccentColor: moreTabAccentColor,
            moreTabPrimaryColor: moreTabPrimaryColor,
          ),
          bottomNavigationBar: BottomNavigationBar(
            selectedItemColor: selectedColor,
            items: model.tabs,
            currentIndex: model.adjustedIndex,
            onTap: model.changeTab,
            fixedColor: backgroundColor ?? Theme.of(context).primaryColor,
            type: type,
            // unselectedItemColor: unselectedItemColor ?? Colors.grey,
          ),
        );
      },
    );
  }
}
