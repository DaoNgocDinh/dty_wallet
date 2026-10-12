import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/back_label.dart';
import 'contribute_fund_screen.dart';
import 'home_screen.dart' show formatVnd;

/// Màn hình Chi tiết quỹ (Có giao diện riêng khi ấn vào quỹ tương ứng)
class FundDetailScreen extends StatefulWidget {
  const FundDetailScreen({
    super.key,
    required this.fund,
  });

  final Map<String, dynamic> fund;

  @override
  State<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<FundDetailScreen> {
  late Map<String, dynamic> _fund;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fund = Map<String, dynamic>.from(widget.fund);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final fundId = _fund['_id']?.toString() ?? _fund['id']?.toString() ?? '';
    if (fundId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AppScope.of(context).fetchFundDetails(fundId);
      if (!mounted) return;
      setState(() {
        if (res['fund'] is Map) {
          _fund = Map<String, dynamic>.from(res['fund'] as Map);
        }
        if (res['transactions'] is List) {
          _transactions = (res['transactions'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Mở màn hình Góp tiền vào quỹ - Use Case 05
  Future<void> _openContributeScreen() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContributeFundScreen(fund: _fund),
      ),
    );

    if (result != null) {
      if (result is Map<String, dynamic>) {
        setState(() => _fund = result);
      }
      _loadDetails();
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final dt = DateTime.parse(dateVal.toString());
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return '$d/$m/$y';
    } catch (_) {
      return dateVal.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _fund['name']?.toString() ?? 'Chi tiết quỹ';
    final fundType = _fund['fundType']?.toString() ?? 'Tiết kiệm';
    final currentAmount = (_fund['currentAmount'] as num?)?.toDouble() ?? 0;
    final targetAmount = (_fund['targetAmount'] as num?)?.toDouble() ?? 0;
    final hasTarget = targetAmount > 0;
    final progress = hasTarget ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
    final completionDate = _fund['completionDate'];

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
                        text: 'Danh sách quỹ',
                        onTap: () => Navigator.of(context).pop(_fund),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.of(context).pop(_fund),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Tiêu đề
                  const Text(
                    'Chi tiết quỹ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Thông tin chi tiết và lịch sử đóng góp quỹ',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadDetails,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Thẻ thông tin chính của quỹ
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE53935).withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE53935).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.savings_rounded,
                                          color: Color(0xFFE53935),
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFE53935),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                fundType,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  const Divider(),
                                  const SizedBox(height: 8),

                                  // Số tiền hiện tại
                                  const Text(
                                    'Số tiền hiện có',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatVnd(currentAmount),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),

                                  // Nếu có mục tiêu
                                  if (hasTarget) ...[
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Mục tiêu: ${formatVnd(targetAmount)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(progress * 100).toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.lightBlueDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 8,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      currentAmount >= targetAmount
                                          ? 'Đã hoàn thành mục tiêu!'
                                          : 'Còn thiếu: ${formatVnd(targetAmount - currentAmount)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: currentAmount >= targetAmount
                                            ? const Color(0xFF2E7D32)
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],

                                  if (completionDate != null) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.event_note_rounded,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Ngày hoàn thành: ${_formatDate(completionDate)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // NÚT "+ GÓP QUỸ" - Trigger Use Case 05
                            AppButton(
                              text: '+ Góp quỹ',
                              icon: Icons.add_circle_outline_rounded,
                              height: 48,
                              fontSize: 15,
                              onPressed: _openContributeScreen,
                            ),
                            const SizedBox(height: 20),

                            // Tiêu đề Lịch sử đóng góp
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Lịch sử đóng góp',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_transactions.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_transactions.length} giao dịch',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.lightBlue,
                                  ),
                                ),
                              )
                            else if (_transactions.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 28,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 40,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Chưa có giao dịch đóng góp nào',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _transactions.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final txn = _transactions[index];
                                  final amt = txn['amount'];
                                  final sender = txn['sender']?.toString() ?? 'Thành viên';
                                  final note = txn['note']?.toString() ?? '';
                                  final date = _formatDate(txn['createdAt']);

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_downward_rounded,
                                            color: Color(0xFF2E7D32),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                sender,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (note.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  note,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                              if (date.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  date,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '+${formatVnd(amt)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
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
