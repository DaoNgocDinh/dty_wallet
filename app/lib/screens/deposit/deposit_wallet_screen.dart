import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

class DepositWalletScreen extends StatefulWidget {
  const DepositWalletScreen({super.key});

  @override
  State<DepositWalletScreen> createState() => _DepositWalletScreenState();
}

class _DepositWalletScreenState extends State<DepositWalletScreen> {
  final _amountController = TextEditingController(text: '100000');
  String _selectedSource = 'Vietcombank (Liên kết)';
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? _parseAmount() {
    final amountText = _amountController.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '');
    if (!RegExp(r'^\d+$').hasMatch(amountText)) return null;
    return double.tryParse(amountText);
  }

  Future<void> _submit() async {
    final amount = _parseAmount();
    if (amount == null || amount <= 0) {
      setState(() => _submitError = 'Vui lòng nhập số tiền hợp lệ');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      await AppScope.of(context)
          .demoDeposit(amount: amount, source: _selectedSource);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _submitError = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nạp ví'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Trở về',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kIPhone18Width),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Chế độ demo: tiền được cộng vào ví và lưu giao dịch trên máy chủ; '
                  'không thực hiện thanh toán thật.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Số tiền nạp (VND)',
                    prefixIcon: Icon(
                      Icons.monetization_on_outlined,
                      color: AppColors.lightBlue,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSource,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Nguồn tiền',
                    prefixIcon: Icon(
                      Icons.account_balance_outlined,
                      color: AppColors.lightBlue,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Vietcombank (Liên kết)',
                      child: Text('Vietcombank (mô phỏng)'),
                    ),
                    DropdownMenuItem(
                      value: 'MB Bank (QR Pay)',
                      child: Text('MB Bank (mô phỏng)'),
                    ),
                    DropdownMenuItem(
                      value: 'Thẻ Quốc tế (Visa/Mastercard)',
                      child: Text('Thẻ quốc tế (mô phỏng)'),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedSource = value);
                          }
                        },
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _submitError!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton(
                  text: 'Nạp ví',
                  icon: Icons.add_card_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
