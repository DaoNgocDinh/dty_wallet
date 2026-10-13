import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/back_label.dart';
import 'contribute_fund_screen.dart' show countWords;
import '../home_screen.dart' show formatVnd;

/// Số tiền tối thiểu được phép rút (đồng nhất với góp tiền)
const double kMinWithdrawAmount = 1000;

/// Màn hình Rút tiền từ quỹ về ví cá nhân (chỉ chủ quỹ).
class WithdrawFundScreen extends StatefulWidget {
  const WithdrawFundScreen({
    super.key,
    required this.fund,
  });

  final Map<String, dynamic> fund;

  @override
  State<WithdrawFundScreen> createState() => _WithdrawFundScreenState();
}

class _WithdrawFundScreenState extends State<WithdrawFundScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isSubmitting = false;

  String? _amountError;
  String? _noteError;
  String? _generalError;

  int _currentWordCount = 0;

  String get _fundId =>
      widget.fund['_id']?.toString() ?? widget.fund['id']?.toString() ?? '';

  String get _fundName => widget.fund['name']?.toString() ?? 'Quỹ';

  double get _fundBalance => (widget.fund['currentAmount'] as num?)?.toDouble() ?? 0;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    final words = countWords(_noteController.text);
    setState(() {
      _currentWordCount = words;
      if (words > 200) {
        _noteError = 'Tối đa 200 từ';
      } else if (_noteError == 'Tối đa 200 từ') {
        _noteError = null;
      }
    });
  }

  /// Kiểm tra hợp lệ số tiền rút
  String? _validateAmount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập số tiền muốn rút';
    }

    final cleaned = trimmed.replaceAll('.', '').replaceAll(',', '');
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Số tiền không hợp lệ';
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return 'Số tiền không hợp lệ';
    }

    if (parsed < kMinWithdrawAmount) {
      return 'Tối thiểu 1000đ';
    }

    if (parsed > _fundBalance) {
      return 'Số dư quỹ không đủ để rút';
    }

    return null;
  }

  double? _getValidAmount() {
    final cleaned = _amountController.text.trim().replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  void _onAmountChanged(String val) {
    if (_amountError != null) {
      setState(() => _amountError = _validateAmount(val));
    }
  }

  void _selectQuickAmount(double amount) {
    if (amount > _fundBalance) return;
    _amountController.text = amount.toInt().toString();
    setState(() => _amountError = _validateAmount(_amountController.text));
  }

  void _withdrawAll() {
    if (_fundBalance < kMinWithdrawAmount) return;
    _amountController.text = _fundBalance.toInt().toString();
    setState(() => _amountError = _validateAmount(_amountController.text));
  }

  void _onProceedToConfirm() {
    final amountError = _validateAmount(_amountController.text);
    final words = countWords(_noteController.text);
    final noteError = words > 200 ? 'Tối đa 200 từ' : null;

    setState(() {
      _amountError = amountError;
      _noteError = noteError;
      _generalError = null;
    });

    if (amountError != null || noteError != null) return;

    final amount = _getValidAmount();
    if (amount == null) return;

    _showWithdrawConfirmationDialog(amount);
  }

  Future<void> _showWithdrawConfirmationDialog(double amount) async {
    final note = _noteController.text.trim();

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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rút tiền',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(sheetCtx).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Xác nhận rút tiền từ quỹ về ví cá nhân',
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
                  _buildConfirmRow('Quỹ rút tiền:', _fundName, isBold: true),
                  const Divider(height: 18),
                  _buildConfirmRow(
                    'Số tiền rút:',
                    formatVnd(amount),
                    valueColor: const Color(0xFFC62828),
                    isBold: true,
                    fontSize: 16,
                  ),
                  const Divider(height: 18),
                  _buildConfirmRow('Nơi nhận:', 'Ví cá nhân của bạn'),
                  const Divider(height: 18),
                  _buildConfirmRow('Số dư quỹ hiện tại:', formatVnd(_fundBalance)),
                  const Divider(height: 18),
                  _buildConfirmRow(
                    'Số dư quỹ sau khi rút:',
                    formatVnd(_fundBalance - amount),
                  ),
                  if (note.isNotEmpty) ...[
                    const Divider(height: 18),
                    _buildConfirmRow('Ghi chú:', note),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            AppButton(
              text: 'Xác nhận rút tiền',
              icon: Icons.check_circle_outline_rounded,
              height: 48,
              fontSize: 15,
              onPressed: () => Navigator.of(sheetCtx).pop(true),
            ),
            const SizedBox(height: 10),

            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(sheetCtx).pop(false),
              child: const Text('Huỷ giao dịch', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await _executeWithdrawal(amount, note);
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

  Future<void> _executeWithdrawal(double amount, String note) async {
    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final res = await AppScope.of(context).withdrawFund(
        fundId: _fundId,
        amount: amount,
        note: note.isNotEmpty ? note : null,
      );

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Rút tiền thành công'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 3),
        ),
      );

      setState(() => _isSubmitting = false);

      final updatedFund = res['fund'] is Map
          ? Map<String, dynamic>.from(res['fund'] as Map)
          : null;
      if (navigator.canPop()) {
        navigator.pop(updatedFund ?? true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      String errorMsg = e.message;
      if (e.code == 'NOT_FUND_OWNER') {
        errorMsg = 'Chỉ chủ quỹ mới được rút tiền';
      } else if (e.code == 'INSUFFICIENT_FUND_BALANCE') {
        errorMsg = 'Số dư quỹ không đủ để rút';
      } else if (e.code == 'WITHDRAWAL_FAILED' || e.statusCode == 500) {
        errorMsg = 'Rút tiền không thành công';
      } else if (e.code != null && e.code != 'AMOUNT_REQUIRED' && e.code != 'MIN_AMOUNT_1000') {
        // Giữ nguyên thông điệp từ server
      }
      messenger.showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
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
    final fundType = widget.fund['fundType']?.toString() ?? 'Quỹ';
    final canWithdraw = _fundBalance >= kMinWithdrawAmount;

    // Các mức rút nhanh chỉ hiển thị khi không vượt quá số dư quỹ
    final quickAmounts = [10000.0, 50000.0, 100000.0, 500000.0]
        .where((amt) => amt <= _fundBalance)
        .toList();

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

                  const Text(
                    'Rút tiền từ quỹ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Chỉ chủ quỹ được rút tiền về ví cá nhân',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card tóm tắt quỹ
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
                                        _fundName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
                                              'Số dư quỹ: ${formatVnd(_fundBalance)}',
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

                          // Cảnh báo quỹ không đủ số dư để rút
                          if (!canWithdraw)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFEF9A9A)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Color(0xFFC62828), size: 22),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Quỹ cần có ít nhất 1.000đ mới có thể rút tiền',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFC62828),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_generalError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFEF9A9A)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828), size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _generalError!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFC62828),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Ô nhập số tiền rút
                          const Text(
                            'Số tiền muốn rút *',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            key: const ValueKey('withdraw_amount_field'),
                            controller: _amountController,
                            enabled: canWithdraw,
                            keyboardType: TextInputType.number,
                            onChanged: _onAmountChanged,
                            decoration: const InputDecoration(
                              hintText: 'Nhập số tiền (tối thiểu 1.000đ)',
                              suffixText: 'đ',
                              prefixIcon: Icon(
                                Icons.monetization_on_outlined,
                                color: AppColors.lightBlue,
                              ),
                            ),
                          ),
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
                          if (quickAmounts.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...quickAmounts.map(
                                  (amt) => InkWell(
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
                                  ),
                                ),
                                if (_fundBalance >= kMinWithdrawAmount)
                                  InkWell(
                                    onTap: _withdrawAll,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.lightBlue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppColors.lightBlue),
                                      ),
                                      child: const Text(
                                        'Rút toàn bộ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.lightBlueDark,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 18),

                          // Ô nhập ghi chú
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
                              hintText: 'Nhập nội dung ghi chú rút tiền...',
                            ),
                          ),
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

                          AppButton(
                            text: 'Rút tiền',
                            icon: Icons.arrow_forward_rounded,
                            height: 48,
                            fontSize: 15,
                            isLoading: _isSubmitting,
                            onPressed: (!canWithdraw || _isSubmitting)
                                ? null
                                : _onProceedToConfirm,
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