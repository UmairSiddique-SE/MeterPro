import 'package:flutter/material.dart';
import '../models/meter.dart';
import '../services/meter_repository.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';
import 'camera_scanner_screen.dart';

class AddMeterScreen extends StatefulWidget {
  const AddMeterScreen({super.key});

  @override
  State<AddMeterScreen> createState() => _AddMeterScreenState();
}

class _AddMeterScreenState extends State<AddMeterScreen> {
  bool _saving = false;
  final ScrollController _formScrollController = ScrollController();

  // Controllers
  final _refCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _meterNoCtrl = TextEditingController();
  final _presReadingCtrl = TextEditingController(text: '0');
  int _sanctionedLoad = 2;
  bool _isProtected = true;
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  String _normaliseSerial(String value) =>
      value.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

  Future<void> _scanMeterNumber() async {
    final result = await Navigator.of(context).push<OCRScanResult>(
      MaterialPageRoute(
        builder: (_) => const CameraScannerScreen(
          initialMode: ScanTargetMode.digitalMeter,
          scanSerialOnly: true,
        ),
      ),
    );
    if (!mounted || result?.meterNo == null) return;
    setState(() => _meterNoCtrl.text = result!.meterNo!);
  }

  String _monthName(int m) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[m];
  }

  // ── Save Meter ────────────────────────────────────────────────────────────
  Future<void> _saveMeter() async {
    final name = _nameCtrl.text.trim();
    final ref = _refCtrl.text.trim();
    final meterNo = _meterNoCtrl.text.trim();
    final pres = int.tryParse(_presReadingCtrl.text.trim()) ?? 0;
    final cleanReference = ref.replaceAll(RegExp(r'\D'), '');

    if (name.isEmpty || ref.isEmpty || meterNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in Name, Reference and Meter Number')),
      );
      return;
    }

    if (cleanReference.length != 14 || cleanReference != ref) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reference number must contain exactly 14 digits.'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    if (pres < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting reading cannot be negative.'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    // Month Validation: Must be current month
    final now = DateTime.now();
    if (_selectedMonth != now.month || _selectedYear != now.year) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error: Only current month bills (${_monthName(now.month)} ${now.year}) can be registered.'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final duplicateGlobally = await MeterRepository.instance
          .checkGlobalMeterIdentity(referenceNo: ref, meterNo: meterNo);
      if (duplicateGlobally) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'This meter number or reference number already exists. Please enter a different one.'),
            backgroundColor: AppColors.accentRed,
          ),
        );
        setState(() => _saving = false);
        return;
      }

      final existingMeters = await MeterRepository.instance.watchMeters().first;
      final duplicate = existingMeters.any((existing) =>
          existing.referenceNo == ref ||
          (meterNo.isNotEmpty &&
              _normaliseSerial(existing.meterNo) == _normaliseSerial(meterNo)));
      if (duplicate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('This meter or reference number is already registered.'),
            backgroundColor: AppColors.accentRed,
          ),
        );
        setState(() => _saving = false);
        return;
      }

      final meter = MeterModel.create(
        name: name,
        referenceNo: ref,
        meterNo: meterNo,
        presentReadingKwh: pres,
        previousReadingKwh: pres,
        sanctionedLoad: _sanctionedLoad,
        isProtected: _isProtected,
        billMonth: DateTime(_selectedYear!, _selectedMonth!),
        initialSource: 'Manual Entry',
      );

      await MeterRepository.instance.addMeter(meter);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meter registered successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save meter: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _formScrollController.dispose();
    _refCtrl.dispose();
    _nameCtrl.dispose();
    _meterNoCtrl.dispose();
    _presReadingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 76,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.png', width: 34, height: 34),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add New Meter',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                Text('Bill Month: ${_monthName(_selectedMonth!)} $_selectedYear',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70)),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        controller: _formScrollController,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: _buildManualForm(),
      ),
    );
  }

  Widget _buildManualForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Consumer Name
        _buildInputField(
          controller: _nameCtrl,
          label: 'CONSUMER NAME',
          hint: 'e.g. Umair',
          icon: Icons.person_outline_rounded,
        ),

        // 2. Bill Month
        _label('BILL MONTH'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedMonth,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_month_rounded, size: 20),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: List.generate(12, (index) => index + 1)
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(_monthName(m)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedMonth = val),
                ),
              ),
              Container(height: 30, width: 1, color: AppColors.border),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedYear,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    DateTime.now().year - 1,
                    DateTime.now().year,
                    DateTime.now().year + 1
                  ]
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedYear = val),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Reference Number
        _buildInputField(
          controller: _refCtrl,
          label: 'REFERENCE NUMBER (14 DIGITS)',
          hint: '2013..........',
          icon: Icons.numbers_rounded,
          keyboard: TextInputType.number,
          limit: 14,
        ),

        // NEW: Starting Meter Reading
        _label('STARTING METER READING (kWh)'),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: TextField(
            controller: _presReadingCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Current reading on your meter',
              prefixIcon:
                  Icon(Icons.speed_rounded, size: 20, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 4. Sanctioned Load
        _label('SANCTIONED LOAD'),
        DropdownButtonFormField<int>(
          initialValue: _sanctionedLoad,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.bolt_rounded, size: 20),
          ),
          items: [1, 2, 3, 4, 5, 10, 15, 20]
              .map((load) => DropdownMenuItem(
                    value: load,
                    child: Text('$load kW'),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _sanctionedLoad = val ?? 2),
        ),
        const SizedBox(height: 24),

        // 5. Consumer Category
        Row(
          children: [
            _label('CONSUMER CATEGORY'),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Tooltip(
                message:
                    'Protected: Used less than 200 units consistently.\nUnprotected: Used more than 200 units.',
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Protected')),
                  selected: _isProtected,
                  onSelected: (val) => setState(() => _isProtected = true),
                  showCheckmark: false,
                  selectedColor: AppColors.accentGreen.withValues(alpha: 0.15),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  labelStyle: TextStyle(
                    color: _isProtected
                        ? AppColors.accentGreen
                        : AppColors.textMuted,
                    fontWeight:
                        _isProtected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Unprotected')),
                  selected: !_isProtected,
                  onSelected: (val) => setState(() => _isProtected = false),
                  showCheckmark: false,
                  selectedColor: AppColors.accentOrange.withValues(alpha: 0.15),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  labelStyle: TextStyle(
                    color: !_isProtected
                        ? AppColors.accentOrange
                        : AppColors.textMuted,
                    fontWeight:
                        !_isProtected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                (_isProtected ? AppColors.accentGreen : AppColors.accentOrange)
                    .withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _isProtected
                    ? Icons.verified_user_outlined
                    : Icons.warning_amber_rounded,
                size: 14,
                color: _isProtected
                    ? AppColors.accentGreen
                    : AppColors.accentOrange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isProtected
                      ? 'Protected category applies to consumption under 200 units.'
                      : 'Unprotected category applies to consumption above 200 units.',
                  style: TextStyle(
                    fontSize: 10,
                    color: _isProtected
                        ? AppColors.accentGreen
                        : AppColors.accentOrange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 6. Meter Serial Number
        _label('METER SERIAL NUMBER'),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _meterNoCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Enter the number printed on your meter',
                    prefixIcon: Icon(Icons.qr_code_rounded,
                        size: 20, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Scan meter number',
                child: IconButton(
                  onPressed: _scanMeterNumber,
                  icon: const Icon(Icons.document_scanner_rounded),
                  color: AppColors.primary,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // Final Action
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveMeter,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
            ),
            child: _saving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Verify & Register Meter',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    int? limit,
    String? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Builder(
            builder: (fieldContext) => TextField(
              controller: controller,
              keyboardType: keyboard,
              maxLength: limit,
              onTap: () {
                Future<void>.delayed(const Duration(milliseconds: 250), () {
                  if (fieldContext.mounted) {
                    Scrollable.ensureVisible(
                      fieldContext,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      alignment: 0.18,
                    );
                  }
                });
              },
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
                suffixText: suffix,
                counterText: '',
                fillColor: Colors.white,
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 1.1)),
      );
}
