import 'package:flutter/material.dart';

import '../../core/auth/session_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/intema_theme.dart';
import '../../shared/widgets/intema_logo.dart';
import 'mes_models.dart';
import 'mes_repository.dart';

import 'dart:io';

class MesPage extends StatefulWidget {
  const MesPage({super.key, required this.session, required this.initialTab});

  final SessionController session;
  final String initialTab;

  @override
  State<MesPage> createState() => _MesPageState();
}

class _MesPageState extends State<MesPage> {
  late final MesRepository _repository;
  var _loading = true;
  String? _error;
  String _query = '';
  String _stageFilter = 'all';
  String _boardTab = 'pending';
  String _warehouseTab = 'inventory';
  String _warehouseStockFilter = 'all';
  int _boardPage = 0;
  List<WorkOrderItem> _orders = [];
  List<MachineItem> _machines = [];

  @override
  void initState() {
    super.initState();
    _repository = MesRepository(widget.session.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await _repository.fetchWorkOrders();
      final machines =
          widget.session.can('production.view')
              ? await _repository.fetchMachines()
              : <MachineItem>[];
      setState(() {
        _orders = orders;
        _machines = machines;
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'No se pudo cargar el flujo MES.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      await _load();
      _message(success);
    } on ApiException catch (error) {
      _message(error.message, error: true);
    } catch (_) {
      _message('No se pudo completar la operación.', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : IntemaColors.navy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 30,
            compact ? 16 : 24,
            compact ? 16 : 26,
            14,
          ),
          child: compact ? _compactHeader() : _desktopHeader(),
        ),
        if (widget.initialTab == 'oit')
          _SearchAndFilterBar(
            orders: _orders,
            stageFilter: _stageFilter,
            onQueryChanged: (value) => setState(() {
              _query = value;
              _boardPage = 0;
            }),
            onStageChanged: (value) => setState(() {
              _stageFilter = value;
              _boardPage = 0;
            }),
          )
        else
          _SimpleSearchBar(
            onQueryChanged: (value) => setState(() {
              _query = value;
              _boardPage = 0;
            }),
          ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : _sectionBody(),
        ),
      ],
    );
  }

