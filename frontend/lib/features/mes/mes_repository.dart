import '../../core/network/api_client.dart';
import 'mes_models.dart';

class MesRepository {
  MesRepository(this._api);

  final ApiClient _api;

  Future<List<WorkOrderItem>> fetchWorkOrders() async {
    final data = await _api.getJson('/mes/work-orders') as List;
    return data
        .map((item) => WorkOrderItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<MachineItem>> fetchMachines() async {
    final data = await _api.getJson('/mes/machines') as List;
    return data
        .map((item) => MachineItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<MachineItem> createMachine(Map<String, dynamic> payload) async {
    final data = await _api.postJson('/mes/machines', payload);
    return MachineItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<MachineItem> updateMachine(String id, Map<String, dynamic> payload) async {
    final data = await _api.putJson('/mes/machines/$id', payload);
    return MachineItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteMachine(String id) async {
    await _api.deleteJson('/mes/machines/$id');
  }

  Future<void> createWorkOrder(Map<String, dynamic> payload) async {
    await _api.postJson('/mes/work-orders', payload);
  }

  Future<void> updateWorkOrder(String id, Map<String, dynamic> payload) async {
    await _api.putJson('/mes/work-orders/$id', payload);
  }

  Future<void> deleteWorkOrder(String id) async {
    await _api.deleteJson('/mes/work-orders/$id');
  }

  Future<void> approveWorkOrder(String id) async {
    await _api.postJson('/mes/work-orders/$id/approve', {});
  }

  Future<void> deliverWorkOrder(String id) async {
    await _api.postJson('/mes/work-orders/$id/deliver', {});
  }

  Future<void> startDesign(String componentId) async {
    await _api.postJson('/mes/components/$componentId/design/start', {});
  }

  Future<void> pauseDesign(String componentId, String observations) async {
    await _api.postJson('/mes/components/$componentId/design/pause', {
      'observations': observations.isEmpty ? null : observations,
    });
  }

  Future<void> finishDesign(String componentId) async {
    await _api.postJson('/mes/components/$componentId/design/finish', {});
  }

  Future<void> planRoute(String componentId, List<Map<String, dynamic>> steps) async {
    await _api.putJson('/mes/components/$componentId/route', {'steps': steps});
  }

  Future<void> startRoute(String routeId) async {
    await _api.postJson('/mes/routes/$routeId/start', {});
  }

  Future<void> startSetup(String routeId) async {
    await _api.postJson('/mes/routes/$routeId/setup/start', {});
  }

  Future<void> pauseSetup(String runId, String observations) async {
    await _api.postJson('/mes/runs/$runId/setup/pause', {
      'observations': observations.isEmpty ? null : observations,
    });
  }

  Future<void> finishSetup(String routeId, String observations) async {
    await _api.postJson('/mes/routes/$routeId/setup/finish', {
      'observations': observations.isEmpty ? null : observations,
    });
  }

  Future<void> finishRun(String runId, int good, int rejected, String observations) async {
    await _api.postJson('/mes/runs/$runId/finish', {
      'good_quantity': good,
      'rejected_quantity': rejected,
      'observations': observations.isEmpty ? null : observations,
    });
  }

  Future<void> pauseRun(String runId, int good, int rejected, String observations) async {
    await _api.postJson('/mes/runs/$runId/pause', {
      'good_quantity': good,
      'rejected_quantity': rejected,
      'observations': observations.isEmpty ? null : observations,
    });
  }

  Future<void> issueWarehouse(Map<String, dynamic> payload) async {
    await _api.postJson('/mes/warehouse/issues', payload);
  }

  Future<void> saveQualityInspection(String componentId, Map<String, dynamic> payload) async {
    await _api.postJson('/mes/components/$componentId/quality/inspection', payload);
  }

  Future<void> skipQualityInspection(String componentId, Map<String, dynamic> payload) async {
    await _api.postJson('/mes/components/$componentId/quality/skip', payload);
  }
}
