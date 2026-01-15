import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_data_view/flutter_data_view.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: HomeScreen(),
    );
  }
}

final _dataSource = ExampleDataSource(List<Map<String, dynamic>>.generate(
  50,
  (i) {
    final tags = [
      ['info', 'money', 'system', 'dev'],
      ['info', 'dev'],
      ['bookmarks'],
      ['about', 'settings', 'auto'],
      ['auto', 'favorites', 'research/apps'],
      ['car', 'truck', 'auto', 'auto/used'],
      ['info', 'favorites/bookmarks'],
      [],
    ];
    return {
      'name': 'Title: $i',
      'tags': <String>[...tags[random.nextInt(tags.length)]],
    };
  },
));

class HomeScreen extends StatelessWidget {
  HomeScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TaggedDataView(
      dataSource: _dataSource,
      actions: [
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {},
        ),
      ],
    );
  }
}

final random = new Random();

class ExampleDataSource extends TaggedDataTableSource {
  ExampleDataSource(List<Map<String, dynamic>> source) : super(source);
}