  Widget _sectionHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _sectionTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(_sectionSubtitle),
      ],
    );
  }

  List<Widget> _headerActions() {
    return [
      IconButton.filledTonal(
        tooltip: 'Actualizar',
        onPressed: _load,
        icon: const Icon(Icons.refresh),
      ),
      if (widget.initialTab == 'production' && widget.session.can('production.edit'))
        OutlinedButton.icon(
          onPressed: _manageMachines,
          icon: const Icon(Icons.precision_manufacturing_outlined),
          label: const Text('Máquinas'),
        ),
      if (widget.initialTab == 'warehouse' && widget.session.can('inventory_movements.create'))
        OutlinedButton.icon(
          onPressed: _createWarehouseItem,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Nuevo ítem'),
        ),
      if (widget.initialTab == 'warehouse' && widget.session.can('inventory_movements.create'))
        ElevatedButton.icon(
          onPressed: _registerWarehouseMovement,
          icon: const Icon(Icons.add),
          label: const Text('Registrar movimiento'),
        ),
      if (widget.initialTab == 'oit' && widget.session.can('work_orders.create'))
        ElevatedButton.icon(
          onPressed: _createWorkOrder,
          icon: const Icon(Icons.add),
          label: const Text('Nueva OIT'),
        ),
    ];
  }

  Widget _desktopHeader() {
    return Row(
      children: [
        Expanded(child: _sectionHeading()),
        Wrap(spacing: 8, runSpacing: 8, children: _headerActions()),
      ],
    );
  }

  Widget _compactHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: _headerActions(),
          ),
        ),
      ],
    );
  }

  String get _sectionTitle {
    switch (widget.initialTab) {
      case 'design':
        return 'Diseño';
      case 'production':
        return 'Producción';
      case 'warehouse':
        return 'Almacén';
      case 'quality':
        return 'Control de Calidad';
      default:
        return 'Órdenes de Trabajo';
    }
  }

  String get _sectionSubtitle {
    switch (widget.initialTab) {
      case 'design':
        return 'Componentes pendientes o en curso de diseño.';
      case 'production':
        return 'Planificación de ruta, máquinas y avance por componente.';
      case 'warehouse':
        return 'Entradas, salidas, kardex e inventario del almacén.';
      case 'quality':
        return 'OIT completas pendientes de inspección y liberación.';
      default:
        return 'Creación, aprobación y seguimiento general de OIT.';
    }
  }

  List<WorkOrderItem> get _sectionOrders {
    switch (widget.initialTab) {
      case 'design':
        return _orders.where(_hasDesign).toList();
      case 'production':
        return _orders.where(_hasProduction).toList();
      case 'warehouse':
        return _orders.where(_isActive).toList();
      case 'quality':
        return _orders
            .where((order) =>
                order.components.any((component) => component.status == 'pending_quality'))
            .toList();
      default:
        return _orders;
    }
  }

  Widget _sectionBody() {
    switch (widget.initialTab) {
      case 'design':
        return _componentBoard([
          _ComponentSection(
            value: 'pending',
            title: 'Pendientes de diseño',
            subtitle: 'Listos para iniciar',
            icon: Icons.pending_actions_outlined,
            filter: (component) => component.status == 'pending_design',
          ),
          _ComponentSection(
            value: 'in_process',
            title: 'Diseño en proceso',
            subtitle: 'En curso / pausados',
            icon: Icons.design_services_outlined,
            filter: (component) =>
                component.status == 'design_in_progress' ||
                component.status == 'design_paused',
          ),
          _ComponentSection(
            value: 'finished',
            title: 'Diseño finalizado',
            subtitle: 'Enviado a producción',
            icon: Icons.check_circle_outline,
            filter: (component) => {
                  'pending_production',
                  'production_planned',
                  'production_in_progress',
                  'pending_quality',
                  'finished',
                }.contains(component.status),
          ),
        ]);
      case 'production':
        return _componentBoard([
          _ComponentSection(
            value: 'pending',
            title: 'Pendientes de producción',
            subtitle: 'Por planificar o iniciar',
            icon: Icons.pending_actions_outlined,
            filter: (component) =>
                component.status == 'pending_production' ||
                component.status == 'production_planned',
          ),
          _ComponentSection(
            value: 'in_process',
            title: 'Producción en curso',
            subtitle: 'Con trabajo activo',
            icon: Icons.precision_manufacturing_outlined,
            filter: (component) => component.status == 'production_in_progress',
          ),
          _ComponentSection(
            value: 'finished',
            title: 'Producción finalizada',
            subtitle: 'En calidad / terminado',
            icon: Icons.check_circle_outline,
            filter: (component) =>
                component.status == 'pending_quality' || component.status == 'finished',
          ),
        ]);
      case 'quality':
        return _componentBoard([
          _ComponentSection(
            value: 'pending',
            title: 'Pendientes de control de calidad',
            subtitle: 'Por inspeccionar',
            icon: Icons.pending_actions_outlined,
            filter: (component) => component.status == 'pending_quality',
          ),
          _ComponentSection(
            value: 'finished',
            title: 'Control de calidad finalizado',
            subtitle: 'Aprobado u omitido',
            icon: Icons.check_circle_outline,
            filter: (component) => component.status == 'finished',
            orderFilter: (order) =>
                order.components.isNotEmpty &&
                order.components.every((component) => component.status == 'finished'),
          ),
        ]);
      case 'warehouse':
        return _warehouseBoard();
      default:
        return _ordersBoard();
    }
  }

  Widget _warehouseBoard() {
    final query = _query.trim().toLowerCase();
    final issues = [
      for (final order in _orders)
        for (final issue in order.warehouseIssues) (order: order, issue: issue),
    ].where((entry) {
      if (query.isEmpty) return true;
      return entry.issue.itemName.toLowerCase().contains(query) ||
          entry.order.code.toLowerCase().contains(query) ||
          entry.order.clientName.toLowerCase().contains(query) ||
          _warehouseIssueTypeLabel(entry.issue.issueType).toLowerCase().contains(query);
    }).toList();
    final inventory = _warehouseInventoryRows(issues);
    final filteredInventory = _filteredWarehouseInventory(inventory);
    final selectedItemsCount = _warehouseTab == 'kardex' ? issues.length : filteredInventory.length;
    final pageSize = 10;
    final pageCount =
        selectedItemsCount == 0 ? 1 : ((selectedItemsCount - 1) ~/ pageSize) + 1;
    final currentPage = _boardPage.clamp(0, pageCount - 1).toInt();
    final pageIssues = issues.skip(currentPage * pageSize).take(pageSize).toList();
    final pageInventory = filteredInventory.skip(currentPage * pageSize).take(pageSize).toList();

    final table = _warehouseTab == 'kardex'
        ? _WarehouseMovementsTable(entries: pageIssues)
        : _WarehouseInventoryTable(records: pageInventory);

    final emptyText = _warehouseEmptyText(_warehouseTab);
    final content = selectedItemsCount == 0
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
            child: Text(emptyText),
          )
        : table;
    final tabs = [
      (
        value: 'kardex',
        title: 'Movimientos',
        subtitle: 'Entrada / salida',
        icon: Icons.receipt_long_outlined,
        count: issues.length,
      ),
      (
        value: 'inventory',
        title: 'Inventario',
        subtitle: 'Kardex / stock',
        icon: Icons.inventory_2_outlined,
        count: inventory.length,
      ),
    ];
    final selected = tabs.any((tab) => tab.value == _warehouseTab)
        ? tabs.firstWhere((tab) => tab.value == _warehouseTab)
        : tabs.last;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WarehouseBoardTabs(
            selectedValue: selected.value,
            tabs: tabs,
            stockFilter: _warehouseStockFilter,
            lowStockCount: inventory.where(_isLowStockRecord).length,
            noStockCount: inventory.where(_isNoStockRecord).length,
            onSelected: (value) => setState(() {
              _warehouseTab = value;
              _boardPage = 0;
            }),
            onStockFilterSelected: (value) => setState(() {
              _warehouseTab = 'inventory';
              _warehouseStockFilter = value;
              _boardPage = 0;
            }),
          ),
          const SizedBox(height: 16),
          _StageHeader(
            title: _warehouseTabTitle(selected.value),
            count: selectedItemsCount,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _PagedWorkSurface(
              currentPage: currentPage,
              pageCount: pageCount,
              total: selectedItemsCount,
              pageSize: pageSize,
              onPrevious: currentPage == 0
                  ? null
                  : () => setState(() => _boardPage = currentPage - 1),
              onNext: currentPage >= pageCount - 1
                  ? null
                  : () => setState(() => _boardPage = currentPage + 1),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  List<
      ({
        String itemName,
        String type,
        double quantity,
        String unit,
        double unitCost,
        double totalCost,
        String lastOrder,
        int movements,
      })> _warehouseInventoryRows(
    List<({WorkOrderItem order, WarehouseIssueItem issue})> issues,
  ) {
    final grouped = <String, List<({WorkOrderItem order, WarehouseIssueItem issue})>>{};
    for (final entry in issues) {
      final family = _warehouseIssueTypeLabel(entry.issue.issueType);
      final description = entry.issue.itemName.trim().isEmpty
          ? 'Ítem sin nombre'
          : entry.issue.itemName.trim();
      final key = '$family|$description';
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    final rows = grouped.entries.map((entry) {
      final rows = entry.value;
      final quantity = rows.fold<double>(0, (sum, row) => sum + row.issue.quantity);
      final totalCost = rows.fold<double>(0, (sum, row) => sum + row.issue.totalCost);
      final unit = rows.isEmpty ? '-' : rows.first.issue.unit;
      final lastOrder = rows.isEmpty ? '-' : rows.last.order.code;
      final type = rows.isEmpty ? '-' : _warehouseIssueTypeLabel(rows.last.issue.issueType);
      final unitCost = rows.isEmpty ? 0.0 : rows.last.issue.unitCost;
      final itemName = entry.key.contains('|') ? entry.key.split('|').skip(1).join('|') : entry.key;
      return (
        itemName: itemName,
        type: type,
        quantity: quantity,
        unit: unit,
        unitCost: unitCost,
        totalCost: totalCost,
        lastOrder: lastOrder,
        movements: rows.length,
      );
    }).toList()
      ..sort((a, b) {
        final byFamily = a.type.compareTo(b.type);
        return byFamily != 0 ? byFamily : a.itemName.compareTo(b.itemName);
      });
    return rows;
  }

  List<
      ({
        String itemName,
        String type,
        double quantity,
        String unit,
        double unitCost,
        double totalCost,
        String lastOrder,
        int movements,
      })> _filteredWarehouseInventory(
    List<
        ({
          String itemName,
          String type,
          double quantity,
          String unit,
          double unitCost,
          double totalCost,
          String lastOrder,
          int movements,
        })> inventory,
  ) {
    switch (_warehouseStockFilter) {
      case 'low':
        return inventory.where(_isLowStockRecord).toList();
      case 'none':
        return inventory.where(_isNoStockRecord).toList();
      default:
        return inventory;
    }
  }

  bool _isLowStockRecord(
    ({
      String itemName,
      String type,
      double quantity,
      String unit,
      double unitCost,
      double totalCost,
      String lastOrder,
      int movements,
    }) record,
  ) {
    return record.quantity > 0 && record.quantity <= 2;
  }

  bool _isNoStockRecord(
    ({
      String itemName,
      String type,
      double quantity,
      String unit,
      double unitCost,
      double totalCost,
      String lastOrder,
      int movements,
    }) record,
  ) {
    return record.quantity <= 0;
  }

  Widget _ordersBoard() {
    final visibleOrders = _filteredOrders(_sectionOrders);
    const pageSize = 10;
    final pageCount = visibleOrders.isEmpty ? 1 : ((visibleOrders.length - 1) ~/ pageSize) + 1;
    final currentPage = _boardPage.clamp(0, pageCount - 1).toInt();
    final pageItems = visibleOrders.skip(currentPage * pageSize).take(pageSize).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StageHeader(
            title: _oitStageTitle(_stageFilter),
            count: visibleOrders.length,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _PagedWorkSurface(
              currentPage: currentPage,
              pageCount: pageCount,
              total: visibleOrders.length,
              pageSize: pageSize,
              onPrevious: currentPage == 0
                  ? null
                  : () => setState(() => _boardPage = currentPage - 1),
              onNext: currentPage >= pageCount - 1
                  ? null
                  : () => setState(() => _boardPage = currentPage + 1),
              child: visibleOrders.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
                      child: Text('No hay OIT en "${_oitStageTitle(_stageFilter)}".'),
                    )
                  : Column(
                      children: pageItems
                          .map(
                            (order) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _workOrderCard(order),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupedOrdersList(List<_ComponentSection> sections) {
    final source = _filteredOrders(_orders);
    final visibleSections = sections
        .map(
          (section) => (
            section: section,
            orders: source
                .where((order) => _sectionComponents(order, section).isNotEmpty)
                .toList(),
          ),
        )
        .where((entry) => entry.orders.isNotEmpty)
        .toList();

    if (visibleSections.isEmpty) {
      return const Center(child: Text('No hay componentes en esta etapa.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final entry in visibleSections) ...[
          _StageHeader(
            title: entry.section.title,
            count: entry.orders.fold<int>(
              0,
              (total, order) =>
                  total + _sectionComponents(order, entry.section).length,
            ),
          ),
          const SizedBox(height: 10),
          ...entry.orders.map(
            (order) => Column(
              children: _sectionComponents(order, entry.section)
                  .map(
                    (component) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _componentWorkCard(order, component),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _componentBoard(List<_ComponentSection> sections) {
    final source = _filteredOrders(_orders);
    final counts = {
      for (final section in sections)
        section.value: source.fold<int>(
          0,
          (total, order) => total + _sectionComponents(order, section).length,
        ),
    };
    final selected = sections.any((section) => section.value == _boardTab)
        ? sections.firstWhere((section) => section.value == _boardTab)
        : sections.first;
    final visibleItems = <_ComponentBoardItem>[
      for (final order in source)
        for (final component in _sectionComponents(order, selected))
          _ComponentBoardItem(order: order, component: component),
    ];
    const pageSize = 10;
    final pageCount = visibleItems.isEmpty ? 1 : ((visibleItems.length - 1) ~/ pageSize) + 1;
    final currentPage = _boardPage.clamp(0, pageCount - 1).toInt();
    final pageItems = visibleItems.skip(currentPage * pageSize).take(pageSize).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WorkflowBoardTabs(
            sections: sections,
            selectedValue: selected.value,
            counts: counts,
            onSelected: (value) => setState(() {
              _boardTab = value;
              _boardPage = 0;
            }),
          ),
          const SizedBox(height: 16),
          _StageHeader(title: selected.title, count: visibleItems.length),
          const SizedBox(height: 10),
          Expanded(
            child: _PagedWorkSurface(
              currentPage: currentPage,
              pageCount: pageCount,
              total: visibleItems.length,
              pageSize: pageSize,
              onPrevious: currentPage == 0
                  ? null
                  : () => setState(() => _boardPage = currentPage - 1),
              onNext: currentPage >= pageCount - 1
                  ? null
                  : () => setState(() => _boardPage = currentPage + 1),
              child: visibleItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
                      child: Text('No hay componentes en "${selected.title}".'),
                    )
                  : Column(
                      children: pageItems
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _componentWorkCard(item.order, item.component),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<WorkOrderComponentItem> _sectionComponents(
    WorkOrderItem order,
    _ComponentSection section,
  ) {
    if (section.orderFilter != null && !section.orderFilter!(order)) {
      return const [];
    }
    return order.components.where(section.filter).toList();
  }

  Widget _ordersList(
    List<WorkOrderItem> orders, {
    bool Function(WorkOrderComponentItem component)? componentFilter,
  }) {
    final filtered = _filteredOrders(orders);
    if (filtered.isEmpty) return const Center(child: Text('No hay OIT en esta etapa.'));
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _workOrderCard(filtered[index], componentFilter: componentFilter),
    );
  }

  List<WorkOrderItem> _filteredOrders(List<WorkOrderItem> orders) {
    final query = _query.trim().toLowerCase();
    return orders.where((order) {
      final matchesQuery = query.isEmpty ||
          order.code.toLowerCase().contains(query) ||
          order.clientName.toLowerCase().contains(query) ||
          order.components.any((component) => component.name.toLowerCase().contains(query));
      final matchesStage =
          widget.initialTab == 'oit' ? _matchesStageFilter(order, _stageFilter) : true;
      return matchesQuery && matchesStage;
    }).toList();
  }

  Widget _workOrderCard(
    WorkOrderItem order, {
    bool Function(WorkOrderComponentItem component)? componentFilter,
  }) {
    return _WorkOrderCard(
      order: order,
      componentFilter: componentFilter,
      session: widget.session,
      onApprove: (order) => _run(() => _repository.approveWorkOrder(order.id), 'OIT aprobada y enviada a diseño.'),
      onDeliver: (order) => _run(() => _repository.deliverWorkOrder(order.id), 'OIT entregada.'),
      onEdit: _editWorkOrder,
      onDelete: _deleteWorkOrder,
      onStartDesign: (component) => _run(() => _repository.startDesign(component.id), 'Diseño iniciado.'),
      onPauseDesign: _pauseDesign,
      onFinishDesign: (component) => _run(() => _repository.finishDesign(component.id), 'Diseño finalizado.'),
      onPlanRoute: _planRoute,
      onStartRoute: (route) => _run(() => _repository.startRoute(route.id), 'Proceso iniciado.'),
      onStartSetup: (route) => _run(() => _repository.startSetup(route.id), 'Preparación iniciada.'),
      onPauseSetup: _pauseSetup,
      onFinishSetup: _finishSetup,
      onPauseRun: (route, requiredQuantity) => _pauseRun(route, requiredQuantity),
      onFinishRun: (route, requiredQuantity) => _finishRun(route, requiredQuantity),
      onWarehouseIssue: _issueWarehouse,
    );
  }

  Widget _componentWorkCard(WorkOrderItem order, WorkOrderComponentItem component) {
    final areaStatus = _areaStatusFor(widget.initialTab, component);
    final areaProgress = _areaProgressFor(widget.initialTab, component);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  component.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                _StatusChip(status: areaStatus),
                Text(order.code),
                Text(order.clientName),
                if (order.dueDate != null)
                  Text('Entrega: ${_formatDate(order.dueDate!)}'),
              ],
            ),
            const SizedBox(height: 10),
            _ProgressLine(
              value: areaProgress,
              label: widget.initialTab == 'production' ? 'Avance producción' : 'Avance',
            ),
            if (widget.initialTab == 'quality') ...[
              const SizedBox(height: 12),
              _QualityActions(
                component: component,
                canEdit: widget.session.can('quality_control.edit'),
                onInspect: () => _qualityInspection(order, component),
                onSkip: () => _skipQualityInspection(component),
              ),
            ] else ...[
              const SizedBox(height: 10),
              _ComponentPanel(
                component: component,
                session: widget.session,
                area: widget.initialTab,
                displayStatus: areaStatus,
                onStartDesign: (component) =>
                    _run(() => _repository.startDesign(component.id), 'Diseño iniciado.'),
                onPauseDesign: _pauseDesign,
                onFinishDesign: (component) =>
                    _run(() => _repository.finishDesign(component.id), 'Diseño finalizado.'),
                onPlanRoute: _planRoute,
                onStartRoute: (route) =>
                    _run(() => _repository.startRoute(route.id), 'Proceso iniciado.'),
                onStartSetup: (route) =>
                    _run(() => _repository.startSetup(route.id), 'Preparación iniciada.'),
                onPauseSetup: _pauseSetup,
                onFinishSetup: _finishSetup,
                onPauseRun: (route, requiredQuantity) => _pauseRun(route, requiredQuantity),
                onFinishRun: (route, requiredQuantity) => _finishRun(route, requiredQuantity),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createWorkOrder() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _OitDialog(),
    );
    if (payload == null) return;
    await _run(() => _repository.createWorkOrder(payload), 'OIT creada.');
  }

  Future<void> _editWorkOrder(WorkOrderItem order) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OitDialog(order: order),
    );
    if (payload == null) return;
    await _run(() => _repository.updateWorkOrder(order.id, payload), 'OIT actualizada.');
  }

  Future<void> _deleteWorkOrder(WorkOrderItem order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${order.code}'),
        content: const Text('Esta acción solo está permitida antes de aprobar la OIT. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _repository.deleteWorkOrder(order.id), 'OIT eliminada.');
  }

  Future<void> _planRoute(WorkOrderComponentItem component) async {
    final steps = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => _PlanRouteDialog(
        component: component,
        machines: _machines,
      ),
    );
    if (steps == null) return;
    await _run(() => _repository.planRoute(component.id, steps), 'Ruta de producción planificada.');
  }

  Future<void> _manageMachines() async {
    final updated = await showDialog<List<MachineItem>>(
      context: context,
      builder: (_) => _MachineAdminDialog(
        machines: _machines,
        onCreateMachine: _createMachine,
        onUpdateMachine: _updateMachine,
        onDeleteMachine: _deleteMachine,
      ),
    );
    if (updated == null) return;
    setState(() => _machines = updated);
  }

  Future<MachineItem> _createMachine(Map<String, dynamic> payload) async {
    final machine = await _repository.createMachine(payload);
    setState(() {
      _machines = [
        ..._machines.where((item) => item.id != machine.id),
        machine,
      ]..sort((a, b) => a.name.compareTo(b.name));
    });
    return machine;
  }

  Future<MachineItem> _updateMachine(MachineItem machine, Map<String, dynamic> payload) async {
    final updated = await _repository.updateMachine(machine.id, payload);
    setState(() {
      _machines = _machines
          .map((item) => item.id == updated.id ? updated : item)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
    return updated;
  }

  Future<void> _deleteMachine(MachineItem machine) async {
    await _repository.deleteMachine(machine.id);
    setState(() {
      _machines = _machines.where((item) => item.id != machine.id).toList();
    });
  }

  Future<void> _pauseSetup(RouteStepItem route) async {
    final run = route.runningSetupRun;
    if (run == null) return;
    final observations = await showDialog<String>(
      context: context,
      builder: (_) => const _ObservationDialog(title: 'Pausar preparación'),
    );
    if (observations == null) return;
    await _run(() => _repository.pauseSetup(run.id, observations), 'Preparación pausada.');
  }

  Future<void> _finishSetup(RouteStepItem route) async {
    final observations = await showDialog<String>(
      context: context,
      builder: (_) => const _ObservationDialog(title: 'Finalizar preparación'),
    );
    if (observations == null) return;
    await _run(() => _repository.finishSetup(route.id, observations), 'Preparación finalizada.');
  }

  Future<void> _pauseDesign(WorkOrderComponentItem component) async {
    final observations = await showDialog<String>(
      context: context,
      builder: (_) => const _ObservationDialog(title: 'Pausar diseño'),
    );
    if (observations == null) return;
    await _run(() => _repository.pauseDesign(component.id, observations), 'Diseño pausado.');
  }

  Future<void> _finishRun(RouteStepItem route, [int requiredQuantity = 0]) async {
    final run = route.runningRun;
    if (run == null) return;
    final remaining = _remainingRouteQuantity(route, requiredQuantity);
    if (requiredQuantity > 0 && remaining <= 0) {
      _message('Este proceso ya no tiene piezas pendientes.', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terminar ${route.machine.name}'),
        content: Text(
          remaining > 0
              ? 'Se completarán las $remaining piezas restantes de este proceso.'
              : 'Se marcará este proceso como terminado.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.task_alt),
            label: const Text('Terminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => _repository.finishRun(run.id, remaining, 0, ''),
      'Producción registrada.',
    );
  }

  Future<void> _pauseRun(RouteStepItem route, [int requiredQuantity = 0]) async {
    final run = route.runningRun;
    if (run == null) return;
    final remaining = _remainingRouteQuantity(route, requiredQuantity);
    if (requiredQuantity > 0 && remaining <= 0) {
      _message('Este proceso ya no tiene piezas pendientes.', error: true);
      return;
    }
    final payload = await showDialog<_QuantityResult>(
      context: context,
      builder: (_) => _QuantityDialog(
        title: 'Pausar ${route.machine.name}',
        maxQuantity: remaining,
      ),
    );
    if (payload == null) return;
    if (requiredQuantity > 0 && payload.good == remaining) {
      final finish = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Completa el proceso'),
          content: const Text('Con esa cantidad completas todas las piezas. Corresponde terminar el proceso.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.task_alt),
              label: const Text('Terminar'),
            ),
          ],
        ),
      );
      if (finish != true) return;
      await _run(
        () => _repository.finishRun(run.id, payload.good, payload.rejected, payload.observations),
        'Producción registrada.',
      );
      return;
    }
    await _run(
      () => _repository.pauseRun(run.id, payload.good, payload.rejected, payload.observations),
      'Producción pausada.',
    );
  }

  Future<void> _issueWarehouse(WorkOrderItem order) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _WarehouseIssueDialog(order: order),
    );
    if (payload == null) return;
    await _run(() => _repository.issueWarehouse(payload), 'Entrega de almacén registrada.');
  }

  Future<void> _registerWarehouseMovement() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _WarehouseMovementDialog(
        activeOrders: _orders.where(_isActive).toList(),
      ),
    );
    if (payload == null) return;
    final movementType = payload.remove('movement_type');
    if (movementType == 'entry') {
      _message('Entrada preparada. Falta conectar inventario maestro para guardar stock real.');
      return;
    }
    await _run(() => _repository.issueWarehouse(payload), 'Salida de almacén registrada.');
  }

  Future<void> _createWarehouseItem() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _WarehouseItemDialog(),
    );
    if (payload == null) return;
    _message('Ítem preparado. Falta conectar el catálogo maestro para guardarlo.');
  }

  Future<void> _qualityInspection(WorkOrderItem order, WorkOrderComponentItem component) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _QualityInspectionDialog(order: order, component: component),
    );
    if (payload == null) return;
    await _run(
      () => _repository.saveQualityInspection(component.id, payload),
      'Inspección de calidad guardada.',
    );
  }

  Future<void> _skipQualityInspection(WorkOrderComponentItem component) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SkipQualityDialog(component: component),
    );
    if (payload == null) return;
    await _run(
      () => _repository.skipQualityInspection(component.id, payload),
      'Control de calidad omitido con trazabilidad.',
    );
  }
}

class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.orders,
    required this.stageFilter,
    required this.onQueryChanged,
    required this.onStageChanged,
  });

  final List<WorkOrderItem> orders;
  final String stageFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStageChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 26, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Flujo de trabajo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 360,
                child: TextField(
                  onChanged: onQueryChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar OIT, cliente o componente',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: _StageSummaryCard(
                        value: 'all',
                        selectedValue: stageFilter,
                        icon: Icons.assignment_outlined,
                        title: 'OIT',
                        count: orders.length,
                        subtitle: 'Registradas',
                        onSelected: onStageChanged,
                      ),
                    ),
                    const _FlowArrow(),
                    SizedBox(
                      width: 170,
                      child: _StageSummaryCard(
                        value: 'design',
                        selectedValue: stageFilter,
                        icon: Icons.design_services_outlined,
                        title: 'Diseño',
                        count: orders.where(_hasDesign).length,
                        subtitle: 'Pendientes / en curso',
                        onSelected: onStageChanged,
                      ),
                    ),
                    const _FlowArrow(),
                    SizedBox(
                      width: 180,
                      child: _StageSummaryCard(
                        value: 'production',
                        selectedValue: stageFilter,
                        icon: Icons.precision_manufacturing_outlined,
                        title: 'Producción',
                        count: orders.where(_hasProduction).length,
                        subtitle: 'Planificación / avance',
                        onSelected: onStageChanged,
                      ),
                    ),
                    const _FlowArrow(),
                    SizedBox(
                      width: 160,
                      child: _StageSummaryCard(
                        value: 'quality',
                        selectedValue: stageFilter,
                        icon: Icons.fact_check_outlined,
                        title: 'Calidad',
                        count: orders
                            .where((order) => order.components
                                .any((component) => component.status == 'pending_quality'))
                            .length,
                        subtitle: 'En inspección',
                        onSelected: onStageChanged,
                      ),
                    ),
                    const _FlowArrow(),
                    SizedBox(
                      width: 160,
                      child: _StageSummaryCard(
                        value: 'finished',
                        selectedValue: stageFilter,
                        icon: Icons.local_shipping_outlined,
                        title: 'Entregado',
                        count: orders.where((order) => order.status == 'finished').length,
                        subtitle: 'Cerradas',
                        onSelected: onStageChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleSearchBar extends StatelessWidget {
  const _SimpleSearchBar({required this.onQueryChanged});

  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 26, 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 420,
          child: TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar OIT, cliente o componente',
            ),
          ),
        ),
      ),
    );
  }
}

class _StageSummaryCard extends StatelessWidget {
  const _StageSummaryCard({
    required this.value,
    required this.selectedValue,
    required this.icon,
    required this.title,
    required this.count,
    required this.subtitle,
    required this.onSelected,
  });

  final String value;
  final String selectedValue;
  final IconData icon;
  final String title;
  final int count;
  final String subtitle;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 112,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6FAFF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? IntemaColors.navy : IntemaColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: IntemaColors.navy.withOpacity(0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: IntemaColors.navy, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, height: 1.15),
                  ),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: IntemaColors.navy,
                          height: 1.05,
                        ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Icon(Icons.arrow_forward, color: Color(0xFFB8C0CC)),
    );
  }
}

