import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web implementation of file download using the browser Blob API.
///
/// Creates a temporary anchor element, triggers a download of [content]
/// as a JSON file named [filename], then cleans up the object URL.
Future<void> downloadFile(String content, String filename) async {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..target = 'blank'
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
