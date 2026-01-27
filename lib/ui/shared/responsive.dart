import 'package:flutter/material.dart';

class Responsive {
  final BuildContext context;
  late final Size size;
  late final double w;
  late final double h;
  late final EdgeInsets padding;
  late final double devicePixelRatio;

  Responsive(this.context) {
    size = MediaQuery.of(context).size;
    w = size.width;
    h = size.height;
    padding = MediaQuery.of(context).padding;
    devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
  }

  // Screen size breakpoints
  bool get isPhone => w < 600;
  bool get isNarrow => w < 360;
  bool get isSmallPhone => w < 400;
  bool get isVerySmallPhone => w < 320;
  bool get isTablet => w >= 600 && w < 1024;
  bool get isDesktop => w >= 1024;
  bool get isLargeDesktop => w >= 1440;

  // Height breakpoints
  bool get isShortScreen => h < 600;
  bool get isVeryShortScreen => h < 500;

  EdgeInsets screenPadding({
    double wide = 32,
    double phone = 20,
    double narrow = 12,
    double veryNarrow = 8,
  }) {
    if (isVerySmallPhone) return EdgeInsets.symmetric(horizontal: veryNarrow);
    if (isNarrow) return EdgeInsets.symmetric(horizontal: narrow);
    if (isPhone) return EdgeInsets.symmetric(horizontal: phone);
    return EdgeInsets.symmetric(horizontal: wide);
  }

  double chartHeight({
    double phoneFactor = 0.22,
    double wideFactor = 0.25,
    double? minHeight,
    double? maxHeight,
  }) {
    final minH = minHeight ?? (isVeryShortScreen ? 150.0 : 200.0);
    final maxH = maxHeight ?? (isShortScreen ? 300.0 : 400.0);
    final clamped = h.clamp(minH, maxH);
    return clamped * (isPhone ? phoneFactor : wideFactor);
  }

  double titleSize(
      {double veryNarrow = 18,
      double narrow = 20,
      double phone = 24,
      double wide = 28}) {
    if (isVerySmallPhone) return veryNarrow;
    if (isNarrow) return narrow;
    if (isPhone) return phone;
    return wide;
  }

  double horizontalPadding({
    double wide = 32,
    double phone = 20,
    double narrow = 12,
    double veryNarrow = 8,
  }) {
    if (isVerySmallPhone) return veryNarrow;
    if (isNarrow) return narrow;
    if (isPhone) return phone;
    return wide;
  }

  double verticalPadding({
    double wide = 16,
    double phone = 12,
    double narrow = 8,
    double veryNarrow = 6,
  }) {
    if (isVerySmallPhone) return veryNarrow;
    if (isNarrow) return narrow;
    if (isPhone) return phone;
    return wide;
  }

  // Responsive dimensions
  double get cardRadius =>
      isVerySmallPhone ? 8.0 : (isSmallPhone ? 12.0 : 15.0);
  double get buttonHeight =>
      isVerySmallPhone ? 40.0 : (isSmallPhone ? 45.0 : 55.0);
  double get inputHeight =>
      isVerySmallPhone ? 40.0 : (isSmallPhone ? 45.0 : 55.0);
  double get titleFontSize =>
      isVerySmallPhone ? 18.0 : (isSmallPhone ? 20.0 : 24.0);
  double get subtitleFontSize =>
      isVerySmallPhone ? 14.0 : (isSmallPhone ? 16.0 : 18.0);
  double get bodyFontSize =>
      isVerySmallPhone ? 12.0 : (isSmallPhone ? 14.0 : 16.0);
  double get smallFontSize =>
      isVerySmallPhone ? 10.0 : (isSmallPhone ? 12.0 : 14.0);

  // Icon sizes
  double get iconSize => isVerySmallPhone ? 16.0 : (isSmallPhone ? 20.0 : 24.0);
  double get smallIconSize =>
      isVerySmallPhone ? 12.0 : (isSmallPhone ? 16.0 : 20.0);
  double get largeIconSize =>
      isVerySmallPhone ? 24.0 : (isSmallPhone ? 28.0 : 32.0);

  // Spacing
  double get smallSpacing =>
      isVerySmallPhone ? 4.0 : (isSmallPhone ? 6.0 : 8.0);
  double get mediumSpacing =>
      isVerySmallPhone ? 8.0 : (isSmallPhone ? 12.0 : 16.0);
  double get largeSpacing =>
      isVerySmallPhone ? 12.0 : (isSmallPhone ? 16.0 : 20.0);

  // Card dimensions
  double get cardMinHeight =>
      isVeryShortScreen ? 60.0 : (isShortScreen ? 80.0 : 100.0);
  double get cardMaxHeight =>
      isVeryShortScreen ? 120.0 : (isShortScreen ? 150.0 : 200.0);

  // List item dimensions
  double get listItemHeight =>
      isVerySmallPhone ? 60.0 : (isSmallPhone ? 70.0 : 80.0);

  // Safe area helpers
  double get safeTop => padding.top;
  double get safeBottom => padding.bottom;
  double get safeHeight => h - padding.top - padding.bottom;
  double get safeWidth => w;
}
