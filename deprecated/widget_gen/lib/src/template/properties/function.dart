import 'impl.dart';

class FunctionOptionTemplate extends SettingsImpl {
  String defaultValue;
  bool isPrivate;

  @override
  String name;

  @override
  String key;

  @override
  String propertyType;

  @override
  String access() {
    final sb = StringBuffer();
    sb.writeln('String get ${name}Val {');
    sb.write("if (params[${name}Key] != null) ");
    sb.writeln('{');
    sb.write('return ');
    sb.write('params[${name}Key] as String');
    sb.writeln(';');
    sb.writeln('}');
    sb.writeln("return $defaultValue;");
      sb.writeln('}');
    sb.writeln('set ${name}Val(String val) {');
    sb.writeln('params[${name}Key] = val;');
    sb.writeln('widgetContext.onUpdate(id, widgetData);');
    sb.writeln('}');
    return sb.toString();
  }

  @override
  String constructor() {
    final sb = StringBuffer();
    sb.write('    ');
    if (int.tryParse(key) != null) {
      sb.write('');
    } else    sb.write("$key: ");
  
    sb.writeln("() => onAction(context, ${name}Val)");
    sb.writeln(',');
    return sb.toString();
  }
}
