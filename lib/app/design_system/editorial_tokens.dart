import 'package:flutter/material.dart';

/// Compatibility palette for feature pages awaiting the editorial migration.
/// New code should consume the editorial theme's semantic colors instead.
class HoopitoColors {
  const HoopitoColors._();

  static const offWhite = Color(0xFFF4F3EF);
  static const cream = Color(0xFFFFFFFF);
  static const orange = Color(0xFFFF5A1F);
  static const orangeLight = Color(0xFFFF6A32);
  static const red = Color(0xFFA41E29);
  static const redLight = Color(0xFFFF747D);
  static const redAccessible = red;
  static const blue = Color(0xFF064BA3);
  static const blueLight = Color(0xFF69A1FF);
  static const blueAccessible = blue;
  static const ink = Color(0xFF101112);
  static const charcoal = Color(0xFF0C0D0E);
  static const charcoalSurface = Color(0xFF151719);
  static const charcoalContainer = Color(0xFF202326);
  static const darkInk = Color(0xFFF4F3EF);
}

class HoopitoSpacing {
  const HoopitoSpacing._();

  static const page = 16.0;
  static const pageMedium = 24.0;
  static const pageWide = 40.0;
  static const section = 24.0;
  static const sectionWide = 40.0;
  static const card = 12.0;
  static const compact = 8.0;
  static const hairline = 4.0;

  static double pageFor(double width) {
    if (width >= 960) return pageWide;
    if (width >= 600) return pageMedium;
    return page;
  }

  static double sectionFor(double width) => width >= 600 ? 32 : section;
}

class HoopitoRadii {
  const HoopitoRadii._();

  static const card = 4.0;
  static const control = 4.0;
  static const pill = 999.0;
}

class HoopitoTypography {
  const HoopitoTypography._();

  static const displayFamily = 'Barlow Condensed';
  static const body = 16.0;
  static const label = 14.0;
  static const title = 22.0;

  static double mastheadFor(double width) {
    if (width >= 960) return 48;
    if (width >= 600) return 40;
    return 32;
  }

  static double scoreFor(double width) => width >= 600 ? 72 : 56;
}

class HoopitoStatusColors {
  const HoopitoStatusColors._();

  static const positive = Color(0xFF176B45);
  static const warning = Color(0xFF7A4B00);
  static const negative = HoopitoColors.red;
  static const info = HoopitoColors.blue;
}
