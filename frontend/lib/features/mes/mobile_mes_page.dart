import 'package:flutter/material.dart';

import '../../core/auth/session_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/intema_theme.dart';
import 'mes_models.dart';
import 'mes_repository.dart';

class MobileMesPage extends StatefulWidget {
  const MobileMesPage({super.key, required this.session});

  final SessionController session;

  @override
  State<MobileMesPage> createState() => _MobileMesPageState();
}

class _MobileMesPageState extends State<MobileMesPage> {
  late final MesRepository _repository;
  var _selectedIndex = 0;
  var _loading = true;
  String? _error;
  String _query = '';
  List<WorkOrderItem> _orders = [];

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
      if (!mounted) return;
      setState(() => _orders = orders);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar la app móvil.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _MobileHeader(
              userName: widget.session.currentUser?.fullName ?? 'Usuario',
              onRefresh: _load,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _MobileError(message: _error!, onRetry: _load)
                      : _body(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: const Color(0xFFEDEBFF),
        indicatorColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Planta',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Ordenes',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Escaner',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Metricas',
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_selectedIndex) {
      case 1:
        return _OrdersMobileView(
          orders: _filteredOrders,
          query: _query,
          onQueryChanged: (value) => setState(() => _query = value),
        );
      case 2:
        return _ScannerMobileView(orders: _orders);
      case 3:
        return _MetricsMobileView(orders: _orders);
      default:
        return _PlantMobileView(orders: _orders);
    }
  }

  List<WorkOrderItem> get _filteredOrders {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _orders;
    return _orders.where((order) {
      final componentNames = order.components.map((item) => item.name).join(' ');
      return '${order.code} ${order.clientName} $componentNames'
          .toLowerCase()
          .contains(needle);
    }).toList();
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.userName, required this.onRefresh});

  final String userName;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final initials = userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Intema MES',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'PLANTA PRINCIPAL  •  TURNO A',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7A8494),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
                CircleAvatar(
                  backgroundColor: const Color(0xFFEDEBFF),
                  foregroundColor: const Color(0xFF5B45E8),
                  child: Text(initials.isEmpty ? 'IN' : initials),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: const [
                Expanded(
                  child: _MobileMetricCard(
                    title: 'EFICIENCIA',
                    value: '92%',
                    color: Color(0xFF5B45E8),
                    background: Color(0xFFF0EFFF),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MobileMetricCard(
                    title: 'TERMINADAS',
                    value: '01',
                    color: Color(0xFF087A55),
                    background: Color(0xFFEFFFF8),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MobileMetricCard(
                    title: 'ATRASADAS',
                    value: '00',
                    color: Color(0xFF8A3D10),
                    background: Color(0xFFFFFAEA),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileMetricCard extends StatelessWidget {
  const _MobileMetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.background,
  });

  final String title;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantMobileView extends StatelessWidget {
  const _PlantMobileView({required this.orders});

  final List<WorkOrderItem> orders;

  @override
  Widget build(BuildContext context) {
    final stages = [
      _StageSummary('Diseno', Icons.design_services_outlined, _countByStatus('pending_design') + _countByStatus('design_in_progress')),
      _StageSummary('Materiales', Icons.inventory_2_outlined, orders.where((order) => order.warehouseIssues.isNotEmpty).length),
      _StageSummary('Corte', Icons.content_cut_outlined, _countByProcess('Corte')),
      _StageSummary('Maquinado', Icons.precision_manufacturing_outlined, _countByProcess('Mecanizado')),
      _StageSummary('Soldadura', Icons.handyman_outlined, _countByProcess('Soldadura')),
      _StageSummary('Pintura', Icons.format_paint_outlined, _countByProcess('Acabado')),
      _StageSummary('Calidad', Icons.fact_check_outlined, _countByStatus('pending_quality')),
      _StageSummary('Despacho', Icons.local_shipping_outlined, _countByStatus('delivered')),
    ];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _MobilePanel(
          child: Column(
            children: [
              for (final stage in stages) _StageProgressRow(stage: stage),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MobilePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tiempos promedio de procesamiento',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Datos preliminares calculados desde trabajos registrados',
                style: TextStyle(color: Color(0xFF9AA1AE)),
              ),
              const SizedBox(height: 14),
              _AverageRow(label: 'Diseno', minutes: _averageDesignMinutes()),
              _AverageRow(label: 'Produccion', minutes: _averageProductionMinutes()),
              _AverageRow(label: 'Calidad', minutes: _countByStatus('finished_quality') * 8),
            ],
          ),
        ),
      ],
    );
  }

  int _countByStatus(String status) {
    return orders.fold(0, (sum, order) {
      return sum + order.components.where((item) => item.status == status).length;
    });
  }

  int _countByProcess(String process) {
    return orders.fold(0, (sum, order) {
      return sum +
          order.components.where((component) {
            return component.routes.any(
              (step) => step.processName.toLowerCase().contains(process.toLowerCase()),
            );
          }).length;
    });
  }

  int _averageDesignMinutes() {
    final values = orders
        .expand((order) => order.components)
        .where((component) => component.designSeconds > 0)
        .map((component) => component.designSeconds ~/ 60)
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) ~/ values.length;
  }

  int _averageProductionMinutes() {
    final values = orders
        .expand((order) => order.components)
        .expand((component) => component.routes)
        .expand((route) => route.runs)
        .where((run) => run.elapsedSeconds > 0)
        .map((run) => run.elapsedSeconds ~/ 60)
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) ~/ values.length;
  }
}

