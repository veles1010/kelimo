import 'package:flutter/material.dart';

class ScaleDownSingleLineText extends StatelessWidget {
  const ScaleDownSingleLineText(
    this.text, {
    super.key,
    this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  final String text;
  final TextStyle? style;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ),
    );
  }
}
