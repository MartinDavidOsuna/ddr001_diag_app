import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/common_widgets.dart';
import '../../domain/enums/app_enums.dart';
import '../../domain/models/app_models.dart';

String statusLabel(InspectionStatus s) => switch (s) {
  InspectionStatus.pending => 'Pendiente',
  InspectionStatus.inProgress => 'En proceso',
  InspectionStatus.completed => 'Terminado',
  InspectionStatus.scheduled => 'Programado',
  InspectionStatus.notRequired => 'No requerido',
  InspectionStatus.returned => 'Devuelto',
  InspectionStatus.validated => 'Validado',
};
String syncLabel(SyncStatus s) => switch (s) {
  SyncStatus.local => 'Guardado localmente',
  SyncStatus.pending => 'Sin sincronizar',
  SyncStatus.synced => 'Sincronizado',
  SyncStatus.returned => 'Devuelto',
  SyncStatus.validated => 'Validado',
};

class HydrantsPage extends StatefulWidget {
  const HydrantsPage({super.key});
  @override
  State<HydrantsPage> createState() => _HydrantsPageState();
}

class _HydrantsPageState extends State<HydrantsPage> {
  String query = '', filter = 'Todos';
  bool matches(Hydrant h) {
    final text = '${h.code} ${h.locality} ${h.parcel}'.toLowerCase().contains(
      query.toLowerCase(),
    );
    final state =
        filter == 'Todos' ||
        filter == 'F02-A' && h.f02a.status != InspectionStatus.completed ||
        filter == 'F02-B' && h.f02b.status != InspectionStatus.notRequired ||
        filter == 'Pendientes' && h.f02a.status == InspectionStatus.pending ||
        filter == 'En proceso' &&
            (h.f02a.status == InspectionStatus.inProgress ||
                h.f02b.status == InspectionStatus.inProgress) ||
        filter == 'Sin sincronizar' && h.syncStatus != SyncStatus.synced;
    return text && state;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.hydrants.where(matches).toList();
    return Scaffold(
      appBar: AppPageHeader(
        title: 'Hidrantes',
        subtitle: '${state.hydrants.length} asignados',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ConnectionBadge(online: state.online),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          state.trace('new_survey_open', 'Abrir nuevo levantamiento');
          context.push('/new-survey');
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('NUEVO LEVANTAMIENTO'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar código, localidad, parcela...',
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children:
                  [
                        'Todos',
                        'F02-A',
                        'F02-B',
                        'Pendientes',
                        'En proceso',
                        'Sin sincronizar',
                      ]
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: filter == f,
                            onSelected: (_) => setState(() => filter = f),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${items.length} resultados',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (_, i) => HydrantCard(
                hydrant: items[i],
                onTap: () {
                  state.trace(
                    'hydrant_open',
                    'Abrir ficha de hidrante',
                    hydrantId: items[i].id,
                  );
                  context.push('/hydrants/${items[i].id}');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HydrantCard extends StatelessWidget {
  const HydrantCard({required this.hydrant, required this.onTap, super.key});
  final Hydrant hydrant;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isB = hydrant.f02b.status != InspectionStatus.notRequired;
    final summary = isB ? hydrant.f02b : hydrant.f02a;
    final color = isB ? AppColors.violet : AppColors.teal;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hydrant.code,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  StatusBadge(
                    syncLabel(hydrant.syncStatus),
                    color:
                        hydrant.syncStatus == SyncStatus.synced ||
                            hydrant.syncStatus == SyncStatus.validated
                        ? AppColors.green
                        : AppColors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${hydrant.locality} · ${hydrant.parcel}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  StatusBadge(isB ? 'F02-B' : 'F02-A', color: color),
                  StatusBadge(statusLabel(summary.status), color: color),
                  StatusBadge(
                    hydrant.priority == PriorityLevel.high
                        ? 'Alta'
                        : hydrant.priority == PriorityLevel.medium
                        ? 'Media'
                        : 'Baja',
                    color: AppColors.orange,
                  ),
                ],
              ),
              if (summary.progress > 0 && summary.progress < 1) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: summary.progress,
                  color: color,
                  backgroundColor: AppColors.border,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HydrantDetailPage extends StatelessWidget {
  const HydrantDetailPage({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final h = state.hydrant(id);
    return Scaffold(
      appBar: AppPageHeader(title: h.code, subtitle: h.locality),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        h.code,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    StatusBadge(
                      syncLabel(h.syncStatus),
                      color: AppColors.green,
                    ),
                  ],
                ),
                Text(
                  '${h.locality} · ${h.parcel} · Hidrante inteligente',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DiagnosticCard(
            type: 'F02-A — Diagnóstico visual',
            summary: h.f02a,
            color: AppColors.teal,
            onPressed: () => context.push('/inspection/$id/a'),
          ),
          const SizedBox(height: 13),
          DiagnosticCard(
            type: 'F02-B — Diagnóstico técnico',
            summary: h.f02b,
            color: AppColors.violet,
            onPressed: () => context.push('/inspection/$id/b'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Metric(value: '${h.photoCount}', label: 'Fotos'),
              Metric(value: '${h.damageCount}', label: 'Daños'),
              const Metric(value: '6', label: 'Historial'),
            ],
          ),
        ],
      ),
    );
  }
}

class DiagnosticCard extends StatelessWidget {
  const DiagnosticCard({
    required this.type,
    required this.summary,
    required this.color,
    required this.onPressed,
    super.key,
  });
  final String type;
  final InspectionSummary summary;
  final Color color;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final disabled = summary.status == InspectionStatus.notRequired;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusBadge(
                statusLabel(summary.status),
                color: disabled ? AppColors.muted : color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (summary.progress > 0) ...[
            LinearProgressIndicator(value: summary.progress, color: color),
            const SizedBox(height: 12),
          ],
          Text(
            disabled
                ? 'Este hidrante no requiere este diagnóstico actualmente.'
                : 'Información local disponible para consulta.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (!disabled) ...[
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: onPressed,
              child: Text(
                summary.status == InspectionStatus.completed
                    ? 'Ver diagnóstico'
                    : summary.status == InspectionStatus.scheduled
                    ? 'Iniciar diagnóstico'
                    : 'Continuar diagnóstico',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.title,
    required this.message,
    super.key,
  });
  final String title, message;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppPageHeader(title: title),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: SectionCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, color: AppColors.orange, size: 56),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