class _StageSummary {
  _StageSummary(this.name, this.icon, this.count);

  final String name;
  final IconData icon;
  final int count;
}

class _StageProgressRow extends StatelessWidget {
  const _StageProgressRow({required this.stage});

  final _StageSummary stage;

  @override
  Widget build(BuildContext context) {
    final progress = stage.count == 0 ? 0.0 : 1.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Row(
              children: [
                Icon(stage.icon, size: 18, color: IntemaColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stage.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 14,
                color: const Color(0xFF5B45E8),
                backgroundColor: const Color(0xFFE6EAF1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              '${stage.count} OT',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: stage.count == 0 ? const Color(0xFFADB4C0) : const Color(0xFF5B45E8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AverageRow extends StatelessWidget {
  const _AverageRow({required this.label, required this.minutes});

  final String label;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          const CircleAvatar(radius: 5, backgroundColor: Color(0xFFE18700)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 17))),
          Text(
            '$minutes mins',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _OrdersMobileView extends StatelessWidget {
  const _OrdersMobileView({
    required this.orders,
    required this.query,
    required this.onQueryChanged,
  });

  final List<WorkOrderItem> orders;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        TextField(
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar OT, cliente, pieza...',
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              _FilterChip(label: 'Todos', selected: true),
              _FilterChip(label: 'Activos'),
              _FilterChip(label: 'Prioritarios'),
              _FilterChip(label: 'Completados'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (orders.isEmpty)
          const _MobilePanel(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: Text('No hay ordenes para mostrar.')),
            ),
          )
        else
          for (final order in orders.take(20)) _MobileOrderCard(order: order),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: const Color(0xFFEDEBFF),
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF5B45E8) : const Color(0xFF6B7280),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MobileOrderCard extends StatelessWidget {
  const _MobileOrderCard({required this.order});

  final WorkOrderItem order;

  @override
  Widget build(BuildContext context) {
    final progress = _orderProgress(order);
    final due = order.dueDate == null ? '-' : '${order.dueDate!.day}/${order.dueDate!.month}/${order.dueDate!.year}';
    final phase = _phaseLabel(order);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E4EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEBFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.code,
                  style: const TextStyle(
                    color: Color(0xFF5B45E8),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  order.clientName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              _PriorityBadge(priority: order.priority),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            order.components.isEmpty ? order.description : order.components.first.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SmallInfo(label: 'Fase actual', value: phase),
              ),
              _SmallInfo(label: 'Entrega', value: due, alignEnd: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Progreso',
                style: TextStyle(color: Color(0xFF8E96A3), fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFF5B45E8),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: const Color(0xFF5B45E8),
              backgroundColor: const Color(0xFFE6EAF1),
            ),
          ),
        ],
      ),
    );
  }

  double _orderProgress(WorkOrderItem order) {
    final components = order.components;
    if (components.isEmpty) return 0;
    final total = components.length * 5;
    var points = 0;
    for (final component in components) {
      if (component.status == 'pending_design') points += 1;
      if (component.status.contains('design')) points += 2;
      if (component.status.contains('production')) points += 3;
      if (component.status.contains('quality')) points += 4;
      if (component.status == 'finished_quality' || component.status == 'delivered') points += 5;
    }
    return (points / total).clamp(0, 1).toDouble();
  }

  String _phaseLabel(WorkOrderItem order) {
    final status = order.components.isEmpty ? order.status : order.components.first.status;
    if (status.contains('design')) return 'Diseño';
    if (status.contains('production')) return 'Produccion';
    if (status.contains('quality')) return 'Calidad';
    if (status == 'delivered') return 'Despacho';
    return 'OIT';
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final label = priority.isEmpty ? 'Normal' : priority;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: IntemaColors.blue,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9AA1AE), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ScannerMobileView extends StatelessWidget {
  const _ScannerMobileView({required this.orders});

  final List<WorkOrderItem> orders;

  @override
  Widget build(BuildContext context) {
    final active = orders.where((order) => order.components.isNotEmpty).take(4).toList();
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Modulo de Escaner QR / Barras',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Terminal de planta para encontrar OIT, registrar operaciones y asociar movimientos.',
          style: TextStyle(fontSize: 16, color: Color(0xFF8E96A3)),
        ),
        const SizedBox(height: 26),
        const Text(
          '1. Selecciona la pieza u orden a escanear:',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final order in active)
              SizedBox(
                width: 154,
                child: _ScanTargetCard(order: order),
              ),
          ],
        ),
        if (active.isEmpty)
          const _MobilePanel(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No hay OIT activas para escanear.'),
            ),
          ),
      ],
    );
  }
}

