import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// ImageLoader class to load images differently on various platforms.
class ImageLoader {
  /// loads the images async and gives the resulted codecs on a Stream. The
  /// Stream gives the option to show multiple images after each other.
  @Deprecated('use loadBufferAsync instead')
  Stream<ui.Codec> loadAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
    int? maxHeight,
    int? maxWidth,
    Function()? errorListener,
    Function() evictImage,
  ) {
    throw UnimplementedError();
  }

  /// loads the images async and gives the resulted codecs on a Stream. The
  /// Stream gives the option to show multiple images after each other.
  Stream<ui.Codec> loadBufferAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderBufferCallback decode,
    int? maxHeight,
    int? maxWidth,
    Function()? errorListener,
    Function() evictImage,
  ) {
    throw UnimplementedError();
  }
}
