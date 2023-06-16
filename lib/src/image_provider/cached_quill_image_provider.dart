import 'dart:async' show Future, StreamController;
import 'dart:ui' as ui show Codec;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'cached_quill_image_provider.dart' as image_provider;
import 'multi_image_stream_completer.dart';

import './_image_loader.dart' show ImageLoader;

/// Function which is called after loading the image failed.
typedef ErrorListener = void Function();

/// IO implementation of the CachedFileImageProvider; the ImageProvider to
/// load network images using a cache.
class CachedQuillImageProvider
    extends ImageProvider<image_provider.CachedQuillImageProvider> {
  /// Creates an ImageProvider which loads an image from the [url], using the [scale].
  /// When the image fails to load [errorListener] is called.
  const CachedQuillImageProvider(
    this.url, {
    this.maxHeight,
    this.maxWidth,
    this.scale = 1.0,
    this.errorListener,
    this.cacheKey,
  });

  /// Web url of the image to load
  final String url;

  /// Cache key of the image to cache
  final String? cacheKey;

  /// Scale of the image
  final double scale;

  /// Listener to be called when images fails to load.
  final image_provider.ErrorListener? errorListener;

  /// Maximum height of the loaded image. If not null and using an
  /// [ImageCacheManager] the image is resized on disk to fit the height.
  final int? maxHeight;

  /// Maximum width of the loaded image. If not null and using an
  /// [ImageCacheManager] the image is resized on disk to fit the width.
  final int? maxWidth;

  @override
  Future<CachedQuillImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedQuillImageProvider>(this);
  }

  @Deprecated(
      'load is deprecated, use loadBuffer instead, see https://docs.flutter.dev/release/breaking-changes/image-provider-load-buffer')
  @override
  ImageStreamCompleter load(
      image_provider.CachedQuillImageProvider key, DecoderCallback decode) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>(
          'Image provider: $this \n Image key: $key',
          this,
          style: DiagnosticsTreeStyle.errorProperty,
        );
      },
    );
  }

  @Deprecated(
      '_loadAsync is deprecated, use loadBuffer instead, see https://docs.flutter.dev/release/breaking-changes/image-provider-load-buffer')
  Stream<ui.Codec> _loadAsync(
    image_provider.CachedQuillImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) {
    assert(key == this);
    return ImageLoader().loadAsync(
      url,
      cacheKey,
      chunkEvents,
      decode,
      maxHeight,
      maxWidth,
      errorListener,
      () => PaintingBinding.instance.imageCache.evict(key),
    );
  }

  @override
  ImageStreamCompleter loadBuffer(image_provider.CachedQuillImageProvider key,
      DecoderBufferCallback decode) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiImageStreamCompleter(
      codec: _loadBufferAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>(
          'Image provider: $this \n Image key: $key',
          this,
          style: DiagnosticsTreeStyle.errorProperty,
        );
      },
    );
  }

  Stream<ui.Codec> _loadBufferAsync(
    image_provider.CachedQuillImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderBufferCallback decode,
  ) {
    assert(key == this);
    return ImageLoader().loadBufferAsync(
      url,
      cacheKey,
      chunkEvents,
      decode,
      maxHeight,
      maxWidth,
      errorListener,
      () => PaintingBinding.instance.imageCache.evict(key),
    );
  }

  @override
  bool operator ==(dynamic other) {
    if (other is CachedQuillImageProvider) {
      return ((cacheKey ?? url) == (other.cacheKey ?? other.url)) &&
          scale == other.scale &&
          maxHeight == other.maxHeight &&
          maxWidth == other.maxWidth;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(cacheKey ?? url, scale, maxHeight, maxWidth);

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';
}