class _WorkOrderCard extends StatefulWidget {
  const _WorkOrderCard({
    required this.order,
    required this.componentFilter,
    required this.session,
    required this.onApprove,
    required this.onDeliver,
    required this.onEdit,
    required this.onDelete,
    required this.onStartDesign,
    required this.onPauseDesign,
    required this.onFinishDesign,
    required this.onPlanRoute,
    required this.onStartRoute,
    required this.onStartSetup,
    required this.onPauseSetup,
    required this.onFinishSetup,
    required this.onPauseRun,
    required this.onFinishRun,
    required this.onWarehouseIssue,
  });

  final WorkOrderItem order;
  final bool Function(WorkOrderComponentItem component)? componentFilter;
  final SessionController session;
  final ValueChanged<WorkOrderItem> onApprove;
  final ValueChanged<WorkOrderItem> onDeliver;
  final ValueChanged<WorkOrderItem> onEdit;
  final ValueChanged<WorkOrderItem> onDelete;
  final ValueChanged<WorkOrderComponentItem> onStartDesign;
  final ValueChanged<WorkOrderComponentItem> onPauseDesign;
  final ValueChanged<WorkOrderComponentItem> onFinishDesign;
  final ValueChanged<WorkOrderComponentItem> onPlanRoute;
  final ValueChanged<RouteStepItem> onStartRoute;
  final ValueChanged<RouteStepItem> onStartSetup;
  final ValueChanged<RouteStepItem> onPauseSetup;
  final ValueChanged<RouteStepItem> onFinishSetup;
  final void Function(RouteStepItem route, int requiredQuantity) onPauseRun;
  final void Function(RouteStepItem route, int requiredQuantity) onFinishRun;
  final ValueChanged<WorkOrderItem> onWarehouseIssue;

  @override
  State<_WorkOrderCard> createState() => _WorkOrderCardState();
}

