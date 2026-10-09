import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/intema_theme.dart';

class IntemaLogo extends StatelessWidget {
  const IntemaLogo({super.key, this.height = 96, this.compact = false});

  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo de INTEMA S.A.C.',
      child: Image.asset(
        AppConfig.logoAsset,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          width: compact ? height : height * 2.6,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: IntemaColors.navy,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: IntemaColors.yellow, width: 3),
          ),
          child: Text(
            compact ? 'i' : 'INTEMA',
            style: const TextStyle(
              color: IntemaColors.yellow,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}
