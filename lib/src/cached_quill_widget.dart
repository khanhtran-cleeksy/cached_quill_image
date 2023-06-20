import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:octo_image/octo_image.dart';

import '../cached_quill_image.dart';

/// Builder function to create an image widget. The function is called after
/// the ImageProvider completes the image loading.
typedef ImageWidgetBuilder = Widget Function(
  BuildContext context,
  ImageProvider imageProvider,
);

/// Builder function to create a placeholder widget. The function is called
/// once while the ImageProvider is loading the image.
typedef PlaceholderWidgetBuilder = Widget Function(
  BuildContext context,
  String url,
);

/// Builder function to create a progress indicator widget. The function is
/// called every time a chuck of the image is downloaded from the web, but at
/// least once during image loading.
typedef ProgressIndicatorBuilder = Widget Function(
  BuildContext context,
  String url,
  DownloadProgress progress,
);

/// Builder function to create an error widget. This builder is called when
/// the image failed loading, for example due to a 404 NotFound exception.
typedef LoadingErrorWidgetBuilder = Widget Function(
  BuildContext context,
  String url,
  dynamic error,
);

/// Image widget to show NetworkImage with caching functionality.
class CachedQuillImage extends StatelessWidget {
  /// Get the current log level of the cache manager.
  static CacheManagerLogLevel get logLevel => CacheManager.logLevel;

  /// Set the log level of the cache manager to a [CacheManagerLogLevel].
  static set logLevel(CacheManagerLogLevel level) =>
      CacheManager.logLevel = level;

  /// Evict an image from both the disk file based caching system of the
  /// [BaseCacheManager] as the in memory [ImageCache] of the [ImageProvider].
  /// [url] is used by both the disk and memory cache. The scale is only used
  /// to clear the image from the [ImageCache].
  static Future evictFromCache(
    String url, {
    String? cacheKey,
    BaseCacheManager? cacheManager,
    double scale = 1.0,
  }) async {
    cacheManager = cacheManager ?? DefaultCacheManager();
    await cacheManager.removeFile(cacheKey ?? url);
    return CachedQuillImageProvider(url, scale: scale).evict();
  }

  CachedQuillImageProvider? _image;

  /// Option to use cachemanager with other settings
  final CacheManager? cacheManager;

  /// The target image that is displayed.
  final String imageUrl;

  /// The target image's cache key.
  final String? cacheKey;

  /// Optional builder to further customize the display of the image.
  final ImageWidgetBuilder? imageBuilder;

  /// Widget displayed while the target [imageUrl] is loading.
  final PlaceholderWidgetBuilder? placeholder;

  /// Widget displayed while the target [imageUrl] is loading.
  final ProgressIndicatorBuilder? progressIndicatorBuilder;

  /// Widget displayed while the target [imageUrl] failed loading.
  final LoadingErrorWidgetBuilder? errorWidget;

  /// The duration of the fade-in animation for the [placeholder].
  final Duration? placeholderFadeInDuration;

  /// The duration of the fade-out animation for the [placeholder].
  final Duration? fadeOutDuration;

  /// The curve of the fade-out animation for the [placeholder].
  final Curve fadeOutCurve;

  /// The duration of the fade-in animation for the [imageUrl].
  final Duration fadeInDuration;

  /// The curve of the fade-in animation for the [imageUrl].
  final Curve fadeInCurve;

  /// If non-null, require the image to have this width.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder widget does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double? width;

  /// If non-null, require the image to have this height.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder widget does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double? height;

  /// How to inscribe the image into the space allocated during layout.
  ///
  /// The default varies based on the other fields. See the discussion at
  /// [paintImage].
  final BoxFit? fit;

  /// How to align the image within its bounds.
  ///
  /// The alignment aligns the given position in the image to the given position
  /// in the layout bounds. For example, a [Alignment] alignment of (-1.0,
  /// -1.0) aligns the image to the top-left corner of its layout bounds, while a
  /// [Alignment] alignment of (1.0, 1.0) aligns the bottom right of the
  /// image with the bottom right corner of its layout bounds. Similarly, an
  /// alignment of (0.0, 1.0) aligns the bottom middle of the image with the
  /// middle of the bottom edge of its layout bounds.
  ///
  /// If the [alignment] is [TextDirection]-dependent (i.e. if it is a
  /// [AlignmentDirectional]), then an ambient [Directionality] widget
  /// must be in scope.
  ///
  /// Defaults to [Alignment.center].
  ///
  /// See also:
  ///
  ///  * [Alignment], a class with convenient constants typically used to
  ///    specify an [AlignmentGeometry].
  ///  * [AlignmentDirectional], like [Alignment] for specifying alignments
  ///    relative to text direction.
  final Alignment alignment;

  /// How to paint any portions of the layout bounds not covered by the image.
  final ImageRepeat repeat;

  /// Whether to paint the image in the direction of the [TextDirection].
  ///
  /// If this is true, then in [TextDirection.ltr] contexts, the image will be
  /// drawn with its origin in the top left (the "normal" painting direction for
  /// children); and in [TextDirection.rtl] contexts, the image will be drawn with
  /// a scaling factor of -1 in the horizontal direction so that the origin is
  /// in the top right.
  ///
  /// This is occasionally used with children in right-to-left environments, for
  /// children that were designed for left-to-right locales. Be careful, when
  /// using this, to not flip children with integral shadows, text, or other
  /// effects that will look incorrect when flipped.
  ///
  /// If this is true, there must be an ambient [Directionality] widget in
  /// scope.
  final bool matchTextDirection;

