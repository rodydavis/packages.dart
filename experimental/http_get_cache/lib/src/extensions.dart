import 'package:cachecontrol/cachecontrol.dart';
import 'package:http/http.dart';

const _cacheControlHeader = 'cache-control';

extension CacheControlRequest on BaseRequest {
  RequestCacheControl get cacheControl {
    final raw = headers[_cacheControlHeader] ?? '';
    return RequestCacheControl.parse(raw);
  }

  set cacheControl(RequestCacheControl value) {
    headers[_cacheControlHeader] = value.toString();
  }
}

extension CacheControlBaseResponse on BaseResponse {
  ResponseCacheControl get cacheControl {
    final raw = headers[_cacheControlHeader] ?? '';
    return ResponseCacheControl.parse(raw);
  }

  set cacheControl(ResponseCacheControl value) {
    headers[_cacheControlHeader] = value.toString();
  }
}
