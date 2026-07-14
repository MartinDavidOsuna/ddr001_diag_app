import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/common_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final date = DateFormat(
      "EEEE, d 'de' MMMM 'de' y",
      'es',
    ).format(DateTime.now());
    return Scaffold(
      appBar: AppPageHeader(
        title: 'DIAGNOSTICO HIDRANTES',
        subtitle: 'Distrito de Riego 001',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ConnectionBadge(online: state.online),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Buenas tardes, ${state.user.fullName.split(' ').first}',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              '${state.user.brigadeName} · Ruta Norte - Pabellón de Arteaga',
              style: const TextStyle(color: AppColors.muted),
            ),
            Text(
              date,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFFE6E6),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1 registro devuelto',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Requiere corrección',
                          style: TextStyle(fontSize: 12, color: AppColors.red),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.go('/hydrants'),
                    icon: const Icon(Icons.chevron_right, color: AppColors.red),
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
                    'CONTINUAR INSPECCIÓN',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'DDR001-HID-0002',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'Rincón de Romos',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 9),
                  const StatusBadge(
                    'F02-A · En proceso',
                    color: AppColors.teal,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                    ),
                    onPressed: () {
                      state.trace(
                        'continue_inspection',
                        'Continuar inspección F02-A',
                        hydrantId: '2',
                      );
                      context.push('/inspection/2/a');
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continuar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESUMEN DE JORNADA',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  SizedBox(height: 18),
                  Row(
                    children: [
                      Metric(value: '12', label: 'Asignados'),
                      Metric(
                        value: '5',
                        label: 'Terminados',
                        color: AppColors.green,
                      ),
                      Metric(
                        value: '1',
                        label: 'En proceso',
                        color: AppColors.teal,
                      ),
                      Metric(
                        value: '2',
                        label: 'Sin sinc.',
                        color: AppColors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.go('/hydrants'),
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('Ver hidrantes'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/sync'),
                    icon: const Icon(Icons.sync),
                    label: const Text('Sincronizar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 52),
                    ),
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
