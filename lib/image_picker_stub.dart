// Mobile / desktop implementation — uses file_picker package.
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<({Uint8List? bytes, String? name})> pickImageBytes() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return (bytes: null, name: null);
  final file = result.files.first;
  return (bytes: file.bytes, name: file.name);
}
