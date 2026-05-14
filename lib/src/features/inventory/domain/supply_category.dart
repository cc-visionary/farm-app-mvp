enum SupplyCategory {
  feed('feed', 'Feed'),
  medicine('medicine', 'Medicine'),
  otherInput('other_input', 'Other input');

  const SupplyCategory(this.value, this.label);
  final String value;
  final String label;

  static SupplyCategory fromString(String s) =>
      SupplyCategory.values.firstWhere(
        (e) => e.value == s,
        orElse: () => SupplyCategory.otherInput,
      );
}

enum SupplyUnit {
  kg('kg', 'kg'),
  sack('sack', 'sack'),
  bag('bag', 'bag'),
  ml('ml', 'ml'),
  dose('dose', 'dose'),
  vial('vial', 'vial'),
  unit('unit', 'unit');

  const SupplyUnit(this.value, this.label);
  final String value;
  final String label;

  static SupplyUnit fromString(String s) =>
      SupplyUnit.values.firstWhere(
        (e) => e.value == s,
        orElse: () => SupplyUnit.unit,
      );
}

enum MovementType {
  purchase('purchase', 'Purchase'),
  consumption('consumption', 'Consumption'),
  adjustment('adjustment', 'Adjustment'),
  wastage('wastage', 'Wastage');

  const MovementType(this.value, this.label);
  final String value;
  final String label;

  static MovementType fromString(String s) =>
      MovementType.values.firstWhere(
        (e) => e.value == s,
        orElse: () => MovementType.adjustment,
      );
}
