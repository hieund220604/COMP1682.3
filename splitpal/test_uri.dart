import 'dart:isolate';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  try {
    final uri = await Isolate.resolvePackageUri(Uri.parse('package:google_sign_in/google_sign_in.dart'));
    print('URI: $uri');
  } catch (e) {
    print('Error: $e');
  }
}
