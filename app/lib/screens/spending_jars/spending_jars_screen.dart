import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/back_label.dart';
import 'create_spending_jar_screen.dart';
import 'spending_jar_detail_screen.dart';

/// Màn hình quản lý Hũ chi tiêu riêng biệt (Dedicated Full Screen)
class SpendingJarsScreen extends StatefulWidget {
  const SpendingJarsScreen({super.key});

  @override
  State<SpendingJarsScreen> createState() => _SpendingJarsScreenState();
}

class _SpendingJarsScreenState extends State<SpendingJarsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _jars = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadJars();
  }

  Future<void> _loadJars() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AppScope.of(context).fetchSpendingJars();
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _jars = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
        _errorMessage = 'Không thể tải danh sách hũ chi tiêu, vui lòng thử lại';
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateJarScreen() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CreateSpendingJarScreen(),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tạo hũ chi tiêu mới thành công!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      _loadJars();
    }
  }

  Future<void> _openJarDetail(Map<String, dynamic> jar) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpendingJarDetailScreen(jar: jar),
      ),
    );
    if (mounted) {
      _loadJars();
    }
  }

  String _formatVnd(dynamic amount) {
    if (amount == null) return '0 đ';
    final n = num.tryParse(amount.toString()) ?? 0;
    final s = n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return '$s đ';
  }

  double get _totalBalance {
    double sum = 0;
    for (var j in _jars) {
      sum += (num.tryParse(j['balance']?.toString() ?? '0') ?? 0).toDouble();
    }
    return sum;
  }

  IconData _getJarIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('ăn') || lower.contains('uống') || lower.contains('thực phẩm')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('mua sắm') || lower.contains('shop')) {
      return Icons.shopping_bag_rounded;
    }
    if (lower.contains('xe') || lower.contains('xăng') || lower.contains('đi lại')) {
      return Icons.directions_car_rounded;
    }
    if (lower.contains('học') || lower.contains('sách')) {
      return Icons.school_rounded;
    }
    if (lower.contains('chơi') || lower.contains('giải trí') || lower.contains('du lịch')) {
      return Icons.sports_esports_rounded;
    }
    if (lower.contains('tiết kiệm') || lower.contains('dự phòng')) {
      return Icons.savings_rounded;
    }
    return Icons.all_inbox_rounded;
  }

  Color _getJarColor(int index) {
    const colors = [
      Color(0xFF00897B), // Teal
      Color(0xFF1976D2), // Blue
      Color(0xFF7B1FA2), // Purple
      Color(0xFFE65100), // Orange
      Color(0xFF0097A7), // Cyan
      Color(0xFFC2185B), // Pink
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
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
                  // Header Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BackLabel(
                        text: 'Trang chủ',
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: 'Làm mới',
                            onPressed: _loadJars,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Đóng',
                            onPressed: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Tiêu đề
                  const Text(
                    'Hũ chi tiêu',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Phân bổ ngân sách thông minh và kiểm soát dòng tiền chi tiêu',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Hero Card: Tổng quan số dư các hũ
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00796B), Color(0xFF004D40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF004D40).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Tổng số dư trong các hũ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_jars.length} hũ đang có',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatVnd(_totalBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nút Tạo hũ mới
                  AppButton(
                    text: 'Tạo hũ chi tiêu mới',
                    icon: Icons.add_rounded,
                    height: 46,
                    fontSize: 15,
                    onPressed: _openCreateJarScreen,
                  ),
                  const SizedBox(height: 14),

                  // Danh sách hũ chi tiêu
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
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadJars,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_jars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF00796B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.all_inbox_rounded,
                size: 38,
                color: Color(0xFF00796B),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Chưa có hũ chi tiêu nào',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hãy tạo các hũ (Ăn uống, Mua sắm, Đi lại...)\nđể phân chia ngân sách chi tiêu hợp lý hơn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJars,
      color: AppColors.lightBlue,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _jars.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final jar = _jars[index];
          final name = jar['name']?.toString() ?? 'Hũ chi tiêu';
          final balance = jar['balance'];
          final color = _getJarColor(index);
          final icon = _getJarIcon(name);

          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 0.5,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openJarDetail(jar),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    // Icon hũ chi tiêu
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

                    // Tên hũ & mô tả
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Chạm để xem chi tiết & biến động',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Số dư
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatVnd(balance),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Chi tiết',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.lightBlueDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: AppColors.lightBlueDark,
                            ),
                          ],
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