  /// Optional headers to use when fetching the image.
  final Map<String, String>? httpHeaders;

  /// If non-null, this color is blended with each image pixel using [colorBlendMode].
  final Color? color;

  /// Used to combine [color] with this image.
  ///
  /// The default is [BlendMode.srcIn]. In terms of the blend mode, [color] is
  /// the source and this image is the destination.
  ///
  /// See also:
  ///
  ///  * [BlendMode], which includes an illustration of the effect of each blend mode.
  final BlendMode? colorBlendMode;

  /// Target the interpolation quality for image scaling.
  ///
  /// If not given a value, defaults to FilterQuality.low.
  final FilterQuality filterQuality;

  /// Whether to use resizeImage to reduce the size of the image.
  final bool isUsingResize;

  /// [CachedQuillImage] shows a network image using a caching mechanism. It also
  /// provides support for a placeholder, showing an error and fading into the
  /// loaded image. Next to that it supports most features of a default Image
  /// widget.
  CachedQuillImage({
    Key? key,
    required this.imageUrl,
    this.imageBuilder,
    this.placeholder,
    this.progressIndicatorBuilder,
    this.errorWidget,
    this.fadeOutDuration = const Duration(milliseconds: 1000),
    this.fadeOutCurve = Curves.easeOut,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.fadeInCurve = Curves.easeIn,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    this.httpHeaders,
    this.cacheManager,
    this.color,
    this.filterQuality = FilterQuality.low,
    this.colorBlendMode,
    this.placeholderFadeInDuration,
    this.cacheKey,
    this.isUsingResize = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var _plBuilder = placeholder != null
        ? (context) => placeholder!.call(context, imageUrl)
        : null;

    var _pIBuilder = progressIndicatorBuilder != null
        ? (BuildContext context, ImageChunkEvent? progress) {
            int? totalSize;
            var downloaded = 0;
            if (progress != null) {
              totalSize = progress.expectedTotalBytes;
              downloaded = progress.cumulativeBytesLoaded;
            }
            return progressIndicatorBuilder!.call(
              context,
              imageUrl,
              DownloadProgress(imageUrl, totalSize, downloaded),
            );
          }
        : null;

    /// If there is no placeholer OctoImage does not fade, so always set an
    /// (empty) placeholder as this always used to be the behaviour of
    /// [CachedQuillImage].
    if (_plBuilder == null && _pIBuilder == null) {
      _plBuilder = (context) => Container();
    }
    return LayoutBuilder(
      builder: (ctx, constraints) {
        int? _constrainWidth = width?.toInt();
        int? _constrainHeight = height?.toInt();

        if (_constrainWidth == null && _constrainHeight == null) {
          int? _getSize(double s) => s != double.infinity ? s.toInt() : null;
          _constrainWidth = _getSize(constraints.maxWidth);
          _constrainHeight = _getSize(constraints.maxHeight);
        }

        // Ratio is needed to scale the width and height to the pixel ratio of the
        // device. This is needed because the image is cached in the pixel ratio
        final ratio = MediaQuery.of(context).devicePixelRatio;
        //
        int? _scaleSize(int? s) => s != null ? (s * ratio).toInt() : null;
        // Scale the width and height to the pixel ratio of the device
        _constrainWidth = _scaleSize(_constrainWidth);
        _constrainHeight = _scaleSize(_constrainHeight);

        // By default _image is null, so if the image is not cached it will be
        // null. If the image is cached it will be an CachedQuillImageProvider
        if (_image == null ||
            _image?.maxHeight != _constrainHeight ||
            _image?.maxWidth != _constrainHeight) {
          _image = CachedQuillImageProvider(
            imageUrl,
            cacheKey: cacheKey,
            maxWidth: _constrainWidth,
            maxHeight: _constrainHeight,
            cacheManager: cacheManager,
            headers: httpHeaders,
            isUsingResize: isUsingResize,
          );
        }
        return OctoImage(
          image: _image!,
          imageBuilder: imageBuilder != null ? _imageBuilder : null,
          placeholderBuilder: _plBuilder,
          progressIndicatorBuilder: _pIBuilder,
          errorBuilder: errorWidget != null ? _errorBuilder : null,
          fadeOutDuration: fadeOutDuration,
          fadeOutCurve: fadeOutCurve,
          fadeInDuration: fadeInDuration,
          fadeInCurve: fadeInCurve,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          repeat: repeat,
          matchTextDirection: matchTextDirection,
          color: color,
          filterQuality: filterQuality,
          colorBlendMode: colorBlendMode,
          placeholderFadeInDuration: placeholderFadeInDuration,
          gaplessPlayback: true,
        );
      },
    );
  }

  Widget _imageBuilder(BuildContext context, Widget child) {
    return imageBuilder!(context, _image!);
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return errorWidget!(context, imageUrl, error);
  }
}
