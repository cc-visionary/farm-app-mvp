import '../../../l10n/generated/app_localizations.dart';

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

String localizedSupplyCategory(AppLocalizations l, SupplyCategory c) {
  switch (c) {
    case SupplyCategory.feed:
      return l.supply_category_feed;
    case SupplyCategory.medicine:
      return l.supply_category_medicine;
    case SupplyCategory.otherInput:
      return l.supply_category_other_input;
  }
}

String localizedSupplyUnit(AppLocalizations l, SupplyUnit u) {
  switch (u) {
    case SupplyUnit.kg:
      return l.supply_unit_kg;
    case SupplyUnit.sack:
      return l.supply_unit_sack;
    case SupplyUnit.bag:
      return l.supply_unit_bag;
    case SupplyUnit.ml:
      return l.supply_unit_ml;
    case SupplyUnit.dose:
      return l.supply_unit_dose;
    case SupplyUnit.vial:
      return l.supply_unit_vial;
    case SupplyUnit.unit:
      return l.supply_unit_unit;
  }
}

String localizedMovementType(AppLocalizations l, MovementType t) {
  switch (t) {
    case MovementType.purchase:
      return l.movement_type_purchase;
    case MovementType.consumption:
      return l.movement_type_consumption;
    case MovementType.adjustment:
      return l.movement_type_adjustment;
    case MovementType.wastage:
      return l.movement_type_wastage;
  }
}
