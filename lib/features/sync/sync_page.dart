import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/common_widgets.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});
  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          context.read<AppState>().trace('sync_open', 'Abrir sincronización'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending = state.syncBox.keys.cast<String>().toList();
    return Scaffold(
      appBar: AppPageHeader(
        title: 'Sincronización',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ConnectionBadge(online: state.online),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (state.online ? AppColors.green : AppColors.orange)
                  .withValues(alpha: .1),
              border: Border.all(
                color: (state.online ? AppColors.green : AppColors.orange)
                    .withValues(alpha: .35),
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Icon(
                  state.online
                      ? Icons.check_circle_outline
                      : Icons.cloud_off_outlined,
                  color: state.online ? AppColors.green : AppColors.orange,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.online ? 'Conexión disponible' : 'Sin conexión',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'Simulación local segura',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COLA DE SINCRONIZACIÓN',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 15),
                _Count(label: 'Diagnósticos pendientes', value: pending.length),
                const _Count(label: 'Fotografías pendientes', value: 2),
                const Divider(),
                const Row(
                  children: [
                    Text(
                      'Tamaño aproximado',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    Spacer(),
                    Text('7.4 MB', style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (pending.isEmpty)
            const SectionCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.green,
                      size: 54,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Todo sincronizado',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'No hay registros pendientes',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            )
          else
            SectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'REGISTROS PENDIENTES',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  for (final code in pending)
                    ListTile(
                      title: Text(
                        code,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Guardado localmente'),
                      trailing: const StatusBadge(
                        'Pendiente',
                        color: AppColors.orange,
                      ),
                    ),
                ],
              ),
            ),
          if (state.syncing) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(value: state.syncProgress),
            const SizedBox(height: 7),
            Text(
              '${(state.syncProgress * 100).round()}%',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: pending.isEmpty || !state.online || state.syncing
                ? null
                : state.synchronize,
            icon: const Icon(Icons.sync),
            label: Text(
              state.syncing ? 'Sincronizando...' : 'Sincronizar ahora',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'La simulación no elimina fotografías ni evidencia local. En producción solo el estado remoto verificado contará como sincronizado.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      children: [
        const Icon(
          Icons.upload_outlined,
          color: AppColors.brightBlue,
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(label),
        const Spacer(),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}
