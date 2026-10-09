class MachineItem {
  MachineItem({
    required this.id,
    required this.name,
    required this.processName,
    required this.isActive,
  });

  final String id;
  final String name;
  final String processName;
  final bool isActive;

  factory MachineItem.fromJson(Map<String, dynamic> json) => MachineItem(
    id: json['id'].toString(),
    name: json['name'].toString(),
    processName: json['process_name'].toString(),
    isActive: json['is_active'] == true,
  );
}

class ProductionRunItem {
  ProductionRunItem({
    required this.id,
    required this.status,
    required this.runType,
    required this.startedAt,
    required this.goodQuantity,
    required this.rejectedQuantity,
    required this.elapsedSeconds,
  });

  final String id;
  final String status;
  final String runType;
  final DateTime? startedAt;
  final int goodQuantity;
  final int rejectedQuantity;
  final int elapsedSeconds;

  factory ProductionRunItem.fromJson(Map<String, dynamic> json) =>
      ProductionRunItem(
        id: json['id'].toString(),
        status: json['status'].toString(),
        runType: json['run_type']?.toString() ?? 'machining',
        startedAt: json['started_at'] == null
            ? null
            : DateTime.tryParse(json['started_at'].toString()),
        goodQuantity: json['good_quantity'] as int? ?? 0,
        rejectedQuantity: json['rejected_quantity'] as int? ?? 0,
        elapsedSeconds: json['elapsed_seconds'] as int? ?? 0,
      );
}

class RouteStepItem {
  RouteStepItem({
    required this.id,
    required this.sequence,
    required this.processName,
    required this.status,
    required this.machine,
    required this.runs,
  });

  final String id;
  final int sequence;
  final String processName;
  final String status;
  final MachineItem machine;
  final List<ProductionRunItem> runs;

  ProductionRunItem? get runningRun {
    for (final run in runs) {
      if (run.status == 'running' && run.runType == 'machining') return run;
    }
    return null;
  }

  ProductionRunItem? get runningSetupRun {
    for (final run in runs) {
      if (run.status == 'running' && run.runType == 'setup') return run;
    }
    return null;
  }

  factory RouteStepItem.fromJson(Map<String, dynamic> json) => RouteStepItem(
    id: json['id'].toString(),
    sequence: json['sequence'] as int? ?? 0,
    processName: json['process_name'].toString(),
    status: json['status'].toString(),
    machine: MachineItem.fromJson(Map<String, dynamic>.from(json['machine'] as Map)),
    runs: (json['runs'] as List? ?? [])
        .map((item) => ProductionRunItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );
}

class WarehouseIssueItem {
  WarehouseIssueItem({
    required this.itemName,
    required this.issueType,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.issuedAt,
    required this.observations,
  });

  final String itemName;
  final String issueType;
  final double quantity;
  final String unit;
  final double unitCost;
  final DateTime? issuedAt;
  final String? observations;

  double get totalCost => quantity * unitCost;

  factory WarehouseIssueItem.fromJson(Map<String, dynamic> json) =>
      WarehouseIssueItem(
        itemName: json['item_name'].toString(),
        issueType: json['issue_type'].toString(),
        quantity: double.tryParse(json['quantity'].toString()) ?? 0,
        unit: json['unit'].toString(),
        unitCost: double.tryParse(json['unit_cost'].toString()) ?? 0,
        issuedAt: json['issued_at'] == null
            ? null
            : DateTime.tryParse(json['issued_at'].toString())?.toLocal(),
        observations: json['observations']?.toString(),
  );
}

class QualityInspectionItem {
  QualityInspectionItem({
    required this.id,
    required this.acceptedQuantity,
    required this.rejectedQuantity,
    required this.nominalValue,
    required this.minValue,
    required this.maxValue,
    required this.measurements,
    required this.photoNotes,
    required this.observations,
  });

  final String id;
  final int acceptedQuantity;
  final int rejectedQuantity;
  final double? nominalValue;
  final double? minValue;
  final double? maxValue;
  final List<Map<String, dynamic>> measurements;
  final List<String> photoNotes;
  final String? observations;

  factory QualityInspectionItem.fromJson(Map<String, dynamic> json) =>
      QualityInspectionItem(
        id: json['id'].toString(),
        acceptedQuantity: json['accepted_quantity'] as int? ?? 0,
        rejectedQuantity: json['rejected_quantity'] as int? ?? 0,
        nominalValue: double.tryParse(json['nominal_value']?.toString() ?? ''),
        minValue: double.tryParse(json['min_value']?.toString() ?? ''),
        maxValue: double.tryParse(json['max_value']?.toString() ?? ''),
        measurements: (json['measurements'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
        photoNotes: (json['photo_notes'] as List? ?? []).map((item) => item.toString()).toList(),
        observations: json['observations']?.toString(),
      );
}

class WorkOrderComponentItem {
  WorkOrderComponentItem({
    required this.id,
    required this.workOrderId,
    required this.name,
    required this.quantityRequired,
    required this.quantityCompleted,
    required this.status,
    required this.designStartedAt,
    required this.designSeconds,
    required this.routes,
    required this.qualityInspections,
  });

  final String id;
  final String workOrderId;
  final String name;
  final int quantityRequired;
  final int quantityCompleted;
  final String status;
  final DateTime? designStartedAt;
  final int designSeconds;
  final List<RouteStepItem> routes;
  final List<QualityInspectionItem> qualityInspections;

  factory WorkOrderComponentItem.fromJson(Map<String, dynamic> json) =>
      WorkOrderComponentItem(
        id: json['id'].toString(),
        workOrderId: json['work_order_id'].toString(),
        name: json['name'].toString(),
        quantityRequired: json['quantity_required'] as int? ?? 0,
        quantityCompleted: json['quantity_completed'] as int? ?? 0,
        status: json['status'].toString(),
        designStartedAt: json['design_started_at'] == null
            ? null
            : DateTime.tryParse(json['design_started_at'].toString())?.toLocal(),
        designSeconds: json['design_seconds'] as int? ?? 0,
        routes: (json['routes'] as List? ?? [])
            .map((item) => RouteStepItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        qualityInspections: (json['quality_inspections'] as List? ?? [])
            .map((item) => QualityInspectionItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
}

class WorkOrderItem {
  WorkOrderItem({
    required this.id,
    required this.code,
    required this.clientName,
    required this.description,
    required this.status,
    required this.priority,
    required this.dueDate,
    required this.approvedAt,
    required this.components,
    required this.warehouseIssues,
  });

  final String id;
  final String code;
  final String clientName;
  final String description;
  final String status;
  final String priority;
  final DateTime? dueDate;
  final DateTime? approvedAt;
  final List<WorkOrderComponentItem> components;
  final List<WarehouseIssueItem> warehouseIssues;

  double get warehouseCost =>
      warehouseIssues.fold(0, (sum, issue) => sum + issue.totalCost);

  factory WorkOrderItem.fromJson(Map<String, dynamic> json) => WorkOrderItem(
    id: json['id'].toString(),
    code: json['code'].toString(),
    clientName: json['client_name'].toString(),
    description: json['description'].toString(),
    status: json['status'].toString(),
    priority: json['priority'].toString(),
    dueDate: json['due_date'] == null
        ? null
        : DateTime.tryParse(json['due_date'].toString()),
    approvedAt: json['approved_at'] == null
        ? null
        : DateTime.tryParse(json['approved_at'].toString()),
    components: (json['components'] as List? ?? [])
        .map((item) => WorkOrderComponentItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
    warehouseIssues: (json['warehouse_issues'] as List? ?? [])
        .map((item) => WarehouseIssueItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );
}
