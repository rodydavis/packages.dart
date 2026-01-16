import 'dart:html' as html;

void newWindow(
  String url,
  double width,
  double height, {
  String name = '',
  double dx,
  double dy,
}) {
  final screen = html.window.screen;
  double top = 0;
  top = dy;
  double left = 0;
  left = dx;
  final sb = StringBuffer();
  sb.write("height=");
  sb.write(height);
  sb.write(",width=");
  sb.write(width);
  sb.write(",top=");
  sb.write(top);
  sb.write(",left=");
  sb.write(left);
  sb.write(",scrollbars=yes,resizable=yes,toolbar=no,status=no,menu=no,");
  sb.write("directories=no,titlebar=no,location=no,addressbar=no");
  final settings = sb.toString();
  html.window.open(url, name, settings);
}
