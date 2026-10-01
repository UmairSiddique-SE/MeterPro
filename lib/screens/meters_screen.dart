import 'package:flutter/material.dart';
import '../models/meter.dart';
import '../services/meter_repository.dart';
import '../theme/app_theme.dart';
import '../utils/animation_utils.dart';
import 'add_meter_screen.dart';
import 'meter_detail_screen.dart';

class MetersScreen extends StatelessWidget {
  const MetersScreen({super.key});

  void _openAddMeter(BuildContext context) {
    Navigator.of(context).push(
      SmoothPageRoute(child: const AddMeterScreen()),
    );
  }

  void _openMeter(BuildContext context, MeterModel meter) {
    Navigator.of(context).push(
      SmoothPageRoute(child: MeterDetailScreen(meter: meter)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/images/logo.png', width: 28, height: 28),
            ),
            const SizedBox(width: 12),
            const Text('My Meters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _openAddMeter(context),
            tooltip: 'Add meter',
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<MeterModel>>(
        stream: MeterRepository.instance.watchMeters(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load meters: ${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }

          final meters = snapshot.data ?? const <MeterModel>[];
          if (meters.isEmpty) {
            return _EmptyMeters(onAdd: () => _openAddMeter(context));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            itemCount: meters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final meter = meters[index];
              return FadeSlideEntrance(
                delay: Duration(milliseconds: 100 * index),
                child: _MeterManagementCard(
                  meter: meter,
                  onTap: () => _openMeter(context, meter),
                  onEditReading: () => Navigator.of(context).push(
                    SmoothPageRoute(
                      child: MeterDetailScreen(
                        meter: meter,
                        openReadingEditor: true,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MeterManagementCard extends StatelessWidget {
  final MeterModel meter;
  final VoidCallback onTap;
  final VoidCallback onEditReading;

  const _MeterManagementCard({
    required this.meter,
    required this.onTap,
    required this.onEditReading,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.electric_meter_rounded,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meter.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Meter: ${meter.meterNo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Reading: ${meter.presentReadingKwh} kWh',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ),
                        IconButton(
                          onPressed: onEditReading,
                          tooltip: 'Edit reading',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined,
                              color: AppColors.primary, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMeters extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyMeters({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.electric_meter_outlined,
                size: 70, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('No meters added yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Add your electricity meter to track readings and bills.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Meter'),
            ),
          ],
        ),
      ),
    );
  }
}
