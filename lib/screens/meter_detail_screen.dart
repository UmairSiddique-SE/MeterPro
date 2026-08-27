import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meter.dart';
import '../services/meter_repository.dart';
import '../theme/app_theme.dart';

final _pkr =
    NumberFormat.currency(locale: 'en_US', symbol: 'Rs ', decimalDigits: 0);
final _pkrDec =
    NumberFormat.currency(locale: 'en_US', symbol: 'Rs ', decimalDigits: 2);

class MeterDetailScreen extends StatefulWidget {
  final MeterModel meter;
  final bool openReadingEditor;

  const MeterDetailScreen({
    super.key,
    required this.meter,
    this.openReadingEditor = false,
  });

  @override
  State<MeterDetailScreen> createState() => _MeterDetailScreenState();
}

class _MeterDetailScreenState extends State<MeterDetailScreen> {
  late MeterModel _meter;
  bool _busy = false;
  bool _showTaxBreakdown = false;

  @override
  void initState() {
    super.initState();
    _meter = widget.meter;
    if (widget.openReadingEditor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddReadingOptions();
      });
    }
  }

  Future<void> _showAddReadingOptions() async {
    final TextEditingController readingCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Add Meter Reading',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the digits from your meter display below.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 28),

              const Text(
                'METER READING (kWh)',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: readingCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. 130019',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade300, fontSize: 20),
                  suffixText: 'kWh',
                  prefixIcon:
                      const Icon(Icons.speed_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 20),

              const SizedBox(height: 32),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final val = int.tryParse(readingCtrl.text.trim());
                    if (val != null) {
                      Navigator.pop(ctx);
                      _applyNewReading(val);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Please enter a valid numeric reading')),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Save & Confirm Reading',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditReadingDialog(MeterReadingLog log) async {
    final ctrl = TextEditingController(text: log.readingKwh.toString());
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Reading'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Previous: ${log.readingKwh} kWh',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'New Reading (kWh)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Delete Log',
                style: TextStyle(color: AppColors.accentRed)),
          ),
          const Spacer(),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == 'delete') {
      if (!mounted) return;
      final verify = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this log?'),
          content: const Text(
              'This action cannot be undone and will remove this data point from your history.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (verify == true) {
        _deleteLog(log);
      }
    } else if (confirmed == 'save') {
      final newVal = int.tryParse(ctrl.text);
      if (newVal != null) _updateLogReading(log, newVal);
    }
  }

  Future<void> _updateLogReading(MeterReadingLog log, int newValue) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final updatedHistory = _meter.readingHistory.map((l) {
        if (l.id == log.id) {
          return MeterReadingLog(
            id: l.id,
            readingKwh: newValue,
            baseReadingKwh: l.baseReadingKwh,
            timestamp: l.timestamp,
            source: l.source,
          );
        }
        return l;
      }).toList();

      // If this was the latest log, update presentReadingKwh
      int nextPresent = _meter.presentReadingKwh;
      if (_meter.readingHistory.isNotEmpty &&
          _meter.readingHistory.first.id == log.id) {
        nextPresent = newValue;
      }

      final updated = _meter.copyWith(
        presentReadingKwh: nextPresent,
        readingHistory: updatedHistory,
      );

      await MeterRepository.instance.updateMeter(updated);
      if (!mounted) return;
      setState(() => _meter = updated);
      messenger.showSnackBar(const SnackBar(content: Text('Reading updated.')));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteLog(MeterReadingLog log) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final updatedHistory =
          _meter.readingHistory.where((l) => l.id != log.id).toList();

      // If we deleted the latest log, we need to roll back presentReadingKwh
      int nextPresent = _meter.presentReadingKwh;
      if (_meter.readingHistory.isNotEmpty &&
          _meter.readingHistory.first.id == log.id) {
        nextPresent = updatedHistory.isNotEmpty
            ? updatedHistory.first.readingKwh
            : _meter.previousReadingKwh;
      }

      final updated = _meter.copyWith(
        presentReadingKwh: nextPresent,
        readingHistory: updatedHistory,
      );

      await MeterRepository.instance.updateMeter(updated);
      if (!mounted) return;
      setState(() => _meter = updated);
      messenger.showSnackBar(const SnackBar(content: Text('Log deleted.')));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyNewReading(int newReading) async {
    if (newReading < _meter.previousReadingKwh) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reading ($newReading kWh) cannot be lower than previous (${_meter.previousReadingKwh} kWh).',
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final consumed = newReading - _meter.previousReadingKwh;
      final newLog = MeterReadingLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        readingKwh: newReading,
        baseReadingKwh: _meter.previousReadingKwh,
        timestamp: DateTime.now(),
        source: 'Manual Entry',
      );
      final updatedLogs = [newLog, ..._meter.readingHistory];

      final updated = _meter.copyWith(
        presentReadingKwh: newReading,
        readingHistory: updatedLogs,
      );

      await MeterRepository.instance.updateMeter(updated);
      if (!mounted) return;
      setState(() => _meter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Reading $newReading kWh saved • Consumed: $consumed kWh'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save reading: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editMeter() async {
    final nameCtrl = TextEditingController(text: _meter.name);
    final readingCtrl =
        TextEditingController(text: _meter.presentReadingKwh.toString());
    final startReadingCtrl =
        TextEditingController(text: _meter.previousReadingKwh.toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Meter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Meter name',
                hintText: 'e.g. Home meter',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: readingCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Present reading (kWh)',
                prefixIcon: Icon(Icons.speed_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: startReadingCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Start reading (kWh)',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
    final newName = nameCtrl.text.trim();
    final newReading = int.tryParse(readingCtrl.text.trim());
    final newStartReading = int.tryParse(startReadingCtrl.text.trim());
    nameCtrl.dispose();
    readingCtrl.dispose();
    startReadingCtrl.dispose();
    if (confirmed != true || !mounted) return;
    if (newName.isEmpty || newReading == null || newStartReading == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid meter details.')),
      );
      return;
    }
    if (newStartReading > newReading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start reading cannot exceed present reading.'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }
    if (newName == _meter.name &&
        newReading == _meter.presentReadingKwh &&
        newStartReading == _meter.previousReadingKwh) {
      return;
    }

    setState(() => _busy = true);
    try {
      var updatedHistory = _meter.readingHistory;
      if (updatedHistory.isNotEmpty) {
        updatedHistory = [
          for (final log in updatedHistory)
            MeterReadingLog(
              id: log.id,
              readingKwh: log.id == updatedHistory.first.id
                  ? newReading
                  : log.readingKwh,
              baseReadingKwh: newStartReading,
              timestamp: log.timestamp,
              source: log.source,
            ),
        ];
      }
      final updated = _meter.copyWith(
        name: newName,
        presentReadingKwh: newReading,
        previousReadingKwh: newStartReading,
        readingHistory: updatedHistory,
      );
      await MeterRepository.instance.updateMeter(updated);
      if (!mounted) return;
      setState(() => _meter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meter details updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update meter name: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Reset Baseline (Start new billing cycle) ──────────────────────────────
  Future<void> _resetBaseline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Start New Billing Cycle?'),
        content: Text(
          'This will set the current reading (${_meter.presentReadingKwh} kWh) '
          'as the new starting baseline.\n\n'
          'Units consumed will reset to 0 and historical logs will be cleared for this meter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Start New Cycle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = _meter.copyWith(
        presentReadingKwh: _meter.presentReadingKwh,
        previousReadingKwh: _meter.presentReadingKwh,
        estimatedBillPkr: 0,
        monthlyUnitsKwh: 0,
        monthlyBillPkr: 0,
        dailyUsage: [],
        weeklyUsage: [],
        monthlyUsage: [],
        readingHistory: [],
      );

      await MeterRepository.instance.updateMeter(updated);
      if (!mounted) return;
      setState(() => _meter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New cycle started! Consumed units reset to 0.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reset cycle: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Delete Meter ──────────────────────────────────────────────────────────
  Future<void> _deleteMeter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Meter?'),
        content:
            Text('This will permanently remove "${_meter.name}" and its logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await MeterRepository.instance.deleteMeter(_meter.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final meter = _meter;
    final breakdown = meter.billBreakdown;

    // Build real unit progression spots from reading history sorted chronologically
    final historyLogsAsc = meter.readingHistory.reversed.toList();
    final spots = <FlSpot>[];
    for (var i = 0; i < historyLogsAsc.length; i++) {
      spots.add(FlSpot(i.toDouble(), historyLogsAsc[i].readingKwh.toDouble()));
    }
    if (spots.isEmpty) {
      spots.add(FlSpot(0, meter.previousReadingKwh.toDouble()));
    }

    // Take up to last 5 readings for a better trend view
    final displayHistory = historyLogsAsc.length > 5
        ? historyLogsAsc.sublist(historyLogsAsc.length - 5)
        : historyLogsAsc;
    final displaySpots = <FlSpot>[];
    for (var i = 0; i < displayHistory.length; i++) {
      displaySpots
          .add(FlSpot(i.toDouble(), displayHistory[i].readingKwh.toDouble()));
    }
    if (displaySpots.isEmpty) {
      displaySpots.add(FlSpot(0, meter.previousReadingKwh.toDouble()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AbsorbPointer(
        absorbing: _busy,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                decoration:
                    const BoxDecoration(gradient: AppColors.headerGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                        Row(
                          children: [
                            if (_busy)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded,
                                  color: Colors.white, size: 20),
                              color: Colors.white,
                              onSelected: (val) {
                                if (val == 'edit_meter') _editMeter();
                                if (val == 'reset') _resetBaseline();
                                if (val == 'delete') _deleteMeter();
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit_meter',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          color: AppColors.primary, size: 18),
                                      SizedBox(width: 10),
                                      Text('Edit Meter',
                                          style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'reset',
                                  child: Row(
                                    children: [
                                      Icon(Icons.restart_alt_rounded,
                                          color: AppColors.primary, size: 18),
                                      SizedBox(width: 10),
                                      Text('Start New Billing Cycle',
                                          style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: AppColors.accentRed, size: 18),
                                      SizedBox(width: 10),
                                      Text('Delete Meter',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.accentRed)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            // Back to badge-style toggle as requested
                            GestureDetector(
                              onTap: () async {
                                final nextStatus = !meter.isActive;
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: Text(
                                        '${nextStatus ? 'Activate' : 'Deactivate'} meter?'),
                                    content: Text(
                                        'This meter will be marked ${nextStatus ? 'active' : 'inactive'}.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogCtx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(dialogCtx).pop(true),
                                        child: Text(nextStatus
                                            ? 'Activate'
                                            : 'Deactivate'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !mounted) return;
                                setState(() => _busy = true);
                                try {
                                  final updated =
                                      _meter.copyWith(isActive: nextStatus);
                                  await MeterRepository.instance
                                      .updateMeter(updated);
                                  if (!context.mounted) return;
                                  setState(() => _meter = updated);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Meter set to ${nextStatus ? "Active" : "Inactive"}'),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: nextStatus
                                          ? AppColors.accentGreen
                                          : AppColors.accentRed,
                                    ),
                                  );
                                } catch (_) {}
                                if (mounted) setState(() => _busy = false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (meter.isActive
                                          ? AppColors.accentGreen
                                          : AppColors.accentRed)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  meter.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                      color: meter.isActive
                                          ? AppColors.accentGreen
                                          : AppColors.accentRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Text('CONSUMER',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0)),
                    Text(meter.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    Text('Ref: ${meter.referenceNo}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),

                    const SizedBox(height: 18),

                    // ── Primary Metric Card ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('UNITS CONSUMED',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${meter.consumedUnitsKwh} kWh',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('ESTIMATED BILL',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(_pkr.format(meter.estimatedBillPkr),
                                      style: const TextStyle(
                                          color: AppColors.accentOrange,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 32),
                          Row(
                            children: [
                              _readingBox(
                                  'START', '${meter.previousReadingKwh} kWh'),
                              const SizedBox(width: 16),
                              _readingBox(
                                  'PRESENT', '${meter.presentReadingKwh} kWh'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Add Meter Reading Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _showAddReadingOptions,
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            size: 20),
                        label: const Text('Add Meter Reading',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentOrange,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Main Details Section ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Government Slabs & Tax Breakdown Card ─────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: const ContainerIcon(
                              icon: Icons.receipt_long_rounded),
                          title: const Text('Government Slabs & Tax Breakdown',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                              '${meter.consumedUnitsKwh} kWh consumed • ${_pkr.format(meter.estimatedBillPkr)} total',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                          trailing: IconButton(
                            icon: Icon(_showTaxBreakdown
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded),
                            onPressed: () => setState(
                                () => _showTaxBreakdown = !_showTaxBreakdown),
                          ),
                          onTap: () => setState(
                              () => _showTaxBreakdown = !_showTaxBreakdown),
                        ),
                        if (_showTaxBreakdown) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calculate_outlined,
                                          size: 18, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Units = ${meter.presentReadingKwh} (Present) - ${meter.previousReadingKwh} (Start) = ${meter.consumedUnitsKwh} kWh',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text('TARIFF SLABS BREAKDOWN',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textMuted,
                                        letterSpacing: 0.5)),
                                const SizedBox(height: 8),
                                if (breakdown.slabs.isEmpty)
                                  const Text('No consumption yet (0 kWh)',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted))
                                else
                                  for (final slab in breakdown.slabs)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${slab.rangeLabel} (${slab.unitsInSlab} units @ ${_pkrDec.format(slab.ratePerUnit)}/kWh)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: slab.rangeLabel
                                                      .contains('Protected')
                                                  ? AppColors.accentGreen
                                                  : null,
                                              fontWeight: slab.rangeLabel
                                                      .contains('Protected')
                                                  ? FontWeight.w600
                                                  : null,
                                            ),
                                          ),
                                          Text(_pkrDec.format(slab.slabCost),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: slab.rangeLabel
                                                          .contains('Protected')
                                                      ? AppColors.accentGreen
                                                      : null,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                const Divider(height: 16),
                                _costRow('Base Energy Charges',
                                    breakdown.baseEnergyCost),
                                _costRow(
                                    'Fixed Charges (${meter.sanctionedLoad} kW)',
                                    breakdown.fixedCharge),
                                if (breakdown.subsidy != 0)
                                  _costRow(
                                      'Government Subsidy', breakdown.subsidy,
                                      color: AppColors.accentGreen),
                                _costRow(
                                    'Net Electricity Charges',
                                    breakdown.baseEnergyCost +
                                        breakdown.fixedCharge +
                                        breakdown.subsidy,
                                    isBold: true),
                                const SizedBox(height: 14),
                                const Text('GOVERNMENT TAXES & SURCHARGES',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textMuted,
                                        letterSpacing: 0.5)),
                                const SizedBox(height: 8),
                                _costRow('Electricity Duty (ED)',
                                    breakdown.electricityDuty),
                                _costRow('FC Surcharge (Rs 0.428/kWh)',
                                    breakdown.fcSurcharge),
                                _costRow('Fuel Price Adjustment (FPA)',
                                    breakdown.fuelPriceAdjustment),
                                _costRow('Sales Tax / GST (18.71%)',
                                    breakdown.salesTax),
                                _costRow('PTV License Fee', breakdown.tvFee),
                                const Divider(height: 18),
                                _costRow('TOTAL ESTIMATED BILL',
                                    breakdown.totalBillPkr,
                                    isBold: true,
                                    color: AppColors.accentOrange,
                                    fontSize: 15),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Single Clean Progression Bar Chart ──────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Usage Progression',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Text(
                        'Recent Readings',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.8)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: 220,
                      child: displaySpots.length < 2
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bar_chart_rounded,
                                      size: 32, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'Scan more readings to see trend',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            )
                          : BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: (displaySpots
                                        .map((s) => s.y)
                                        .reduce((a, b) => a > b ? a : b)) *
                                    1.15,
                                minY: (displaySpots
                                        .map((s) => s.y)
                                        .reduce((a, b) => a < b ? a : b)) *
                                    0.9,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (_) => AppColors.primary,
                                    tooltipPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    tooltipBorderRadius:
                                        BorderRadius.circular(12),
                                    getTooltipItem:
                                        (group, groupIndex, rod, rodIndex) {
                                      final log = displayHistory[groupIndex];
                                      return BarTooltipItem(
                                        '${rod.toY.toInt()} kWh\n',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: DateFormat('MMM dd, hh:mm a')
                                                .format(log.timestamp),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 100,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: Colors.grey.withValues(alpha: 0.05),
                                    strokeWidth: 1,
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (v, meta) {
                                        return Text(
                                          v.toInt().toString(),
                                          style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textMuted),
                                        );
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 32,
                                      getTitlesWidget: (v, meta) {
                                        final idx = v.toInt();
                                        if (idx < 0 ||
                                            idx >= displayHistory.length) {
                                          return const SizedBox();
                                        }
                                        final time =
                                            displayHistory[idx].timestamp;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: Text(
                                            DateFormat('dd/MM').format(time),
                                            style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textMuted),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: [
                                  for (var i = 0; i < displaySpots.length; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: displaySpots[i].y,
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primaryLight,
                                              AppColors.primary
                                                  .withValues(alpha: 0.7),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          width: 16,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(6)),
                                          backDrawRodData:
                                              BackgroundBarChartRodData(
                                            show: true,
                                            toY: (displaySpots
                                                    .map((s) => s.y)
                                                    .reduce((a, b) =>
                                                        a > b ? a : b)) *
                                                1.15,
                                            color: AppColors.background,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Reading History Log (FIXED OVERFLOW BUG) ─────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reading History Log',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Text('Showing last 3 logs',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (meter.readingHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No historical logs recorded yet.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    )
                  else
                    for (int i = 0;
                        i < meter.readingHistory.take(3).length;
                        i++)
                      _buildLogTile(
                          meter.readingHistory[i],
                          i < meter.readingHistory.length - 1
                              ? meter.readingHistory[i].readingKwh -
                                  meter.readingHistory[i + 1].readingKwh
                              : meter.readingHistory[i].readingKwh -
                                  meter.readingHistory[i].baseReadingKwh),

                  if (meter.readingHistory.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context, 'go_to_usage');
                        },
                        child: const Text('View All Usage History'),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _costRow(String label, double amount,
      {bool isBold = false, Color? color, double fontSize = 12}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? AppColors.textPrimary,
              )),
          Text(_pkrDec.format(amount),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? AppColors.textPrimary,
              )),
        ],
      ),
    );
  }

  // ── FIXED OVERFLOW LOG TILE ──────────────────────────────────────────────
  Widget _buildLogTile(MeterReadingLog log, int incrementalUnits) {
    final isCycleReset = log.source.contains('Reset');
    final unitsToShow = incrementalUnits.clamp(0, 999999);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCycleReset
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Line: Reading + Units Consumed Pill + Source Tag (Fits cleanly without overflow)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                      (isCycleReset ? AppColors.primary : AppColors.textMuted)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCycleReset
                      ? Icons.restart_alt_rounded
                      : Icons.edit_calendar_outlined,
                  size: 18,
                  color: isCycleReset ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${log.readingKwh} kWh',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.accentGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+$unitsToShow kWh',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _showEditReadingDialog(log),
                          icon: const Icon(Icons.edit_outlined,
                              size: 14, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Edit reading',
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        log.source,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Subtitle Line: Base Reading + Timestamp
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(
              'Base: ${log.baseReadingKwh} kWh • ${DateFormat('dd MMM yyyy, hh:mm a').format(log.timestamp)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readingBox(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 8,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ContainerIcon extends StatelessWidget {
  final IconData icon;
  const ContainerIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    );
  }
}
