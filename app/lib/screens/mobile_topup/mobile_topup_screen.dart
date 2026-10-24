import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../utils/format_utils.dart' show formatVnd;

/// Danh sách 4 nhà mạng theo chuẩn đặc tả Use Case 08
const List<Map<String, dynamic>> kCarriers = [
  {
    'name': 'Viettel',
    'color': Color(0xFFD32F2F),
    'icon': Icons.cell_tower_rounded,
  },
  {
    'name': 'Vinaphone',
    'color': Color(0xFF0288D1),
    'icon': Icons.wifi_calling_3_rounded,
  },
  {
    'name': 'Mobifone',
    'color': Color(0xFF1976D2),
    'icon': Icons.signal_cellular_alt_rounded,
  },
  {
    'name': 'Vietnamobile',
    'color': Color(0xFFFF9800),
    'icon': Icons.bolt_rounded,
  },
];

/// Mệnh giá nạp ĐT theo đặc tả luồng con 8.1.1
const List<double> kDenominations = [
  10000,
  20000,
  50000,
  100000,
  200000,
  500000,
];

/// Màn hình Nạp tiền điện thoại / Nạp Data - Use Case 08 (Cao Thái Tuấn)
class MobileTopupScreen extends StatefulWidget {
  const MobileTopupScreen({
    super.key,
    this.initialIsData = false,
    this.initialPhoneNumber,
    this.initialCarrier,
    this.initialAmount,
    this.isEmbedded = false,
    this.onBackToHome,
  });

  final bool initialIsData;
  final String? initialPhoneNumber;
  final String? initialCarrier;
  final double? initialAmount;
  final bool isEmbedded;
  final VoidCallback? onBackToHome;

  @override
  State<MobileTopupScreen> createState() => _MobileTopupScreenState();
}

class _MobileTopupScreenState extends State<MobileTopupScreen> {
  // Loại dịch vụ: false = Nạp tiền điện thoại (8.1), true = Nạp Data (8.2)
  late bool _isData;
  late String _selectedCarrier;
  final _phoneController = TextEditingController();

  double _selectedDenomination = 50000;
  List<Map<String, dynamic>> _dataPackages = [];
  Map<String, dynamic>? _selectedDataPackage;
  bool _isLoadingPackages = false;

  double _walletBalance = 0;
  bool _isLoadingWallet = false;
  bool _isOtherPhone = false; // Luồng thay thế AF1: Nạp cho số khác

  String? _phoneError;
  String? _packageError;
  String? _generalError;

  int _failedPinCount = 0;
  bool _isPinLocked = false;