class _WorkOrderCardState extends State<_WorkOrderCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final filter = widget.componentFilter;
    final visibleComponents = filter == null
        ? order.components
        : order.components.where(filter).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(order.code, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                if (order.status == 'finished')
                  _DueStatusChip(order: order)
                else ...[
                  _StatusChip(status: order.status),
                  _DueStatusChip(order: order),
                ],
                Text(order.clientName),
                if (order.dueDate != null)
                  Text('Entrega: ${_formatDate(order.dueDate!)}'),
                Text('Almacén: S/ ${order.warehouseCost.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            _ProgressLine(value: _orderProgress(order), label: 'Avance general'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (visibleComponents.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    label: Text(
                      _expanded
                          ? 'Ocultar componentes'
                          : 'Ver componentes (${visibleComponents.length})',
                    ),
                  ),
                if (order.status == 'draft' && widget.session.can('work_orders.approve'))
                  ElevatedButton.icon(
                    onPressed: () => widget.onApprove(order),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aprobar OIT'),
                  ),
                if (_canDeliver(order) && widget.session.can('work_orders.edit'))
                  ElevatedButton.icon(
                    onPressed: () => widget.onDeliver(order),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Entregar'),
                  ),
                if (order.status == 'draft' && widget.session.can('work_orders.edit'))
                  OutlinedButton.icon(
                    onPressed: () => widget.onEdit(order),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                if (order.status == 'draft' && widget.session.can('work_orders.delete'))
                  OutlinedButton.icon(
                    onPressed: () => widget.onDelete(order),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
                if (_isActive(order) && widget.session.can('inventory_movements.create'))
                  OutlinedButton.icon(
                    onPressed: () => widget.onWarehouseIssue(order),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Entregar almacén'),
                  ),
              ],
            ),
            if (_expanded) ...[
              const Divider(height: 24),
              ...visibleComponents.map(
                (component) => _ComponentPanel(
                  component: component,
                  session: widget.session,
                  area: 'oit',
                  displayStatus: component.status,
                  onStartDesign: widget.onStartDesign,
                  onPauseDesign: widget.onPauseDesign,
                  onFinishDesign: widget.onFinishDesign,
                  onPlanRoute: widget.onPlanRoute,
                  onStartRoute: widget.onStartRoute,
                  onStartSetup: widget.onStartSetup,
                  onPauseSetup: widget.onPauseSetup,
                  onFinishSetup: widget.onFinishSetup,
                  onPauseRun: widget.onPauseRun,
                  onFinishRun: widget.onFinishRun,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComponentSection {
  const _ComponentSection({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.filter,
    this.orderFilter,
  });

  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool Function(WorkOrderComponentItem component) filter;
  final bool Function(WorkOrderItem order)? orderFilter;
}

class _ComponentBoardItem {
  const _ComponentBoardItem({required this.order, required this.component});

  final WorkOrderItem order;
  final WorkOrderComponentItem component;
}

class _WorkflowBoardTabs extends StatelessWidget {
  const _WorkflowBoardTabs({
    required this.sections,
    required this.selectedValue,
    required this.counts,
    required this.onSelected,
  });

  final List<_ComponentSection> sections;
  final String selectedValue;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final subtitle = sections.any((section) => section.value == 'in_process')
        ? 'Separa pendientes, trabajo en proceso y finalizados para no saturar la pantalla.'
        : 'Separa pendientes y finalizados para no saturar la pantalla.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tablero operativo',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < sections.length; index++) ...[
                    SizedBox(
                      width: 220,
                      child: _StageSummaryCard(
                        value: sections[index].value,
                        selectedValue: selectedValue,
                        icon: sections[index].icon,
                        title: sections[index].title,
                        count: counts[sections[index].value] ?? 0,
                        subtitle: sections[index].subtitle,
                        onSelected: onSelected,
                      ),
                    ),
                    if (index != sections.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseBoardTabs extends StatelessWidget {
  const _WarehouseBoardTabs({
    required this.tabs,
    required this.selectedValue,
    required this.stockFilter,
    required this.lowStockCount,
    required this.noStockCount,
    required this.onSelected,
    required this.onStockFilterSelected,
  });

  final List<({String value, String title, String subtitle, IconData icon, int count})> tabs;
  final String selectedValue;
  final String stockFilter;
  final int lowStockCount;
  final int noStockCount;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onStockFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tablero operativo de almacén',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Organiza movimientos e inventario en tablas separadas. Los filtros aplican al stock.',
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in tabs) ...[
                    SizedBox(
                      width: 220,
                      child: _StageSummaryCard(
                        value: tab.value,
                        selectedValue: selectedValue,
                        icon: tab.icon,
                        title: tab.title,
                        count: tab.count,
                        subtitle: tab.subtitle,
                        onSelected: onSelected,
                      ),
                    ),
                    if (tab != tabs.last) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
            if (selectedValue == 'inventory') ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _WarehouseStockFilterChip(
                    value: 'all',
                    selectedValue: stockFilter,
                    icon: Icons.inventory_2_outlined,
                    label: 'Todo inventario',
                    count: tabs.firstWhere((tab) => tab.value == 'inventory').count,
                    onSelected: onStockFilterSelected,
                  ),
                  _WarehouseStockFilterChip(
                    value: 'low',
                    selectedValue: stockFilter,
                    icon: Icons.warning_amber_outlined,
                    label: 'Stock bajo',
                    count: lowStockCount,
                    onSelected: onStockFilterSelected,
                  ),
                  _WarehouseStockFilterChip(
                    value: 'none',
                    selectedValue: stockFilter,
                    icon: Icons.error_outline,
                    label: 'Sin stock',
                    count: noStockCount,
                    onSelected: onStockFilterSelected,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WarehouseStockFilterChip extends StatelessWidget {
  const _WarehouseStockFilterChip({
    required this.value,
    required this.selectedValue,
    required this.icon,
    required this.label,
    required this.count,
    required this.onSelected,
  });

  final String value;
  final String selectedValue;
  final IconData icon;
  final String label;
  final int count;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;
    final color = value == 'none'
        ? const Color(0xFFB42318)
        : value == 'low'
            ? const Color(0xFFB54708)
            : IntemaColors.navy;
    return OutlinedButton.icon(
      onPressed: () => onSelected(value),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: selected ? color.withOpacity(0.10) : Colors.white,
        side: BorderSide(color: selected ? color : IntemaColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text('$label ($count)'),
    );
  }
}

class _PagedWorkSurface extends StatelessWidget {
  const _PagedWorkSurface({
    required this.currentPage,
    required this.pageCount,
    required this.total,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final int currentPage;
  final int pageCount;
  final int total;
  final int pageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : (currentPage * pageSize) + 1;
    final to = total == 0
        ? 0
        : ((currentPage + 1) * pageSize).clamp(0, total).toInt();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    total == 0
                        ? 'Sin trabajos en esta hoja'
                        : 'Mostrando $from-$to de $total trabajos',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Página anterior',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${currentPage + 1}/$pageCount'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFFE9EEF7),
                  side: const BorderSide(color: IntemaColors.border),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Página siguiente',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 8),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(width: 10),
        Chip(
          label: Text('$count'),
          visualDensity: VisualDensity.compact,
          backgroundColor: const Color(0xFFE9EEF7),
          side: const BorderSide(color: IntemaColors.border),
        ),
      ],
    );
  }
}

class _ComponentPanel extends StatelessWidget {
  const _ComponentPanel({
    required this.component,
    required this.session,
    this.showRoute = true,
    required this.area,
    required this.displayStatus,
    required this.onStartDesign,
    required this.onPauseDesign,
    required this.onFinishDesign,
    required this.onPlanRoute,
    required this.onStartRoute,
    required this.onStartSetup,
    required this.onPauseSetup,
    required this.onFinishSetup,
    required this.onPauseRun,
    required this.onFinishRun,
  });

  final WorkOrderComponentItem component;
  final SessionController session;
  final bool showRoute;
  final String area;
  final String displayStatus;
  final ValueChanged<WorkOrderComponentItem> onStartDesign;
  final ValueChanged<WorkOrderComponentItem> onPauseDesign;
  final ValueChanged<WorkOrderComponentItem> onFinishDesign;
  final ValueChanged<WorkOrderComponentItem> onPlanRoute;
  final ValueChanged<RouteStepItem> onStartRoute;
  final ValueChanged<RouteStepItem> onStartSetup;
  final ValueChanged<RouteStepItem> onPauseSetup;
  final ValueChanged<RouteStepItem> onFinishSetup;
  final void Function(RouteStepItem route, int requiredQuantity) onPauseRun;
  final void Function(RouteStepItem route, int requiredQuantity) onFinishRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        border: Border.all(color: IntemaColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(component.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              _StatusChip(status: displayStatus),
              Text('${component.quantityCompleted}/${component.quantityRequired} piezas'),
              if (area == 'design') Text('Diseño: ${_designElapsedLabel(component)}'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (area == 'design' &&
                  {'pending_design', 'design_paused'}.contains(component.status) &&
                  session.can('design.edit'))
                OutlinedButton.icon(
                  onPressed: () => onStartDesign(component),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(component.status == 'design_paused' ? 'Reanudar diseño' : 'Iniciar diseño'),
                ),
              if (area == 'design' &&
                  component.status == 'design_in_progress' &&
                  session.can('design.edit'))
                OutlinedButton.icon(
                  onPressed: () => onPauseDesign(component),
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Pausar diseño'),
                ),
              if (area == 'design' &&
                  component.status == 'design_in_progress' &&
                  session.can('design.edit'))
                ElevatedButton.icon(
                  onPressed: () => onFinishDesign(component),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Terminar diseño'),
                ),
              if (area == 'production' &&
                  {'pending_production', 'production_planned', 'production_in_progress'}.contains(component.status) &&
                  session.can('production.edit'))
                OutlinedButton.icon(
                  onPressed: () => onPlanRoute(component),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Planificar ruta'),
                ),
            ],
          ),
          if (area == 'production' && showRoute && component.routes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _RouteList(
              routes: component.routes,
              requiredQuantity: component.quantityRequired,
              canOperate: session.can('production.operate'),
              onStartRoute: onStartRoute,
              onStartSetup: onStartSetup,
              onPauseSetup: onPauseSetup,
              onFinishSetup: onFinishSetup,
              onPauseRun: onPauseRun,
              onFinishRun: onFinishRun,
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteList extends StatefulWidget {
  const _RouteList({
    required this.routes,
    required this.requiredQuantity,
    required this.canOperate,
    required this.onStartRoute,
    required this.onStartSetup,
    required this.onPauseSetup,
    required this.onFinishSetup,
    required this.onPauseRun,
    required this.onFinishRun,
  });

  final List<RouteStepItem> routes;
  final int requiredQuantity;
  final bool canOperate;
  final ValueChanged<RouteStepItem> onStartRoute;
  final ValueChanged<RouteStepItem> onStartSetup;
  final ValueChanged<RouteStepItem> onPauseSetup;
  final ValueChanged<RouteStepItem> onFinishSetup;
  final void Function(RouteStepItem route, int requiredQuantity) onPauseRun;
  final void Function(RouteStepItem route, int requiredQuantity) onFinishRun;

  @override
  State<_RouteList> createState() => _RouteListState();
}

class _RouteListState extends State<_RouteList> {
  var _expanded = true;
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.routes]..sort((a, b) => a.sequence.compareTo(b.sequence));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: IntemaColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ruta de producción',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${sorted.length} procesos'),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 1480 ? 1480.0 : constraints.maxWidth;
                return Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: constraints.maxWidth < tableWidth,
                  trackVisibility: constraints.maxWidth < tableWidth,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        children: [
                          const _RouteHeader(),
                          ...sorted.map(
                            (route) => _RouteRow(
                              route: route,
                              requiredQuantity: widget.requiredQuantity,
                              canOperate: widget.canOperate,
                              onStart: () => widget.onStartRoute(route),
                              onStartSetup: () => widget.onStartSetup(route),
                              onPauseSetup: () => widget.onPauseSetup(route),
                              onFinishSetup: () => widget.onFinishSetup(route),
                              onPause: () => widget.onPauseRun(route, widget.requiredQuantity),
                              onFinish: () => widget.onFinishRun(route, widget.requiredQuantity),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF667085),
        );
    return Container(
      color: const Color(0xFFF8FAFD),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('#', style: style)),
          Expanded(flex: 3, child: Text('Máquina', style: style)),
          Expanded(flex: 3, child: Text('Proceso', style: style)),
          SizedBox(width: 130, child: Text('Estado', style: style)),
          SizedBox(width: 100, child: Text('Avance', style: style)),
          SizedBox(width: 130, child: Text('Preparación', style: style)),
          SizedBox(width: 130, child: Text('Mecanizado', style: style)),
          const SizedBox(width: 500, child: Text('')),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.route,
    required this.requiredQuantity,
    required this.canOperate,
    required this.onStart,
    required this.onStartSetup,
    required this.onPauseSetup,
    required this.onFinishSetup,
    required this.onPause,
    required this.onFinish,
  });

  final RouteStepItem route;
  final int requiredQuantity;
  final bool canOperate;
  final VoidCallback onStart;
  final VoidCallback onStartSetup;
  final VoidCallback onPauseSetup;
  final VoidCallback onFinishSetup;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final running = route.status == 'running';
    final setupRunning = route.status == 'setup_running';
    final canStartSetup = route.status == 'pending' || route.status == 'setup_paused';
    final canStartMachining = route.status == 'setup_finished' || route.status == 'paused';
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: IntemaColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${route.sequence}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              route.machine.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(route.processName),
          ),
          SizedBox(
            width: 130,
            child: _StatusChip(status: route.status),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '${_routeCompletedQuantity(route)}/$requiredQuantity',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              _routeElapsedLabel(route, 'setup'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              _routeElapsedLabel(route, 'machining'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 500,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canStartSetup)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB42318),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: canOperate ? onStartSetup : null,
                    icon: const Icon(Icons.timer_outlined),
                    label: Text(route.status == 'setup_paused'
                        ? 'Reanudar prep.'
                        : 'Iniciar prep.'),
                  ),
                if (setupRunning && canOperate) ...[
                  OutlinedButton.icon(
                    onPressed: onPauseSetup,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Pausar prep.'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onFinishSetup,
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Finalizar prep.'),
                  ),
                ],
                if (canStartMachining)
                  OutlinedButton.icon(
                    onPressed: canOperate && !running ? onStart : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar mec.'),
                  ),
                if (running && canOperate) ...[
                  OutlinedButton.icon(
                    onPressed: onPause,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Pausar mec.'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onFinish,
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Terminar mec.'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OitDialog extends StatefulWidget {
  const _OitDialog({this.order});

  final WorkOrderItem? order;

  @override
  State<_OitDialog> createState() => _OitDialogState();
}

class _OitDialogState extends State<_OitDialog> {
  final _code = TextEditingController();
  final _client = TextEditingController();
  final List<_ComponentDraft> _components = [];
  DateTime? _dueDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    if (order == null) {
      _components.add(_ComponentDraft());
      return;
    }
    _code.text = order.code;
    _client.text = order.clientName;
    _dueDate = order.dueDate;
    _components.addAll(
      order.components.map(
        (component) => _ComponentDraft(
          name: component.name,
          quantity: component.quantityRequired.toString(),
        ),
      ),
    );
    if (_components.isEmpty) _components.add(_ComponentDraft());
  }

  @override
  void dispose() {
    _code.dispose();
    _client.dispose();
    for (final component in _components) {
      component.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dueDateLabel = _dueDate == null
        ? 'Seleccionar fecha'
        : _formatDate(_dueDate!);
    return AlertDialog(
      title: Text(widget.order == null ? 'Nueva OIT' : 'Editar ${widget.order!.code}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'N° OIT',
                  hintText: 'Automático',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _client,
                decoration: const InputDecoration(labelText: 'Cliente'),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final now = DateTime.now();
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                    helpText: 'Fecha de entrega',
                    cancelText: 'Cancelar',
                    confirmText: 'Seleccionar',
                  );
                  if (selected != null) {
                    setState(() => _dueDate = selected);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de entrega',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(dueDateLabel),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Componentes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _components.add(_ComponentDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar componente'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._components.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ComponentDraftRow(
                        index: entry.key,
                        draft: entry.value,
                        canRemove: _components.length > 1,
                        onRemove: () {
                          setState(() {
                            final removed = _components.removeAt(entry.key);
                            removed.dispose();
                          });
                        },
                      ),
                    ),
                  ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB71C1C)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton.icon(
          onPressed: () {
            final components = <Map<String, dynamic>>[];
            for (final draft in _components) {
              final name = draft.name.text.trim();
              final quantity = int.tryParse(draft.quantity.text.trim()) ?? 0;
              if (name.isEmpty || quantity <= 0) {
                setState(
                  () => _error =
                      'Cada componente debe tener nombre y cantidad mayor a cero.',
                );
                return;
              }
              components.add({
                'name': name,
                'quantity_required': quantity,
              });
            }
            final clientName = _client.text.trim();
            if (clientName.isEmpty) {
              setState(
                () => _error = 'Completa cliente y componentes.',
              );
              return;
            }
            Navigator.pop(context, {
              'code': _code.text.trim().isEmpty ? null : _code.text.trim(),
              'client_name': clientName,
              'description': 'OIT - $clientName',
              'priority': 'normal',
              'due_date': _dueDate?.toIso8601String(),
              'components': components,
            });
          },
          icon: const Icon(Icons.save_outlined),
          label: Text(widget.order == null ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }
}

class _ComponentDraft {
  _ComponentDraft({String name = '', String quantity = '1'})
      : name = TextEditingController(text: name),
        quantity = TextEditingController(text: quantity);

  final TextEditingController name;
  final TextEditingController quantity;

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _ComponentDraftRow extends StatelessWidget {
  const _ComponentDraftRow({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _ComponentDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          height: 56,
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: draft.name,
            decoration: const InputDecoration(labelText: 'Nombre del componente'),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: TextField(
            controller: draft.quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Quitar componente',
          onPressed: canRemove ? onRemove : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _PlanRouteDialog extends StatefulWidget {
  const _PlanRouteDialog({
    required this.component,
    required this.machines,
  });

  final WorkOrderComponentItem component;
  final List<MachineItem> machines;

  @override
  State<_PlanRouteDialog> createState() => _PlanRouteDialogState();
}

class _PlanRouteDialogState extends State<_PlanRouteDialog> {
  final _selected = <_SelectedRouteMachine>[];
  late List<MachineItem> _machines;

  @override
  void initState() {
    super.initState();
    _machines = [...widget.machines]..sort((a, b) => a.name.compareTo(b.name));
    _selected.addAll(
      ([...widget.component.routes]..sort((a, b) => a.sequence.compareTo(b.sequence))).map(
        (route) => _SelectedRouteMachine(
          machine: route.machine,
          locked: _routePlanLocked(route),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditingRoute = widget.component.routes.isNotEmpty;
    return AlertDialog(
      title: Text('Ruta para ${widget.component.name}'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditingRoute
                  ? 'Actualiza la ruta sin perder avance. Los procesos con candado ya tienen datos y se conservarán.'
                  : 'Selecciona máquinas/procesos en el orden planificado.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selected
                  .asMap()
                  .entries
                  .map(
                    (entry) => Chip(
                      avatar: entry.value.locked ? const Icon(Icons.lock_outline, size: 16) : null,
                      label: Text('${entry.key + 1}. ${entry.value.machine.name}'),
                      onDeleted: entry.value.locked
                          ? null
                          : () => setState(() => _selected.removeAt(entry.key)),
                    ),
                  )
                  .toList(),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: _machines
                    .map(
                      (machine) => ListTile(
                        leading: const Icon(Icons.precision_manufacturing_outlined),
                        title: Text(machine.name),
                        subtitle: Text(machine.processName),
                        trailing: IconButton(
                          tooltip: 'Agregar a ruta',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _selected.add(_SelectedRouteMachine(machine: machine))),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton.icon(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _selected
                        .asMap()
                        .entries
                        .map((entry) => {
                              'sequence': entry.key + 1,
                              'machine_id': entry.value.machine.id,
                              'process_name': entry.value.machine.processName,
                            })
                        .toList(),
                  ),
          icon: const Icon(Icons.save_outlined),
          label: Text(isEditingRoute ? 'Actualizar ruta' : 'Guardar ruta'),
        ),
      ],
    );
  }
}

class _SelectedRouteMachine {
  const _SelectedRouteMachine({
    required this.machine,
    this.locked = false,
  });

  final MachineItem machine;
  final bool locked;
}

class _MachineAdminDialog extends StatefulWidget {
  const _MachineAdminDialog({
    required this.machines,
    required this.onCreateMachine,
    required this.onUpdateMachine,
    required this.onDeleteMachine,
  });

  final List<MachineItem> machines;
  final Future<MachineItem> Function(Map<String, dynamic> payload) onCreateMachine;
  final Future<MachineItem> Function(MachineItem machine, Map<String, dynamic> payload)
      onUpdateMachine;
  final Future<void> Function(MachineItem machine) onDeleteMachine;

  @override
  State<_MachineAdminDialog> createState() => _MachineAdminDialogState();
}

class _MachineAdminDialogState extends State<_MachineAdminDialog> {
  late List<MachineItem> _machines;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _machines = [...widget.machines]..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _saveMachine([MachineItem? machine]) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MachineDialog(machine: machine),
    );
    if (payload == null) return;
    setState(() => _saving = true);
    try {
      final saved = machine == null
          ? await widget.onCreateMachine(payload)
          : await widget.onUpdateMachine(machine, payload);
      setState(() {
        _machines = [
          ..._machines.where((item) => item.id != saved.id),
          saved,
        ]..sort((a, b) => a.name.compareTo(b.name));
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('No se pudo guardar la máquina.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteMachine(MachineItem machine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${machine.name}'),
        content: const Text('La máquina se retirará del catálogo para nuevas rutas. Las rutas antiguas se conservarán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await widget.onDeleteMachine(machine);
      setState(() => _machines = _machines.where((item) => item.id != machine.id).toList());
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('No se pudo eliminar la máquina.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Administrar máquinas'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('Catálogo de máquinas y procesos de producción.')),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _saveMachine(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva máquina'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: _machines.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final machine = _machines[index];
                  return ListTile(
                    leading: const Icon(Icons.precision_manufacturing_outlined),
                    title: Text(machine.name),
                    subtitle: Text(machine.processName),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Editar máquina',
                          onPressed: _saving ? null : () => _saveMachine(machine),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Eliminar máquina',
                          onPressed: _saving ? null : () => _deleteMachine(machine),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _machines),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _MachineDialog extends StatefulWidget {
  const _MachineDialog({this.machine});

  final MachineItem? machine;

  @override
  State<_MachineDialog> createState() => _MachineDialogState();
}

class _MachineDialogState extends State<_MachineDialog> {
  late final TextEditingController _name;
  late final TextEditingController _processName;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.machine?.name ?? '');
    _processName = TextEditingController(text: widget.machine?.processName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _processName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.machine != null;
    return AlertDialog(
      title: Text(isEditing ? 'Editar máquina' : 'Nueva máquina'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Máquina'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _processName,
              decoration: const InputDecoration(labelText: 'Proceso'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton.icon(
          onPressed: () {
            final name = _name.text.trim();
            final process = _processName.text.trim();
            if (name.length < 2 || process.length < 2) {
              setState(() => _error = 'Completa máquina y proceso.');
              return;
            }
            Navigator.pop(context, {
              'name': name,
              'process_name': process,
              'is_active': true,
            });
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _QualityActions extends StatelessWidget {
  const _QualityActions({
    required this.component,
    required this.canEdit,
    required this.onInspect,
    required this.onSkip,
  });

  final WorkOrderComponentItem component;
  final bool canEdit;
  final VoidCallback onInspect;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final last = component.qualityInspections.isEmpty ? null : component.qualityInspections.last;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: canEdit ? onInspect : null,
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(last == null ? 'Inspeccionar' : 'Editar / nueva inspección'),
        ),
        ElevatedButton.icon(
          onPressed: canEdit ? onSkip : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB42318),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.block_outlined),
          label: const Text('Omitir inspección'),
        ),
        if (last != null) ...[
          _QualityCountChip(label: 'Aceptadas', value: last.acceptedQuantity, ok: true),
          _QualityCountChip(label: 'Rechazadas', value: last.rejectedQuantity, ok: false),
        ],
      ],
    );
  }
}

class _QualityCountChip extends StatelessWidget {
  const _QualityCountChip({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final int value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF0B6B3A) : const Color(0xFFB42318);
    return Chip(
      label: Text('$label: $value'),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      backgroundColor: ok ? const Color(0xFFE6F4EA) : const Color(0xFFFFE4E2),
      side: BorderSide(color: ok ? const Color(0xFF8ACCA8) : const Color(0xFFFDA29B)),
    );
  }
}

class _SkipQualityDialog extends StatefulWidget {
  const _SkipQualityDialog({required this.component});

  final WorkOrderComponentItem component;

  @override
  State<_SkipQualityDialog> createState() => _SkipQualityDialogState();
}

class _SkipQualityDialogState extends State<_SkipQualityDialog> {
  final _reason = TextEditingController();
  final _authorizedBy = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _authorizedBy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Omitir control de calidad'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.component.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'Esta acción liberará el componente sin inspección dimensional. '
              'El motivo quedará registrado en la trazabilidad.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Motivo obligatorio',
                hintText: 'Ejemplo: lote urgente, control por muestreo externo, responsable ausente...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _authorizedBy,
              decoration: const InputDecoration(
                labelText: 'Autorizado por',
                hintText: 'Si lo dejas vacío se registrará el usuario actual',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
          onPressed: () {
            final reason = _reason.text.trim();
            if (reason.length < 3) {
              setState(() => _error = 'Indica el motivo para omitir la inspección.');
              return;
            }
            Navigator.pop(context, {
              'reason': reason,
              'authorized_by': _authorizedBy.text.trim().isEmpty ? null : _authorizedBy.text.trim(),
            });
          },
          icon: const Icon(Icons.block_outlined),
          label: const Text('Omitir y liberar'),
        ),
      ],
    );
  }
}

class _QualityInspectionDialog extends StatefulWidget {
  const _QualityInspectionDialog({required this.order, required this.component});

  final WorkOrderItem order;
  final WorkOrderComponentItem component;

  @override
  State<_QualityInspectionDialog> createState() => _QualityInspectionDialogState();
}

class _QualityInspectionDialogState extends State<_QualityInspectionDialog> {
  final _drawing = TextEditingController();
  final _instrument = TextEditingController();
  final _observations = TextEditingController();
  final List<String> _photoPaths = [];
  final List<_QualityPointDraft> _points = [];
  var _inspectionPieceCount = 1;
  var _versionNumber = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _drawing.text = widget.component.name;
    final pieceCount = _initialInspectionPieceCount();
    _inspectionPieceCount = pieceCount;
    final last = widget.component.qualityInspections.isEmpty
        ? null
        : widget.component.qualityInspections.last;
    if (last != null) {
      final needsNewVersion = _inspectionHasRejected(last);
      _versionNumber = widget.component.qualityInspections.length + (needsNewVersion ? 1 : 0);
      _loadInspection(
        last,
        pieceCount: _savedInspectionPieceCount(last, fallback: pieceCount),
        onlyAccepted: needsNewVersion,
      );
    } else {
      for (var index = 0; index < 6; index++) {
        _points.add(_QualityPointDraft(pieceCount, name: 'Cota ${index + 1}'));
      }
    }
  }

  @override
  void dispose() {
    _drawing.dispose();
    _instrument.dispose();
    _observations.dispose();
    for (final point in _points) {
      point.dispose();
    }
    super.dispose();
  }

  double? _parse(String value) => double.tryParse(value.trim().replaceAll(',', '.'));

  int _initialInspectionPieceCount() => widget.component.quantityRequired.clamp(1, 10).toInt();

  int _savedInspectionPieceCount(QualityInspectionItem inspection, {required int fallback}) {
    var savedCount = 0;
    for (final point in inspection.measurements) {
      final values = point['values'];
      if (values is List && values.length > savedCount) savedCount = values.length;
    }
    final maxPieces = widget.component.quantityRequired.clamp(1, 80).toInt();
    return (savedCount <= 0 ? fallback : savedCount).clamp(1, maxPieces).toInt();
  }

  bool get _canAddInspectionPieces =>
      _isDraftVersion && _inspectionPieceCount < widget.component.quantityRequired.clamp(1, 80).toInt();

  void _addInspectionPieces() {
    final maxPieces = widget.component.quantityRequired.clamp(1, 80).toInt();
    final nextCount = (_inspectionPieceCount + 10).clamp(1, maxPieces).toInt();
    final toAdd = nextCount - _inspectionPieceCount;
    if (toAdd <= 0) return;
    setState(() {
      _inspectionPieceCount = nextCount;
      for (final point in _points) {
        point.addPieces(toAdd);
      }
    });
  }

  bool? _isOk(_QualityPointDraft point, String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    final nominal = _parse(point.nominal.text);
    final min = _parse(point.min.text);
    final max = _parse(point.max.text);
    if (parsed == null || nominal == null || min == null || max == null) return null;
    return parsed >= nominal + min && parsed <= nominal + max;
  }

  int get _accepted => _points.fold(
        0,
        (total, point) =>
            total +
            point.values
                .take(_inspectionPieceCount)
                .where((item) => _isOk(point, item.text) == true)
                .length,
      );
  int get _rejected => _points.fold(
        0,
        (total, point) =>
            total +
            point.values
                .take(_inspectionPieceCount)
                .where((item) => _isOk(point, item.text) == false)
                .length,
      );
  bool get _isDraftVersion =>
      widget.component.qualityInspections.isEmpty ||
      _versionNumber > widget.component.qualityInspections.length;
  bool get _canStartNewVersion =>
      widget.component.qualityInspections.isNotEmpty &&
      _inspectionHasRejected(widget.component.qualityInspections.last);

  List<int>? _inspectionCountsFromMeasurements(QualityInspectionItem inspection) {
    if (inspection.measurements.isEmpty) return null;
    var accepted = 0;
    var rejected = 0;
    var hasMeasuredValue = false;
    for (final point in inspection.measurements) {
      final values = point['values'];
      if (values is! List) continue;
      for (final item in values) {
        if (item is! Map) continue;
        final value = item['value']?.toString().trim() ?? '';
        if (value.isEmpty) continue;
        hasMeasuredValue = true;
        if (item['in_range'] == true) {
          accepted++;
        } else if (item['in_range'] == false) {
          rejected++;
        }
      }
    }
    if (!hasMeasuredValue) return null;
    return [accepted, rejected];
  }

  bool _inspectionHasRejected(QualityInspectionItem inspection) {
    final counts = _inspectionCountsFromMeasurements(inspection);
    return counts == null ? inspection.rejectedQuantity > 0 : counts[1] > 0;
  }

  bool _inspectionHasAcceptedOnly(QualityInspectionItem inspection) {
    final counts = _inspectionCountsFromMeasurements(inspection);
    if (counts == null) {
      return inspection.acceptedQuantity > 0 && inspection.rejectedQuantity <= 0;
    }
    return counts[0] > 0 && counts[1] <= 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.straighten_outlined, size: 20),
          const SizedBox(width: 8),
          Text('Control dimensional ${widget.order.code} - V$_versionNumber'),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      content: SizedBox(
        width: 1220,
        height: (MediaQuery.of(context).size.height * 0.76).clamp(660.0, 780.0).toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _QualityDataHeader(order: widget.order, component: widget.component),
            if (widget.component.qualityInspections.isNotEmpty) ...[
              const SizedBox(height: 8),
              _versionBar(),
            ],
          const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field(_drawing, 'Descripción / plano', enabled: _isDraftVersion)),
                const SizedBox(width: 10),
                Expanded(child: _field(_instrument, 'Instrumento de medición', enabled: _isDraftVersion)),
                const SizedBox(width: 10),
                _QualityCountChip(label: 'Aprobado', value: _accepted, ok: true),
                const SizedBox(width: 8),
                _QualityCountChip(label: 'Rechazado', value: _rejected, ok: false),
              ],
            ),
            const SizedBox(height: 8),
            _photoEvidenceSection(),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Cotas nominales, tolerancias y mediciones por pieza',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _canAddInspectionPieces ? _addInspectionPieces : null,
                  icon: const Icon(Icons.add_box_outlined),
                  label: Text('Agregar piezas ($_inspectionPieceCount/${widget.component.quantityRequired})'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isDraftVersion ? _addPoint : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar cota'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _QualityMatrixEditor(
                points: _points,
                pieceCount: _inspectionPieceCount,
                isOk: _isOk,
                enabled: _isDraftVersion,
                onChanged: () => setState(() {}),
                onDelete: !_isDraftVersion || _points.length <= 1
                    ? null
                    : (point) {
                        setState(() {
                          point.dispose();
                          _points.remove(point);
                        });
                      },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _observations,
                    enabled: _isDraftVersion,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones de calidad',
                      hintText: 'Defecto, motivo de rechazo o acción sugerida.',
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        OutlinedButton.icon(
          onPressed: () {
            _printA4();
          },
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Imprimir A4'),
        ),
        ElevatedButton.icon(
          onPressed: _isDraftVersion
              ? () {
                  _save();
                }
              : null,
          icon: const Icon(Icons.save_outlined),
          label: Text(_isDraftVersion ? 'Guardar V$_versionNumber' : 'Versión guardada'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, {bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _versionBar() {
    final inspections = widget.component.qualityInspections;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Versiones:', style: TextStyle(fontWeight: FontWeight.w900)),
        for (var index = 0; index < inspections.length; index++)
          _versionChip(index, inspections[index]),
        OutlinedButton.icon(
          onPressed: _canStartNewVersion && !_isDraftVersion ? _startNewVersionFromLast : null,
          icon: const Icon(Icons.add),
          label: Text('Nueva inspección V${inspections.length + 1}'),
        ),
        if (_versionNumber > inspections.length)
          Chip(
            label: Text('Editando V$_versionNumber'),
            backgroundColor: const Color(0xFFFFF4C2),
            side: const BorderSide(color: IntemaColors.yellow),
          ),
      ],
    );
  }

  Widget _versionChip(int index, QualityInspectionItem inspection) {
    final selected = _versionNumber == index + 1;
    final rejected = _inspectionHasRejected(inspection);
    final accepted = _inspectionHasAcceptedOnly(inspection);
    final background = rejected
        ? const Color(0xFFFFE4E2)
        : accepted
            ? const Color(0xFFE6F4EA)
            : const Color(0xFFF2F4F7);
    final selectedBackground = rejected
        ? const Color(0xFFFFC9C3)
        : accepted
            ? const Color(0xFFCDEBD8)
            : const Color(0xFFE7ECFB);
    final border = rejected
        ? const Color(0xFFF04438)
        : accepted
            ? const Color(0xFF12B76A)
            : IntemaColors.border;
    final textColor = rejected
        ? const Color(0xFFB42318)
        : accepted
            ? const Color(0xFF087443)
            : IntemaColors.navy;
    return ChoiceChip(
      label: Text(
        'V${index + 1}',
        style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
      ),
      avatar: Icon(
        rejected ? Icons.close : accepted ? Icons.check : Icons.circle_outlined,
        size: 16,
        color: textColor,
      ),
      selected: selected,
      backgroundColor: background,
      selectedColor: selectedBackground,
      side: BorderSide(color: border),
      onSelected: (_) {
        setState(() {
          _versionNumber = index + 1;
          _loadInspection(
            inspection,
            pieceCount: _savedInspectionPieceCount(
              inspection,
              fallback: _initialInspectionPieceCount(),
            ),
            onlyAccepted: false,
          );
        });
      },
    );
  }

  void _startNewVersionFromLast() {
    final inspections = widget.component.qualityInspections;
    if (inspections.isEmpty) return;
    if (!_inspectionHasRejected(inspections.last)) {
      setState(() => _error = 'Solo se puede crear otra versión si la última inspección tiene rechazos.');
      return;
    }
    setState(() {
      _versionNumber = inspections.length + 1;
      _loadInspection(
        inspections.last,
        pieceCount: _savedInspectionPieceCount(
          inspections.last,
          fallback: _initialInspectionPieceCount(),
        ),
        onlyAccepted: true,
      );
    });
  }

  void _loadInspection(
    QualityInspectionItem inspection, {
    required int pieceCount,
    required bool onlyAccepted,
  }) {
    _inspectionPieceCount = pieceCount.clamp(1, widget.component.quantityRequired.clamp(1, 80)).toInt();
    _observations.text = onlyAccepted ? '' : inspection.observations ?? '';
    _photoPaths
      ..clear()
      ..addAll(inspection.photoNotes);
    for (final point in _points) {
      point.dispose();
    }
    _points.clear();
    if (inspection.measurements.isNotEmpty && inspection.measurements.first.containsKey('point_name')) {
      for (final point in inspection.measurements) {
        _points.add(_QualityPointDraft.fromSaved(point, _inspectionPieceCount, onlyAccepted: onlyAccepted));
      }
    }
    if (_points.isEmpty) {
      for (var index = 0; index < 6; index++) {
        _points.add(_QualityPointDraft(_inspectionPieceCount, name: 'Cota ${index + 1}'));
      }
    }
    _error = null;
  }

  Future<void> _save() async {
    if (!_isDraftVersion) {
      setState(() => _error = 'Esta versión ya fue guardada. Crea una nueva versión solo si hubo rechazos.');
      return;
    }
    final validPoints = _points.where((point) => point.nominal.text.trim().isNotEmpty).toList();
    if (validPoints.isEmpty) {
      setState(() => _error = 'Agrega al menos una cota nominal.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Guardar inspección V$_versionNumber'),
        content: const Text(
          'Después de guardar esta versión ya no podrá editarse. '
          'Si luego se encuentran piezas rechazadas, tendrás que crear una nueva versión de inspección.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Guardar y bloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.pop(context, {
      'drawing_code': _drawing.text.trim(),
      'instrument': _instrument.text.trim().isEmpty ? null : _instrument.text.trim(),
      'quality_points': [
        for (final point in validPoints)
          {
            'name': point.name.text.trim(),
            'nominal_value': _parse(point.nominal.text),
            'min_value': _parse(point.min.text),
            'max_value': _parse(point.max.text),
            'values': [
              for (var index = 0; index < _inspectionPieceCount; index++)
                _parse(point.values[index].text),
            ],
          }
      ],
      'photo_notes': _photoPaths,
      'observations': _observations.text.trim().isEmpty ? null : _observations.text.trim(),
    });
  }

  Widget _photoEvidenceSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: IntemaColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF667085)),
          const SizedBox(width: 10),
          Expanded(
            child: _photoPaths.isEmpty
                ? const Text(
                    'Sin foto referencial de la pieza inspeccionada.',
                    style: TextStyle(color: Color(0xFF667085)),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final path in _photoPaths)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFD),
                              border: Border.all(color: IntemaColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image_outlined, size: 16),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 180),
                                  child: Text(
                                    path.split(RegExp(r'[\\/]')).last,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: _isDraftVersion ? () => setState(() => _photoPaths.remove(path)) : null,
                                  child: const Icon(Icons.close, size: 16),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _isDraftVersion ? _pickImages : null,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Buscar en carpeta'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    if (!Platform.isWindows) {
      setState(() => _error = 'Por ahora la selección directa de imágenes está habilitada en Windows.');
      return;
    }
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "Imágenes|*.png;*.jpg;*.jpeg;*.bmp;*.webp|Todos los archivos|*.*"
$dialog.Multiselect = $true
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $dialog.FileNames -join "`n"
}
''';
    try {
      final result = await Process.run('powershell.exe', ['-NoProfile', '-STA', '-Command', script]);
      if (!mounted) return;
      if (result.exitCode != 0) {
        setState(() => _error = 'No se pudo abrir el selector de imágenes.');
        return;
      }
      final paths = result.stdout
          .toString()
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (paths.isEmpty) return;
      setState(() {
        _error = null;
        for (final path in paths) {
          if (!_photoPaths.contains(path)) _photoPaths.add(path);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo abrir el selector de imágenes.');
    }
  }

  Future<void> _printA4() async {
    final validPoints = _points.where((point) => point.nominal.text.trim().isNotEmpty).toList();
    if (validPoints.isEmpty) {
      setState(() => _error = 'Agrega al menos una cota nominal antes de imprimir.');
      return;
    }

    final html = _buildA4Html(validPoints);
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}control_dimensional_${widget.order.code.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_v$_versionNumber.html',
    );
    await file.writeAsString(html);
    await Process.start('rundll32.exe', ['url.dll,FileProtocolHandler', file.path]);
  }

  String _buildA4Html(List<_QualityPointDraft> points) {
    const maxCotasPerPage = 6;
    const maxPiecesPerPage = 10;
    final pieceCount = _inspectionPieceCount.clamp(1, widget.component.quantityRequired.clamp(1, 80)).toInt();
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final due = widget.order.dueDate == null ? '-' : _formatDate(widget.order.dueDate!);
    final buffer = StringBuffer();
    buffer.write('''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Control dimensional ${_html(widget.order.code)}</title>
<style>
  @page { size: A4 landscape; margin: 10mm; }
  * { box-sizing: border-box; }
  body { margin: 0; background: #eee; font-family: Arial, sans-serif; color: #111; }
  .sheet {
    width: 277mm;
    min-height: 190mm;
    margin: 0 auto 10mm;
    padding: 7mm;
    background: white;
    page-break-after: always;
    page-break-inside: avoid;
  }
  .outer { border: 1.2px solid #111; min-height: 176mm; padding: 0; }
  table { width: 100%; border-collapse: collapse; table-layout: fixed; }
  th, td { border: 0.8px solid #111; padding: 4px 5px; font-size: 10px; vertical-align: middle; }
  .title { font-size: 13px; font-weight: 800; text-align: center; }
  .logo { width: 28mm; text-align: center; font-weight: 900; color: #05206f; }
  .label { width: 30mm; font-weight: 800; background: #f7f7f7; }
  .small { font-size: 8px; line-height: 1.2; }
  .center { text-align: center; }
  .bold { font-weight: 800; }
  .ok { color: #087443; font-weight: 800; }
  .bad { color: #b42318; font-weight: 800; }
  .blank { color: #777; }
  .measure th { height: 13mm; }
  .measure td { height: 8mm; text-align: center; }
  .footer td { height: 9mm; }
  .email { text-align: center; border: 0; font-size: 8px; padding-top: 4mm; }
  .evidence-title { font-size: 15px; font-weight: 800; text-align: center; margin: 0 0 5mm; }
  .evidence-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 6mm; }
  .evidence-card { border: 0.8px solid #111; padding: 3mm; min-height: 70mm; page-break-inside: avoid; }
  .evidence-card img { width: 100%; height: 58mm; object-fit: contain; display: block; }
  .evidence-name { font-size: 9px; font-weight: 700; text-align: center; margin-top: 2mm; word-break: break-all; }
  @media print {
    body { background: white; }
    .sheet { margin: 0 auto; }
  }
</style>
<script>
  window.addEventListener('load', () => setTimeout(() => window.print(), 350));
</script>
</head>
<body>
''');

    for (var cotaStart = 0; cotaStart < points.length; cotaStart += maxCotasPerPage) {
      final cotaChunk = points.skip(cotaStart).take(maxCotasPerPage).toList();
      for (var pieceStart = 0; pieceStart < pieceCount; pieceStart += maxPiecesPerPage) {
        final pieces = List.generate(
          (pieceCount - pieceStart).clamp(0, maxPiecesPerPage).toInt(),
          (index) => pieceStart + index,
        );
        buffer.write('''
<section class="sheet">
  <div class="outer">
    <table>
      <tr>
        <td class="logo" rowspan="2">INTEMA<br><span class="small">S.A.C.</span></td>
        <td class="title" colspan="6" rowspan="2">FORMATO PARA CONTROL DIMENSIONAL DE FABRICACIONES</td>
        <td class="label">REVISION:</td><td>V$_versionNumber</td>
      </tr>
      <tr><td class="label">FECHA:</td><td>${_html(date)}</td></tr>
      <tr>
        <td class="label">CLIENTE</td><td colspan="3">${_html(widget.order.clientName)}</td>
        <td class="label">OIT</td><td colspan="4">${_html(widget.order.code)}</td>
      </tr>
      <tr>
        <td class="label">DESCRIPCION PIEZA</td><td colspan="3">${_html(_drawing.text)}</td>
        <td class="label">CODIGO MATERIAL</td><td colspan="4">${_html(widget.component.name)}</td>
      </tr>
      <tr>
        <td class="label">INSTRUMENTO MEDICION</td><td colspan="3">${_html(_instrument.text)}</td>
        <td class="label">N° PIEZAS INSPEC.</td><td colspan="2">$pieceCount / ${widget.component.quantityRequired}</td>
        <td class="label">ENTREGA</td><td>${_html(due)}</td>
      </tr>
    </table>
    <table class="measure">
      <tr>
        <th style="width: 24mm;">PIEZA</th>
''');
        for (var index = 0; index < cotaChunk.length; index++) {
          final point = cotaChunk[index];
          buffer.write(
            '<th>Cota ${cotaStart + index + 1}<br><span class="small">Nom: ${_html(point.nominal.text)} mm<br>Tol: ${_html(point.min.text)} / ${_html(point.max.text)}</span></th>',
          );
        }
        buffer.write('<th style="width: 24mm;">RESULTADO</th></tr>');

        for (final pieceIndex in pieces) {
          var hasValue = false;
          var allOk = true;
          buffer.write('<tr><td class="bold">PIEZA ${pieceIndex + 1}</td>');
          for (final point in cotaChunk) {
            final value = point.values[pieceIndex].text.trim();
            final ok = _isOk(point, value);
            if (value.isNotEmpty) hasValue = true;
            if (ok == false) allOk = false;
            final cls = ok == null ? '' : ok ? 'ok' : 'bad';
            buffer.write('<td class="$cls">${_html(value)}</td>');
          }
          final result = !hasValue ? '-' : allOk ? 'APROBADO' : 'RECHAZADO';
          final cls = !hasValue ? 'blank' : allOk ? 'ok' : 'bad';
          buffer.write('<td class="$cls">$result</td></tr>');
        }

        buffer.write('''
    </table>
    <table>
      <tr><td class="label">FOTOS / EVIDENCIAS</td><td colspan="8">${_html(_photoPaths.map((path) => path.split(RegExp(r'[\\/]')).last).join(', '))}</td></tr>
      <tr><td class="label">OBSERVACIONES</td><td colspan="8">${_html(_observations.text)}</td></tr>
    </table>
    <table class="footer">
      <tr>
        <td class="label">ELABORADO POR</td><td colspan="2">Administrador INTEMA</td>
        <td class="label">APROBADO POR</td><td colspan="2"></td>
        <td class="label">JEFE DE PRODUCCION</td><td colspan="2"></td>
      </tr>
      <tr>
        <td class="label">INSPECTOR</td><td colspan="2"></td>
        <td class="label">FECHA</td><td colspan="2">${_html(date)}</td>
        <td class="label">JEFE DE CALIDAD</td><td colspan="2"></td>
      </tr>
    </table>
    <div class="email">administracion@intemasac.com</div>
  </div>
</section>
''');
      }
    }
    if (_photoPaths.isNotEmpty) {
      for (var start = 0; start < _photoPaths.length; start += 4) {
        final chunk = _photoPaths.skip(start).take(4).toList();
        buffer.write('''
<section class="sheet">
  <div class="outer" style="padding: 7mm;">
    <div class="evidence-title">EVIDENCIAS FOTOGRAFICAS - ${_html(widget.order.code)} - V$_versionNumber</div>
    <table style="margin-bottom: 5mm;">
      <tr>
        <td class="label">CLIENTE</td><td>${_html(widget.order.clientName)}</td>
        <td class="label">PIEZA</td><td>${_html(widget.component.name)}</td>
        <td class="label">FECHA</td><td>${_html(date)}</td>
      </tr>
    </table>
    <div class="evidence-grid">
''');
        for (final path in chunk) {
          final name = path.split(RegExp(r'[\\/]')).last;
          buffer.write('''
      <div class="evidence-card">
        <img src="${_html(_fileUri(path))}" alt="${_html(name)}">
        <div class="evidence-name">${_html(name)}</div>
      </div>
''');
        }
        buffer.write('''
    </div>
  </div>
</section>
''');
      }
    }
    buffer.write('</body></html>');
    return buffer.toString();
  }

  String _fileUri(String path) => Uri.file(path).toString();

  String _html(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  void _addPoint() {
    setState(() {
      _points.add(
        _QualityPointDraft(
          _inspectionPieceCount,
          name: 'Cota ${_points.length + 1}',
        ),
      );
    });
  }
}

class _QualityPointDraft {
  _QualityPointDraft(int pieceCount, {String name = ''})
      : name = TextEditingController(text: name),
        nominal = TextEditingController(),
        min = TextEditingController(),
        max = TextEditingController(),
        values = List.generate(pieceCount, (_) => TextEditingController());

  _QualityPointDraft.fromSaved(
    Map<String, dynamic> json,
    int pieceCount, {
    bool onlyAccepted = false,
  })
      : name = TextEditingController(text: json['point_name']?.toString() ?? ''),
        nominal = TextEditingController(text: json['nominal_value']?.toString() ?? ''),
        min = TextEditingController(text: json['min_value']?.toString() ?? ''),
        max = TextEditingController(text: json['max_value']?.toString() ?? ''),
        values = List.generate(pieceCount, (index) {
          final savedValues = json['values'] as List? ?? [];
          var value = '';
          if (index < savedValues.length && savedValues[index] is Map) {
            final saved = savedValues[index] as Map;
            final accepted = saved['in_range'] == true;
            if (!onlyAccepted || accepted) {
              value = saved['value']?.toString() ?? '';
            }
          }
          return TextEditingController(text: value);
        });

  final TextEditingController name;
  final TextEditingController nominal;
  final TextEditingController min;
  final TextEditingController max;
  final List<TextEditingController> values;

  void addPieces(int count) {
    for (var index = 0; index < count; index++) {
      values.add(TextEditingController());
    }
  }

  void dispose() {
    name.dispose();
    nominal.dispose();
    min.dispose();
    max.dispose();
    for (final value in values) {
      value.dispose();
    }
  }
}

class _QualityDataHeader extends StatelessWidget {
  const _QualityDataHeader({required this.order, required this.component});

  final WorkOrderItem order;
  final WorkOrderComponentItem component;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        border: Border.all(color: IntemaColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const IntemaLogo(height: 38, compact: true),
          Text(order.code, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(order.clientName),
          Text(component.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('${component.quantityRequired} piezas'),
          if (order.dueDate != null) Text('Entrega: ${_formatDate(order.dueDate!)}'),
        ],
      ),
    );
  }
}

class _QualityMatrixEditor extends StatelessWidget {
  const _QualityMatrixEditor({
    required this.points,
    required this.pieceCount,
    required this.isOk,
    required this.enabled,
    required this.onChanged,
    required this.onDelete,
  });

  final List<_QualityPointDraft> points;
  final int pieceCount;
  final bool? Function(_QualityPointDraft point, String value) isOk;
  final bool enabled;
  final VoidCallback onChanged;
  final ValueChanged<_QualityPointDraft>? onDelete;

  @override
  Widget build(BuildContext context) {
    final count = pieceCount.clamp(1, 80).toInt();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: IntemaColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = 148 + (points.length * 176);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width < constraints.maxWidth ? constraints.maxWidth : width.toDouble(),
              height: constraints.maxHeight,
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF8FAFD),
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(
                          width: 128,
                          child: Text(
                            'Pieza',
                            style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF667085)),
                          ),
                        ),
                        for (var index = 0; index < points.length; index++)
                          _QualityCotaCard(
                            index: index,
                            point: points[index],
                            enabled: enabled,
                            onChanged: onChanged,
                            onDelete: onDelete == null ? null : () => onDelete!(points[index]),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var index = 0; index < count; index++)
                            _QualityPieceRow(
                              pieceIndex: index,
                                points: points,
                                isOk: isOk,
                                enabled: enabled,
                                onChanged: onChanged,
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QualityCotaCard extends StatelessWidget {
  const _QualityCotaCard({
    required this.index,
    required this.point,
    required this.enabled,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _QualityPointDraft point;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 166,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: IntemaColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cota ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: IntemaColors.navy),
                ),
              ),
              IconButton(
                tooltip: 'Eliminar cota',
                visualDensity: VisualDensity.compact,
                onPressed: enabled ? onDelete : null,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _matrixInput(point.nominal, 'Cota nominal', numeric: true, enabled: enabled, onChanged: onChanged)),
              const SizedBox(width: 6),
              const Text('mm', style: TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _matrixInput(point.min, 'Tol. min', numeric: true, enabled: enabled, onChanged: onChanged)),
              const SizedBox(width: 6),
              Expanded(child: _matrixInput(point.max, 'Tol. max', numeric: true, enabled: enabled, onChanged: onChanged)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _matrixInput(
    TextEditingController controller,
    String hint, {
    bool numeric = false,
    bool enabled = true,
    required VoidCallback onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}

class _QualityPieceRow extends StatelessWidget {
  const _QualityPieceRow({
    required this.pieceIndex,
    required this.points,
    required this.isOk,
    required this.enabled,
    required this.onChanged,
  });

  final int pieceIndex;
  final List<_QualityPointDraft> points;
  final bool? Function(_QualityPointDraft point, String value) isOk;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: IntemaColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: Text('Pieza ${pieceIndex + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          for (final point in points)
            SizedBox(
              width: 166,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _measurementInput(
                  point.values[pieceIndex],
                  hint: point.name.text.trim().isEmpty ? 'Medida' : point.name.text.trim(),
                  result: isOk(point, point.values[pieceIndex].text),
                  enabled: enabled,
                  onChanged: onChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _measurementInput(
    TextEditingController controller, {
    required String hint,
    required VoidCallback onChanged,
    bool enabled = true,
    bool? result,
  }) {
    final color = result == null
        ? Colors.white
        : result
            ? const Color(0xFFE6F4EA)
            : const Color(0xFFFFE4E2);
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: color,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        suffixIcon: result == null
            ? null
            : Icon(
                result ? Icons.check_circle : Icons.cancel,
                color: result ? const Color(0xFF0B6B3A) : const Color(0xFFB42318),
                size: 16,
              ),
      ),
    );
  }
}

class _QualitySheetTitle extends StatelessWidget {
  const _QualitySheetTitle({required this.order});

  final WorkOrderItem order;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.black87, width: 0.8),
      columnWidths: const {
        0: FixedColumnWidth(118),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(168),
      },
      children: [
        TableRow(
          children: [
            const SizedBox(height: 72, child: Center(child: IntemaLogo(height: 52))),
            const _SheetTextCell(
              'FORMATO PARA CONTROL DIMENSIONAL DE FABRICACIONES',
              bold: true,
              centered: true,
              height: 72,
            ),
            _SheetTextCell(
              'REVISIÓN: 001\nFECHA: ${_qualityDateText}\nOIT: ${order.code}',
              bold: true,
              centered: true,
              height: 72,
            ),
          ],
        ),
      ],
    );
  }
}

class _SheetInfoGrid extends StatelessWidget {
  const _SheetInfoGrid({
    required this.drawing,
    required this.instrument,
    required this.order,
    required this.component,
  });

  final TextEditingController drawing;
  final TextEditingController instrument;
  final WorkOrderItem order;
  final WorkOrderComponentItem component;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.black87, width: 0.8),
      columnWidths: const {
        0: FixedColumnWidth(170),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(170),
        3: FlexColumnWidth(),
      },
      children: [
        _row('CLIENTE', order.clientName, 'N° OIT', order.code),
        _row('DESCRIPCIÓN PIEZA', null, 'CÓDIGO MATERIAL', component.name,
            leftController: drawing),
        _row('PLANO DE FABRICACIÓN', component.name, 'N° PIEZAS', '${component.quantityRequired}'),
        _row('INSTRUMENTO MEDICIÓN', null, 'ENTREGA', order.dueDate == null ? '-' : _formatDate(order.dueDate!),
            leftController: instrument),
      ],
    );
  }

  TableRow _row(
    String leftLabel,
    String? leftText,
    String rightLabel,
    String? rightText, {
    TextEditingController? leftController,
  }) {
    return TableRow(
      children: [
        _SheetTextCell(leftLabel, bold: true),
        leftController == null
            ? _SheetTextCell(leftText ?? '')
            : _SheetInputCell(controller: leftController),
        _SheetTextCell(rightLabel, bold: true),
        _SheetTextCell(rightText ?? ''),
      ],
    );
  }
}

class _ToleranceBand extends StatelessWidget {
  const _ToleranceBand({
    required this.nominal,
    required this.min,
    required this.max,
    required this.accepted,
    required this.rejected,
    required this.onChanged,
  });

  final TextEditingController nominal;
  final TextEditingController min;
  final TextEditingController max;
  final int accepted;
  final int rejected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.black87, width: 0.8),
      columnWidths: const {
        0: FixedColumnWidth(140),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(140),
        3: FlexColumnWidth(),
        4: FixedColumnWidth(140),
        5: FlexColumnWidth(),
        6: FixedColumnWidth(96),
        7: FixedColumnWidth(96),
      },
      children: [
        TableRow(
          children: [
            const _SheetTextCell('COTA NOMINAL', bold: true),
            _SheetInputCell(controller: nominal, numeric: true, onChanged: onChanged),
            const _SheetTextCell('MÍNIMA', bold: true),
            _SheetInputCell(controller: min, numeric: true, onChanged: onChanged),
            const _SheetTextCell('MÁXIMA', bold: true),
            _SheetInputCell(controller: max, numeric: true, onChanged: onChanged),
            _SheetResultCell(label: 'Aprobado', value: accepted, ok: true),
            _SheetResultCell(label: 'Rechazado', value: rejected, ok: false),
          ],
        ),
      ],
    );
  }
}

class _QualitySheetMeasurements extends StatelessWidget {
  const _QualitySheetMeasurements({
    required this.measurements,
    required this.isOk,
    required this.onChanged,
  });

  final List<TextEditingController> measurements;
  final bool? Function(String value) isOk;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final visibleCount = measurements.length.clamp(1, 12).toInt();
    return Table(
      border: TableBorder.all(color: Colors.black87, width: 0.8),
      columnWidths: const {
        0: FixedColumnWidth(96),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(96),
        3: FlexColumnWidth(),
        4: FixedColumnWidth(96),
        5: FlexColumnWidth(),
      },
      children: [
        const TableRow(
          children: [
            _SheetTextCell('PUNTOS DE INSPECCIÓN', bold: true, centered: true, height: 34),
            _SheetTextCell('MEDIDA', bold: true, centered: true, height: 34),
            _SheetTextCell('PUNTO', bold: true, centered: true, height: 34),
            _SheetTextCell('MEDIDA', bold: true, centered: true, height: 34),
            _SheetTextCell('PUNTO', bold: true, centered: true, height: 34),
            _SheetTextCell('MEDIDA', bold: true, centered: true, height: 34),
          ],
        ),
        for (var row = 0; row < 4; row++)
          TableRow(
            children: [
              for (var col = 0; col < 3; col++) ...[
                _SheetTextCell(_pieceLabel(row + (col * 4), visibleCount), bold: true),
                _pieceInput(row + (col * 4), visibleCount),
              ],
            ],
          ),
      ],
    );
  }

  static String _pieceLabel(int index, int visibleCount) {
    if (index >= visibleCount) return '';
    return 'PIEZA ${index + 1}';
  }

  Widget _pieceInput(int index, int visibleCount) {
    if (index >= visibleCount) return const _SheetTextCell('', height: 42);
    final ok = isOk(measurements[index].text);
    return _SheetInputCell(
      controller: measurements[index],
      numeric: true,
      onChanged: onChanged,
      result: ok,
    );
  }
}

class _SheetMultilineRow extends StatelessWidget {
  const _SheetMultilineRow({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.black87, width: 0.8),
      columnWidths: const {
        0: FixedColumnWidth(170),
        1: FlexColumnWidth(),
      },
      children: [
        TableRow(
          children: [
            _SheetTextCell(label, bold: true, height: 62),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: controller,
                minLines: 2,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QualitySignatureRows extends StatelessWidget {
  const _QualitySignatureRows();

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.black87, width: 0.8),
      columnWidths: const {
        0: FixedColumnWidth(130),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(130),
        3: FlexColumnWidth(),
        4: FixedColumnWidth(130),
        5: FlexColumnWidth(),
      },
      children: const [
        TableRow(
          children: [
            _SheetTextCell('ELABORADO POR', bold: true),
            _SheetTextCell(''),
            _SheetTextCell('APROBADO POR', bold: true),
            _SheetTextCell(''),
            _SheetTextCell('FECHA', bold: true),
            _SheetTextCell(''),
          ],
        ),
        TableRow(
          children: [
            _SheetTextCell('INSPECTOR', bold: true),
            _SheetTextCell(''),
            _SheetTextCell('JEFE DE PRODUCCIÓN', bold: true),
            _SheetTextCell(''),
            _SheetTextCell('JEFE DE CALIDAD', bold: true),
            _SheetTextCell(''),
          ],
        ),
      ],
    );
  }
}

class _SheetTextCell extends StatelessWidget {
  const _SheetTextCell(
    this.text, {
    this.bold = false,
    this.centered = false,
    this.height = 34,
  });

  final String text;
  final bool bold;
  final bool centered;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Align(
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Text(
            text,
            textAlign: centered ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetInputCell extends StatelessWidget {
  const _SheetInputCell({
    required this.controller,
    this.numeric = false,
    this.onChanged,
    this.result,
  });

  final TextEditingController controller;
  final bool numeric;
  final VoidCallback? onChanged;
  final bool? result;

  @override
  Widget build(BuildContext context) {
    final color = result == null
        ? Colors.transparent
        : result!
            ? const Color(0xFFE6F4EA)
            : const Color(0xFFFFE4E2);
    return Container(
      height: 42,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        controller: controller,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        onChanged: (_) => onChanged?.call(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}

class _SheetResultCell extends StatelessWidget {
  const _SheetResultCell({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final int value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF0B6B3A) : const Color(0xFFB42318);
    return Container(
      height: 42,
      color: ok ? const Color(0xFFE6F4EA) : const Color(0xFFFFE4E2),
      child: Center(
        child: Text(
          '$label: $value',
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }
}

const _qualityDateText = '08/2025';

class _QualityHeader extends StatelessWidget {
  const _QualityHeader({required this.order, required this.component});

  final WorkOrderItem order;
  final WorkOrderComponentItem component;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: IntemaColors.border),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFF8FAFD),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          Text(order.code, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(order.clientName),
          Text(component.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('${component.quantityRequired} piezas'),
          if (order.dueDate != null) Text('Entrega: ${_formatDate(order.dueDate!)}'),
        ],
      ),
    );
  }
}

class _MeasurementBox extends StatelessWidget {
  const _MeasurementBox({
    required this.label,
    required this.controller,
    required this.ok,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool? ok;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = ok == null
        ? IntemaColors.border
        : ok!
            ? const Color(0xFF12B76A)
            : const Color(0xFFF04438);
    return SizedBox(
      width: 122,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: ok == null
              ? null
              : Icon(ok! ? Icons.check_circle : Icons.cancel, color: color, size: 18),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: color)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 2)),
        ),
      ),
    );
  }
}

class _ObservationDialog extends StatefulWidget {
  const _ObservationDialog({required this.title});

  final String title;

  @override
  State<_ObservationDialog> createState() => _ObservationDialogState();
}

class _ObservationDialogState extends State<_ObservationDialog> {
  final _observations = TextEditingController();

  @override
  void dispose() {
    _observations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _observations,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Observaciones',
            hintText: 'Motivo, incidencia o comentario',
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, _observations.text.trim()),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.title, required this.maxQuantity});

  final String title;
  final int maxQuantity;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final _quantity = TextEditingController(text: '0');
  final _observations = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _observations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _quantity,
              decoration: InputDecoration(
                labelText: 'Piezas avanzadas en este pase',
                helperText: 'Máximo pendiente: ${widget.maxQuantity}',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observations,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Observación del pare',
                hintText: 'Motivo, incidencia o comentario del pare',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            final value = int.tryParse(_quantity.text) ?? 0;
            if (value <= 0) {
              setState(() => _error = 'Ingresa una cantidad mayor a cero.');
              return;
            }
            if (widget.maxQuantity > 0 && value > widget.maxQuantity) {
              setState(() => _error = 'Solo faltan ${widget.maxQuantity} piezas.');
              return;
            }
            Navigator.pop(context, _QuantityResult(value, 0, _observations.text.trim()));
          },
          child: const Text('Registrar'),
        ),
      ],
    );
  }
}

class _WarehouseIssueDialog extends StatefulWidget {
  const _WarehouseIssueDialog({required this.order});

  final WorkOrderItem order;

  @override
  State<_WarehouseIssueDialog> createState() => _WarehouseIssueDialogState();
}

class _WarehouseIssueDialogState extends State<_WarehouseIssueDialog> {
  final _item = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _cost = TextEditingController(text: '0');
  var _type = 'material';
  var _unit = 'm';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Entrega a ${widget.order.code}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'material', child: Text('Material / componente')),
                DropdownMenuItem(value: 'tool', child: Text('Herramienta')),
              ],
              onChanged: (value) => setState(() {
                _type = value ?? 'material';
                _unit = _defaultWarehouseUnit(_type);
              }),
            ),
            const SizedBox(height: 12),
            TextField(controller: _item, decoration: const InputDecoration(labelText: 'Ítem entregado')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _quantity, decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                  child: _WarehouseUnitDropdown(
                    value: _unit,
                    family: _type,
                    onChanged: (value) => setState(() => _unit = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _cost, decoration: const InputDecoration(labelText: 'Costo unit.'), keyboardType: TextInputType.number)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, {
            'work_order_id': widget.order.id,
            'component_id': null,
            'item_name': _item.text.trim(),
            'issue_type': _type,
            'quantity': double.tryParse(_quantity.text) ?? 1,
            'unit': _unit,
            'unit_cost': double.tryParse(_cost.text) ?? 0,
          }),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Registrar'),
        ),
      ],
    );
  }
}

class _WarehouseMovementDialog extends StatefulWidget {
  const _WarehouseMovementDialog({required this.activeOrders});

  final List<WorkOrderItem> activeOrders;

  @override
  State<_WarehouseMovementDialog> createState() => _WarehouseMovementDialogState();
}

class _WarehouseMovementDialogState extends State<_WarehouseMovementDialog> {
  final _item = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _cost = TextEditingController(text: '0');
  final _supplier = TextEditingController();
  final _invoice = TextEditingController();
  final _requester = TextEditingController();
  final _observations = TextEditingController();
  var _movementType = 'entry';
  var _entryType = 'purchase';
  var _issueType = 'material';
  var _unit = 'm';
  WorkOrderItem? _order;
  String? _error;

  @override
  void dispose() {
    _item.dispose();
    _quantity.dispose();
    _cost.dispose();
    _supplier.dispose();
    _invoice.dispose();
    _requester.dispose();
    _observations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOutput = _movementType == 'output';
    return AlertDialog(
      title: const Text('Registrar movimiento'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'entry',
                    icon: Icon(Icons.input_outlined),
                    label: Text('Entrada'),
                  ),
                  ButtonSegment(
                    value: 'output',
                    icon: Icon(Icons.output_outlined),
                    label: Text('Salida'),
                  ),
                ],
                selected: {_movementType},
                onSelectionChanged: (value) => setState(() {
                  _movementType = value.first;
                  _error = null;
                }),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _issueType,
                decoration: const InputDecoration(labelText: 'Familia'),
                items: const [
                  DropdownMenuItem(value: 'material', child: Text('MATERIAL')),
                  DropdownMenuItem(value: 'fresas', child: Text('FRESAS')),
                  DropdownMenuItem(value: 'placas', child: Text('PLACAS')),
                  DropdownMenuItem(value: 'tool', child: Text('HERRAMIENTA')),
                  DropdownMenuItem(value: 'consumable', child: Text('CONSUMIBLES')),
                  DropdownMenuItem(value: 'epp', child: Text('EPP')),
                  DropdownMenuItem(value: 'gases', child: Text('GASES')),
                  DropdownMenuItem(value: 'soldadura', child: Text('SOLDADURA')),
                  DropdownMenuItem(value: 'perneria', child: Text('PERNERÍA')),
                  DropdownMenuItem(value: 'administrativo', child: Text('ADMINISTRATIVO')),
                ],
                onChanged: (value) => setState(() {
                  _issueType = value ?? 'material';
                  _unit = _defaultWarehouseUnit(_issueType);
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _item,
                decoration: const InputDecoration(
                  labelText: 'Ítem / descripción',
                  hintText: 'Código o descripción del producto',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WarehouseUnitDropdown(
                      value: _unit,
                      family: _issueType,
                      onChanged: (value) => setState(() => _unit = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cost,
                      decoration: const InputDecoration(labelText: 'Costo unit.'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              if (!isOutput) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _entryType,
                  decoration: const InputDecoration(labelText: 'Tipo de entrada'),
                  items: const [
                    DropdownMenuItem(value: 'purchase', child: Text('Compra / factura')),
                    DropdownMenuItem(value: 'return', child: Text('Devolución de almacén')),
                    DropdownMenuItem(value: 'loan_return', child: Text('Retorno de préstamo')),
                    DropdownMenuItem(value: 'adjustment', child: Text('Ajuste de inventario')),
                  ],
                  onChanged: (value) => setState(() => _entryType = value ?? 'purchase'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _supplier,
                        decoration: InputDecoration(
                          labelText: _entryType == 'purchase'
                              ? 'Proveedor'
                              : 'Responsable / persona que devuelve',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _invoice,
                        decoration: const InputDecoration(labelText: 'N° factura'),
                      ),
                    ),
                  ],
                ),
              ],
              if (isOutput) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _requester,
                  decoration: const InputDecoration(labelText: 'Solicitante / técnico'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WorkOrderItem>(
                  value: _order,
                  decoration: const InputDecoration(labelText: 'OIT activa'),
                  items: widget.activeOrders
                      .map(
                        (order) => DropdownMenuItem(
                          value: order,
                          child: Text('${order.code} · ${order.clientName}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _order = value;
                    _error = null;
                  }),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _observations,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observación',
                  hintText: 'Factura, motivo, responsable o comentario',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Registrar'),
        ),
      ],
    );
  }

  void _submit() {
    final itemName = _item.text.trim();
    final quantity = double.tryParse(_quantity.text.trim()) ?? 0;
    if (itemName.length < 2) {
      setState(() => _error = 'Ingresa el nombre del ítem.');
      return;
    }
    if (quantity <= 0) {
      setState(() => _error = 'Ingresa una cantidad mayor a cero.');
      return;
    }
    if (_movementType == 'output' && _order == null) {
      setState(() => _error = 'Selecciona una OIT activa para la salida.');
      return;
    }
    final detailParts = <String>[
      if (_movementType == 'entry') 'Entrada: ${_warehouseEntryTypeLabel(_entryType)}',
      if (_supplier.text.trim().isNotEmpty) 'Proveedor: ${_supplier.text.trim()}',
      if (_invoice.text.trim().isNotEmpty) 'Factura: ${_invoice.text.trim()}',
      if (_requester.text.trim().isNotEmpty) 'Solicitante: ${_requester.text.trim()}',
      if (_observations.text.trim().isNotEmpty) _observations.text.trim(),
    ];
    Navigator.pop(context, {
      'movement_type': _movementType,
      'work_order_id': _order?.id,
      'component_id': null,
      'item_name': itemName,
      'issue_type': _issueType,
      'quantity': quantity,
      'unit': _unit,
      'unit_cost': double.tryParse(_cost.text.trim()) ?? 0,
      'observations': detailParts.isEmpty ? null : detailParts.join(' | '),
    });
  }
}

class _WarehouseItemDialog extends StatefulWidget {
  const _WarehouseItemDialog();

  @override
  State<_WarehouseItemDialog> createState() => _WarehouseItemDialogState();
}

class _WarehouseItemDialogState extends State<_WarehouseItemDialog> {
  final _code = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _minimumStock = TextEditingController(text: '0');
  final _cost = TextEditingController(text: '0');
  var _family = 'material';
  var _unit = 'm';
  var _requiresOit = true;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _description.dispose();
    _location.dispose();
    _minimumStock.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo ítem de inventario'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      decoration: const InputDecoration(
                        labelText: 'Código interno',
                        hintText: 'Ej. MAT-BARRA-001',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _family,
                      decoration: const InputDecoration(labelText: 'Familia'),
                      items: const [
                        DropdownMenuItem(value: 'material', child: Text('MATERIAL')),
                        DropdownMenuItem(value: 'fresas', child: Text('FRESAS')),
                        DropdownMenuItem(value: 'placas', child: Text('PLACAS')),
                        DropdownMenuItem(value: 'tool', child: Text('HERRAMIENTA')),
                        DropdownMenuItem(value: 'consumable', child: Text('CONSUMIBLES')),
                        DropdownMenuItem(value: 'epp', child: Text('EPP')),
                        DropdownMenuItem(value: 'gases', child: Text('GASES')),
                        DropdownMenuItem(value: 'soldadura', child: Text('SOLDADURA')),
                        DropdownMenuItem(value: 'perneria', child: Text('PERNERÍA')),
                        DropdownMenuItem(value: 'administrativo', child: Text('ADMINISTRATIVO')),
                      ],
                      onChanged: (value) => setState(() {
                        _family = value ?? 'material';
                        _unit = _defaultWarehouseUnit(_family);
                        _requiresOit = _family == 'material' ||
                            _family == 'fresas' ||
                            _family == 'placas';
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Nombre exacto del producto',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _WarehouseUnitDropdown(
                      value: _unit,
                      family: _family,
                      onChanged: (value) => setState(() => _unit = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minimumStock,
                      decoration: const InputDecoration(labelText: 'Stock mínimo'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cost,
                      decoration: const InputDecoration(labelText: 'Costo referencial'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Ubicación',
                  hintText: 'Estante, zona o almacén',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _requiresOit,
                onChanged: (value) => setState(() => _requiresOit = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Requiere OIT para salida'),
                subtitle: const Text('Útil para materiales, fresas, placas o ítems cargados al costo de la OIT.'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar ítem'),
        ),
      ],
    );
  }

  void _submit() {
    if (_description.text.trim().length < 2) {
      setState(() => _error = 'Ingresa la descripción del ítem.');
      return;
    }
    Navigator.pop(context, {
      'code': _code.text.trim(),
      'description': _description.text.trim(),
      'family': _family,
      'unit': _unit,
      'minimum_stock': double.tryParse(_minimumStock.text.trim()) ?? 0,
      'reference_cost': double.tryParse(_cost.text.trim()) ?? 0,
      'location': _location.text.trim(),
      'requires_oit': _requiresOit,
    });
  }
}

class _WarehouseUnitDropdown extends StatelessWidget {
  const _WarehouseUnitDropdown({
    required this.value,
    required this.family,
    required this.onChanged,
  });

  final String value;
  final String family;
  final ValueChanged<String> onChanged;

  static const materialUnits = [
    'm',
    'cm',
    'mm',
    'm²',
    'cm²',
    'mm²',
    'm³',
    'cm³',
    'mm³',
    'kg',
    'g',
    'L',
    'ml',
    'und',
  ];

  static const simpleUnits = [
    'und',
    'jgo',
    'par',
    'caja',
    'paq',
    'kg',
    'g',
    'L',
    'ml',
  ];

  static const allUnits = [
    'und',
    'm',
    'cm',
    'mm',
    'm²',
    'cm²',
    'mm²',
    'm³',
    'cm³',
    'mm³',
    'kg',
    'g',
    'L',
    'ml',
    'jgo',
    'par',
    'caja',
    'paq',
  ];

  @override
  Widget build(BuildContext context) {
    final units = family == 'material' ? materialUnits : simpleUnits;
    final safeUnits = units.contains(value) ? units : allUnits;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Unidad'),
      items: safeUnits
          .map(
            (unit) => DropdownMenuItem(
              value: unit,
              child: Text(unit),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

String _defaultWarehouseUnit(String family) {
  return family == 'material' ? 'm' : 'und';
}

String _warehouseEntryTypeLabel(String type) {
  switch (type) {
    case 'return':
      return 'Devolución de almacén';
    case 'loan_return':
      return 'Retorno de préstamo';
    case 'adjustment':
      return 'Ajuste de inventario';
    default:
      return 'Compra / factura';
  }
}

class _WarehouseMovementsTable extends StatelessWidget {
  const _WarehouseMovementsTable({required this.entries});

  final List<({WorkOrderItem order, WarehouseIssueItem issue})> entries;

  @override
  Widget build(BuildContext context) {
    return _PlainDataTable(
      minWidth: 1200,
      columns: const [
        _PlainColumn(label: 'Movimiento', flex: 1),
        _PlainColumn(label: 'Fecha / hora', flex: 2),
        _PlainColumn(label: 'Descripción', flex: 3),
        _PlainColumn(label: 'Tipo', flex: 2),
        _PlainColumn(label: 'OIT', flex: 2),
        _PlainColumn(label: 'Cliente', flex: 2),
        _PlainColumn(label: 'Cantidad', flex: 2),
        _PlainColumn(label: 'Observación', flex: 3),
        _PlainColumn(label: 'Costo total', flex: 2),
      ],
      rows: entries
          .map(
            (entry) => _PlainRow(
              cells: [
                const _MovementBadge(label: 'Salida', icon: Icons.output_outlined),
                Text(_formatDateTime(entry.issue.issuedAt)),
                Text(
                  entry.issue.itemName.trim().isEmpty
                      ? 'Ítem sin nombre'
                      : entry.issue.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(_warehouseIssueTypeLabel(entry.issue.issueType)),
                Text(entry.order.code),
                Text(entry.order.clientName),
                Text('${_formatQuantity(entry.issue.quantity)} ${entry.issue.unit}'),
                Text(
                  entry.issue.observations?.trim().isEmpty ?? true
                      ? '-'
                      : entry.issue.observations!,
                ),
                Text('S/ ${entry.issue.totalCost.toStringAsFixed(2)}'),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _WarehouseInventoryTable extends StatelessWidget {
  const _WarehouseInventoryTable({required this.records});

  final List<
      ({
        String itemName,
        String type,
        double quantity,
        String unit,
        double unitCost,
        double totalCost,
        String lastOrder,
        int movements,
      })> records;

  @override
  Widget build(BuildContext context) {
    return _PlainDataTable(
      minWidth: 1160,
      columns: const [
        _PlainColumn(label: 'Descripción', flex: 4),
        _PlainColumn(label: 'Familia', flex: 2),
        _PlainColumn(label: 'Entradas', flex: 2),
        _PlainColumn(label: 'Salidas', flex: 2),
        _PlainColumn(label: 'Stock actual', flex: 2),
        _PlainColumn(label: 'Costo unit.', flex: 2),
        _PlainColumn(label: 'Costo total', flex: 2),
        _PlainColumn(label: 'Última OIT', flex: 2),
      ],
      rows: records
          .map(
            (record) => _PlainRow(
              cells: [
                Text(record.itemName, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(record.type),
                const Text('-'),
                Text('${_formatQuantity(record.quantity)} ${record.unit}'),
                Text('${_formatQuantity(record.quantity)} ${record.unit}'),
                Text('S/ ${record.unitCost.toStringAsFixed(2)}'),
                Text('S/ ${record.totalCost.toStringAsFixed(2)}'),
                Text(record.lastOrder),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _PlainDataTable extends StatelessWidget {
  const _PlainDataTable({
    required this.columns,
    required this.rows,
    this.minWidth = 900,
  });

  final List<_PlainColumn> columns;
  final List<_PlainRow> rows;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  color: const Color(0xFFF6F8FB),
                  child: Row(
                    children: [
                      for (final column in columns)
                        Expanded(
                          flex: column.flex,
                          child: Text(
                            column.label,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (final row in rows)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFD8DEE8)),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < row.cells.length; i++)
                          Expanded(
                            flex: columns[i].flex,
                            child: row.cells[i],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlainColumn {
  const _PlainColumn({required this.label, required this.flex});

  final String label;
  final int flex;
}

class _PlainRow {
  const _PlainRow({required this.cells});

  final List<Widget> cells;
}

class _MovementBadge extends StatelessWidget {
  const _MovementBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: IntemaColors.navy, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: IntemaColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    final percent = (normalized * 100).round();
    return Row(
      children: [
        SizedBox(
          width: 135,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 9,
              backgroundColor: const Color(0xFFE9EEF7),
              valueColor: const AlwaysStoppedAnimation<Color>(IntemaColors.navy),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            '$percent%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = _statusChipColors(status);
    return Chip(
      label: Text(_statusLabel(status)),
      labelStyle: TextStyle(color: colors.foreground, fontWeight: FontWeight.w800),
      backgroundColor: colors.background,
      side: BorderSide(color: colors.border),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusChipColors {
  const _StatusChipColors({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

class _DueStatusChip extends StatelessWidget {
  const _DueStatusChip({required this.order});

  final WorkOrderItem order;

  @override
  Widget build(BuildContext context) {
    if (order.status == 'finished') {
      return const _SignalChip(
        label: 'Entregado',
        foreground: Color(0xFF0B6B3A),
        background: Color(0xFFE6F4EA),
        border: Color(0xFF8ACCA8),
      );
    }

    final dueDate = order.dueDate;
    if (dueDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (today.isAfter(due)) {
      return const _SignalChip(
        label: 'Vencido',
        foreground: Color(0xFFB42318),
        background: Color(0xFFFFE4E2),
        border: Color(0xFFFDA29B),
      );
    }

    final approvedAt = order.approvedAt;
    if (approvedAt == null) return const SizedBox.shrink();

    final approved = DateTime(approvedAt.year, approvedAt.month, approvedAt.day);
    final totalWorkingDays = _workingDaysBetween(approved, due);
    final elapsedWorkingDays = _workingDaysBetween(approved, today);
    final shouldWarn =
        totalWorkingDays > 0 && elapsedWorkingDays >= (totalWorkingDays / 2).ceil();

    if (shouldWarn) {
      return const _SignalChip(
        label: 'Próximo a vencer',
        foreground: Color(0xFF92400E),
        background: Color(0xFFFFF4D6),
        border: Color(0xFFF6C453),
      );
    }
    return const SizedBox.shrink();
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w800),
      backgroundColor: background,
      side: BorderSide(color: border),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityResult {
  _QuantityResult(this.good, this.rejected, this.observations);

  final int good;
  final int rejected;
  final String observations;
}

bool _hasDesign(WorkOrderItem order) => order.components.any((component) => component.status.contains('design'));

bool _hasProduction(WorkOrderItem order) =>
    order.components.any((component) => component.status.contains('production') || component.routes.isNotEmpty);

bool _isActive(WorkOrderItem order) => {
      'pending_design',
      'design_in_progress',
      'design_paused',
      'pending_production',
      'production_planned',
      'production_in_progress',
      'pending_quality',
    }.contains(order.status);

bool _canDeliver(WorkOrderItem order) =>
    order.status != 'finished' &&
    order.components.isNotEmpty &&
    order.components.every((component) => {'pending_quality', 'finished'}.contains(component.status));

bool _matchesStageFilter(WorkOrderItem order, String filter) {
  switch (filter) {
    case 'design':
      return _hasDesign(order);
    case 'production':
      return _hasProduction(order);
    case 'quality':
      return order.components.any((component) => component.status == 'pending_quality');
    case 'finished':
      return order.status == 'finished';
    default:
      return true;
  }
}

String _oitStageTitle(String filter) {
  switch (filter) {
    case 'design':
      return 'OIT en diseño';
    case 'production':
      return 'OIT en producción';
    case 'quality':
      return 'OIT en control de calidad';
    case 'finished':
      return 'OIT entregadas';
    default:
      return 'OIT registradas';
  }
}

String _warehouseTabTitle(String tab) {
  switch (tab) {
    case 'kardex':
      return 'Tabla de movimientos';
    default:
      return 'Tabla de inventario';
  }
}

String _warehouseEmptyText(String tab) {
  switch (tab) {
    case 'kardex':
      return 'Aún no hay movimientos registrados. Usa "Registrar movimiento" para crear una entrada o salida.';
    default:
      return 'Aún no hay ítems en inventario. Se llenará con las entradas y el stock maestro.';
  }
}

String _warehouseIssueTypeLabel(String type) {
  switch (type) {
    case 'tool':
      return 'HERRAMIENTA';
    case 'material':
      return 'MATERIAL';
    case 'fresas':
      return 'FRESAS';
    case 'placas':
      return 'PLACAS';
    case 'epp':
      return 'EPP';
    case 'gases':
      return 'GASES';
    case 'soldadura':
      return 'SOLDADURA';
    case 'perneria':
      return 'PERNERÍA';
    case 'administrativo':
      return 'ADMINISTRATIVO';
    case 'consumable':
      return 'CONSUMIBLES';
    default:
      return type.trim().isEmpty ? 'SIN FAMILIA' : type.toUpperCase();
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

double _orderProgress(WorkOrderItem order) {
  if (order.components.isEmpty) return order.status == 'finished' ? 1 : 0;
  final total = order.components.fold<double>(
    0,
    (sum, component) => sum + _componentProgress(component),
  );
  return total / order.components.length;
}

double _componentProgress(WorkOrderComponentItem component) {
  switch (component.status) {
    case 'draft':
      return 0;
    case 'pending_design':
      return 0.05;
    case 'design_in_progress':
      return 0.20;
    case 'design_paused':
      return 0.20;
    case 'pending_production':
      return 0.35;
    case 'production_planned':
      return 0.50;
    case 'production_in_progress':
      final produced = component.quantityRequired <= 0
          ? 0.0
          : component.quantityCompleted / component.quantityRequired;
      return 0.55 + (produced.clamp(0.0, 1.0).toDouble() * 0.30);
    case 'pending_quality':
      return 0.90;
    case 'finished':
      return 1;
    default:
      return 0;
  }
}

String _areaStatusFor(String area, WorkOrderComponentItem component) {
  switch (area) {
    case 'design':
      if (component.status == 'pending_design' ||
          component.status == 'design_in_progress' ||
          component.status == 'design_paused') {
        return component.status;
      }
      return 'finished';
    case 'production':
      if (component.status == 'pending_production' ||
          component.status == 'production_planned' ||
          component.status == 'production_in_progress') {
        return component.status;
      }
      return 'finished';
    case 'quality':
      if (component.status == 'pending_quality') {
        return component.qualityInspections.isEmpty ? 'pending_quality' : 'quality_in_progress';
      }
      if (component.status == 'finished') return 'finished';
      return component.status;
    default:
      return component.status;
  }
}

double _areaProgressFor(String area, WorkOrderComponentItem component) {
  switch (area) {
    case 'design':
      if (component.status == 'pending_design') return 0;
      if (component.status == 'design_in_progress' || component.status == 'design_paused') return 0.5;
      return 1;
    case 'production':
      if (component.status == 'pending_production') return 0;
      if (component.status == 'production_planned') return 0;
      if (component.status == 'production_in_progress') return _productionProgress(component);
      return 1;
    case 'quality':
      if (component.status == 'pending_quality') {
        return component.qualityInspections.isEmpty ? 0 : 0.5;
      }
      if (component.status == 'finished') return 1;
      return _componentProgress(component);
    default:
      return _componentProgress(component);
  }
}

double _productionProgress(WorkOrderComponentItem component) {
  if (component.status == 'pending_quality' || component.status == 'finished') return 1;
  if (component.routes.isEmpty || component.quantityRequired <= 0) return 0;
  final requiredAcrossRoute = component.quantityRequired * component.routes.length;
  final completedAcrossRoute = component.routes.fold<int>(
    0,
    (total, route) => total + _routeCompletedQuantity(route).clamp(0, component.quantityRequired).toInt(),
  );
  return (completedAcrossRoute / requiredAcrossRoute).clamp(0.0, 1.0).toDouble();
}

String _formatSeconds(int value) {
  final minutes = value ~/ 60;
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours == 0) return '${remaining}min';
  return '${hours}h ${remaining}min';
}

String _designElapsedLabel(WorkOrderComponentItem component) {
  var seconds = component.designSeconds;
  if (component.status == 'design_in_progress' && component.designStartedAt != null) {
    seconds += DateTime.now().difference(component.designStartedAt!).inSeconds;
  }
  return _formatSeconds(seconds);
}

String _routeElapsedLabel(RouteStepItem route, String runType) {
  final storedSeconds = route.runs.fold<int>(
    0,
    (total, run) => run.runType != runType || run.status == 'running'
        ? total
        : total + run.elapsedSeconds,
  );
  final running =
      runType == 'setup' ? route.runningSetupRun : route.runningRun;
  if (running?.startedAt != null) {
    final liveSeconds = DateTime.now().difference(running!.startedAt!).inSeconds;
    return _formatSeconds(storedSeconds + liveSeconds);
  }
  if (storedSeconds == 0) return '-';
  return _formatSeconds(storedSeconds);
}

int _routeCompletedQuantity(RouteStepItem route) {
  return route.runs.fold<int>(
    0,
    (total, run) =>
        run.runType != 'machining' || run.status == 'running'
            ? total
            : total + run.goodQuantity,
  );
}

bool _routePlanLocked(RouteStepItem route) => route.status != 'pending' || route.runs.isNotEmpty;

int _remainingRouteQuantity(RouteStepItem route, int requiredQuantity) {
  if (requiredQuantity <= 0) return 0;
  return (requiredQuantity - _routeCompletedQuantity(route)).clamp(0, requiredQuantity).toInt();
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '-';
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${_formatDate(value)} $hour:$minute';
}

int _workingDaysBetween(DateTime start, DateTime end) {
  if (!end.isAfter(start)) return 0;
  var count = 0;
  var current = DateTime(start.year, start.month, start.day).add(const Duration(days: 1));
  final limit = DateTime(end.year, end.month, end.day);
  while (!current.isAfter(limit)) {
    if (current.weekday != DateTime.sunday) count++;
    current = current.add(const Duration(days: 1));
  }
  return count;
}

String _statusLabel(String status) {
  const labels = {
    'draft': 'Borrador',
    'pending_design': 'Pendiente diseño',
    'design_in_progress': 'Diseño en curso',
    'design_paused': 'Diseño pausado',
    'pending_production': 'Pendiente producción',
    'production_planned': 'Producción planificada',
    'production_in_progress': 'Producción en curso',
    'pending_quality': 'Pendiente calidad',
    'quality_in_progress': 'Calidad en proceso',
    'finished': 'Terminado',
    'pending': 'Pendiente',
    'running': 'En curso',
    'paused': 'Pausado',
    'setup_running': 'Preparación en curso',
    'setup_paused': 'Preparación pausada',
    'setup_finished': 'Preparación lista',
  };
  return labels[status] ?? status;
}

_StatusChipColors _statusChipColors(String status) {
  switch (status) {
    case 'finished':
      return const _StatusChipColors(
        foreground: Color(0xFF087443),
        background: Color(0xFFE6F4EA),
        border: Color(0xFF8ACCA8),
      );
    case 'running':
    case 'design_in_progress':
    case 'production_in_progress':
    case 'quality_in_progress':
      return const _StatusChipColors(
        foreground: Color(0xFF0B3B8F),
        background: Color(0xFFE7F0FF),
        border: Color(0xFF9CC4FF),
      );
    case 'paused':
    case 'design_paused':
      return const _StatusChipColors(
        foreground: Color(0xFF92400E),
        background: Color(0xFFFFF4C2),
        border: Color(0xFFFACC15),
      );
    case 'setup_running':
      return const _StatusChipColors(
        foreground: Color(0xFFB42318),
        background: Color(0xFFFFE4E2),
        border: Color(0xFFFDA29B),
      );
    case 'setup_paused':
      return const _StatusChipColors(
        foreground: Color(0xFF92400E),
        background: Color(0xFFFFF4C2),
        border: Color(0xFFFACC15),
      );
    case 'setup_finished':
    case 'production_planned':
      return const _StatusChipColors(
        foreground: Color(0xFF0B3B8F),
        background: Color(0xFFE7ECFB),
        border: Color(0xFFA9B8F3),
      );
    case 'pending':
    case 'draft':
    case 'pending_design':
    case 'pending_production':
    case 'pending_quality':
    default:
      return const _StatusChipColors(
        foreground: Color(0xFF344054),
        background: Color(0xFFF2F4F7),
        border: IntemaColors.border,
      );
  }
}
