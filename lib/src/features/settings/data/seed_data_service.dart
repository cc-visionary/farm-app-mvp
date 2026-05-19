// lib/src/features/settings/data/seed_data_service.dart
//
// Smoke-test data seeder. Populates a single farm with a realistic spread of
// records covering every feature surface (areas, pens, equipment, pigs,
// breedings, farrowings, health, mortality, supplies, purchases, expenses,
// sales, shifts, manual tasks) so a developer can exercise the app end-to-end
// without manually creating each record through the UI.
//
// IMPORTANT: This service is exercised from a debug-only Settings section
// (`SeedTestDataSection`). All writes go through the existing repositories so
// the atomicity contract (source-of-truth doc + activity entry + derived
// tasks in a single Firestore batch/transaction) is honoured. No direct
// Firestore writes happen here.
//
// All seed records are tagged with names beginning with a recognisable string
// (e.g. "Pigrolac Starter", "SOW-001") so `wipeAll` can find them later by
// querying the farm's sub-collections without affecting unrelated records.
// In practice the wipe deletes ALL docs under the farm's sub-collections —
// it's intended to leave the farm itself + members intact but reset the data.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../areas/data/area_repository.dart';
import '../../areas/domain/area.dart';
import '../../equipment/data/equipment_repository.dart';
import '../../equipment/domain/equipment.dart';
import '../../equipment/domain/maintenance_record.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense_category.dart';
import '../../inventory/data/supply_repository.dart';
import '../../inventory/domain/supply_category.dart';
import '../../pigs/data/breeding_repository.dart';
import '../../pigs/data/farrowing_repository.dart';
import '../../pigs/data/health_repository.dart';
import '../../pigs/data/mortality_repository.dart';
import '../../pigs/data/pig_repository.dart';
import '../../pigs/domain/breeding_record.dart';
import '../../pigs/domain/health_record.dart';
import '../../pigs/domain/pig.dart';
import '../../purchases/data/purchase_repository.dart';
import '../../sales/data/sale_repository.dart';
import '../../sales/domain/payment_method.dart';
import '../../sales/domain/payment_status.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/domain/shift.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task.dart';

typedef SeedStatusCallback = void Function(String);

/// Orchestrates seeding/wiping of smoke-test data for one farm.
///
/// All repositories are passed via constructor injection so this stays
/// pure-Dart and decoupled from the widget tree. The accompanying UI section
/// (`SeedTestDataSection`) reads each repository from its Riverpod provider
/// and hands them to this class.
class SeedDataService {
  SeedDataService({
    required this.firestore,
    required this.areaRepo,
    required this.pigRepo,
    required this.breedingRepo,
    required this.farrowingRepo,
    required this.healthRepo,
    required this.mortalityRepo,
    required this.equipmentRepo,
    required this.supplyRepo,
    required this.purchaseRepo,
    required this.expenseRepo,
    required this.saleRepo,
    required this.shiftRepo,
    required this.taskRepo,
  });

  final FirebaseFirestore firestore;
  final AreaRepository areaRepo;
  final PigRepository pigRepo;
  final BreedingRepository breedingRepo;
  final FarrowingRepository farrowingRepo;
  final HealthRepository healthRepo;
  final MortalityRepository mortalityRepo;
  final EquipmentRepository equipmentRepo;
  final SupplyRepository supplyRepo;
  final PurchaseRepository purchaseRepo;
  final ExpenseRepository expenseRepo;
  final SaleRepository saleRepo;
  final ShiftRepository shiftRepo;
  final TaskRepository taskRepo;

  // ---------------------------------------------------------------------------
  // SEED
  // ---------------------------------------------------------------------------