  @override
  void initState() {
    super.initState();
    _isData = widget.initialIsData;
    _selectedCarrier = widget.initialCarrier ?? 'Viettel';
    if (widget.initialAmount != null && kDenominations.contains(widget.initialAmount)) {
      _selectedDenomination = widget.initialAmount!;
    }
    if (widget.initialPhoneNumber != null) {
      _phoneController.text = widget.initialPhoneNumber!;
      _isOtherPhone = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AppScope.of(context).user;
    if (user != null) {
      _walletBalance = user.walletBalance;
      if (_phoneController.text.isEmpty && !_isOtherPhone) {
        if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
          _phoneController.text = user.phoneNumber!;
        }
      }
    }
    _loadWallet();
    if (_isData) {
      _fetchDataPackages();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    _isLoadingWallet = true;
    try {
      final res = await AppScope.of(context).fetchWallet();
      if (!mounted) return;
      final bal = res['walletBalance'] ?? res['balance'] ?? 0;
      setState(() => _walletBalance = (bal as num).toDouble());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  Future<void> _fetchDataPackages() async {
    setState(() {
      _isLoadingPackages = true;
      _packageError = null;
    });
    try {
      final list = await AppScope.of(context).fetchDataPackages(carrier: _selectedCarrier);
      if (!mounted) return;
      setState(() {
        _dataPackages = list;
        if (list.isNotEmpty) {
          // Mặc định chọn gói khả dụng đầu tiên
          _selectedDataPackage = list.firstWhere(
            (p) => p['available'] != false,
            orElse: () => list.first,
          );
        } else {
          _selectedDataPackage = null;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _packageError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _packageError = 'Không thể lấy danh sách gói Data');
    } finally {
      if (mounted) setState(() => _isLoadingPackages = false);
    }
  }

  /// Bước 7 & Ngoại lệ E1: Kiểm tra định dạng số điện thoại
  /// Bắt buộc nhập, chỉ gồm ký tự số và có 10 chữ số
  String? _validatePhoneNumber(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      return 'Số điện thoại không hợp lệ. Vui lòng kiểm tra lại.';
    }
    final regex = RegExp(r'^[0-9]{10}$');
    if (!regex.hasMatch(trimmed)) {
      return 'Số điện thoại không hợp lệ. Vui lòng kiểm tra lại.';
    }
    return null;
  }

  double get _currentAmount {
    if (_isData) {
      final price = _selectedDataPackage?['price'];
      if (price is num) return price.toDouble();
      return 0;
    }
    return _selectedDenomination;
  }

  /// Bước 10: Người dùng bấm "Tiếp tục" -> Kiểm tra thông tin trước khi xác nhận
  void _onProceed() {
    final phoneErr = _validatePhoneNumber(_phoneController.text);
    String? pkgErr;

    if (_isData) {
      if (_selectedDataPackage == null) {
        pkgErr = 'Vui lòng chọn một gói Data';
      } else if (_selectedDataPackage!['available'] == false) {
        // Ngoại lệ E6: Gói Data không còn khả dụng
        pkgErr = 'Gói Data không còn khả dụng. Vui lòng chọn gói khác.';
      }
    }

    setState(() {
      _phoneError = phoneErr;
      _packageError = pkgErr;
      _generalError = null;
    });

    if (phoneErr != null || pkgErr != null) {
      return;
    }

    // Bước 9: Hiển thị thông tin xác nhận giao dịch
    _showConfirmationSheet();
  }

  /// Bước 9: Hệ thống hiển thị thông tin xác nhận giao dịch gồm:
  /// số điện thoại, nhà mạng, dịch vụ, mệnh giá/gói Data và số tiền thanh toán.
  /// Bước 10: Người dùng kiểm tra và xác nhận (hoặc Hủy -> AF2)
  Future<void> _showConfirmationSheet() async {
    final phone = _phoneController.text.trim();
    final amount = _currentAmount;
    final serviceName = _isData ? 'Nạp gói Data' : 'Nạp tiền điện thoại';
    final packageName = _isData ? (_selectedDataPackage?['name']?.toString() ?? '') : '';
    final packageData = _isData ? (_selectedDataPackage?['data']?.toString() ?? '') : '';
    final packageDuration = _isData ? (_selectedDataPackage?['duration']?.toString() ?? '') : '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Xác nhận giao dịch',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Hủy giao dịch',
                  onPressed: () => _handleCancelTransaction(sheetCtx),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Vui lòng kiểm tra kỹ thông tin trước khi thực hiện',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _confirmRow('Dịch vụ:', serviceName, isBold: true),
                  const Divider(height: 16),
                  _confirmRow('Nhà mạng:', _selectedCarrier),
                  const Divider(height: 16),
                  _confirmRow('Số điện thoại nhận:', phone, isBold: true),
                  const Divider(height: 16),
                  if (_isData) ...[
                    _confirmRow('Gói Data:', '$packageName ($packageData - $packageDuration)'),
                    const Divider(height: 16),
                  ] else ...[
                    _confirmRow('Mệnh giá nạp:', formatVnd(_selectedDenomination)),
                    const Divider(height: 16),
                  ],
                  _confirmRow(
                    'Số tiền thanh toán:',
                    formatVnd(amount),
                    valueColor: const Color(0xFF2E7D32),
                    isBold: true,
                    fontSize: 16,
                  ),
                  const Divider(height: 16),
                  _confirmRow('Nguồn thanh toán:', 'Số dư ví điện tử'),
                  const Divider(height: 16),
                  _confirmRow('Số dư khả dụng:', formatVnd(_walletBalance)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Nút Xác nhận giao dịch
            AppButton(
              text: 'Xác nhận thanh toán',
              icon: Icons.check_circle_outline_rounded,
              height: 48,
              fontSize: 15,
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                _promptPinAndExecute(amount);
              },
            ),
            const SizedBox(height: 10),
            // Nút Hủy (AF2)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _handleCancelTransaction(sheetCtx),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  /// Luồng thay thế AF2: Hủy giao dịch
  /// AF2.1: Người dùng chọn "Hủy"
  /// AF2.2: Hệ thống hiển thị yêu cầu xác nhận hủy giao dịch
  /// AF2.3: Người dùng xác nhận hủy
  /// AF2.4: Hệ thống hủy giao dịch và quay về màn hình chức năng Nạp tiền điện thoại/data
  Future<void> _handleCancelTransaction(BuildContext currentCtx) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xác nhận hủy'),
        content: const Text('Bạn có chắc chắn muốn hủy giao dịch này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Tiếp tục'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      if (mounted) {
        Navigator.of(currentCtx).pop(); // Đóng bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Giao dịch đã được hủy'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Bước 11: Hệ thống yêu cầu người dùng nhập mã PIN
  /// Bước 12: Người dùng nhập mã PIN
  /// Bước 13: Hệ thống xác thực mã PIN và kiểm tra số dư ví (E2, E3)
  /// Bước 14: Gọi API nhà mạng để xử lý giao dịch (E4, E5)
  /// Bước 15, 16, 17, 18: Nhận kết quả, trừ tiền và hiển thị "Giao dịch thành công"
  Future<void> _promptPinAndExecute(double amount) async {
    // 13.1 & 13.2: Kiểm tra số dư ví trước (Ngoại lệ E2)
    if (_walletBalance < amount) {
      _showInsufficientBalanceDialog(amount);
      return;
    }

    if (_isPinLocked) {
      _showPinLockedDialog();
      return;
    }

    final pinController = TextEditingController();
    String? pinError;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pinSheetCtx) => StatefulBuilder(
        builder: (context, setPinState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(pinSheetCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nhập mã PIN xác nhận',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(pinSheetCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Vui lòng nhập mã PIN gồm 6 chữ số để thanh toán ${formatVnd(amount)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: pinController,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Mã PIN giao dịch (6 chữ số)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.lightBlue),
                    errorText: pinError,
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  text: 'Xác thực & Thanh toán',
                  isLoading: isSubmitting,
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    if (pin.length != 6) {
                      setPinState(() => pinError = 'Mã PIN bắt buộc gồm 6 chữ số');
                      return;
                    }

                    setPinState(() {
                      isSubmitting = true;
                      pinError = null;
                    });

                    try {
                      final phone = _phoneController.text.trim();
                      final String? pkgName = _isData && _selectedDataPackage != null
                          ? _selectedDataPackage!['name']?.toString()
                          : null;
                      final res = await AppScope.of(context).mobileTopup(
                        carrier: _selectedCarrier,
                        phoneNumber: phone,
                        amount: amount,
                        pin: pin,
                        dataPackage: pkgName,
                      );

                      if (!mounted) return;
                      Navigator.of(pinSheetCtx).pop(); // Đóng sheet PIN
                      _failedPinCount = 0;
                      await _loadWallet();

                      // Bước 18: Hiển thị thông báo Giao dịch thành công
                      _showSuccessDialog(
                        phone: phone,
                        amount: amount,
                        transaction: res['transaction'] as Map<String, dynamic>?,
                      );
                    } on ApiException catch (e) {
                      if (!mounted) return;

                      // Xử lý ngoại lệ E3: PIN không chính xác
                      if (e.code == 'WRONG_PIN' || e.message.contains('PIN không chính xác')) {
                        _failedPinCount++;
                        if (_failedPinCount >= 3) {
                          _isPinLocked = true;
                          Navigator.of(pinSheetCtx).pop();
                          _showPinLockedDialog();
                          return;
                        }
                        setPinState(() {
                          isSubmitting = false;
                          pinError = 'PIN không chính xác. (Còn ${3 - _failedPinCount} lần thử)';
                        });
                        return;
                      }

                      if (e.code == 'PIN_LOCKED' || e.message.contains('khóa xác thực')) {
                        _isPinLocked = true;
                        Navigator.of(pinSheetCtx).pop();
                        _showPinLockedDialog();
                        return;
                      }

                      // Ngoại lệ E2: Số dư không đủ
                      if (e.code == 'INSUFFICIENT_BALANCE' || e.message.contains('Số dư không đủ')) {
                        Navigator.of(pinSheetCtx).pop();
                        _showInsufficientBalanceDialog(amount);
                        return;
                      }

                      // Ngoại lệ E4: API nhà mạng không phản hồi
                      if (e.code == 'CARRIER_TIMEOUT' || e.message.contains('Máy chủ phản hồi quá lâu') || e.message.contains('Không thể xử lý giao dịch')) {
                        Navigator.of(pinSheetCtx).pop();
                        _showCarrierErrorDialog(
                          title: 'Lỗi kết nối',
                          message: 'Không thể xử lý giao dịch. Vui lòng thử lại sau.',
                          canRetry: true,
                          amount: amount,
                        );
                        return;
                      }

                      // Ngoại lệ E5: Giao dịch nhà mạng thất bại
                      if (e.code == 'CARRIER_FAILED' || e.message.contains('Giao dịch không thành công')) {
                        Navigator.of(pinSheetCtx).pop();
                        _showCarrierErrorDialog(
                          title: 'Giao dịch thất bại',
                          message: 'Giao dịch không thành công. Vui lòng thử lại.',
                          canRetry: true,
                          amount: amount,
                        );
                        return;
                      }

                      // Ngoại lệ E6: Gói Data không còn khả dụng
                      if (e.code == 'PACKAGE_NOT_AVAILABLE' || e.message.contains('không còn khả dụng')) {
                        Navigator.of(pinSheetCtx).pop();
                        setState(() {
                          _packageError = 'Gói Data không còn khả dụng. Vui lòng chọn gói khác.';
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Gói Data không còn khả dụng. Vui lòng chọn gói khác.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      // Lỗi chung khác
                      setPinState(() {
                        isSubmitting = false;
                        pinError = e.message;
                      });
                    } catch (_) {
                      setPinState(() {
                        isSubmitting = false;
                        pinError = 'Không thể thực hiện giao dịch, vui lòng thử lại';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ngoại lệ E2: Số dư không đủ (13.1 - 13.5)
  /// Hiển thị thông báo "Số dư không đủ để thực hiện giao dịch."
  /// Quay lại bước 9 hoặc thay đổi mệnh giá / nạp thêm
  void _showInsufficientBalanceDialog(double amount) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.error, size: 48),
        title: const Text('Số dư không đủ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Số dư không đủ để thực hiện giao dịch.',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
            ),
            const SizedBox(height: 8),
            Text('Cần thanh toán: ${formatVnd(amount)}'),
            Text('Số dư ví hiện tại: ${formatVnd(_walletBalance)}'),
            const SizedBox(height: 8),
            const Text(
              'Bạn có thể thay đổi mệnh giá/gói Data khác hoặc nạp thêm tiền vào ví để tiếp tục.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đổi gói cước / Mệnh giá'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.onBackToHome != null) {
                widget.onBackToHome!();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(); // Trở về Home để nạp ví
              }
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  /// Ngoại lệ E3: Nhập sai PIN quá 3 lần (13.9)
  void _showPinLockedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 48),
        title: const Text('Khóa xác thực tạm thời'),
        content: const Text(
          'Nhập sai mã PIN quá 3 lần. Giao dịch đã bị hủy và khóa xác thực giao dịch tạm thời.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  /// Ngoại lệ E4 & E5: Lỗi kết nối API nhà mạng hoặc nhà mạng từ chối
  void _showCarrierErrorDialog({
    required String title,
    required String message,
    required bool canRetry,
    required double amount,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
        title: Text(title),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
          if (canRetry)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _promptPinAndExecute(amount); // Thử lại
              },
              child: const Text('Thử lại'),
            ),
        ],
      ),
    );
  }

  /// Bước 18: Hiển thị thông báo "Giao dịch thành công"
  void _showSuccessDialog({
    required String phone,
    required double amount,
    Map<String, dynamic>? transaction,
  }) {
    final code = transaction?['transactionCode']?.toString() ?? '';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 56),
        title: const Text(
          'Giao dịch thành công',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                formatVnd(amount),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _receiptRow('Dịch vụ:', _isData ? 'Nạp gói Data' : 'Nạp tiền điện thoại'),
            _receiptRow('Nhà mạng:', _selectedCarrier),
            _receiptRow('Số nhận:', phone),
            if (_isData && _selectedDataPackage != null)
              _receiptRow('Gói cước:', _selectedDataPackage!['name'].toString()),
            if (code.isNotEmpty) _receiptRow('Mã giao dịch:', code),
            _receiptRow('Số dư ví mới:', formatVnd(_walletBalance)),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 42),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (widget.onBackToHome != null) {
                  widget.onBackToHome!();
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop(); // Quay lại trang trước
                }
              },
              child: const Text('Hoàn tất'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value, {bool isBold = false, Color? valueColor, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Nạp tiền điện thoại/data',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Quay lại',
          onPressed: () { if (widget.onBackToHome != null) { widget.onBackToHome!(); } else if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } },
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới số dư',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadWallet,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thẻ số dư ví hiện tại
              _buildWalletBalanceCard(),
              const SizedBox(height: 16),

              // Bước 3 & 4: Chọn loại dịch vụ (Nạp ĐT / Nạp Data)
              _buildServiceTypeSelector(),
              const SizedBox(height: 16),

              // Bước 5: Chọn nhà mạng
              _buildCarrierSelector(),
              const SizedBox(height: 16),

              // Bước 6 & AF1: Nhập số điện thoại nhận tiền/data
              _buildPhoneNumberInput(),
              const SizedBox(height: 16),

              // Bước 8: Luồng con tương ứng (8.1 Mệnh giá ĐT hoặc 8.2 Gói Data)
              if (!_isData) ...[
                _buildDenominationSelector(),
              ] else ...[
                _buildDataPackageSelector(),
              ],

              const SizedBox(height: 24),

              // Hiển thị tổng tiền & Nút xác nhận tiếp tục
              _buildPaymentSummaryCard(),
              const SizedBox(height: 16),

              AppButton(
                text: 'Tiếp tục',
                icon: Icons.arrow_forward_rounded,
                onPressed: _onProceed,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Thẻ thông tin số dư ví
  Widget _buildWalletBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.lightBlue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Số dư ví khả dụng',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  formatVnd(_walletBalance),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bước 3 & 4: Chọn loại dịch vụ (Nạp tiền điện thoại / Nạp Data)
  Widget _buildServiceTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (_isData) {
                  setState(() => _isData = false);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isData ? AppColors.lightBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Nạp tiền điện thoại',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: !_isData ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                if (!_isData) {
                  setState(() => _isData = true);
                  _fetchDataPackages();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isData ? AppColors.lightBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Nạp Data 4G/5G',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _isData ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bước 5: Chọn nhà mạng (Viettel, Vinaphone, Mobifone, Vietnamobile)
  Widget _buildCarrierSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn nhà mạng',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        Row(
          children: kCarriers.map((carrier) {
            final name = carrier['name'] as String;
            final isSelected = _selectedCarrier.toLowerCase() == name.toLowerCase();
            final color = carrier['color'] as Color;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCarrier = name;
                    });
                    if (_isData) {
                      _fetchDataPackages();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(carrier['icon'] as IconData, color: color, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? color : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Bước 6 & AF1: Số điện thoại nhận tiền hoặc Data
  Widget _buildPhoneNumberInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Số điện thoại nhận',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            // Luồng thay thế AF1: Nạp cho số khác / Số của tôi
            TextButton.icon(
              icon: Icon(
                _isOtherPhone ? Icons.person_rounded : Icons.contacts_rounded,
                size: 16,
              ),
              label: Text(_isOtherPhone ? 'Nạp số của tôi' : 'Nạp cho số khác'),
              onPressed: () {
                setState(() {
                  _isOtherPhone = !_isOtherPhone;
                  if (!_isOtherPhone) {
                    final userPhone = AppScope.of(context).user?.phoneNumber;
                    if (userPhone != null && userPhone.isNotEmpty) {
                      _phoneController.text = userPhone;
                    }
                  } else {
                    _phoneController.clear();
                  }
                  _phoneError = null;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (val) {
            if (_phoneError != null) {
              setState(() => _phoneError = _validatePhoneNumber(val));
            }
          },
          decoration: InputDecoration(
            hintText: 'Nhập số điện thoại (10 chữ số)',
            counterText: '',
            prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.lightBlue),
            suffixIcon: _phoneController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _phoneController.clear();
                      setState(() => _phoneError = null);
                    },
                  )
                : null,
            errorText: _phoneError,
          ),
        ),
      ],
    );
  }

  /// Luồng con 8.1: Nạp tiền điện thoại - Hiển thị danh sách mệnh giá
  Widget _buildDenominationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn mệnh giá nạp',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kDenominations.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final amt = kDenominations[index];
            final isSelected = _selectedDenomination == amt;

            return InkWell(
              onTap: () => setState(() => _selectedDenomination = amt),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.lightBlue.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.lightBlue : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    formatVnd(amt),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppColors.lightBlue : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Luồng con 8.2: Nạp Data - Gọi API lấy danh sách và hiển thị các gói Data
  Widget _buildDataPackageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Chọn gói Data',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            if (_isLoadingPackages)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (_packageError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_packageError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 10),
        if (_dataPackages.isEmpty && !_isLoadingPackages) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Không có gói Data nào khả dụng cho nhà mạng này'),
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dataPackages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final pkg = _dataPackages[index];
              final isSelected = _selectedDataPackage?['id'] == pkg['id'];
              final isAvailable = pkg['available'] != false;
              final name = pkg['name']?.toString() ?? '';
              final data = pkg['data']?.toString() ?? '';
              final duration = pkg['duration']?.toString() ?? '';
              final price = (pkg['price'] as num?)?.toDouble() ?? 0;
              final desc = pkg['description']?.toString() ?? '';

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDataPackage = pkg;
                    _packageError = null;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.lightBlue.withOpacity(0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.lightBlue : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.lightBlue : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  data,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const Text(' • ', style: TextStyle(color: Colors.grey)),
                                Text(
                                  duration,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                if (!isAvailable) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Ngừng cung cấp',
                                      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                desc,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        formatVnd(price),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected ? AppColors.lightBlue : const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  /// Tóm tắt thanh toán ở dưới cùng (8.1.3 & 8.2.4)
  Widget _buildPaymentSummaryCard() {
    final amount = _currentAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Số tiền thanh toán:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          Text(
            formatVnd(amount),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }
}
