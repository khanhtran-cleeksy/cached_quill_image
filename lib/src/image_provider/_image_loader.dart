import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:cached_quill_image/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// ImageLoader class to load images on IO platforms.
class ImageLoader {
  @Deprecated('use loadBufferAsync instead')

  /// Loads the image from the [url] and returns the loaded [ui.Codec].
  Stream<ui.Codec> loadAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
    int? maxHeight,
    int? maxWidth,
    Function()? errorListener,
    Function() evictImage,
    CacheManager? cacheManager,
    Map<String, String>? headers,
    bool isUsingResize,
  ) {
    return _load(url, cacheKey, chunkEvents, decode, maxHeight, maxWidth,
        errorListener, evictImage, cacheManager, headers, isUsingResize);
  }

  /// Loads the image from the [url] and returns the loaded [ui.Codec].
  Stream<ui.Codec> loadBufferAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderBufferCallback decode,
    int? maxHeight,
    int? maxWidth,
    Function()? errorListener,
    Function() evictImage,
    CacheManager? cacheManager,
    Map<String, String>? headers,
    bool isUsingResize,
  ) {
    return _load(
      url,
      cacheKey,
      chunkEvents,
      (bytes) async {
        final buffer = await ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      },
      maxHeight,
      maxWidth,
      errorListener,
      evictImage,
      cacheManager,
      headers,
      isUsingResize,
    );
  }

  Stream<ui.Codec> _load(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    _FileDecoderCallback decode,
    int? maxHeight,
    int? maxWidth,
    Function()? errorListener,
    Function() evictImage,
    CacheManager? cacheManager,
    Map<String, String>? headers,
    bool isUsingResize,
  ) async* {
    try {
      var mngr = DefaultCacheManager();

      if (isFromServer(url) || isUsingResize) {
        final stream = isUsingResize
            ? mngr.getImageFile(
                url,
                withProgress: true,
                key: cacheKey,
                headers: headers,
                maxHeight: maxHeight,
                maxWidth: maxWidth,
              )
            : mngr.getFileStream(
                url,
                withProgress: true,
                key: cacheKey,
                headers: headers,
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
            var decoded = await decode(bytes);
            yield decoded;
          }
        }
      } else {
        FileInfo? fileInfo;

        fileInfo = await mngr.getFileFromCache(url);
        Uint8List? bytes;

        if (fileInfo == null) {
          bytes = await File(url).readAsBytes();
          await mngr.putFile(url, bytes);
        } else {
          bytes = await fileInfo.file.readAsBytes();
        }
        chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: bytes.lengthInBytes,
          expectedTotalBytes: bytes.lengthInBytes,
        ));
        var decoded = await decode(bytes);
        yield decoded;
      }
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        evictImage();
      });

      errorListener?.call();
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }
}

typedef _FileDecoderCallback = Future<ui.Codec> Function(Uint8List);
