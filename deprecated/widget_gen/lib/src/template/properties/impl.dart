abstract class SettingsImpl {
  @override
  String toString() {
    final sb = StringBuffer();

    return sb.toString();
  }

  String access();

  String constructor() {
    final sb = StringBuffer();
    sb.write('    ');
    if (int.tryParse(key) != null) {
      sb.write('${name}Val');
    } else    sb.write("$key: ${name}Val");
  
    sb.writeln(',');
    return sb.toString();
  }

  String keyValue() {
    final sb = StringBuffer();
    sb.write('    ');
    sb.writeln("String ${name}Key = '${key ?? name}';");
    return sb.toString();
  }

  String get name;

  String get key;

  String get propertyType;
}
