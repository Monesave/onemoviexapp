// Flutter Web implementation — uses dart:html directly to avoid
// FilePicker._instance LateInitializationError on web builds.
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<({Uint8List? bytes, String? name})> pickImageBytes() async {
  final completer = Completer<({Uint8List? bytes, String? name})>();

  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..style.display = 'none';

  html.document.body!.children.add(input);

  input.onChange.listen((_) async {
    if (input.files == null || input.files!.isEmpty) {
      if (!completer.isCompleted) {
        completer.complete((bytes: null, name: null));
      }
      return;
    }
    final file = input.files!.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final raw = reader.result;
    Uint8List? bytes;
    if (raw is Uint8List) {
      bytes = raw;
    } else if (raw is List<int>) {
      bytes = Uint8List.fromList(raw);
    }
    if (!completer.isCompleted) {
      completer.complete((bytes: bytes, name: file.name));
    }
  });

  input.click();

  final result = await completer.future;
  input.remove();
  return result;
}
