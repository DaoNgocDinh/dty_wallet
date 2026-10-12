import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/back_label.dart';
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
        itemCount: _funds.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _funds[index];
          final name = item['name']?.toString() ?? 'Quỹ';
          final fundType = item['fundType']?.toString() ?? 'Tiết kiệm';
          final targetAmount = item['targetAmount'];
          final hasTarget = targetAmount != null && (targetAmount as num) > 0;
          final targetAmountStr = hasTarget ? '${targetAmount} đ' : '0 đ';

          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openFundDetail(item),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE53935).withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Icon đại diện
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Color(0xFFE53935),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Thông tin quỹ
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE53935),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
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
                                      fontSize: 11.5,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    targetAmountStr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Mũi tên điều hướng xem chi tiết quỹ
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
