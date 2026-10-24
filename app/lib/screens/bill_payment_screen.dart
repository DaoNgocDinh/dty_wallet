import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import 'home_screen.dart' show formatVnd;

/// Loại hóa đơn theo đặc tả UC07 (bước 5 luồng chính)
const List<Map<String, dynamic>> kBillTypes = [
  {
    'id': 'Điện',
    'label': 'Điện',
    'icon': Icons.bolt_rounded,
    'color': Color(0xFFF59E0B),
    'hint': 'VD: EVN001',
  },
  {
    'id': 'Nước',
    'label': 'Nước',
    'icon': Icons.water_drop_rounded,
    'color': Color(0xFF0EA5E9),
    'hint': 'VD: WATER001',
  },
  {
    'id': 'Internet',
    'label': 'Internet',
    'icon': Icons.wifi_rounded,
    'color': Color(0xFF6366F1),
    'hint': 'VD: INET001',
  },
  {
    'id': 'Bảo hiểm',
    'label': 'Bảo hiểm',
    'icon': Icons.health_and_safety_rounded,
    'color': Color(0xFF10B981),
    'hint': 'VD: INS001',
  },
];

/// Màn hình Thanh toán hóa đơn – Use Case 07 (Cao Thái Tuấn)
///
/// Luồng chính:
/// 1. Chọn hình thức: Trực tiếp (3.1) hoặc QR (3.2)
/// 2. Chọn loại hóa đơn
/// 3. Nhập mã KH (trực tiếp) hoặc nhập mã QR (giả lập quét)
/// 4. Gọi API lấy thông tin hóa đơn → Xác nhận (bước 9-10)
/// 5. Nhập PIN 6 số → Thanh toán (bước 11-14)
/// 6. Cập nhật số dư & Biên lai thành công (bước 15-17)
class BillPaymentScreen extends StatefulWidget {
  const BillPaymentScreen({super.key});

  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  // ── Bước UI ──────────────────────────────────────────────────────────────
  // step 1: chọn hình thức  |  step 2: chọn loại hóa đơn
  // step 3: nhập mã / QR    |  step 4: thông tin hóa đơn + xác nhận
  int _step = 1;

  // Bước 3: hình thức thanh toán
  // 'direct' = Thanh toán trực tiếp (3.1) | 'qr' = Thanh toán QR (3.2)
  String _paymentMethod = 'direct';

  // Bước 6: loại hóa đơn (Điện / Nước / Internet / Bảo hiểm)
  String _selectedBillType = 'Điện';

  // Bước 7: thông tin nhập liệu
  final _codeController = TextEditingController();     // Mã KH / Mã hóa đơn
  final _qrController = TextEditingController();       // Mã QR (giả lập)
  final _contentController = TextEditingController();  // Nội dung thanh toán (tùy chọn)

  String? _codeError;
  String? _qrError;

  // Bước 9: thông tin hóa đơn từ API đối tác
  Map<String, dynamic>? _billInfo;
  bool _isLoadingBill = false;
  String? _billError;

  // PIN
  int _pinFailCount = 0;
  bool _isPinLocked = false;

  // Trạng thái tổng thể
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    _qrController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ── Getter helper ─────────────────────────────────────────────────────────
  Map<String, dynamic> get _billTypeMeta =>
      kBillTypes.firstWhere((t) => t['id'] == _selectedBillType, orElse: () => kBillTypes.first);

  // ── Bước 7: Kiểm tra định dạng đầu vào ───────────────────────────────────

