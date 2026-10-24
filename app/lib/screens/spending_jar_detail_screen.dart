import 'package:flutter/material.dart';

import '../state/app_session.dart';
import '../theme/app_theme.dart';

class SpendingJarDetailScreen extends StatefulWidget {
  const SpendingJarDetailScreen({super.key, required this.jar});

  final Map<String, dynamic> jar;

  @override
  State<SpendingJarDetailScreen> createState() =>
      _SpendingJarDetailScreenState();
}

class _SpendingJarDetailScreenState extends State<SpendingJarDetailScreen> {
  late int _year;
  late int _month;
  int _page = 1;
  Future<Map<String, dynamic>>? _detailsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_detailsFuture == null) {
      final now = DateTime.now();
      _year = now.year;
      _month = now.month;
      _loadDetails();
    }
  }

  String get _jarId =>
      widget.jar['id']?.toString() ?? widget.jar['_id']?.toString() ?? '';

  void _loadDetails() {
    _detailsFuture = AppScope.of(context).fetchSpendingJarDetails(
      jarId: _jarId,
      year: _year,
      month: _month,
      page: _page,
    );
  }

  void _changeMonth(int direction) {
    setState(() {
      _month += direction;
      if (_month < 1) {
        _month = 12;
        _year--;
      } else if (_month > 12) {
        _month = 1;
        _year++;
      }
      _page = 1;
      _loadDetails();
    });
  }

  void _changePage(int page) {
    setState(() {
      _page = page;
      _loadDetails();
    });
  }

  String _dateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Thời gian không xác định';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} • $hour:$minute';
  }

  String _formatVnd(dynamic value) {
    final amount = value is num ? value.round() : int.tryParse('$value') ?? 0;
    final digits = amount.abs().toString();
    final formatted = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        formatted.write('.');
      }
      formatted.write(digits[index]);
    }
    return '${amount < 0 ? '-' : ''}${formatted.toString()} đ';
  }

  String _transactionTitle(Map<String, dynamic> transaction) {
    final note = transaction['note']?.toString().trim() ?? '';
    if (note.isNotEmpty) return note;
    final type = transaction['type']?.toString();
    if (type == 'jar_contribution') return 'Cấp tiền vào hũ';
    return 'Giao dịch hũ chi tiêu';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.jar['name']?.toString() ?? 'Chi tiết hũ';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Tháng trước',
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(
                    '${_month.toString().padLeft(2, '0')}/$_year',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tháng sau',
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _detailsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.lightBlue,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Không thể tải dữ liệu, vui lòng thử lại sau.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                setState(_loadDetails);
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final data = snapshot.data ?? const <String, dynamic>{};
                  final transactions =
                      (data['transactions'] as List?) ?? const [];
                  if (transactions.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Hũ này chưa có giao dịch nào.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          itemCount: transactions.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final transaction =
                                transactions[index] as Map<String, dynamic>;
                            final isContribution =
                                transaction['type'] == 'jar_contribution';
                            final amount =
                                (transaction['amount'] as num?)?.toDouble() ??
                                0;

                            return Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _transactionTitle(transaction),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${isContribution ? '+' : '-'}${_formatVnd(amount)}',
                                          style: TextStyle(
                                            color: isContribution
                                                ? Colors.green.shade700
                                                : AppColors.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _dateTime(transaction['createdAt']),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Số dư sau giao dịch',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          _formatVnd(
                                            transaction['balanceAfter'],
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Trang trước',
                                onPressed: _page > 1
                                    ? () => _changePage(_page - 1)
                                    : null,
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Text('Trang $_page / $totalPages'),
                              IconButton(
                                tooltip: 'Trang sau',
                                onPressed: _page < totalPages
                                    ? () => _changePage(_page + 1)
                                    : null,
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
