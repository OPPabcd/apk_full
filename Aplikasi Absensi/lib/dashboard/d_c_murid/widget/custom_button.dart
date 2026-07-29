import 'package:flutter/material.dart';

enum IconPosition {
  left,
  right,
}

class CustomCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? customSubtitle;

  // SIZE
  final double? width;
  final double? height;

  // ACTION
  final VoidCallback? onTap;

  // CARD ALIGNMENT
  final AlignmentGeometry alignment;

  // STYLE
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;

  // TEXT STYLE
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  // TEXT DEFAULT
  final TextAlign titleAlign;
  final TextAlign subtitleAlign;
  final int? titleMaxLines;
  final int? subtitleMaxLines;
  final TextOverflow? titleOverflow;
  final TextOverflow? subtitleOverflow;

  // ICON
  final IconData? icon;
  final Color iconColor;
  final double iconSize;
  final bool showIcon;

  // SPACING
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  // SHADOW
  final List<BoxShadow>? boxShadow;

  final Widget? customIcon;
  
  final IconPosition iconPosition;
  final BoxDecoration? iconDecoration;
  final Gradient? iconGradient;
  final EdgeInsetsGeometry iconPadding;
  final double iconContainerSize;
  final Gradient? gradient;

  const CustomCard({
    super.key,
    required this.title,
    this.subtitle,
    this.customSubtitle,

    this.width,
    this.height,
    this.onTap,

    this.alignment = Alignment.centerLeft,

    this.backgroundColor = const Color(0xFFF1F5F9),
    this.borderColor = const Color(0xFFBFDBFE),
    this.borderWidth = 1,
    this.borderRadius = 16,

    this.titleStyle,
    this.subtitleStyle,

    //TEXT DEFAULT
    this.titleAlign = TextAlign.left,
    this.subtitleAlign = TextAlign.left,
    this.titleMaxLines,
    this.subtitleMaxLines,
    this.titleOverflow,
    this.subtitleOverflow,

    this.icon = Icons.chevron_right,
    this.iconColor = const Color(0xFF94A3B8),
    this.iconSize = 24,
    this.showIcon = true,

    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),

    this.boxShadow,

    this.customIcon,

    this.iconPosition = IconPosition.right,
    this.iconDecoration,
    this.iconGradient,
    this.iconPadding = const EdgeInsets.all(8),
    this.iconContainerSize = 40,
    this.gradient,
  });

  Widget _buildIcon() {
  if (!showIcon) return const SizedBox();

  Widget iconWidget = customIcon ??
      (icon != null
          ? Icon(
              icon,
              color: iconColor,
              size: iconSize,
            )
          : const SizedBox());

    return Container(
      width: iconContainerSize,
      height: iconContainerSize,
      padding: iconPadding,
      decoration: iconDecoration ??
          BoxDecoration(
            gradient: iconGradient,
            borderRadius: BorderRadius.circular(12),
          ),
      child: Center(child: iconWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Container(
          width: width ?? double.infinity,
          height: height,
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: gradient == null ? backgroundColor : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ICON
    if (iconPosition == IconPosition.left) ...[
      _buildIcon(),
      const SizedBox(width: 8),
    ],
              
              // TEXT
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  // 🔥 ini ikut textAlign
                  crossAxisAlignment: titleAlign == TextAlign.right
                      ? CrossAxisAlignment.end
                      : titleAlign == TextAlign.center
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,
                      textAlign: titleAlign,
                      maxLines: titleMaxLines,
                      overflow: titleOverflow,
                      style: titleStyle ??
                          const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                    ),
                    if (customSubtitle != null) ...[
                      const SizedBox(height: 4),
                      customSubtitle!,
                    ] else if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        textAlign: subtitleAlign,
                        maxLines: subtitleMaxLines,
                        overflow: subtitleOverflow,
                        style: subtitleStyle ??
                            const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
    if (iconPosition == IconPosition.right) ...[
      const SizedBox(width: 8),
      _buildIcon(),
    ],
            ],
          ),
        ),
      ),
    );
  }
}
