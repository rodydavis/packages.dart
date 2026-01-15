import 'package:dynamic_tabs/dynamic_tabs.dart';
import 'package:flutter/material.dart';

class DesktopView extends StatelessWidget {
  const DesktopView({
    Key? key,
    required this.routes,
    required this.adaptive,
    required this.moreTabAccentColor,
    required this.moreTabPrimaryColor,
    required this.breakpoint,
    required this.masterDetailOnMoreTab,
  }) : super(key: key);

  final bool adaptive;
  final Color? moreTabAccentColor;
  final Color? moreTabPrimaryColor;
  final Map? routes;
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
          drawer: Drawer(
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    for (var i = 0; i < model.allTabs.length; i++) ...[
                      ListTile(
                        selected: i == model.currentIndex,
                        leading: model.allTabs[i].tab.icon,
                        title: Text(model.allTabs[i].tab.label ?? ''),
                        onTap: () {
                          model.changeTab(i);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
