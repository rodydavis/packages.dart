import 'package:dynamic_tabs/dynamic_tabs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CupertinoView extends StatelessWidget {
  const CupertinoView({
    Key? key,
    required this.selectedColor,
    required this.maxTabs,
    required this.backgroundColor,
    required this.adaptive,
    required this.routes,
    required this.moreTabAccentColor,
    required this.moreTabPrimaryColor,
    required this.breakpoint,
    required this.masterDetailOnMoreTab,
  }) : super(key: key);

  final bool adaptive;
  final Color? backgroundColor;
  final int maxTabs;
  final Color? moreTabAccentColor;
  final Color? moreTabPrimaryColor;
  final Map<String, WidgetBuilder>? routes;
  final Color? selectedColor;
  final bool masterDetailOnMoreTab;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final model = TabProvider.of(context)!.state;
        return CupertinoTabScaffold(
          tabBuilder: (BuildContext context, int index) {
            return ContentView(
              routes: routes,
              adaptive: adaptive,
              breakpoint: breakpoint,
              masterDetailOnMoreTab: masterDetailOnMoreTab,
              moreTabAccentColor: moreTabAccentColor,
              moreTabPrimaryColor: moreTabPrimaryColor,
            );
          },
          tabBar: CupertinoTabBar(
            activeColor: selectedColor,
            items: model.tabs,
            currentIndex: model.adjustedIndex,
            onTap: model.changeTab,
            backgroundColor: backgroundColor,
          ),
        );
      },
    );
  }
}
