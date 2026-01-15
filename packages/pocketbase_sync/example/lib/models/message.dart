import 'package:dart_mappable/dart_mappable.dart';

part 'message.mapper.dart';

@MappableClass()
class Message with MessageMappable {
  final String id;
  final String message;
  final String author;

  Message({required this.id, required this.message, required this.author});

  static const fromJson = MessageMapper.fromJson;
}
