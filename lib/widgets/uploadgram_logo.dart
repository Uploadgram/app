import 'package:flutter/material.dart';

class UploadgramLogo extends StatelessWidget {
  final double size;
  UploadgramLogo({this.size = 128.0});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size, height: size, child: Image.asset('assets/icon-256.png'));
}

class UploadgramTitle extends StatelessWidget {
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final double size;

  UploadgramTitle({
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.size = 128,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Row(
          mainAxisAlignment: mainAxisAlignment,
          mainAxisSize: mainAxisSize,
          crossAxisAlignment: crossAxisAlignment,
          children: [
            UploadgramLogo(size: size),
            SizedBox(width: 25 * size / 128),
            Text('Uploadgram',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 40 * size / 128,
                ))
          ]),
    );
  }
}
