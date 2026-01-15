import 'package:pocketbase/pocketbase.dart';

String parseErrorMessage(dynamic error) {
  if (error is ClientException) {
    final response = error.response;
    if (response['message'] != null) {
      return response['message'] as String;
    }
  }
  return error.toString();
}
