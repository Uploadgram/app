import 'package:flutter/material.dart';
import 'package:uploadgram/gen/assets.gen.dart';

class UploadgramLogo extends StatelessWidget {
  final double size;
  const UploadgramLogo({Key? key, this.size = 128.0}) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: Assets.icon256.image());
}

class UploadgramTitle extends StatelessWidget {
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final double size;

  const UploadgramTitle({
    Key? key,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.size = 128,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
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
