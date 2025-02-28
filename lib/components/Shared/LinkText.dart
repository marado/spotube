import 'package:flutter/material.dart';
import 'package:spotube/components/Shared/AnchorButton.dart';

class LinkText<T> extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final Route<T> route;
  const LinkText(
    this.text,
    this.route, {
    Key? key,
    this.textAlign,
    this.overflow,
    this.style = const TextStyle(),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnchorButton(
      text,
      onTap: () async {
        await Navigator.of(context).push(route);
      },
      key: key,
      overflow: overflow,
      style: style,
      textAlign: textAlign,
    );
  }
}
