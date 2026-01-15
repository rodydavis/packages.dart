import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dynamic_tabs/dynamic_tabs.dart';

import 'package:flutter/foundation.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: HomeScreen(),
      routes: _buildRoutes(context),
    );
  }
}

Map<String, WidgetBuilder> _buildRoutes(BuildContext context) =>
    <String, WidgetBuilder>{
      '/help': (BuildContext context) => RandomScreen(
            color: Colors.redAccent,
            title: "Info",
          ),
      '/about': (BuildContext context) => RandomScreen(
            color: Colors.amber,
            title: "Account",
          ),
    };

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    Key key,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return DynamicTabScaffold.adaptive(
      routes: _buildRoutes(context),
      persistIndex: true,
      maxTabs: 4,
      masterDetailOnMoreTab: true,
      tabs: <DynamicTab>[
        DynamicTab(
          child: RandomScreen(
            color: Colors.redAccent,
            title: "Info",
          ),
          tab: BottomNavigationBarItem(
            label: "Info",
            icon: Icon(Icons.info),
          ),
          tag: "info", // Must Be Unique
        ),
        DynamicTab(
          child: RandomScreen(
            color: Colors.amber,
            title: "Account",
          ),
          tab: BottomNavigationBarItem(
            label: "Account",
            icon: Icon(Icons.account_circle),
          ),
          tag: "account", // Must Be Unique
        ),
        DynamicTab(
          child: RandomScreen(
            color: Colors.blueGrey,
            title: "Help",
          ),
          tab: BottomNavigationBarItem(
            label: "Help",
            icon: Icon(Icons.help),
          ),
          tag: "help", // Must Be Unique
        ),
        DynamicTab(
          child: RandomScreen(
            color: Colors.purple,
            title: "Settings",
          ),
          tab: BottomNavigationBarItem(
            label: "Settings",
            icon: Icon(Icons.settings),
          ),
          tag: "settings", // Must Be Unique
        ),
        DynamicTab(
          child: RandomScreen(
            color: Colors.yellow,
            title: "Theme",
          ),
          tab: BottomNavigationBarItem(
            label: "Theme",
            icon: Icon(Icons.palette),
          ),
          tag: "theme", // Must Be Unique
        ),
        DynamicTab(
          child: RandomScreen(
            color: Colors.grey,
            title: "FAQ",
          ),
          tab: BottomNavigationBarItem(
            label: "FAQ",
            icon: Icon(Icons.perm_contact_calendar),
          ),
          tag: "faq", // Must Be Unique
        ),
        DynamicTab(
          child: RandomScreen(
            color: Colors.pink,
            title: "Contacts",
          ),
          tab: BottomNavigationBarItem(
            label: "Contacts",
            icon: Icon(Icons.people),
          ),
          tag: "contacts", // Must Be Unique
        ),
      ],
    );
  }
}

class RandomScreen extends StatelessWidget {
  RandomScreen({
    @required this.title,
    @required this.color,
  });
  final String title;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoPageScaffold(
        child: CustomScrollView(
          slivers: <Widget>[
            CupertinoSliverNavigationBar(
              largeTitle: Text(title),
              previousPageTitle: "More",
            ),
            SliverToBoxAdapter(
              child: Container(
                color: color,
              ),
            ),
          ],
        ),
      );
    }
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          title: Text(title),
        ),
        SliverFillRemaining(
          child: Container(
            color: color,
          ),
        ),
      ],
    );
  }
}
