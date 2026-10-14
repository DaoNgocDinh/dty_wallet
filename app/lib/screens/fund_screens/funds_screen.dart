import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/back_label.dart';
import '../home_screen.dart' show formatVnd;
import 'create_fund_screen.dart';
import 'fund_detail_screen.dart';

/// Màn hình quản lý Quỹ riêng biệt (Full screen, không phải dạng pop-up)
class FundsScreen extends StatefulWidget {
  const FundsScreen({super.key});

  @override
  State<FundsScreen> createState() => _FundsScreenState();
}

class _FundsScreenState extends State<FundsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _funds = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFunds();
  }

  Future<void> _loadFunds() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AppScope.of(context).fetchFunds();
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _funds = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
        _errorMessage = 'Không thể tải danh sách quỹ, vui lòng thử lại';
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateFundScreen() async {
    if (_funds.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tạo thêm quỹ'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateFundScreen(initialFundCount: _funds.length),
      ),
    );

    if (created == true) {
      _loadFunds();
    }
  }

  Future<void> _openFundDetail(Map<String, dynamic> fund) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FundDetailScreen(fund: fund),
      ),
    );
    _loadFunds();
  }

  @override
  Widget build(BuildContext context) {
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
                  // Thanh tiêu đề phía trên với nút Trở về và nút Đóng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BackLabel(
                        text: 'Trang chủ',
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
                    'Quỹ tiết kiệm & Đầu tư',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Quản lý, theo dõi và tích lũy tài chính cho các mục tiêu',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nút Tạo quỹ riêng biệt
                  AppButton(
                    text: 'Tạo quỹ',
                    icon: Icons.add_rounded,
                    height: 46,
                    fontSize: 15,
                    onPressed: _openCreateFundScreen,
                  ),
                  const SizedBox(height: 14),

                  // Danh sách quỹ
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFundIcon(String fundType) {
    switch (fundType.trim()) {
      case 'Cá nhân':
        return Icons.person_rounded;
      case 'Cặp đôi':
        return Icons.favorite_rounded;
      case 'Tích lũy':
        return Icons.savings_rounded;
      case 'Hội nhóm':
        return Icons.groups_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color _getFundColor(String fundType) {
    switch (fundType.trim()) {
      case 'Cá nhân':
        return const Color(0xFF1976D2);
      case 'Cặp đôi':
        return const Color(0xFFE91E63);
      case 'Tích lũy':
        return const Color(0xFFE65100);
      case 'Hội nhóm':
        return const Color(0xFF7B1FA2);
      default:
        return const Color(0xFFE53935);
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.lightBlue),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadFunds, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    if (_funds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.savings_outlined,
                size: 56,
                color: Color(0xFFE53935),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có quỹ nào được tạo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hãy bắt đầu tạo quỹ để hiện thực hoá các mục tiêu tài chính',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFunds,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: _funds.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final item = _funds[index];
          final name = item['name']?.toString() ?? 'Quỹ';
          final fundType = item['fundType']?.toString() ?? 'Tiết kiệm';
          final currentAmount =
              (item['currentAmount'] as num?)?.toDouble() ?? 0.0;
          final targetAmount =
              (item['targetAmount'] as num?)?.toDouble() ?? 0.0;
          final hasTarget = targetAmount > 0;
          final progress = hasTarget
              ? (currentAmount / targetAmount).clamp(0.0, 1.0)
              : 0.0;
          final percent = (progress * 100).toInt();
          final completionDate = item['completionDate'];
          final isPendingPartner =
              item['status']?.toString() == 'pending_partner';

          final fundColor = _getFundColor(fundType);
          final fundIcon = _getFundIcon(fundType);

          return Card(
            elevation: 1.5,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: fundColor.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            color: Colors.white,
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openFundDetail(item),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header của Card: Icon + Tên quỹ + Loại quỹ + Trạng thái
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: fundColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            fundIcon,
                            color: fundColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: fundColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: fundColor.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Text(
                                      fundType,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: fundColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isPendingPartner) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF8E1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFFFE082),
                                        ),
                                      ),
                                      child: const Text(
                                        'Chờ đồng ý',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFF57F17),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Phần tài chính của Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Số dư hiện tại',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatVnd(currentAmount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: fundColor,
                                ),
                              ),
                            ],
                          ),
                          if (hasTarget) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Mục tiêu: ${formatVnd(targetAmount)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$percent%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: progress >= 1.0
                                        ? const Color(0xFF2E7D32)
                                        : fundColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 1.0
                                      ? const Color(0xFF2E7D32)
                                      : fundColor,
                                ),
                              ),
                            ),
                          ],
                          if (completionDate != null &&
                              _formatDate(completionDate).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.event_outlined,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Thời hạn: ${_formatDate(completionDate)}',
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Footer nhỏ của Card
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Xem chi tiết & quản lý quỹ',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.lightBlue,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.lightBlue,
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
    );
  }
}
