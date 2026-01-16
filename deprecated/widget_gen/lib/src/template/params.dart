class ParamTemplate {
  String name;
  String type;
  String defaultValue;
  bool hasRequiredAnnotation = false;

  String get asArgument => name;

  NamedArgTemplate get asNamedArgument => NamedArgTemplate()..name = name;

  String get metadata => hasRequiredAnnotation ? '@required ' : '';

  @override
  String toString() => '$type $name = $defaultValue';
}

class TypeParamTemplate {
  String name;
  String bound;

  String get asArgument => name;

  @override
  String toString() => '$name extends $bound';
}

class NamedArgTemplate {
  String name;

  @override
  String toString() => '$name: $name';
}