class _ScanTargetCard extends StatelessWidget {
  const _ScanTargetCard({required this.order});

  final WorkOrderItem order;

  @override
  Widget build(BuildContext context) {
    final componentName = order.components.isEmpty ? order.description : order.components.first.name;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E4EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.code,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: IntemaColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            componentName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _MetricsMobileView extends StatelessWidget {
  const _MetricsMobileView({required this.orders});

  final List<WorkOrderItem> orders;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _MobilePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exportacion rapida',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vista movil para compartir datos resumidos. El Excel/PDF formal queda para PC.',
                style: TextStyle(color: Color(0xFF8E96A3)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Guardar / Compartir CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B45E8),
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Vista previa de datos de ordenes',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        _MobilePanel(
          padding: EdgeInsets.zero,
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.1),
              1: FlexColumnWidth(1.6),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1),
            },
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Color(0xFFE9EEF7)),
                children: [
                  _TableCellText('OT', heading: true),
                  _TableCellText('Pieza', heading: true),
                  _TableCellText('Fase', heading: true),
                  _TableCellText('Entrega', heading: true),
                ],
              ),
              for (final order in orders.take(6))
                TableRow(
                  children: [
                    _TableCellText(order.code),
                    _TableCellText(order.components.isEmpty ? order.description : order.components.first.name),
                    _TableCellText(_phase(order)),
                    _TableCellText(order.dueDate == null ? '-' : '${order.dueDate!.day}/${order.dueDate!.month}'),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _phase(WorkOrderItem order) {
    final status = order.components.isEmpty ? order.status : order.components.first.status;
    if (status.contains('design')) return 'Diseno';
    if (status.contains('production')) return 'Produccion';
    if (status.contains('quality')) return 'Calidad';
    if (status == 'delivered') return 'Completado';
    return 'OIT';
  }
}

class _TableCellText extends StatelessWidget {
  const _TableCellText(this.text, {this.heading = false});

  final String text;
  final bool heading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: heading ? FontWeight.w800 : FontWeight.w500,
          color: heading ? const Color(0xFF374151) : const Color(0xFF111827),
        ),
      ),
    );
  }
}

class _MobilePanel extends StatelessWidget {
  const _MobilePanel({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E4EC)),
      ),
      child: child,
    );
  }
}

class _MobileError extends StatelessWidget {
  const _MobileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