  bool _validateDirectInput() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Mã khách hàng/Mã hóa đơn không được để trống.');
      return false;
    }
    setState(() => _codeError = null);
    return true;
  }

  bool _validateQrInput() {
    final qr = _qrController.text.trim();
    if (qr.isEmpty) {
      setState(() => _qrError = 'Vui lòng nhập mã QR để tiếp tục.');
      return false;
    }
    if (!qr.toUpperCase().startsWith('QR_')) {
      setState(() => _qrError = 'Mã QR không hợp lệ hoặc không thể giải mã.');
      return false;
    }
    setState(() => _qrError = null);
    return true;
  }

  // ── Bước 8: Gọi API đối tác lấy thông tin hóa đơn ───────────────────────
  Future<void> _lookupBill() async {
    final isValid = _paymentMethod == 'direct' ? _validateDirectInput() : _validateQrInput();
    if (!isValid) return;

    setState(() {
      _isLoadingBill = true;
      _billError = null;
      _billInfo = null;
    });

    try {
      final session = AppScope.of(context);
      final res = await session.fetchBillInfo(
        paymentMethod: _paymentMethod,
        billType: _selectedBillType,
        customerCode: _paymentMethod == 'direct' ? _codeController.text.trim() : null,
        qrData: _paymentMethod == 'qr' ? _qrController.text.trim() : null,
      );
      if (!mounted) return;
      setState(() {
        _billInfo = res['bill'] as Map<String, dynamic>?;
        _step = 4; // Bước 9: hiển thị thông tin hóa đơn
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _billError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _billError = 'Không thể kết nối đến hệ thống đối tác. Vui lòng thử lại sau.');
    } finally {
      if (mounted) setState(() => _isLoadingBill = false);
    }
  }

  // ── Bước 10: Xác nhận → mở bottom sheet nhập PIN ─────────────────────────
  void _confirmPayment() {
    if (_isPinLocked) {
      _showErrorDialog('Khóa xác thực', 'Giao dịch đã bị khóa do nhập sai PIN quá 3 lần. Vui lòng thử lại sau.');
      return;
    }
    _showPinSheet();
  }

  // ── Bước 11-13: Bottom sheet nhập PIN 6 số ───────────────────────────────
  void _showPinSheet() {
    final pinController = TextEditingController();
    String? pinError;
    bool isLoading = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nhập mã PIN',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Xác thực giao dịch thanh toán hóa đơn ${_billInfo?['billType'] ?? ''}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Mã PIN (6 chữ số)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.lightBlue),
                  counterText: '',
                  errorText: pinError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_pinFailCount > 0 && _pinFailCount < 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Còn ${3 - _pinFailCount} lần nhập trước khi khóa.',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 20),
              AppButton(
                text: 'Xác thực & Thanh toán',
                isLoading: isLoading,
                onPressed: () async {
                  final pin = pinController.text.trim();
                  if (pin.length != 6) {
                    setSheet(() => pinError = 'Mã PIN gồm đúng 6 chữ số.');
                    return;
                  }
                  setSheet(() { isLoading = true; pinError = null; });

                  try {
                    await _submitPayment(pin);
                    if (!mounted) return;
                    Navigator.of(sheetCtx).pop();
                    _showSuccessDialog();
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    if (e.code == 'PIN_LOCKED') {
                      setState(() => _isPinLocked = true);
                      Navigator.of(sheetCtx).pop();
                      _showErrorDialog(
                        'Khóa xác thực',
                        'Nhập sai mã PIN quá 3 lần. Giao dịch đã bị hủy và khóa xác thực giao dịch tạm thời.',
                      );
                    } else if (e.code == 'WRONG_PIN') {
                      setState(() => _pinFailCount++);
                      setSheet(() {
                        isLoading = false;
                        pinError = e.message;
                      });
                    } else if (e.code == 'INSUFFICIENT_BALANCE') {
                      Navigator.of(sheetCtx).pop();
                      // E2: quay về bước 9 xác nhận
                      _showErrorDialog('Số dư không đủ', e.message);
                    } else {
                      Navigator.of(sheetCtx).pop();
                      _showRetryDialog(e.message);
                    }
                  } catch (_) {
                    if (!mounted) return;
                    Navigator.of(sheetCtx).pop();
                    _showRetryDialog('Không thể kết nối đến hệ thống đối tác. Vui lòng thử lại sau.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bước 14: Gọi API thanh toán ──────────────────────────────────────────
  Future<void> _submitPayment(String pin) async {
    setState(() => _isSubmitting = true);
    try {
      final session = AppScope.of(context);
      final bill = _billInfo!;
      final res = await session.payBill(
        paymentMethod: _paymentMethod,
        billType: bill['billType'] as String,
        customerCode: bill['customerCode'] as String,
        pin: pin,
        amount: (bill['totalAmount'] as num?)?.toDouble(),
        qrData: _paymentMethod == 'qr' ? _qrController.text.trim() : null,
        content: _contentController.text.trim().isNotEmpty
            ? _contentController.text.trim()
            : null,
      );
      // Cập nhật thông tin hóa đơn từ response nếu có
      if (res['bill'] is Map<String, dynamic>) {
        setState(() => _billInfo = res['bill'] as Map<String, dynamic>);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Bước 17: Dialog "Thanh toán thành công" ───────────────────────────────
  void _showSuccessDialog() {
    final bill = _billInfo;
    final totalAmount = (bill?['totalAmount'] as num?)?.toDouble() ?? 0;
    final balance = AppScope.of(context).user?.walletBalance ?? 0;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 12),
            const Text(
              'Thanh toán thành công',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _ReceiptRow(label: 'Loại hóa đơn', value: bill?['billType']?.toString() ?? ''),
            _ReceiptRow(label: 'Nhà cung cấp', value: bill?['provider']?.toString() ?? ''),
            _ReceiptRow(label: 'Khách hàng', value: bill?['customerName']?.toString() ?? ''),
            _ReceiptRow(label: 'Kỳ thanh toán', value: bill?['period']?.toString() ?? ''),
            if ((bill?['fee'] as num? ?? 0) > 0)
              _ReceiptRow(
                label: 'Phí dịch vụ',
                value: formatVnd(bill?['fee']),
                valueColor: Colors.orange,
              ),
            _ReceiptRow(
              label: 'Số tiền thanh toán',
              value: formatVnd(totalAmount),
              valueColor: AppColors.lightBlue,
              bold: true,
            ),
            _ReceiptRow(label: 'Số dư còn lại', value: formatVnd(balance)),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(); // Quay về trang chủ
              } else {
                setState(() {
                  _step = 1;
                  _billInfo = null;
                  _billError = null;
                  _codeController.clear();
                  _qrController.clear();
                  _contentController.clear();
                  _pinFailCount = 0;
                });
              }
            },
            child: const Text('Hoàn tất', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.lightBlue)),
          ),
        ],
      ),
    );
  }

  // ── AF2: Hủy giao dịch ───────────────────────────────────────────────────
  void _confirmCancel() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận hủy'),
        content: const Text('Bạn có chắc muốn hủy giao dịch thanh toán hóa đơn này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Không'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              // AF2.4: quay về màn hình hóa đơn (bước 1)
              setState(() {
                _step = 1;
                _billInfo = null;
                _billError = null;
                _codeController.clear();
                _qrController.clear();
                _contentController.clear();
                _codeError = null;
                _qrError = null;
                _pinFailCount = 0;
                _isPinLocked = false;
              });
            },
            child: const Text('Xác nhận hủy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // E5: Nút "Thử lại"
  void _showRetryDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Lỗi kết nối'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmPayment();
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Thanh toán hóa đơn',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (_step > 1) {
              // AF1: Quay lại bước trước
              setState(() {
                if (_step == 4) {
                  _step = 3;
                  _billInfo = null;
                  _billError = null;
                } else {
                  _step--;
                }
              });
            } else {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            }
          },
        ),
        actions: [
          if (_step > 1)
            TextButton(
              onPressed: _confirmCancel,
              child: const Text('Hủy', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SafeArea(
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 1:
        return _buildStep1SelectMethod();
      case 2:
        return _buildStep2SelectBillType();
      case 3:
        return _buildStep3InputCode();
      case 4:
        return _buildStep4ConfirmBill();
      default:
        return _buildStep1SelectMethod();
    }
  }

  // ── Bước 3: Chọn hình thức thanh toán ────────────────────────────────────
  Widget _buildStep1SelectMethod() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepIndicator(current: 1, total: 4, labels: const ['Hình thức', 'Loại HĐ', 'Nhập mã', 'Xác nhận']),
          const SizedBox(height: 24),
          const Text(
            'Chọn hình thức thanh toán',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _MethodCard(
            key: const Key('method_direct'),
            icon: Icons.receipt_long_rounded,
            color: AppColors.lightBlue,
            title: 'Thanh toán trực tiếp',
            subtitle: 'Nhập mã khách hàng / mã hóa đơn',
            selected: _paymentMethod == 'direct',
            onTap: () => setState(() => _paymentMethod = 'direct'),
          ),
          const SizedBox(height: 12),
          _MethodCard(
            key: const Key('method_qr'),
            icon: Icons.qr_code_scanner_rounded,
            color: const Color(0xFF6366F1),
            title: 'Thanh toán qua QR',
            subtitle: 'Quét mã QR hóa đơn',
            selected: _paymentMethod == 'qr',
            onTap: () => setState(() => _paymentMethod = 'qr'),
          ),
          const SizedBox(height: 28),
          AppButton(
            text: 'Tiếp tục',
            onPressed: () => setState(() => _step = 2),
          ),
        ],
      ),
    );
  }

  // ── Bước 5-6: Chọn loại hóa đơn ─────────────────────────────────────────
  Widget _buildStep2SelectBillType() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepIndicator(current: 2, total: 4, labels: const ['Hình thức', 'Loại HĐ', 'Nhập mã', 'Xác nhận']),
          const SizedBox(height: 24),
          const Text(
            'Chọn loại hóa đơn',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: kBillTypes.map((bt) {
              final selected = _selectedBillType == bt['id'];
              return GestureDetector(
                onTap: () => setState(() => _selectedBillType = bt['id'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected ? (bt['color'] as Color).withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? (bt['color'] as Color) : Colors.grey.withValues(alpha: 0.2),
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: (bt['color'] as Color).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))]
                        : [const BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(bt['icon'] as IconData, color: bt['color'] as Color, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        bt['label'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: selected ? (bt['color'] as Color) : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          AppButton(
            text: 'Tiếp tục',
            onPressed: () => setState(() => _step = 3),
          ),
        ],
      ),
    );
  }

  // ── Bước 7: Nhập mã KH hoặc QR ───────────────────────────────────────────
  Widget _buildStep3InputCode() {
    final meta = _billTypeMeta;
    final isQr = _paymentMethod == 'qr';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepIndicator(current: 3, total: 4, labels: const ['Hình thức', 'Loại HĐ', 'Nhập mã', 'Xác nhận']),
          const SizedBox(height: 24),

          // Header loại hóa đơn
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (meta['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(meta['icon'] as IconData, color: meta['color'] as Color, size: 26),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta['label'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      isQr ? 'Thanh toán qua mã QR' : 'Thanh toán trực tiếp',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Input: Mã KH (trực tiếp) hoặc Mã QR
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isQr) ...[
                  // Luồng con 3.1: Thanh toán trực tiếp
                  Text(
                    'Mã khách hàng / Mã hóa đơn',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('customerCodeField'),
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: meta['hint'] as String,
                      prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.lightBlue),
                      errorText: _codeError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) {
                      if (_codeError != null) setState(() => _codeError = null);
                    },
                  ),
                ] else ...[
                  // Luồng con 3.2: Thanh toán QR
                  const Text(
                    'Mã QR hóa đơn',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Nhập mã QR từ hóa đơn (bắt đầu bằng QR_)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('qrDataField'),
                    controller: _qrController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'VD: QR_EVN001',
                      prefixIcon: const Icon(Icons.qr_code_rounded, color: AppColors.lightBlue),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt_rounded, color: AppColors.lightBlue),
                        tooltip: 'Quét QR',
                        onPressed: () {
                          // Giả lập quét QR: điền sẵn mẫu
                          _qrController.text = 'QR_EVN001';
                          if (_qrError != null) setState(() => _qrError = null);
                        },
                      ),
                      errorText: _qrError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) {
                      if (_qrError != null) setState(() => _qrError = null);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // Nội dung thanh toán (tùy chọn)
                const Text(
                  'Nội dung thanh toán (tùy chọn)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('contentField'),
                  controller: _contentController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: 'Ghi chú thêm...',
                    prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.lightBlue),
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          if (_billError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_billError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            text: 'Tra cứu hóa đơn',
            isLoading: _isLoadingBill,
            onPressed: _lookupBill,
          ),
        ],
      ),
    );
  }

  // ── Bước 9-10: Hiển thị thông tin hóa đơn và xác nhận ───────────────────
  Widget _buildStep4ConfirmBill() {
    final bill = _billInfo;
    if (bill == null) return const SizedBox.shrink();

    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0;
    final fee = (bill['fee'] as num?)?.toDouble() ?? 0;
    final amount = (bill['amount'] as num?)?.toDouble() ?? 0;
    final balance = AppScope.of(context).user?.walletBalance ?? 0;
    final isEnough = balance >= totalAmount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepIndicator(current: 4, total: 4, labels: const ['Hình thức', 'Loại HĐ', 'Nhập mã', 'Xác nhận']),
          const SizedBox(height: 24),

          // Card thông tin hóa đơn (Bước 9)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (_billTypeMeta['color'] as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_billTypeMeta['icon'] as IconData, color: _billTypeMeta['color'] as Color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hóa đơn ${bill['billType']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          bill['provider']?.toString() ?? '',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                _InfoRow(label: 'Khách hàng', value: bill['customerName']?.toString() ?? ''),
                _InfoRow(label: 'Mã khách hàng', value: bill['customerCode']?.toString() ?? ''),
                _InfoRow(label: 'Kỳ thanh toán', value: bill['period']?.toString() ?? ''),
                _InfoRow(label: 'Tiền hóa đơn', value: formatVnd(amount)),
                if (fee > 0)
                  _InfoRow(label: 'Phí dịch vụ', value: formatVnd(fee), valueColor: Colors.orange),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng thanh toán',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      formatVnd(totalAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isEnough ? AppColors.lightBlue : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Số dư ví
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isEnough
                  ? Colors.green.withValues(alpha: 0.06)
                  : AppColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEnough
                    ? Colors.green.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isEnough ? Icons.account_balance_wallet_rounded : Icons.warning_rounded,
                      color: isEnough ? Colors.green : AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Số dư ví', style: TextStyle(fontSize: 13)),
                  ],
                ),
                Text(
                  formatVnd(balance),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isEnough ? Colors.green : AppColors.error,
                  ),
                ),
              ],
            ),
          ),

          if (!isEnough) ...[
            const SizedBox(height: 8),
            // E2: Số dư không đủ
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Số dư không đủ để thực hiện giao dịch.',
                style: TextStyle(color: AppColors.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            text: 'Xác nhận thanh toán',
            isLoading: _isSubmitting,
            onPressed: isEnough ? _confirmPayment : null,
          ),
        ],
      ),
    );
  }
}

// ── Widgets nhỏ tái sử dụng ───────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total, required this.labels});
  final int current;
  final int total;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i + 1 == current;
        final done = i + 1 < current;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 4,
                      decoration: BoxDecoration(
                        color: done || active ? AppColors.lightBlue : Colors.grey.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: active ? AppColors.lightBlue : (done ? AppColors.lightBlue.withValues(alpha: 0.7) : AppColors.textSecondary),
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (i < total - 1) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.grey.withValues(alpha: 0.2), width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: selected ? color.withValues(alpha: 0.15) : const Color(0x0D000000),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: selected ? color : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? color : Colors.grey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: valueColor ?? AppColors.textPrimary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.valueColor, this.bold = false});
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                fontSize: bold ? 15 : 13,
                color: valueColor ?? AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
