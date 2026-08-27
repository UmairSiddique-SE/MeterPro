import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ocr_service.dart';
import '../services/lcd_reading_service.dart';
import '../theme/app_theme.dart';

enum ScanTargetMode { bill, digitalMeter }

enum ScannerStage {
  searchingSerial,
  searchingReading,
  // Bill Scan Stages
  checkingDate,
  checkingRefNo,
  checkingLoad,
  checkingReading,
  extractionComplete,
}

/// Smart Fullscreen interactive camera scanner widget for scanning electricity bills & meter readings.
/// Supports sequential stateful scanning (Verify Serial -> Auto-Capture Reading).
class CameraScannerScreen extends StatefulWidget {
  final ScanTargetMode initialMode;
  final String? expectedReferenceNo;
  final List<String> registeredMeterNumbers;
  final bool scanSerialOnly;
  final bool allowUnregisteredMeter;
  final int? minimumReading;

  const CameraScannerScreen({
    super.key,
    this.initialMode = ScanTargetMode.digitalMeter,
    this.expectedReferenceNo,
    this.registeredMeterNumbers = const [],
    this.scanSerialOnly = false,
    this.allowUnregisteredMeter = false,
    this.minimumReading,
  });

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false;
  bool _isProcessingFrame = false;
  bool _flashOn = false;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoomLevel = 1;
  ScanTargetMode _currentMode = ScanTargetMode.digitalMeter;
  ScannerStage _scannerStage = ScannerStage.searchingSerial;
  Timer? _lookupTimeout;
  Timer? _autoReadingCaptureTimer;
  bool _hasReturnedMatch = false;
  bool _hasShownBillDateMessage = false;
  String? _serialCandidate;
  int _serialCandidateHits = 0;

  final TextEditingController _meterNoCtrl = TextEditingController();
  final TextEditingController _readingCtrl = TextEditingController();
  final FocusNode _meterNoFocus = FocusNode();
  final FocusNode _readingFocus = FocusNode();
  final GlobalKey _serialFieldKey = GlobalKey();
  final GlobalKey _readingFieldKey = GlobalKey();

  OCRScanResult? _latestResult;

