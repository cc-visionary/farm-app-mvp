import 'package:flutter/material.dart';
import '../domain/supply.dart';

class AddEditSupplyScreen extends StatelessWidget {
  const AddEditSupplyScreen({super.key, this.existing});
  final Supply? existing;
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Add/Edit Supply — Task 2')));
}
