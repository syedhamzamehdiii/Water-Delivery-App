import 'package:flutter/material.dart';

/// Responsive breakpoints for different screen sizes
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1600;
}

/// Responsive helper class to determine screen size and provide responsive values
class ResponsiveHelper {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.mobile && width < ResponsiveBreakpoints.tablet;
  }

  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.tablet && width < ResponsiveBreakpoints.desktop;
  }

  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktop;
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(12);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16);
    } else if (isDesktop(context)) {
      return const EdgeInsets.all(20);
    } else {
      return const EdgeInsets.all(24);
    }
  }

  /// Get responsive margin based on screen size
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(8);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(12);
    } else if (isDesktop(context)) {
      return const EdgeInsets.all(16);
    } else {
      return const EdgeInsets.all(20);
    }
  }

  /// Get responsive font size based on screen size
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    if (isMobile(context)) {
      return baseFontSize * 0.9;
    } else if (isTablet(context)) {
      return baseFontSize;
    } else if (isDesktop(context)) {
      return baseFontSize * 1.1;
    } else {
      return baseFontSize * 1.2;
    }
  }

  /// Get responsive icon size based on screen size
  static double getResponsiveIconSize(BuildContext context, double baseIconSize) {
    if (isMobile(context)) {
      return baseIconSize * 0.8;
    } else if (isTablet(context)) {
      return baseIconSize;
    } else if (isDesktop(context)) {
      return baseIconSize * 1.1;
    } else {
      return baseIconSize * 1.2;
    }
  }

  /// Get responsive grid columns based on screen size
  static int getResponsiveColumns(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else if (isDesktop(context)) {
      return 3;
    } else {
      return 4;
    }
  }

  /// Get responsive card width based on screen size
  static double getResponsiveCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isMobile(context)) {
      return screenWidth - 32; // Full width minus padding
    } else if (isTablet(context)) {
      return (screenWidth - 48) / 2; // Half width minus padding
    } else if (isDesktop(context)) {
      return (screenWidth - 64) / 3; // Third width minus padding
    } else {
      return (screenWidth - 80) / 4; // Quarter width minus padding
    }
  }

  /// Get responsive dialog width based on screen size
  static double getResponsiveDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isMobile(context)) {
      return screenWidth * 0.95;
    } else if (isTablet(context)) {
      return screenWidth * 0.7;
    } else if (isDesktop(context)) {
      return screenWidth * 0.5;
    } else {
      return screenWidth * 0.4;
    }
  }

  /// Get responsive dialog height based on screen size
  static double getResponsiveDialogHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (isMobile(context)) {
      return screenHeight * 0.8;
    } else if (isTablet(context)) {
      return screenHeight * 0.7;
    } else if (isDesktop(context)) {
      return screenHeight * 0.6;
    } else {
      return screenHeight * 0.5;
    }
  }

  /// Get responsive spacing based on screen size
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    if (isMobile(context)) {
      return baseSpacing * 0.8;
    } else if (isTablet(context)) {
      return baseSpacing;
    } else if (isDesktop(context)) {
      return baseSpacing * 1.2;
    } else {
      return baseSpacing * 1.4;
    }
  }

  /// Get responsive border radius based on screen size
  static double getResponsiveBorderRadius(BuildContext context, double baseRadius) {
    if (isMobile(context)) {
      return baseRadius * 0.8;
    } else if (isTablet(context)) {
      return baseRadius;
    } else if (isDesktop(context)) {
      return baseRadius * 1.1;
    } else {
      return baseRadius * 1.2;
    }
  }
}

/// Responsive widget that adapts its child based on screen size
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? largeDesktop;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isLargeDesktop(context) && largeDesktop != null) {
      return largeDesktop!;
    } else if (ResponsiveHelper.isDesktop(context) && desktop != null) {
      return desktop!;
    } else if (ResponsiveHelper.isTablet(context) && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

/// Responsive grid widget that adapts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveHelper.getResponsiveColumns(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) => SizedBox(
            width: itemWidth,
            child: child,
          )).toList(),
        );
      },
    );
  }
}

/// Responsive container that adapts its constraints based on screen size
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxWidth = maxWidth ?? screenWidth;
    
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: effectiveMaxWidth,
      ),
      padding: padding ?? ResponsiveHelper.getResponsivePadding(context),
      margin: margin ?? ResponsiveHelper.getResponsiveMargin(context),
      child: child,
    );
  }
}