  /// Seeds the entire test inventory into [farmId]. Idempotent enough for
  /// re-runs because each repository write creates fresh doc IDs — but in
  /// practice you should `wipeAll` first so you don't accumulate duplicates.
  Future<void> seedAll({
    required String farmId,
    required String ownerUserId,
    required String ownerDisplayName,
    required SeedStatusCallback onStatus,
  }) async {
    final now = DateTime.now();
    Timestamp ago(int days) =>
        Timestamp.fromDate(now.subtract(Duration(days: days)));

    // -----------------------------------------------------------------------
    // Areas + pens
    // -----------------------------------------------------------------------
    onStatus('Creating 3 areas + 6 pens…');
    final farrowingAreaId = await areaRepo.createArea(
      farmId: farmId,
      name: 'Farrowing 1',
      purpose: AreaPurpose.farrowing,
      notes: null,
    );
    final gestationAreaId = await areaRepo.createArea(
      farmId: farmId,
      name: 'Gestation',
      purpose: AreaPurpose.gestation,
      notes: null,
    );
    final growFinishAreaId = await areaRepo.createArea(
      farmId: farmId,
      name: 'Grow-Finish',
      purpose: AreaPurpose.growFinish,
      notes: null,
    );

    final farrowingPen1 = await areaRepo.createPen(
      farmId: farmId,
      areaId: farrowingAreaId,
      name: 'F1-Pen1',
      capacity: 12,
      notes: null,
    );
    final farrowingPen2 = await areaRepo.createPen(
      farmId: farmId,
      areaId: farrowingAreaId,
      name: 'F1-Pen2',
      capacity: 12,
      notes: null,
    );
    final gestationPen1 = await areaRepo.createPen(
      farmId: farmId,
      areaId: gestationAreaId,
      name: 'G-Pen1',
      capacity: 20,
      notes: null,
    );
    await areaRepo.createPen(
      farmId: farmId,
      areaId: gestationAreaId,
      name: 'G-Pen2',
      capacity: 20,
      notes: null,
    );
    final growFinishPen1 = await areaRepo.createPen(
      farmId: farmId,
      areaId: growFinishAreaId,
      name: 'GF-Pen1',
      capacity: 30,
      notes: null,
    );
    await areaRepo.createPen(
      farmId: farmId,
      areaId: growFinishAreaId,
      name: 'GF-Pen2',
      capacity: 30,
      notes: null,
    );

    // -----------------------------------------------------------------------
    // Equipment + maintenance
    // -----------------------------------------------------------------------
    onStatus('Adding 8 equipment items…');
    Future<String> mkEquip({
      required String name,
      required EquipmentType type,
      required String? areaId,
      required EquipmentStatus status,
      required int ageDays,
      required double costPhp,
    }) =>
        equipmentRepo.createEquipment(
          farmId: farmId,
          name: name,
          type: type,
          areaId: areaId,
          status: status,
          purchaseDate: ago(ageDays),
          purchaseCostPhp: costPhp,
          photoUrl: null,
          notes: null,
          actorUserId: ownerUserId,
          actorDisplayName: ownerDisplayName,
        );

    await mkEquip(
      name: 'Tunnel Fan A',
      type: EquipmentType.ventilation,
      areaId: farrowingAreaId,
      status: EquipmentStatus.inUse,
      ageDays: 180,
      costPhp: 25000,
    );
    final tunnelFanBId = await mkEquip(
      name: 'Tunnel Fan B',
      type: EquipmentType.ventilation,
      areaId: growFinishAreaId,
      status: EquipmentStatus.needsRepair,
      ageDays: 180,
      costPhp: 25000,
    );
    await mkEquip(
      name: 'Auto Feeder 1',
      type: EquipmentType.feeder,
      areaId: growFinishAreaId,
      status: EquipmentStatus.inUse,
      ageDays: 90,
      costPhp: 12000,
    );
    await mkEquip(
      name: 'Heat Lamp 1',
      type: EquipmentType.other,
      areaId: farrowingAreaId,
      status: EquipmentStatus.inUse,
      ageDays: 30,
      costPhp: 800,
    );
    await mkEquip(
      name: 'Heat Lamp 2',
      type: EquipmentType.other,
      areaId: farrowingAreaId,
      status: EquipmentStatus.available,
      ageDays: 30,
      costPhp: 800,
    );
    final generatorId = await mkEquip(
      name: 'Generator',
      type: EquipmentType.generator,
      areaId: null,
      status: EquipmentStatus.inUse,
      ageDays: 365,
      costPhp: 65000,
    );
    await mkEquip(
      name: 'Weighing Scale',
      type: EquipmentType.scale,
      areaId: null,
      status: EquipmentStatus.inUse,
      ageDays: 180,
      costPhp: 8000,
    );
    await mkEquip(
      name: 'Pressure Washer',
      type: EquipmentType.tool,
      areaId: null,
      status: EquipmentStatus.retired,
      ageDays: 730,
      costPhp: 5000,
    );

    onStatus('Logging maintenance on generator…');
    for (final daysAgo in [300, 180, 60]) {
      await equipmentRepo.logMaintenance(
        farmId: farmId,
        equipmentId: generatorId,
        equipmentName: 'Generator',
        type: MaintenanceType.preventive,
        date: ago(daysAgo),
        performedBy: ownerDisplayName,
        partsReplaced: null,
        costPhp: 500,
        photoUrls: const [],
        notes: 'Routine check',
        actorUserId: ownerUserId,
        actorDisplayName: ownerDisplayName,
      );
    }

    // -----------------------------------------------------------------------
    // Pigs (30 total: 4 sows + 2 boars + 2 gilts + 18 grow-finish + 4 weaners)
    // -----------------------------------------------------------------------
    onStatus('Adding 4 sows…');
    final sowIds = <String>[];
    for (var i = 1; i <= 4; i++) {
      final id = await pigRepo.createPig(
        farmId: farmId,
        tagId: 'SOW-${i.toString().padLeft(3, '0')}',
        sex: PigSex.female,
        breed: 'Landrace',
        birthDate: ago(365 * 2 + i * 30),
        sireId: null,
        damId: null,
        stage: PigStage.sow,
        currentAreaId: gestationAreaId,
        currentPenId: gestationPen1,
        currentWeight: 180.0 + i,
        photoUrl: null,
        notes: null,
        actorUserId: ownerUserId,
        actorDisplayName: ownerDisplayName,
      );
      sowIds.add(id);
    }

    onStatus('Adding 2 boars…');
    final boarIds = <String>[];
    for (var i = 1; i <= 2; i++) {
      final id = await pigRepo.createPig(
        farmId: farmId,
        tagId: 'BOAR-${i.toString().padLeft(2, '0')}',
        sex: PigSex.male,
        breed: 'Duroc',
        birthDate: ago(365 * 2 + i * 60),
        sireId: null,
        damId: null,
        stage: PigStage.boar,
        currentAreaId: gestationAreaId,
        currentPenId: gestationPen1,
        currentWeight: 250.0 + i,
        photoUrl: null,
        notes: null,
        actorUserId: ownerUserId,
        actorDisplayName: ownerDisplayName,
      );
      boarIds.add(id);
    }

    onStatus('Adding 2 gilts…');
    for (var i = 1; i <= 2; i++) {
      await pigRepo.createPig(
        farmId: farmId,
        tagId: 'GILT-${i.toString().padLeft(2, '0')}',
        sex: PigSex.female,
        breed: 'Landrace',
        birthDate: ago(240),
        sireId: null,
        damId: null,
        stage: PigStage.gilt,
        currentAreaId: gestationAreaId,
        currentPenId: gestationPen1,
        currentWeight: 130.0,
        photoUrl: null,
        notes: null,
        actorUserId: ownerUserId,
        actorDisplayName: ownerDisplayName,
      );
    }

    onStatus('Adding 18 grow-finish pigs…');
    final growFinishIds = <String>[];
    for (var i = 1; i <= 18; i++) {
      final id = await pigRepo.createPig(
        farmId: farmId,
        tagId: 'GF-${i.toString().padLeft(3, '0')}',
        sex: i.isEven ? PigSex.male : PigSex.female,
        breed: 'Landrace x Duroc',
        birthDate: ago(150),
        sireId: null,
        damId: null,
        stage: PigStage.finisher,
        currentAreaId: growFinishAreaId,
        currentPenId: growFinishPen1,
        currentWeight: 60.0 + (i % 4) * 7.5,
        photoUrl: null,
        notes: null,
        actorUserId: ownerUserId,
        actorDisplayName: ownerDisplayName,
      );
      growFinishIds.add(id);
    }

    onStatus('Adding 4 weaners…');
    final weanerIds = <String>[];
    for (var i = 1; i <= 4; i++) {
      final id = await pigRepo.createPig(
        farmId: farmId,
        tagId: 'WNR-${i.toString().padLeft(2, '0')}',
        sex: i.isEven ? PigSex.male : PigSex.female,
        breed: 'Landrace x Duroc',
        birthDate: ago(42),
        sireId: null,
        damId: null,
        stage: PigStage.weaner,
        currentAreaId: farrowingAreaId,
        currentPenId: farrowingPen2,
        currentWeight: 12.0,
        photoUrl: null,
        notes: null,
        actorUserId: ownerUserId,
        actorDisplayName: ownerDisplayName,
      );
      weanerIds.add(id);
    }

    // -----------------------------------------------------------------------
    // Breeding records
    // -----------------------------------------------------------------------
    onStatus('Logging 5 breedings…');
    // Sow 0 — confirmed pregnancy 50d in.
    final br0 = await breedingRepo.logBreeding(
      farmId: farmId,
      sowId: sowIds[0],
      sowTagId: 'SOW-001',
      sowAreaId: gestationAreaId,
      boarId: boarIds[0],
      heatDate: ago(52),
      inseminationDate: ago(50),
      method: BreedingMethod.natural,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await breedingRepo.recordPregnancyCheck(
      farmId: farmId,
      sowId: sowIds[0],
      breedingRecordId: br0,
      confirmed: true,
      checkDate: ago(20),
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
      sowTagId: 'SOW-001',
      areaId: gestationAreaId,
    );

    // Sow 1 — confirmed pregnancy 90d in.
    final br1 = await breedingRepo.logBreeding(
      farmId: farmId,
      sowId: sowIds[1],
      sowTagId: 'SOW-002',
      sowAreaId: gestationAreaId,
      boarId: boarIds[1],
      heatDate: ago(92),
      inseminationDate: ago(90),
      method: BreedingMethod.ai,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await breedingRepo.recordPregnancyCheck(
      farmId: farmId,
      sowId: sowIds[1],
      breedingRecordId: br1,
      confirmed: true,
      checkDate: ago(60),
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
      sowTagId: 'SOW-002',
      areaId: gestationAreaId,
    );

    // Sow 2 — planned breeding 5 days ago.
    await breedingRepo.logBreeding(
      farmId: farmId,
      sowId: sowIds[2],
      sowTagId: 'SOW-003',
      sowAreaId: gestationAreaId,
      boarId: boarIds[0],
      heatDate: ago(7),
      inseminationDate: ago(5),
      method: BreedingMethod.natural,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );

    // Sow 3 — failed pregnancy check 30 days ago.
    final br3 = await breedingRepo.logBreeding(
      farmId: farmId,
      sowId: sowIds[3],
      sowTagId: 'SOW-004',
      sowAreaId: gestationAreaId,
      boarId: boarIds[1],
      heatDate: ago(62),
      inseminationDate: ago(60),
      method: BreedingMethod.natural,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await breedingRepo.recordPregnancyCheck(
      farmId: farmId,
      sowId: sowIds[3],
      breedingRecordId: br3,
      confirmed: false,
      checkDate: ago(30),
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
      sowTagId: 'SOW-004',
      areaId: gestationAreaId,
    );

    // A 5th breeding paired with a farrowing record. Use sow 0 again so we
    // have multiple records on a single sow for the detail screen.
    final br4 = await breedingRepo.logBreeding(
      farmId: farmId,
      sowId: sowIds[0],
      sowTagId: 'SOW-001',
      sowAreaId: gestationAreaId,
      boarId: boarIds[0],
      heatDate: ago(142),
      inseminationDate: ago(140),
      method: BreedingMethod.natural,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await breedingRepo.recordPregnancyCheck(
      farmId: farmId,
      sowId: sowIds[0],
      breedingRecordId: br4,
      confirmed: true,
      checkDate: ago(110),
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
      sowTagId: 'SOW-001',
      areaId: gestationAreaId,
    );

    // -----------------------------------------------------------------------
    // Farrowing records
    // -----------------------------------------------------------------------
    onStatus('Logging 2 farrowings + litter batches…');
    // Farrowing 25d ago on sow 0 / br4.
    await farrowingRepo.logFarrowing(
      farmId: farmId,
      sowId: sowIds[0],
      sowTagId: 'SOW-001',
      sowAreaId: farrowingAreaId,
      sowPenId: farrowingPen1,
      breedingRecordId: br4,
      date: ago(25),
      liveBorn: 10,
      stillborn: 1,
      mummified: 0,
      avgBirthWeightKg: 1.4,
      createLitterBatch: true,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );

    // Farrowing 7d ago on sow 1 / br1.
    await farrowingRepo.logFarrowing(
      farmId: farmId,
      sowId: sowIds[1],
      sowTagId: 'SOW-002',
      sowAreaId: farrowingAreaId,
      sowPenId: farrowingPen1,
      breedingRecordId: br1,
      date: ago(7),
      liveBorn: 12,
      stillborn: 0,
      mummified: 0,
      avgBirthWeightKg: 1.5,
      createLitterBatch: true,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );

    // -----------------------------------------------------------------------
    // Health records (10)
    // -----------------------------------------------------------------------
    onStatus('Logging 10 health records…');
    Future<void> mkHealth({
      required String pigId,
      required String tagId,
      required String areaId,
      required HealthEventType type,
      required int daysAgo,
      String? product,
      String? dosage,
      HealthRoute? route,
      String? diagnosis,
      int? withdrawalDays,
    }) =>
        healthRepo.logHealth(
          farmId: farmId,
          pigId: pigId,
          tagId: tagId,
          areaId: areaId,
          type: type,
          date: ago(daysAgo),
          productName: product,
          dosage: dosage,
          route: route,
          diagnosis: diagnosis,
          withdrawalEndDate: withdrawalDays == null
              ? null
              : ago(daysAgo - withdrawalDays),
          costPhp: null,
          photoUrls: const [],
          notes: null,
          actorUserId: ownerUserId,
          actorDisplayName: ownerDisplayName,
        );

    // Vaccinations (4)
    await mkHealth(
      pigId: sowIds[0],
      tagId: 'SOW-001',
      areaId: gestationAreaId,
      type: HealthEventType.vaccination,
      daysAgo: 60,
      product: 'PRRS Vaccine',
      dosage: '2 ml',
      route: HealthRoute.im,
      withdrawalDays: 21,
    );
    await mkHealth(
      pigId: sowIds[1],
      tagId: 'SOW-002',
      areaId: gestationAreaId,
      type: HealthEventType.vaccination,
      daysAgo: 45,
      product: 'FMD Vaccine',
      dosage: '2 ml',
      route: HealthRoute.im,
      withdrawalDays: 21,
    );
    await mkHealth(
      pigId: boarIds[0],
      tagId: 'BOAR-01',
      areaId: gestationAreaId,
      type: HealthEventType.vaccination,
      daysAgo: 30,
      product: 'PRRS Vaccine',
      dosage: '2 ml',
      route: HealthRoute.im,
      withdrawalDays: 21,
    );
    await mkHealth(
      pigId: growFinishIds[0],
      tagId: 'GF-001',
      areaId: growFinishAreaId,
      type: HealthEventType.vaccination,
      daysAgo: 15,
      product: 'FMD Vaccine',
      dosage: '2 ml',
      route: HealthRoute.im,
      withdrawalDays: 21,
    );

    // Treatments (3)
    await mkHealth(
      pigId: growFinishIds[1],
      tagId: 'GF-002',
      areaId: growFinishAreaId,
      type: HealthEventType.treatment,
      daysAgo: 12,
      product: 'Amoxicillin',
      dosage: '5 ml',
      route: HealthRoute.im,
      diagnosis: 'Respiratory infection',
      withdrawalDays: 14,
    );
    await mkHealth(
      pigId: growFinishIds[2],
      tagId: 'GF-003',
      areaId: growFinishAreaId,
      type: HealthEventType.treatment,
      daysAgo: 8,
      product: 'Sulfa drug',
      dosage: '3 ml',
      route: HealthRoute.oral,
      diagnosis: 'Digestive upset',
    );
    await mkHealth(
      pigId: weanerIds[0],
      tagId: 'WNR-01',
      areaId: farrowingAreaId,
      type: HealthEventType.treatment,
      daysAgo: 4,
      product: 'Iodine 7%',
      dosage: 'Topical',
      route: HealthRoute.topical,
      diagnosis: 'Skin lesion',
    );

    // Deworming (2)
    await mkHealth(
      pigId: sowIds[2],
      tagId: 'SOW-003',
      areaId: gestationAreaId,
      type: HealthEventType.deworming,
      daysAgo: 20,
      product: 'Ivermectin',
      dosage: '1 ml/33kg',
      route: HealthRoute.sc,
    );
    await mkHealth(
      pigId: growFinishIds[3],
      tagId: 'GF-004',
      areaId: growFinishAreaId,
      type: HealthEventType.deworming,
      daysAgo: 18,
      product: 'Ivermectin',
      dosage: '1 ml/33kg',
      route: HealthRoute.sc,
    );

    // Checkup (1)
    await mkHealth(
      pigId: sowIds[1],
      tagId: 'SOW-002',
      areaId: farrowingAreaId,
      type: HealthEventType.checkup,
      daysAgo: 5,
      diagnosis: 'Post-farrowing wellness check',
    );

    // -----------------------------------------------------------------------
    // Mortalities (3)
    // -----------------------------------------------------------------------
    onStatus('Logging 3 mortalities…');
    await mortalityRepo.logMortality(
      farmId: farmId,
      pigId: weanerIds[3],
      tagId: 'WNR-04',
      areaId: farrowingAreaId,
      date: ago(5),
      cause: 'Respiratory',
      photoUrls: const [],
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await mortalityRepo.logMortality(
      farmId: farmId,
      pigId: growFinishIds[17], // GF-018: keep this one out of the sales pool.
      tagId: 'GF-018',
      areaId: growFinishAreaId,
      date: ago(20),
      cause: 'Accident',
      photoUrls: const [],
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await mortalityRepo.logMortality(
      farmId: farmId,
      pigId: sowIds[3],
      tagId: 'SOW-004',
      areaId: gestationAreaId,
      date: ago(60),
      cause: 'Unknown',
      photoUrls: const [],
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );

    // -----------------------------------------------------------------------
    // Supplies + purchases + consumptions
    // -----------------------------------------------------------------------
    onStatus('Creating 6 supplies…');
    final pigrolacStarterId = await supplyRepo.createSupply(
      farmId: farmId,
      name: 'Pigrolac Starter',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: 10,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    final pigrolacGrowerId = await supplyRepo.createSupply(
      farmId: farmId,
      name: 'Pigrolac Grower',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: 10,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    final pigrolacFinisherId = await supplyRepo.createSupply(
      farmId: farmId,
      name: 'Pigrolac Finisher',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: 10,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    final prrsVaccineId = await supplyRepo.createSupply(
      farmId: farmId,
      name: 'PRRS Vaccine',
      category: SupplyCategory.medicine,
      unit: SupplyUnit.dose,
      unitsPerPackage: null,
      lowStockThreshold: 20,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    final iodineId = await supplyRepo.createSupply(
      farmId: farmId,
      name: 'Iodine 7%',
      category: SupplyCategory.medicine,
      unit: SupplyUnit.ml,
      unitsPerPackage: null,
      lowStockThreshold: 100,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    // Out-of-stock supply.
    await supplyRepo.createSupply(
      farmId: farmId,
      name: 'Iron supplement',
      category: SupplyCategory.medicine,
      unit: SupplyUnit.vial,
      unitsPerPackage: null,
      lowStockThreshold: 5,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );

    onStatus('Logging 3 purchases…');
    // Purchase #1 — feed kickoff.
    await purchaseRepo.logPurchase(
      farmId: farmId,
      vendorName: 'Pilmico Feeds',
      purchaseDate: ago(45),
      referenceNo: 'OR-001',
      lineItems: [
        PurchaseLineItemInput(
          supplyId: pigrolacStarterId,
          quantity: 15,
          unitCostPhp: 1650,
        ),
        PurchaseLineItemInput(
          supplyId: pigrolacGrowerId,
          quantity: 22,
          unitCostPhp: 1700,
        ),
        PurchaseLineItemInput(
          supplyId: pigrolacFinisherId,
          quantity: 8,
          unitCostPhp: 1750,
        ),
      ],
      receiptPhotoUrl: null,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    // Purchase #2 — vaccines.
    await purchaseRepo.logPurchase(
      farmId: farmId,
      vendorName: 'Provincial Vet Supply',
      purchaseDate: ago(30),
      referenceNo: 'OR-002',
      lineItems: [
        PurchaseLineItemInput(
          supplyId: prrsVaccineId,
          quantity: 45,
          unitCostPhp: 85,
        ),
      ],
      receiptPhotoUrl: null,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    // Purchase #3 — iodine top-up.
    await purchaseRepo.logPurchase(
      farmId: farmId,
      vendorName: 'Mercury Drug',
      purchaseDate: ago(15),
      referenceNo: 'OR-003',
      lineItems: [
        PurchaseLineItemInput(
          supplyId: iodineId,
          quantity: 500,
          unitCostPhp: 0.5,
        ),
      ],
      receiptPhotoUrl: null,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );

    onStatus('Logging 8 supply consumptions…');
    // Mix of grower/finisher feed to GF pen + vaccine to specific pigs.
    final consumptions = [
      (pigrolacGrowerId, 'Pigrolac Grower', 2.0, growFinishPen1, null, 28),
      (pigrolacGrowerId, 'Pigrolac Grower', 2.0, growFinishPen1, null, 21),
      (pigrolacGrowerId, 'Pigrolac Grower', 2.0, growFinishPen1, null, 14),
      (pigrolacFinisherId, 'Pigrolac Finisher', 1.0, growFinishPen1, null, 7),
      (pigrolacFinisherId, 'Pigrolac Finisher', 1.0, growFinishPen1, null, 3),
      (prrsVaccineId, 'PRRS Vaccine', 2.0, gestationPen1, null, 60),
      (prrsVaccineId, 'PRRS Vaccine', 1.0, gestationPen1, null, 30),
      (iodineId, 'Iodine 7%', 25.0, farrowingPen2, null, 4),
    ];
    for (final c in consumptions) {
      await supplyRepo.logConsumption(
        farmId: farmId,
        supplyId: c.$1,
        supplyName: c.$2,
        quantity: c.$3,
        penId: c.$4,
        derivedBatchId: c.$5,
        healthRecordId: null,
        notes: null,
        actorUserId: ownerUserId,
        actorDisplayName: ownerDisplayName,
      );
    }

    // -----------------------------------------------------------------------
    // Expenses (5)
    // -----------------------------------------------------------------------
    onStatus('Logging 5 expenses…');
    await expenseRepo.createExpense(
      farmId: farmId,
      category: ExpenseCategory.labor,
      description: 'Monthly payroll',
      amountPhp: 12000,
      date: ago(18),
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await expenseRepo.createExpense(
      farmId: farmId,
      category: ExpenseCategory.utilities,
      description: 'May electricity',
      amountPhp: 8500,
      date: ago(18),
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await expenseRepo.createExpense(
      farmId: farmId,
      category: ExpenseCategory.equipment,
      description: 'Fan repair',
      amountPhp: 500,
      date: ago(10),
      relatedEquipmentId: tunnelFanBId,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await expenseRepo.createExpense(
      farmId: farmId,
      category: ExpenseCategory.maintenance,
      description: 'Generator service',
      amountPhp: 1200,
      date: ago(7),
      relatedEquipmentId: generatorId,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await expenseRepo.createExpense(
      farmId: farmId,
      category: ExpenseCategory.other,
      description: 'Vehicle fuel for vet trip',
      amountPhp: 600,
      date: ago(3),
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );

    // -----------------------------------------------------------------------
    // Sales (2) — sell 10 of the 18 grow-finish pigs.
    //
    // GF-018 was already marked deceased above, so use GF-001..010 for the
    // two sales (6 + 4) and leave GF-011..017 as the 7 surviving actives
    // (+1 deceased = 8 inactive-or-active slots accounted for).
    // -----------------------------------------------------------------------
    onStatus('Logging 2 sales…');
    final sale1Lines = <SaleLineItemInput>[
      for (var i = 0; i < 6; i++)
        SaleLineItemInput(
          pigId: growFinishIds[i],
          pigTagId: 'GF-${(i + 1).toString().padLeft(3, '0')}',
          finalWeightKg: 90.0 + i,
          pricePerKgPhp: 85.0,
        ),
    ];
    await saleRepo.logSale(
      farmId: farmId,
      buyerName: 'Mang Berto',
      buyerContact: null,
      saleDate: ago(12),
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
      amountPaidPhp: null,
      lineItems: sale1Lines,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );

    final sale2Lines = <SaleLineItemInput>[
      for (var i = 6; i < 10; i++)
        SaleLineItemInput(
          pigId: growFinishIds[i],
          pigTagId: 'GF-${(i + 1).toString().padLeft(3, '0')}',
          finalWeightKg: 95.0 + (i - 6),
          pricePerKgPhp: 85.0,
        ),
    ];
    await saleRepo.logSale(
      farmId: farmId,
      buyerName: 'Aling Maria',
      buyerContact: null,
      saleDate: ago(5),
      paymentMethod: PaymentMethod.gcash,
      paymentStatus: PaymentStatus.paid,
      amountPaidPhp: null,
      lineItems: sale2Lines,
      notes: null,
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );

    // -----------------------------------------------------------------------
    // Shifts (4)
    // -----------------------------------------------------------------------
    onStatus('Creating 4 shifts…');
    await shiftRepo.createShift(
      farmId: farmId,
      name: 'Morning Farrowing',
      pattern: ShiftPattern.daily,
      daysOfWeek: const [],
      startTime: '06:00',
      endTime: '14:00',
      assignedAreaId: farrowingAreaId,
      assignedUserIds: const [],
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await shiftRepo.createShift(
      farmId: farmId,
      name: 'Afternoon Farrowing',
      pattern: ShiftPattern.daily,
      daysOfWeek: const [],
      startTime: '14:00',
      endTime: '22:00',
      assignedAreaId: farrowingAreaId,
      assignedUserIds: const [],
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await shiftRepo.createShift(
      farmId: farmId,
      name: 'Grow-Finish Feed Crew',
      pattern: ShiftPattern.weekly,
      daysOfWeek: const [1, 3, 5], // Mon/Wed/Fri
      startTime: '08:00',
      endTime: '12:00',
      assignedAreaId: growFinishAreaId,
      assignedUserIds: const [],
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );
    await shiftRepo.createShift(
      farmId: farmId,
      name: 'Vet Visit',
      pattern: ShiftPattern.weekly,
      daysOfWeek: const [4], // Thu
      startTime: '13:00',
      endTime: '15:00',
      assignedAreaId: farrowingAreaId,
      assignedUserIds: const [],
      actorUserId: ownerUserId,
      actorDisplayName: ownerDisplayName,
    );

    // -----------------------------------------------------------------------
    // Manual tasks (2)
    // -----------------------------------------------------------------------
    onStatus('Adding 2 manual tasks…');
    await taskRepo.createManualTask(
      farmId: farmId,
      title: 'Order replacement fan motor',
      description: 'Tunnel Fan B in Grow-Finish needs a new motor.',
      dueDate: Timestamp.fromDate(now.add(const Duration(days: 3))),
      assignedTo: null,
      creatorUserId: ownerUserId,
    );
    await taskRepo.createManualTask(
      farmId: farmId,
      title: 'Wash water troughs in Grow-Finish',
      dueDate: Timestamp.fromDate(now.add(const Duration(days: 1))),
      relatedAreaId: growFinishAreaId,
      assignedTo: TaskAssignment(kind: 'area', id: growFinishAreaId),
      creatorUserId: ownerUserId,
    );

    onStatus('Done.');
  }

  // ---------------------------------------------------------------------------
  // WIPE
  // ---------------------------------------------------------------------------

  /// List of sub-collections (relative to `farms/{farmId}`) that
  /// [wipeAll] will recursively delete. The farm doc + members + invitations
  /// are intentionally preserved so the user stays signed in as owner.
  static const _wipeCollections = <String>[
    'pigs', // recursive: pulls breeding_records, farrowing_records,
    // health_records, mortality_record under each pig.
    'areas', // recursive: pulls pens under each area.
    'equipment', // recursive: pulls maintenance_records under each.
    'purchases', // recursive: pulls line_items under each.
    'sales', // recursive: pulls line_items under each.
    'supplies',
    'supply_movements',
    'expenses',
    'shifts',
    'tasks',
    'batches',
    'activity',
  ];

  /// Removes every seeded record from [farmId] by walking each top-level
  /// sub-collection and (recursively) deleting nested documents and
  /// sub-collections in client-side batches of 250.
  ///
  /// The farm doc and its `members` / `invitations` sub-collections are NOT
  /// touched so the current user stays signed in as the farm Owner.
  Future<void> wipeAll({
    required String farmId,
    required SeedStatusCallback onStatus,
  }) async {
    for (final col in _wipeCollections) {
      onStatus('Wiping $col…');
      final ref = firestore.collection('farms').doc(farmId).collection(col);
      await _deleteCollection(ref);
    }
    onStatus('Done.');
  }

  /// Deletes every document in [collection] (and any sub-collections we know
  /// about) in client-side WriteBatches of 250 docs each. Walks one
  /// hard-coded layer of children — sufficient for our schema (e.g. pigs has
  /// breeding_records, farrowing_records, health_records, mortality_record).
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snap = await collection.get();
    // First descend into known children so we don't leave orphans.
    for (final doc in snap.docs) {
      for (final child in _childCollectionsOf(collection.id)) {
        final childRef = doc.reference.collection(child);
        await _deleteAllDocs(childRef);
      }
    }
    await _deleteAllDocs(collection);
  }

  /// Sub-collections to recurse into for each top-level wipe target. Keep this
  /// list narrow — only collections we actually create.
  List<String> _childCollectionsOf(String parentId) {
    switch (parentId) {
      case 'pigs':
        return const [
          'breeding_records',
          'farrowing_records',
          'health_records',
          'mortality_record',
        ];
      case 'areas':
        return const ['pens'];
      case 'equipment':
        return const ['maintenance_records'];
      case 'purchases':
        return const ['line_items'];
      case 'sales':
        return const ['line_items'];
      default:
        return const [];
    }
  }

  /// Deletes every document under [collection] using batches of 250.
  Future<void> _deleteAllDocs(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const pageSize = 250;
    while (true) {
      final snap = await collection.limit(pageSize).get();
      if (snap.docs.isEmpty) return;
      final batch = firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < pageSize) return;
    }
  }
}
