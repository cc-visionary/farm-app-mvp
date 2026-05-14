import 'package:flutter/material.dart';

class SupplyDetailScreen extends StatelessWidget {
  const SupplyDetailScreen({super.key, required this.supplyId});
  final String supplyId;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Supply Detail — $supplyId — Task 2')));
}
