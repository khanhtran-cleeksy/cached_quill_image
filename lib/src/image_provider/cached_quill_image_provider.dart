import 'dart:ui' as ui show Codec;
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../utils.dart';
import 'cached_quill_image_provider.dart' as image_provider;
import 'multi_image_stream_completer.dart';

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
    this.headers,
    this.cacheManager,
    this.cacheKey,
  });

  /// The [BaseCacheManager] that is used to download the image from the internet.
  /// If null the [DefaultCacheManager] instance is used.
  final BaseCacheManager? cacheManager;

  /// Url of the image to load
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

  /// Set headers for the image provider, for example for authentication
  @override
  final Map<String, String>? headers;

  @override
  Future<CachedQuillImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedQuillImageProvider>(this);
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
  ) async* {
    assert(key == this);
    try {
      var cacheManager = this.cacheManager ?? DefaultCacheManager();
      _decode(bytes) async {
        return decode(await ImmutableBuffer.fromUint8List(bytes));
      }

      if (isFromServer(url)) {
        assert(
          cacheManager is ImageCacheManager ||
              (maxHeight == null && maxWidth == null),
          'To resize the image with a CacheManager the '
          'CacheManager needs to be an ImageCacheManager. maxWidth and '
          'maxHeight will be ignored when a normal CacheManager is used.',
        );

        final stream = cacheManager is ImageCacheManager
            ? cacheManager.getImageFile(
                url,
                withProgress: true,
                key: cacheKey,
                headers: headers,
                maxHeight: maxHeight,
                maxWidth: maxWidth,
              )
            : cacheManager.getFileStream(
                url,
                withProgress: true,
                key: cacheKey,
              );

        await for (var result in stream) {
          if (result is DownloadProgress) {
            chunkEvents.add(ImageChunkEvent(
              cumulativeBytesLoaded: result.downloaded,
              expectedTotalBytes: result.totalSize,
            ));
          }
          if (result is FileInfo) {
            var file = result.file;
            var bytes = await file.readAsBytes();
            var decoded = await _decode(bytes);
            yield decoded;
          }
        }
      } else {
        FileInfo? fileInfo;

        fileInfo = await cacheManager.getFileFromCache(url);
        Uint8List? bytes;

        if (fileInfo == null) {
          bytes = await File(url).readAsBytes();
          await cacheManager.putFile(url, bytes);
        } else {
          bytes = await fileInfo.file.readAsBytes();
        }
        chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: bytes.lengthInBytes,
          expectedTotalBytes: bytes.lengthInBytes,
        ));
        var decoded = await _decode(bytes);
        yield decoded;
      }
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });

      errorListener?.call();
      rethrow;
    } finally {
      await chunkEvents.close();
    }
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
