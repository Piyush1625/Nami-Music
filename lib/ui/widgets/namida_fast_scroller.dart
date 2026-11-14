import 'package:flutter/material.dart';
class NamidaFastScroller extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final int? itemCount;
  final String Function(int)? labelBuilder;
  const NamidaFastScroller({super.key, required this.child, this.controller, this.itemCount, this.labelBuilder});
  @override Widget build(BuildContext context) => child;
}
