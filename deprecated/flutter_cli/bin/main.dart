import 'package:reflected_mustache/mustache.dart';

main() {
  var source = '''
import 'package:flutter/material.dart';

class {{className}} extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      
    );
  }
}
  ''';

  var template = new Template(source, name: 'template-filename.html');

  final String output = template.renderString(
    {'className': 'FlutterWidget'},
  );

  print(output);
}
