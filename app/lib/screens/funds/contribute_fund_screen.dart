import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/back_label.dart';

import '../../utils/format_utils.dart' show formatVnd;

/// Đếm số từ trong văn bản
int countWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

/// Màn hình Góp tiền vào quỹ - Use Case 05
class ContributeFundScreen extends StatefulWidget {
  const ContributeFundScreen({
    super.key,
    required this.fund,
    this.initialWalletBalance,
  });

  final Map<String, dynamic> fund;
  final double? initialWalletBalance;

  @override
  State<ContributeFundScreen> createState() => _ContributeFundScreenState();
}

class _ContributeFundScreenState extends State<ContributeFundScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  double _walletBalance = 0;
  bool _isLoadingWallet = false;
  bool _isSubmitting = false;

  String? _amountError;
  String? _noteError;
  String? _generalError;

  int _currentWordCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialWalletBalance != null) {
      _walletBalance = widget.initialWalletBalance!;
    }
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialWalletBalance == null && !_isLoadingWallet) {
      _loadWalletBalance();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    final text = _noteController.text;
    final words = countWords(text);
    setState(() {
      _currentWordCount = words;
      if (words > 200) {
        _noteError = 'Tối đa 200 từ';
      } else {
        if (_noteError == 'Tối đa 200 từ') {
          _noteError = null;
        }
      }
    });
  }

  Future<void> _loadWalletBalance() async {
    _isLoadingWallet = true;
    try {
      final user = AppScope.of(context).user;
      if (user != null) {
        setState(() => _walletBalance = user.walletBalance);
      }
      final walletData = await AppScope.of(context).fetchWallet();
      final balance = walletData['walletBalance'] ?? walletData['balance'] ?? 0;
      if (!mounted) return;
      setState(() {
        _walletBalance = (balance as num).toDouble();
      });
    } catch (_) {
      // Giữ nguyên số dư hiện tại nếu lỗi
    } finally {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  /// Kiểm tra hợp lệ số tiền góp theo các phân vùng và giá trị biên
  String? _validateAmountString(String text) {
    final trimmed = text.trim();
    // 3.1: Người dùng để trống số tiền góp -> E1
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập số tiền muốn góp';
    }

    // 3.3: Số tiền không hợp lệ, không phải là số hoặc chứa ký tự không hợp lệ -> E3
    // Chuỗi chỉ được chứa chữ số và dấu phân cách dấu chấm/phẩy
    final cleaned = trimmed.replaceAll('.', '').replaceAll(',', '');
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Số tiền không hợp lệ';
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return 'Số tiền không hợp lệ';
    }

    // 3.2: Nhập số tiền nhỏ hơn 1.000đ -> E2
    if (parsed < 1000) {
      return 'Tối thiểu 1000đ';
    }

    // 3.4: Số tiền lớn hơn số dư khả dụng trong ví -> E4
    if (parsed > _walletBalance) {
      return 'Số dư ví không đủ để thực hiện giao dịch';
    }

    return null;
  }

  double? _getValidAmount() {
    final trimmed = _amountController.text.trim();
    final cleaned = trimmed.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  void _onAmountChanged(String val) {
    if (_amountError != null) {
      setState(() {
        _amountError = _validateAmountString(val);
      });
    }
  }

  void _selectQuickAmount(double amount) {
    _amountController.text = amount.toInt().toString();
    setState(() {
      _amountError = _validateAmountString(_amountController.text);
    });
  }

  /// Bước 4: Kiểm tra thông tin người dùng nhập & chuyển sang Bước 5: Giao diện "Chuyển tiền"
  void _onProceedToConfirm() {
    final amountError = _validateAmountString(_amountController.text);
    String? noteError;
    final words = countWords(_noteController.text);
    if (words > 200) {
      noteError = 'Tối đa 200 từ';
    }

    setState(() {
      _amountError = amountError;
      _noteError = noteError;
      _generalError = null;
    });

    if (amountError != null || noteError != null) {
      return;
    }

    final amount = _getValidAmount();
    if (amount == null) return;

    // Bước 5: Hiển thị giao diện "Chuyển tiền" với thông tin giao dịch
    _showTransferConfirmationDialog(amount);
  }

  /// Bước 5: Giao diện "Chuyển tiền" với thông tin giao dịch
  /// Bước 6: Người dùng xác nhận chuyển tiền (hoặc Huỷ / Quay lại theo 6.1)
  Future<void> _showTransferConfirmationDialog(double amount) async {
    final fundName = widget.fund['name']?.toString() ?? 'Quỹ';
    final note = _noteController.text.trim();
    final balanceAfter = _walletBalance - amount;

    final confirmed = await showModalBottomSheet<bool>(
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
            const SizedBox(height: 14),

            // Tiêu đề giao diện Chuyển tiền
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chuyển tiền',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(sheetCtx).pop(false), // 6.1
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Xác nhận thông tin giao dịch đóng góp vào quỹ',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Hộp thông tin chi tiết giao dịch
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildConfirmRow('Quỹ nhận:', fundName, isBold: true),
                  const Divider(height: 18),
                  _buildConfirmRow(
                    'Số tiền chuyển:',
                    formatVnd(amount),
                    valueColor: const Color(0xFF2E7D32),
                    isBold: true,
                    fontSize: 16,
                  ),
                  const Divider(height: 18),
                  _buildConfirmRow('Nguồn tiền:', 'Số dư ví cá nhân'),
                  const Divider(height: 18),
                  _buildConfirmRow('Số dư hiện tại:', formatVnd(_walletBalance)),
                  const Divider(height: 18),
                  _buildConfirmRow('Số dư sau khi góp:', formatVnd(balanceAfter)),
                  if (note.isNotEmpty) ...[
                    const Divider(height: 18),
                    _buildConfirmRow('Ghi chú:', note),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6. Nút Xác nhận chuyển tiền
            AppButton(
              text: 'Xác nhận chuyển tiền',
              icon: Icons.check_circle_outline_rounded,
              height: 48,
              fontSize: 15,
              onPressed: () => Navigator.of(sheetCtx).pop(true),
            ),
            const SizedBox(height: 10),

            // 6.1 Nút Huỷ giao dịch (quay lại giao diện Góp quỹ)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(sheetCtx).pop(false), // 6.1 Huỷ
              child: const Text('Huỷ giao dịch', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );

    // 6.1 Người dùng không xác nhận chuyển tiền -> Hủy giao dịch và quay lại giao diện Góp quỹ
    if (confirmed != true) {
      return;
    }

    // 7, 8, 9, 10: Thực hiện giao dịch
    await _executeContribution(amount, note);
  }

  Widget _buildConfirmRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    double fontSize = 13.5,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
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

  /// Thực hiện gọi API góp tiền
  Future<void> _executeContribution(double amount, String note) async {
    setState(() => _isSubmitting = true);
    final fundId = widget.fund['_id']?.toString() ?? widget.fund['id']?.toString() ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final res = await AppScope.of(context).contributeFund(
        fundId: fundId,
        amount: amount,
        note: note.isNotEmpty ? note : null,
      );

      if (!mounted) return;

      // 10. Thông báo "Góp tiền thành công"
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Góp tiền thành công'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 3),
        ),
      );

      setState(() => _isSubmitting = false);

      // Quay lại màn hình Chi tiết quỹ và trả về dữ liệu quỹ đã cập nhật
      final updatedFund = res['fund'] is Map ? Map<String, dynamic>.from(res['fund'] as Map) : null;
      if (navigator.canPop()) {
        navigator.pop(updatedFund ?? true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // 7.1 Phát sinh lỗi trong quá trình chuyển tiền -> E6
      // 7.2 Gián đoạn hoặc không kết nối được -> E7
      String errorMsg = e.message;
      if (e.code == 'CONTRIBUTION_FAILED' || e.statusCode == 500) {
        errorMsg = 'Góp quỹ không thành công'; // E6
      } else if (e.message.contains('kết nối') || e.message.contains('SocketException')) {
        errorMsg = 'Không thể thực hiện giao dịch. Vui lòng thử lại sau'; // E7
      }
      messenger.showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // 7.2 Không thể kết nối hoặc lỗi bất định
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không thể thực hiện giao dịch. Vui lòng thử lại sau'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fundName = widget.fund['name']?.toString() ?? 'Quỹ';
    final fundType = widget.fund['fundType']?.toString() ?? 'Tiết kiệm';
    final currentAmount = widget.fund['currentAmount'] ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kIPhone18Width),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thanh tiêu đề phía trên
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BackLabel(
                        text: 'Chi tiết quỹ',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Tiêu đề màn hình
                  const Text(
                    'Góp tiền vào quỹ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Đóng góp từ số dư ví cá nhân vào quỹ',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card tóm tắt Quỹ nhận tiền
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.savings_rounded,
                                    color: Color(0xFFE53935),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fundName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              fundType,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Hiện có: ${formatVnd(currentAmount)}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Card hiển thị số dư ví cá nhân
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.lightBlue.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppColors.lightBlueDark,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Số dư ví khả dụng: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    formatVnd(_walletBalance),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.lightBlueDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Ô NHẬP SỐ TIỀN GÓP
                          const Text(
                            'Số tiền muốn góp *',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            onChanged: _onAmountChanged,
                            decoration: InputDecoration(
                              hintText: 'Nhập số tiền (tối thiểu 1.000đ)',
                              suffixText: 'đ',
                              prefixIcon: const Icon(
                                Icons.monetization_on_outlined,
                                color: AppColors.lightBlue,
                              ),
                              errorText: null, // Thông báo lỗi hiển thị ngay dưới theo yêu cầu đặc tả
                            ),
                          ),

                          // Thông báo lỗi ngay dưới ô nhập số tiền (E1, E2, E3, E4)
                          if (_amountError != null) ...[
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                _amountError!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),

                          // Gợi ý mức tiền nhanh
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [10000.0, 50000.0, 100000.0, 500000.0].map((amt) {
                              return InkWell(
                                onTap: () => _selectQuickAmount(amt),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    formatVnd(amt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Ô NHẬP GHI CHÚ
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Ghi chú (không bắt buộc)',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_currentWordCount/200 từ',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _currentWordCount > 200
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                                  fontWeight: _currentWordCount > 200
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _noteController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Nhập nội dung ghi chú góp tiền...',
                            ),
                          ),

                          // Thông báo lỗi ghi chú (E5)
                          if (_noteError != null) ...[
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                _noteError!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),

                          // Nút Chuyển tiền (tiếp tục sang bước xác nhận giao dịch)
                          AppButton(
                            text: 'Chuyển tiền',
                            icon: Icons.arrow_forward_rounded,
                            height: 48,
                            fontSize: 15,
                            isLoading: _isSubmitting,
                            onPressed: _isSubmitting ? null : _onProceedToConfirm,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
