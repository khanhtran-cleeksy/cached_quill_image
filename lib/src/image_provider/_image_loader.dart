import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../cached_file_image_platform_interface.dart' as platform show ImageLoader;

/// ImageLoader class to load images on IO platforms.
class ImageLoader implements platform.ImageLoader {
  @Deprecated('use loadBufferAsync instead')
  @override
  Stream<ui.Codec> loadAsync(
    String url,
    DecoderCallback decode,
    int? maxHeight,
    int? maxWidth,
    Function()? errorListener,
    Function() evictImage,
  ) {
    return _load(
      url,
      decode,
      maxHeight,
      maxWidth,
      errorListener,
      evictImage,
    );
  }

  @override
  Stream<ui.Codec> loadBufferAsync(
      String url,
      DecoderBufferCallback decode,
      int? maxHeight,
      int? maxWidth,
      Function()? errorListener,
      Function() evictImage) {
    return _load(
      url,
      (bytes) async {
        final buffer = await ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      },
      maxHeight,
      maxWidth,
      errorListener,
      evictImage,
    );
  }

  Stream<ui.Codec> _load(
    String url,
    _FileDecoderCallback decode,
    int? maxHeight,
    int? maxWidth,
    Function()? errorListener,
    Function() evictImage,
  ) async* {
    try {
      var cacheManager = DefaultCacheManager();
      FileInfo? fileInfo;

      fileInfo = await cacheManager.getFileFromCache(url);
      Uint8List? bytes;

      if (fileInfo == null) {
        bytes = await File(url).readAsBytes();
        await cacheManager.putFile(url, bytes);
      } else {
        bytes = await fileInfo.file.readAsBytes();
      }

      var decoded = await decode(bytes);
      yield decoded;
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        evictImage();
      });

      errorListener?.call();
      rethrow;
    }
  }
}

typedef _FileDecoderCallback = Future<ui.Codec> Function(Uint8List);
