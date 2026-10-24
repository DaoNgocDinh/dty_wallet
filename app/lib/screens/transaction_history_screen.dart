import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';

/// Màn hình chuyên biệt Lịch sử giao dịch
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({
    super.key,
    this.isEmbedded = false,
    this.onBackToHome,
  });

  final bool isEmbedded;
  final VoidCallback? onBackToHome;

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'all'; // all, deposit, topup, bill, fund, jar
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await AppScope.of(context).fetchTransactions();
      if (!mounted) return;
      final rawList = (res['data'] as List?) ?? [];
      final list = rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _transactions = list;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách giao dịch. Vui lòng thử lại sau.';
        _isLoading = false;
      });
    }
  }

  String _formatVnd(dynamic amount) {
    if (amount == null) return '0 đ';
    final num? value = amount is num ? amount : num.tryParse(amount.toString());
    if (value == null) return '0 đ';
    final int val = value.round();
    final isNegative = val < 0;
    final absStr = val.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < absStr.length; i++) {
      if (i > 0 && (absStr.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(absStr[i]);
    }
    return '${isNegative ? '-' : ''}${buffer.toString()} đ';
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$h:$min - $d/$m/$y';
    } catch (_) {
      return dateVal.toString();
    }
  }

  bool _isIncoming(Map<String, dynamic> item, String? userEmail) {
    final type = item['type']?.toString().toLowerCase() ?? '';
    if (type == 'deposit' || type == 'fund_withdrawal') return true;
    if (userEmail != null && userEmail.isNotEmpty) {
      final recipient = item['recipient']?.toString().toLowerCase() ?? '';
      if (recipient == userEmail.toLowerCase()) return true;
    }
    return false;
  }

  String _getDisplayTitle(Map<String, dynamic> item) {
    final type = item['type']?.toString().toLowerCase() ?? '';
    final note = item['note']?.toString() ?? '';
    final recipient = item['recipient']?.toString() ?? '';

    switch (type) {
      case 'deposit':
        return 'Nạp tiền vào ví';
      case 'mobile_topup':
        return recipient.isNotEmpty
            ? 'Nạp tiền ĐT: $recipient'
            : (note.isNotEmpty ? note : 'Nạp tiền điện thoại');
      case 'data_topup':
        return recipient.isNotEmpty
            ? 'Nạp Data 4G: $recipient'
            : (note.isNotEmpty ? note : 'Nạp gói cước Data');
      case 'bill_payment':
        return note.isNotEmpty ? note : 'Thanh toán hoá đơn';
      case 'fund_contribution':
        return note.isNotEmpty ? note : 'Góp tiền vào quỹ';
      case 'fund_withdrawal':
        return note.isNotEmpty ? note : 'Rút tiền từ quỹ về ví';
      case 'spending_jar':
        return note.isNotEmpty ? note : 'Chi tiêu từ hũ';
      default:
        if (note.isNotEmpty) return note;
        return type.replaceAll('_', ' ');
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'deposit':
        return Icons.add_card_rounded;
      case 'mobile_topup':
        return Icons.phone_iphone_rounded;
      case 'data_topup':
        return Icons.data_usage_rounded;
      case 'bill_payment':
        return Icons.receipt_outlined;
      case 'fund_contribution':
        return Icons.group_add_rounded;
      case 'fund_withdrawal':
        return Icons.savings_rounded;
      case 'spending_jar':
        return Icons.all_inbox_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'deposit':
        return const Color(0xFF2E7D32);
      case 'mobile_topup':
        return const Color(0xFFEF6C00);
      case 'data_topup':
        return AppColors.lightBlue;
      case 'bill_payment':
        return const Color(0xFFC2185B);
      case 'fund_contribution':
        return const Color(0xFFE53935);
      case 'fund_withdrawal':
        return const Color(0xFF00897B);
      case 'spending_jar':
        return const Color(0xFF7B1FA2);
      default:
        return AppColors.lightBlueDark;
    }
  }

  void _showTransactionDetails(Map<String, dynamic> item, bool isIncome) {
    final code = item['transactionCode']?.toString() ?? 'N/A';
    final type = item['type']?.toString() ?? '';
    final amount = (item['amount'] as num?)?.toDouble() ?? 0;
    final status = item['status']?.toString().toLowerCase() ?? 'completed';
    final date = _formatDate(item['createdAt']);
    final sender = item['sender']?.toString() ?? '';
    final recipient = item['recipient']?.toString() ?? '';
    final note = item['note']?.toString() ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: (isIncome ? const Color(0xFF2E7D32) : AppColors.lightBlue)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getTypeIcon(type),
                    size: 32,
                    color: isIncome ? const Color(0xFF2E7D32) : AppColors.lightBlueDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _getDisplayTitle(item),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '${isIncome ? '+' : '-'}${_formatVnd(amount)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? const Color(0xFF2E7D32) : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              _buildReceiptRow('Mã giao dịch', code, isBold: true),
              _buildReceiptRow('Thời gian', date),
              _buildReceiptRow('Loại dịch vụ', _getDisplayTitle(item)),
              if (sender.isNotEmpty) _buildReceiptRow('Nguồn tiền / Người gửi', sender),
              if (recipient.isNotEmpty) _buildReceiptRow('Người nhận / Đích đến', recipient),
              if (note.isNotEmpty) _buildReceiptRow('Nội dung / Ghi chú', note),
              _buildReceiptRow(
                'Trạng thái',
                status == 'completed'
                    ? 'Thành công'
                    : (status == 'pending' ? 'Đang xử lý' : 'Thất bại'),
                statusColor: status == 'completed'
                    ? const Color(0xFF2E7D32)
                    : (status == 'pending' ? const Color(0xFFEF6C00) : AppColors.error),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: statusColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    final userEmail = user?.email;

    // Lọc danh sách giao dịch
    final filtered = _transactions.where((item) {
      // 1. Lọc theo danh mục
      final type = item['type']?.toString().toLowerCase() ?? '';
      if (_selectedCategory == 'deposit' && type != 'deposit') return false;
      if (_selectedCategory == 'topup' &&
          type != 'mobile_topup' &&
          type != 'data_topup') return false;
      if (_selectedCategory == 'bill' && type != 'bill_payment') return false;
      if (_selectedCategory == 'fund' &&
          type != 'fund_contribution' &&
          type != 'fund_withdrawal') return false;
      if (_selectedCategory == 'jar' && type != 'spending_jar') return false;

      // 2. Lọc theo từ khoá tìm kiếm
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final code = (item['transactionCode'] ?? '').toString().toLowerCase();
        final note = (item['note'] ?? '').toString().toLowerCase();
        final sender = (item['sender'] ?? '').toString().toLowerCase();
        final recipient = (item['recipient'] ?? '').toString().toLowerCase();
        final title = _getDisplayTitle(item).toLowerCase();
        if (!code.contains(q) &&
            !note.contains(q) &&
            !sender.contains(q) &&
            !recipient.contains(q) &&
            !title.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Tính tổng thu / chi
    double totalIn = 0;
    double totalOut = 0;
    for (final item in _transactions) {
      final amt = (item['amount'] as num?)?.toDouble() ?? 0;
      final isPending = item['status']?.toString().toLowerCase() == 'pending';
      if (_isIncoming(item, userEmail)) {
        if (!isPending) totalIn += amt;
      } else {
        if (!isPending) totalOut += amt;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lịch sử giao dịch',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: widget.isEmbedded
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: 'Về trang chủ',
                onPressed: () {
                  if (widget.onBackToHome != null) {
                    widget.onBackToHome!();
                  } else if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: 'Quay lại',
                onPressed: () => Navigator.of(context).pop(),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTransactions,
          color: AppColors.lightBlue,
          child: Column(
            children: [
              // Thẻ tổng quan thu chi & số dư
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.lightBlue, AppColors.lightBlueDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lightBlueDark.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Tổng tiền vào
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.arrow_downward_rounded,
                                    color: Color(0xFFC8E6C9), size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Tổng tiền vào',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${_formatVnd(totalIn)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 38,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      const SizedBox(width: 16),
                      // Tổng tiền ra
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.arrow_upward_rounded,
                                    color: Color(0xFFFFCDD2), size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Tổng tiền ra',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '-${_formatVnd(totalOut)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Thanh tìm kiếm giao dịch
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.lightBlue.withValues(alpha: 0.35),
                    ),
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
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.search_rounded,
                        color: AppColors.lightBlueDark,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Tìm theo mã TX, tên, ghi chú...',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            fillColor: Colors.transparent,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Dãy nút lọc danh mục
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('Tất cả', 'all', Icons.all_inclusive_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('Nạp ví', 'deposit', Icons.add_card_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('Nạp ĐT/Data', 'topup', Icons.phone_iphone_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('Hoá đơn', 'bill', Icons.receipt_outlined),
                    const SizedBox(width: 8),
                    _buildFilterChip('Quỹ nhóm', 'fund', Icons.groups_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('Hũ chi tiêu', 'jar', Icons.all_inbox_rounded),
                  ],
                ),
              ),

              // Danh sách giao dịch
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.lightBlue),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 40, color: AppColors.error),
                                const SizedBox(height: 8),
                                Text(_error!, style: const TextStyle(color: AppColors.error)),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: _loadTransactions,
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          )
                        : filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.receipt_long_rounded,
                                        size: 44,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Không tìm thấy giao dịch nào phù hợp'
                                          : 'Chưa có giao dịch nào được ghi nhận',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Các giao dịch nạp tiền, chi tiêu sẽ hiển thị tại đây',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final type = item['type']?.toString().toLowerCase() ?? '';
                                  final amt = (item['amount'] as num?)?.toDouble() ?? 0;
                                  final isIncome = _isIncoming(item, userEmail);
                                  final code = item['transactionCode']?.toString() ?? '';
                                  final date = _formatDate(item['createdAt']);
                                  final status =
                                      item['status']?.toString().toLowerCase() ?? 'completed';
                                  final color = _getTypeColor(type);
                                  final icon = _getTypeIcon(type);

                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    elevation: 0.5,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _showTransactionDetails(item, isIncome),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Row(
                                          children: [
                                            // Icon tròn loại giao dịch
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(icon, color: color, size: 22),
                                            ),
                                            const SizedBox(width: 12),

                                            // Thông tin tên + ngày giờ
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _getDisplayTitle(item),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        date,
                                                        style: const TextStyle(
                                                          fontSize: 11.5,
                                                          color: AppColors.textSecondary,
                                                        ),
                                                      ),
                                                      if (code.isNotEmpty) ...[
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '• $code',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors.textSecondary
                                                                .withValues(alpha: 0.8),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Số tiền và trạng thái
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${isIncome ? '+' : '-'}${_formatVnd(amt)}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: isIncome
                                                        ? const Color(0xFF2E7D32)
                                                        : AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: status == 'completed'
                                                        ? const Color(0xFFE8F5E9)
                                                        : (status == 'pending'
                                                            ? const Color(0xFFFFF3E0)
                                                            : const Color(0xFFFFEBEE)),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    status == 'completed'
                                                        ? 'Thành công'
                                                        : (status == 'pending'
                                                            ? 'Đang xử lý'
                                                            : 'Thất bại'),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: status == 'completed'
                                                          ? const Color(0xFF2E7D32)
                                                          : (status == 'pending'
                                                              ? const Color(0xFFEF6C00)
                                                              : AppColors.error),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String categoryKey, IconData icon) {
    final isSelected = _selectedCategory == categoryKey;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = categoryKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.lightBlueDark
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.lightBlueDark
                : AppColors.border,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.lightBlueDark.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
