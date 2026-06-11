import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Renders a PDF inline in an <iframe> backed by a Blob URL, using the browser's
/// native PDF viewer — no third-party PDF rendering dependency. Each call
/// registers a unique view type so multiple previews don't collide.
Widget buildPdfPreview(Uint8List bytes) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final viewType = 'pdf-preview-${url.hashCode}';

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%',
  );

  return HtmlElementView(viewType: viewType);
}