  late AnimationController _laserAnimCtrl;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    if (_isBillScan) {
      _scannerStage = ScannerStage.checkingDate;
    }
    _setupLaserAnimation();
    _meterNoFocus.addListener(_keepSerialFieldVisible);
    _readingFocus.addListener(_keepReadingFieldVisible);
    _checkPermissionAndInitCamera();
    if (_isMeterLookup) {
      _lookupTimeout = Timer(const Duration(seconds: 12), _showNoMeterMatch);
    }
  }

  void _keepReadingFieldVisible() {
    _keepFieldVisible(_readingFieldKey, _readingFocus);
  }

  void _keepSerialFieldVisible() {
    _keepFieldVisible(_serialFieldKey, _meterNoFocus);
  }

  void _keepFieldVisible(GlobalKey key, FocusNode focusNode) {
    if (!focusNode.hasFocus) return;
    Future<void>.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final fieldContext = key.currentContext;
      if (fieldContext != null && fieldContext.mounted) {
        await Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.15,
        );
      }
    });
  }

  bool get _isMeterLookup =>
      widget.expectedReferenceNo == null &&
      widget.registeredMeterNumbers.isNotEmpty;
  bool get _isBillScan => _currentMode == ScanTargetMode.bill;
  bool get _isSerialOnly => widget.scanSerialOnly;

  void _setupLaserAnimation() {
    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _laserAnimation =
        Tween<double>(begin: 0.05, end: 0.95).animate(_laserAnimCtrl);
  }

  Future<void> _checkPermissionAndInitCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _isPermissionGranted = true);
      await _initCamera();
    } else {
      if (mounted) setState(() => _isPermissionGranted = false);
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }

      final backCam = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCam,
        // The LCD digits are narrow and low-contrast; the higher stream
        // resolution gives ML Kit enough detail to read values such as 130018.
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      _controller = controller;
      await controller.initialize();
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _zoomLevel = _minZoom;

      if (!mounted) return;
      setState(() => _isCameraInitialized = true);

      _startLiveStream();
      if (_isBillScan) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Place the complete bill inside the frame. Only a bill with this month\'s Due/Last Date will be accepted.'),
              duration: Duration(seconds: 5),
            ),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not initialize camera: $e')),
      );
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final nextFlash = !_flashOn;
      await controller
          .setFlashMode(nextFlash ? FlashMode.torch : FlashMode.off);
      setState(() => _flashOn = nextFlash);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Torch not supported on this device: $e')),
      );
    }
  }

  Future<void> _setZoom(double zoom) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final nextZoom = zoom.clamp(_minZoom, _maxZoom);
    try {
      await controller.setZoomLevel(nextZoom);
      if (mounted) setState(() => _zoomLevel = nextZoom);
    } catch (_) {
      // Zoom is optional on some camera hardware.
    }
  }

  /// A camera stream is intentionally low resolution for speed. LCD digits
  /// often need a full-resolution still image, so give the user a reliable
  /// capture path when live OCR is still searching.
  Future<void> _captureHighQualityReading() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isProcessingFrame) {
      return;
    }

    try {
      setState(() => _isProcessingFrame = true);
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final photo = await controller.takePicture();
      final result = await LcdReadingService.instance.readFromPhoto(photo.path);
      if (!mounted) return;

      final serial = _serialFromResult(result);
      setState(() {
        _latestResult = result;
        if (serial != null && !_meterNoFocus.hasFocus) {
          _meterNoCtrl.text = serial;
        }
        if (_isValidSerialMatch(result)) {
          _scannerStage = ScannerStage.searchingReading;
          _scheduleAutomaticReadingCapture();
        }
        _applyDetectedReading(result.meterReading);
        _isProcessingFrame = false;
      });

      if (result.meterReading == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'kWh reading was not clear. Hold the camera closer to the LCD and try again.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingFrame = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture meter reading: $e')),
        );
      }
    } finally {
      if (mounted &&
          controller.value.isInitialized &&
          !controller.value.isStreamingImages) {
        _startLiveStream();
      }
    }
  }

  void _scheduleAutomaticReadingCapture() {
    if (_readingCtrl.text.isNotEmpty ||
        _autoReadingCaptureTimer?.isActive == true) {
      return;
    }
    _autoReadingCaptureTimer = Timer(
      const Duration(milliseconds: 900),
      _captureHighQualityReading,
    );
  }

  bool _isPlausibleReading(int? reading) =>
      reading != null &&
      (widget.minimumReading == null || reading >= widget.minimumReading!);

  void _applyDetectedReading(int? reading) {
    if (reading == null || _readingFocus.hasFocus) return;
    // Do not replace the field with a short/incorrect OCR value. This also
    // makes the scanner keep waiting for the actual LCD value.
    if (_isPlausibleReading(reading)) {
      _readingCtrl.text = reading.toString();
    }
  }

  void _startLiveStream() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    controller.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage != null) {
          final result = await OCRService.instance.processImage(inputImage);
          if (mounted) {
            setState(() => _latestResult = result);

            if (_isBillScan) {
              _handleSequentialBillScan(result);
              return;
            }

            final scannedSerial = _serialFromResult(result);

            // OPTIMIZATION: If we are looking for a SPECIFIC serial, search ALL detected lines
            // for an exact match, even without a label. This makes verification instant.
            String? verifiedSerial;
            if (widget.expectedReferenceNo != null) {
              final target = _normaliseSerial(widget.expectedReferenceNo!);
              for (final line in result.detectedLines) {
                final cleanLine = _normaliseSerial(line);
                // Check if the line IS the serial, or contains the serial as a whole word
                if (cleanLine == target || cleanLine.contains(target)) {
                  verifiedSerial = target;
                  break;
                }
              }
            }

            // Used by bill registration: scan only the physical meter serial
            // and return it to the manual Meter No field.
            String? labelledSerial;
            if (_isSerialOnly) {
              labelledSerial =
                  verifiedSerial ?? _labelledSerialFromResult(result);
            } else {
              labelledSerial = scannedSerial;
            }

            if (_isSerialOnly &&
                labelledSerial != null &&
                (widget.expectedReferenceNo == null ||
                    _isValidSerialMatch(result)) &&
                _confirmSerialCandidate(labelledSerial) &&
                !_hasReturnedMatch) {
              _hasReturnedMatch = true;
              await controller.stopImageStream();
              if (mounted) {
                Navigator.of(context).pop(OCRScanResult(
                  meterNo: labelledSerial,
                  meterReading:
                      result.meterReading, // Return reading if it was captured
                  rawText: result.rawText,
                  detectedLines: result.detectedLines,
                ));
              }
              return;
            }
            if (_isSerialOnly) return;

            if (_scannerStage == ScannerStage.searchingSerial) {
              // Show the serial that OCR actually read. Never replace it with
              // the saved serial: doing so can make a wrong meter look valid.
              if (scannedSerial != null && !_meterNoFocus.hasFocus) {
                _meterNoCtrl.text = scannedSerial;
              }

              if (_isMeterLookup &&
                  !_hasReturnedMatch &&
                  _isRegisteredMeter(scannedSerial)) {
                _hasReturnedMatch = true;
                _lookupTimeout?.cancel();
                Future<void>.delayed(const Duration(milliseconds: 450), () {
                  if (!mounted) return;
                  Navigator.of(context).pop(OCRScanResult(
                    meterNo: scannedSerial,
                    meterReading: result.meterReading,
                    rawText: result.rawText,
                    detectedLines: result.detectedLines,
                  ));
                });
                return;
              }

              // Transition to next stage if it matches our expected meter
              if (_isValidSerialMatch(result)) {
                setState(() => _scannerStage = ScannerStage.searchingReading);
                _scheduleAutomaticReadingCapture();
              }
            } else {
              // Stage: searchingReading
              // We stay in this stage until the user confirms or we find a reading
              _applyDetectedReading(result.meterReading);
            }
          }
        }
      } catch (_) {
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  void _handleSequentialBillScan(OCRScanResult result) {
    if (_hasReturnedMatch) return;

    if (_scannerStage == ScannerStage.checkingDate) {
      if (result.billDate != null) {
        if (result.isForCurrentMonth) {
          setState(() => _scannerStage = ScannerStage.checkingRefNo);
        } else if (!_hasShownBillDateMessage) {
          _hasShownBillDateMessage = true;
          final now = DateTime.now();
          final monthName = [
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
          ][now.month];

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Invalid Bill! Only $monthName ${now.year} bills are accepted.'),
                backgroundColor: AppColors.accentRed),
          );
          // Wait a bit then reset message flag to allow re-showing if they try again
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) _hasShownBillDateMessage = false;
          });
        }
      }
    } else if (_scannerStage == ScannerStage.checkingRefNo) {
      if (result.referenceNo != null && result.referenceNo!.length == 14) {
        setState(() => _scannerStage = ScannerStage.checkingLoad);
      }
    } else if (_scannerStage == ScannerStage.checkingLoad) {
      if (result.sanctionedLoad != null) {
        setState(() => _scannerStage = ScannerStage.checkingReading);
      }
    } else if (_scannerStage == ScannerStage.checkingReading) {
      if (result.meterReading != null) {
        setState(() => _scannerStage = ScannerStage.extractionComplete);
        _hasReturnedMatch = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.of(context).pop(result);
        });
      }
    }
  }

  bool _isValidSerialMatch(OCRScanResult? result) {
    return _isValidSerialText(_serialFromResult(result));
  }

  String? _serialFromResult(OCRScanResult? result) {
    if (result == null) return null;
    // A meter scan should prefer the meter serial. A 14-digit bill reference
    // is used only when the registered meter number itself is 14 digits.
    if (result.meterNo != null && result.meterNo!.trim().isNotEmpty) {
      return result.meterNo;
    }
    final expected = _normaliseSerial(widget.expectedReferenceNo ?? '');
    if (expected.length == 14) return result.referenceNo;
    return null;
  }

  /// Add-meter scanning accepts only a value explicitly printed beside a
  /// serial-number label. It may contain letters (e.g. F-086361), but must
  /// include a digit so normal text cannot be used as a serial.
  String? _labelledSerialFromResult(OCRScanResult result) {
    // Broaden search to include more common labels found on meters
    // Supports alphanumeric serials like F-086361
    const labelPattern =
        r'(?:sr\.?\s*(?:no|number)?|serial\s*(?:no|number)?|meter\s*(?:no|id|number)?|s/n|property\s*of|id|sr|s\.r)';
    final regex = RegExp(
      '$labelPattern\\s*[:.#-]?\\s*([A-Z0-9][A-Z0-9\\s.-]{3,16})',
      caseSensitive: false,
    );

    for (var index = 0; index < result.detectedLines.length; index++) {
      final line = result.detectedLines[index];

      // Try with label
      final match = regex.firstMatch(line);
      if (match != null) {
        final sameLine = _validLabelledSerial(match.group(1));
        if (sameLine != null) return sameLine;
      }

      // Try next line if current line only has the label
      if (RegExp(labelPattern, caseSensitive: false).hasMatch(line) &&
          index + 1 < result.detectedLines.length) {
        final nextLine = _validLabelledSerial(result.detectedLines[index + 1]);
        if (nextLine != null) return nextLine;
      }

      // Fallback: Check if ANY line looks like a serial number (e.g. F-086361 or 086361)
      // to make detection much faster.
      final alphanumericSerial =
          RegExp(r'\b[A-Z]-[0-9]{6}\b|\b[A-Z][0-9]{6}\b|\b[0-9]{6,10}\b');
      final directMatch = alphanumericSerial.firstMatch(line);
      if (directMatch != null) {
        return directMatch.group(0);
      }
    }
    return null;
  }

  String? _validLabelledSerial(String? value) {
    if (value == null) return null;
    final serial = _normaliseSerial(value);
    // Serial must be at least 5 chars and contain at least one digit
    if (serial.length < 5 ||
        serial.length > 14 ||
        !RegExp(r'\d').hasMatch(serial)) {
      return null;
    }
    return serial;
  }

  /// A serial must be read consistently in two OCR frames. This filters out
  /// one-frame noise such as a random reading or a date.
  bool _confirmSerialCandidate(String serial) {
    if (_serialCandidate == serial) {
      _serialCandidateHits++;
    } else {
      _serialCandidate = serial;
      _serialCandidateHits = 1;
    }

    // Speed up lock-on for expected serial numbers
    if (widget.expectedReferenceNo != null &&
        serial == _normaliseSerial(widget.expectedReferenceNo!)) {
      return _serialCandidateHits >= 1;
    }

    return _serialCandidateHits >= 2;
  }

  bool _isValidSerialText(String? scannedSerial) {
    if (scannedSerial == null) return false;
    if (_isBillScan) return true;

    final cleanScanned = _normaliseSerial(scannedSerial);

    if (_isSerialOnly) {
      // Alphanumeric, 5-14 chars, must have a digit
      return cleanScanned.length >= 5 &&
          cleanScanned.length <= 14 &&
          RegExp(r'\d').hasMatch(cleanScanned);
    }

    if (widget.expectedReferenceNo == null) {
      if (widget.allowUnregisteredMeter &&
          cleanScanned.length >= 5 &&
          cleanScanned.length <= 14 &&
          RegExp(r'\d').hasMatch(cleanScanned)) {
        return true;
      }
      return _isRegisteredMeter(cleanScanned);
    }

    final cleanExpected = _normaliseSerial(widget.expectedReferenceNo!);

    // Exact match or partial match if the scanned is a subset (e.g. 086361 matching F-086361)
    return cleanExpected.isNotEmpty &&
        (cleanScanned == cleanExpected ||
            cleanExpected.contains(cleanScanned) ||
            cleanScanned.contains(cleanExpected));
  }

  String _normaliseSerial(String value) =>
      value.replaceAll(RegExp(r'[^A-Z0-9-]'), '').toUpperCase();

  bool _isRegisteredMeter(String? serial) {
    if (serial == null) return false;
    final normalized = _normaliseSerial(serial);
    return normalized.isNotEmpty &&
        widget.registeredMeterNumbers
            .map(_normaliseSerial)
            .contains(normalized);
  }

  void _showNoMeterMatch() {
    if (!mounted || _hasReturnedMatch) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'No registered meter match found. Please align the serial number and try again.'),
        backgroundColor: AppColors.accentRed,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _laserAnimCtrl.dispose();
    _meterNoCtrl.dispose();
    _readingCtrl.dispose();
    _meterNoFocus.removeListener(_keepSerialFieldVisible);
    _meterNoFocus.dispose();
    _readingFocus.removeListener(_keepReadingFieldVisible);
    _readingFocus.dispose();
    _lookupTimeout?.cancel();
    _autoReadingCaptureTimer?.cancel();
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;

    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _imageRotationFromSensorOrientation(sensorOrientation),
        format: InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation _imageRotationFromSensorOrientation(int orientation) {
    switch (orientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return _buildPermissionDeniedUI();
    }

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final cameraHeight =
        keyboardVisible ? 150.0 : MediaQuery.of(context).size.height * 0.45;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Top controls
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                  ),
                  Text(
                    _isBillScan
                        ? 'Electricity Bill Scanner'
                        : 'Smart Meter Scanner',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _toggleFlash,
                        tooltip: _flashOn ? 'Turn flash off' : 'Turn flash on',
                        icon: Icon(
                          _flashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _flashOn ? Colors.amber : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Camera Viewport (Box shaped)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: cameraHeight,
            child: Stack(
              children: [
                if (_isCameraInitialized && _controller != null)
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ?? 1,
                        height: _controller!.value.previewSize?.width ?? 1,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),

                // Viewfinder
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          _ScannerOverlayWidget(
                            mode: _currentMode,
                            stage: _scannerStage,
                            isSerialOnly: _isSerialOnly,
                            laserPos: _laserAnimation.value,
                            hasDetection: _scannerStage ==
                                    ScannerStage.searchingReading ||
                                _isValidSerialMatch(_latestResult),
                          ),
                          // Stage Indicators (Top Left) - Only for Bill Scan
                          if (_isBillScan)
                            Positioned(
                              top: 40,
                              left: 30,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _statusIndicator(
                                      'BILL MONTH',
                                      _scannerStage.index >
                                          ScannerStage.checkingDate.index),
                                  _statusIndicator(
                                      'REFERENCE NO',
                                      _scannerStage.index >
                                          ScannerStage.checkingRefNo.index),
                                  _statusIndicator(
                                      'SAN LOAD',
                                      _scannerStage.index >
                                          ScannerStage.checkingLoad.index),
                                  _statusIndicator(
                                      'READING',
                                      _scannerStage.index >
                                          ScannerStage.checkingReading.index),
                                ],
                              ),
                            ),
                          Align(
                            alignment: const Alignment(0, 0.7),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _isBillScan
                                    ? _scannerStage == ScannerStage.checkingDate
                                        ? 'CHECKING BILL DATE...'
                                        : _scannerStage ==
                                                ScannerStage.checkingRefNo
                                            ? 'DETECTING REFERENCE NO...'
                                            : _scannerStage ==
                                                    ScannerStage.checkingLoad
                                                ? 'DETECTING SANCTIONED LOAD...'
                                                : _scannerStage ==
                                                        ScannerStage
                                                            .checkingReading
                                                    ? 'DETECTING PRESENT READING...'
                                                    : 'EXTRACTION COMPLETE'
                                    : _isSerialOnly
                                        ? _meterNoCtrl.text.isNotEmpty
                                            ? 'SERIAL DETECTED'
                                            : 'ALIGN SR. NO. LABEL INSIDE THE FRAME'
                                        : _scannerStage ==
                                                ScannerStage.searchingSerial
                                            ? 'SEARCHING SERIAL...'
                                            : 'SEARCHING KWH...',
                                style: TextStyle(
                                  color: _scannerStage ==
                                              ScannerStage.searchingReading ||
                                          _scannerStage ==
                                              ScannerStage.checkingReading ||
                                          _scannerStage ==
                                              ScannerStage.extractionComplete
                                      ? AppColors.accentGreen
                                      : AppColors.accentOrange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_maxZoom > _minZoom)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.zoom_out,
                              color: Colors.white, size: 18),
                          Expanded(
                            child: Slider(
                              value: _zoomLevel,
                              min: _minZoom,
                              max: _maxZoom,
                              divisions: ((_maxZoom - _minZoom) * 10)
                                  .round()
                                  .clamp(1, 80),
                              activeColor: AppColors.accentOrange,
                              inactiveColor: Colors.white38,
                              onChanged: _setZoom,
                            ),
                          ),
                          const Icon(Icons.zoom_in,
                              color: Colors.white, size: 18),
                          Text(
                            '${_zoomLevel.toStringAsFixed(1)}×',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bill capture is intentionally separate from meter OCR.
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _isBillScan
                  ? _buildBillCapturePanel()
                  : _isSerialOnly
                      ? _buildSerialOnlyPanel()
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Live Verification',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (_scannerStage ==
                                      ScannerStage.searchingReading)
                                    TextButton.icon(
                                      onPressed: () => setState(() {
                                        _scannerStage =
                                            ScannerStage.searchingSerial;
                                        _meterNoCtrl.clear();
                                        _readingCtrl.clear();
                                      }),
                                      icon: const Icon(
                                          Icons.restart_alt_rounded,
                                          size: 16),
                                      label: const Text('Reset',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // METER SERIAL NUMBER
                              _inputLabel('METER SERIAL NUMBER'),
                              Container(
                                key: _serialFieldKey,
                                child: TextField(
                                  controller: _meterNoCtrl,
                                  focusNode: _meterNoFocus,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                  decoration: InputDecoration(
                                    hintText: 'Scanning for Serial...',
                                    prefixIcon: Icon(
                                      _scannerStage ==
                                                  ScannerStage
                                                      .searchingReading ||
                                              _meterNoCtrl.text.isNotEmpty
                                          ? Icons.check_circle_rounded
                                          : Icons.numbers_rounded,
                                      color: _scannerStage ==
                                                  ScannerStage
                                                      .searchingReading ||
                                              _meterNoCtrl.text.isNotEmpty
                                          ? AppColors.accentGreen
                                          : AppColors.accentOrange,
                                    ),
                                    suffixIcon: _scannerStage ==
                                                ScannerStage.searchingReading ||
                                            _meterNoCtrl.text.isNotEmpty
                                        ? const Icon(Icons.lock_outline_rounded,
                                            size: 16,
                                            color: AppColors.accentGreen)
                                        : null,
                                    filled: true,
                                    fillColor: _scannerStage ==
                                                ScannerStage.searchingReading ||
                                            _meterNoCtrl.text.isNotEmpty
                                        ? AppColors.accentGreen
                                            .withValues(alpha: 0.05)
                                        : AppColors.background,
                                  ),
                                ),
                              ),

                              if (!_isSerialOnly) ...[
                                const SizedBox(height: 16),
                                _inputLabel('CURRENT READING (kWh)'),
                                Container(
                                  key: _readingFieldKey,
                                  child: TextField(
                                    controller: _readingCtrl,
                                    focusNode: _readingFocus,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: _scannerStage ==
                                              ScannerStage.searchingSerial
                                          ? 'Waiting for Serial Match...'
                                          : 'Scanning for kWh...',
                                      prefixIcon: Icon(Icons.speed_rounded,
                                          color: _readingCtrl.text.isNotEmpty
                                              ? AppColors.accentGreen
                                              : AppColors.textMuted),
                                      suffixIcon: _readingCtrl.text.isNotEmpty
                                          ? const Icon(Icons.auto_awesome,
                                              size: 14,
                                              color: AppColors.accentGreen)
                                          : null,
                                      filled: true,
                                      fillColor: _readingCtrl.text.isNotEmpty
                                          ? AppColors.accentGreen
                                              .withValues(alpha: 0.05)
                                          : AppColors.background,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _isProcessingFrame
                                        ? null
                                        : _captureHighQualityReading,
                                    icon: const Icon(Icons.camera_alt_rounded),
                                    label: Text(
                                      _isProcessingFrame
                                          ? 'Reading meter...'
                                          : 'Capture Reading',
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final serial = _meterNoCtrl.text.trim();
                                    final reading =
                                        int.tryParse(_readingCtrl.text.trim());

                                    if (!_isValidSerialText(serial)) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Serial does not match the registered meter. Please scan again.'),
                                          backgroundColor: AppColors.accentRed,
                                        ),
                                      );
                                      return;
                                    }

                                    if (!_isSerialOnly &&
                                        !_isPlausibleReading(reading)) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(widget.minimumReading ==
                                                  null
                                              ? 'No valid kWh reading detected yet.'
                                              : 'Reading must be at least ${widget.minimumReading} kWh. Keep the LCD in focus and scan again.'),
                                        ),
                                      );
                                      return;
                                    }

                                    final result = OCRScanResult(
                                      meterReading: reading,
                                      meterNo: serial,
                                      referenceNo: _latestResult?.referenceNo,
                                      consumerName: _latestResult?.consumerName,
                                      billDate: _latestResult?.billDate,
                                      rawText: _latestResult?.rawText ?? '',
                                      detectedLines:
                                          _latestResult?.detectedLines ?? [],
                                    );
                                    Navigator.of(context).pop(result);
                                  },
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: Text(_isSerialOnly
                                      ? 'Confirm Meter No'
                                      : 'Confirm & Save'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
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

  Widget _buildSerialOnlyPanel() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scan Meter Serial Number',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Text(
          'Keep the meter\'s “Sr. No.” or “Serial No.” label and its value clearly inside the frame. A labelled 5–14 character serial with letters and digits is accepted.',
          style: TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Current reading is not scanned while adding a meter.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBillCapturePanel() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scanning electricity bill',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text(
          'Hold the bill inside the frame. The app will automatically detect current month\'s bill details.',
          style:
              TextStyle(color: AppColors.textMuted, height: 1.35, fontSize: 13),
        ),
        Spacer(),
        Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 12),
              Text('Analyzing bill in real-time...',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
        Spacer(),
      ],
    );
  }

  Widget _statusIndicator(String label, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: isDone ? AppColors.accentGreen : Colors.white38,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isDone ? Colors.white : Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (isDone)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text(
                'ADDED',
                style: TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 8,
                    fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inputLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 0.5),
        ),
      );

  Widget _buildPermissionDeniedUI() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Camera Permission Required'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                size: 72, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text(
              'Camera Access Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'MeterPro requires camera access to scan electricity bills and digital meters in real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () async {
                if (await Permission.camera.isPermanentlyDenied) {
                  await openAppSettings();
                } else {
                  await _checkPermissionAndInitCamera();
                }
              },
              icon: const Icon(Icons.settings),
              label: const Text('Grant Camera Permission'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlayWidget extends StatelessWidget {
  final ScanTargetMode mode;
  final ScannerStage stage;
  final bool isSerialOnly;
  final double laserPos;
  final bool hasDetection;

  const _ScannerOverlayWidget({
    required this.mode,
    required this.stage,
    required this.isSerialOnly,
    required this.laserPos,
    required this.hasDetection,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(
        mode: mode,
        stage: stage,
        isSerialOnly: isSerialOnly,
        laserPos: laserPos,
        hasDetection: hasDetection,
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final ScanTargetMode mode;
  final ScannerStage stage;
  final bool isSerialOnly;
  final double laserPos;
  final bool hasDetection;

  _OverlayPainter({
    required this.mode,
    required this.stage,
    required this.isSerialOnly,
    required this.laserPos,
    required this.hasDetection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final double boxWidth = width * 0.90;
    final double boxHeight = mode == ScanTargetMode.bill
        ? height * 0.82
        : height * 0.08; // Very thin for Sr No

    final Rect scanRect = Rect.fromCenter(
      center: Offset(width / 2, height / 2 - 20),
      width: boxWidth,
      height: boxHeight,
    );

    // Specific Search Rects (relative to scanRect)
    Rect? searchRect;
    String label = "";

    if (mode == ScanTargetMode.bill) {
      switch (stage) {
        case ScannerStage.checkingDate:
          searchRect = Rect.fromLTWH(
              scanRect.right - (boxWidth * 0.3),
              scanRect.top + (boxHeight * 0.05),
              boxWidth * 0.25,
              boxHeight * 0.12);
          label = "BILL MONTH";
          break;
        case ScannerStage.checkingRefNo:
          searchRect = Rect.fromLTWH(
              scanRect.left + (boxWidth * 0.05),
              scanRect.top + (boxHeight * 0.2),
              boxWidth * 0.45,
              boxHeight * 0.1);
          label = "REFERENCE NO";
          break;
        case ScannerStage.checkingLoad:
          searchRect = Rect.fromLTWH(
              scanRect.left + (boxWidth * 0.45),
              scanRect.top + (boxHeight * 0.2),
              boxWidth * 0.2,
              boxHeight * 0.1);
          label = "SAN LOAD";
          break;
        case ScannerStage.checkingReading:
          searchRect = Rect.fromLTWH(
              scanRect.left + (boxWidth * 0.45),
              scanRect.top + (boxHeight * 0.42),
              boxWidth * 0.25,
              boxHeight * 0.08);
          label = "PRESENT READING";
          break;
        default:
          break;
      }
    }

    final backgroundPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, width, height))
      ..addRect(scanRect);

    if (searchRect != null) {
      backgroundPath.addRect(searchRect);
    }

    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawPath(backgroundPath, bgPaint);

    // Main Viewfinder Color Logic
    Color viewfinderColor =
        isSerialOnly ? Colors.cyanAccent : AppColors.accentRed;
    if (mode == ScanTargetMode.bill) {
      if (stage == ScannerStage.checkingRefNo) {
        viewfinderColor = Colors.orangeAccent;
      }

      if (stage == ScannerStage.checkingLoad) {
        viewfinderColor = Colors.blueAccent;
      }
      if (stage == ScannerStage.checkingReading) {
        viewfinderColor = Colors.purpleAccent;
      }
      if (stage == ScannerStage.extractionComplete) {
        viewfinderColor = AppColors.accentGreen;
      }
    } else {
      if (stage == ScannerStage.searchingReading || hasDetection) {
        viewfinderColor = AppColors.accentGreen;
      }
    }

    final borderPaint = Paint()
      ..color = viewfinderColor.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(16)),
      borderPaint,
    );

    // Draw Corners like in the screenshot
    final cornerPaint = Paint()
      ..color = viewfinderColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double len = mode == ScanTargetMode.bill ? boxWidth * 0.15 : 24;
    const double rad = 8;

    // Top Left
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.left, scanRect.top + len)
          ..lineTo(scanRect.left, scanRect.top + rad)
          ..arcToPoint(Offset(scanRect.left + rad, scanRect.top),
              radius: const Radius.circular(rad))
          ..lineTo(scanRect.left + len, scanRect.top),
        cornerPaint);

    // Top Right
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.right - len, scanRect.top)
          ..lineTo(scanRect.right - rad, scanRect.top)
          ..arcToPoint(Offset(scanRect.right, scanRect.top + rad),
              radius: const Radius.circular(rad))
          ..lineTo(scanRect.right, scanRect.top + len),
        cornerPaint);

    // Bottom Left
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.left, scanRect.bottom - len)
          ..lineTo(scanRect.left, scanRect.bottom - rad)
          ..arcToPoint(Offset(scanRect.left + rad, scanRect.bottom),
              radius: const Radius.circular(rad), clockwise: false)
          ..lineTo(scanRect.left + len, scanRect.bottom),
        cornerPaint);

    // Bottom Right
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.right - len, scanRect.bottom)
          ..lineTo(scanRect.right - rad, scanRect.bottom)
          ..arcToPoint(Offset(scanRect.right, scanRect.bottom - rad),
              radius: const Radius.circular(rad), clockwise: false)
          ..lineTo(scanRect.right, scanRect.bottom - len),
        cornerPaint);

    final double laserY = scanRect.top + (scanRect.height * laserPos);
    final laserPaint = Paint()
      ..color = viewfinderColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(scanRect.left + 12, laserY),
      Offset(scanRect.right - 12, laserY),
      laserPaint,
    );

    // Draw active search rect with label
    if (searchRect != null) {
      final searchPaint = Paint()
        ..color = viewfinderColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
          RRect.fromRectAndRadius(searchRect, const Radius.circular(8)),
          searchPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              color: viewfinderColor,
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(searchRect.left, searchRect.top - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) => true;
}
