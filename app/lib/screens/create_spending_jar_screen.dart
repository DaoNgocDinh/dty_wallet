import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

class CreateSpendingJarScreen extends StatefulWidget {
  const CreateSpendingJarScreen({super.key});

  @override
  State<CreateSpendingJarScreen> createState() =>
      _CreateSpendingJarScreenState();
}

class _CreateSpendingJarScreenState extends State<CreateSpendingJarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double? _parseAmount(String value) {
    final cleaned = value.trim().replaceAll('.', '').replaceAll(',', '');
    if (cleaned.isEmpty || !RegExp(r'^\d+$').hasMatch(cleaned)) return null;
    return double.tryParse(cleaned);
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số tiền cung cấp';
    }
    final amount = _parseAmount(value);
    if (amount == null || amount <= 0) {
      return 'Số tiền phải là số hợp lệ và lớn hơn 0';
    }
    if (amount > (AppScope.of(context).user?.walletBalance ?? 0)) {
      return 'Số tiền cung cấp không được lớn hơn số dư ví';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      await AppScope.of(context).createSpendingJar(
        name: _nameController.text.trim(),
        amount: _parseAmount(_amountController.text)!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletBalance = AppScope.of(context).user?.walletBalance ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm hũ chi tiêu')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Tạo hũ để phân chia và theo dõi các khoản chi tiêu của bạn.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Tên hũ',
                  hintText: 'Ví dụ: Ăn uống',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập tên hũ'
                    : null,
                onChanged: (_) {
                  if (_submitError != null) {
                    setState(() => _submitError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Số tiền cung cấp',
                  hintText: 'Ví dụ: 1.000.000',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: 'đ',
                  helperText: 'Số dư ví khả dụng: ${_formatVnd(walletBalance)}',
                  border: const OutlineInputBorder(),
                ),
                validator: _validateAmount,
                onChanged: (_) {
                  if (_submitError != null) {
                    setState(() => _submitError = null);
                  }
                },
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _submitError!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 20),
              AppButton(
                text: 'Tạo hũ chi tiêu',
                icon: Icons.add_rounded,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatVnd(double amount) {
    final digits = amount.round().toString();
    final result = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) result.write('.');
      result.write(digits[i]);
    }
    return '${result.toString()} đ';
  }
}
