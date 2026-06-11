import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Non-web fallback: embedding a browser PDF viewer isn't available, so show a
/// hint. (The app runs on web; this stub only keeps non-web builds compiling.)
Widget buildPdfPreview(Uint8List bytes) => const Center(
      child: Text('PDF-Vorschau ist nur im Browser verfügbar.'),
    );
