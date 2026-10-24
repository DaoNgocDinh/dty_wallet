import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import 'fund_screens/fund_invitations_screen.dart';
import 'fund_screens/funds_screen.dart';
import 'spending_jars_screen.dart';
import 'transaction_history_screen.dart';

/// Modal bottom sheet hiển thị danh sách thông báo
class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AppScope.of(context).fetchNotifications();
      if (!mounted) return;

      final dataList = res['data'];
      final unread = res['unreadCount'] as num? ?? 0;

      setState(() {
        if (dataList is List) {
          _notifications = dataList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _notifications = [];
        }
        _unreadCount = unread.toInt();
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
        _errorMessage = 'Không thể tải thông báo';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await AppScope.of(context).markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (var n in _notifications) {
          n['isRead'] = true;
        }
        _unreadCount = 0;
      });
    } catch (_) {}
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> item) async {
    final id = item['_id']?.toString() ?? item['id']?.toString() ?? '';
    final isRead = item['isRead'] == true;
    final type = item['type']?.toString() ?? '';

    if (!isRead && id.isNotEmpty) {
      try {
        await AppScope.of(context).markNotificationRead(id);
        setState(() {
          item['isRead'] = true;
          if (_unreadCount > 0) _unreadCount--;
        });
      } catch (_) {}
    }

    if (!mounted) return;

    if (type == 'fund_invitation' || item['metadata']?['invitationId'] != null) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FundInvitationsScreen()),
      );
    } else if (type == 'fund' ||
        type == 'fund_contribution' ||
        type == 'fund_withdrawal' ||
        type == 'invitation_accepted') {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FundsScreen()),
      );
    } else if (type == 'spending_jar') {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SpendingJarsScreen()),
      );
    } else if (type == 'wallet_deposit' ||
        type == 'mobile_topup' ||
        type == 'data_topup' ||
        type == 'bill_payment') {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
      );
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'wallet_deposit':
        return Icons.account_balance_wallet_rounded;
      case 'mobile_topup':
        return Icons.phone_android_rounded;
      case 'data_topup':
        return Icons.wifi_rounded;
      case 'bill_payment':
        return Icons.receipt_long_rounded;
      case 'spending_jar':
        return Icons.all_inbox_rounded;
      case 'fund':
      case 'fund_contribution':
      case 'fund_withdrawal':
        return Icons.savings_rounded;
      case 'fund_invitation':
        return Icons.mail_rounded;
      case 'invitation_accepted':
        return Icons.check_circle_rounded;
      case 'invitation_rejected':
      case 'member_left':
        return Icons.cancel_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'wallet_deposit':
        return const Color(0xFF2E7D32);
      case 'mobile_topup':
        return const Color(0xFF00897B);
      case 'data_topup':
        return const Color(0xFF0288D1);
      case 'bill_payment':
        return const Color(0xFFEF6C00);
      case 'spending_jar':
        return const Color(0xFF00796B);
      case 'fund':
      case 'fund_contribution':
      case 'fund_withdrawal':
        return const Color(0xFF7B1FA2);
      case 'fund_invitation':
        return const Color(0xFFE53935);
      case 'invitation_accepted':
        return const Color(0xFF2E7D32);
      case 'invitation_rejected':
      case 'member_left':
        return const Color(0xFFD32F2F);
      default:
        return AppColors.lightBlue;
    }
  }

  String? _getActionLabel(String type, Map<String, dynamic>? metadata) {
    if (type == 'fund_invitation' || metadata?['invitationId'] != null) {
      return 'Nhấn để xem lời mời';
    }
    if (type == 'fund' ||
        type == 'fund_contribution' ||
        type == 'fund_withdrawal' ||
        type == 'invitation_accepted') {
      return 'Nhấn để xem Quỹ';
    }
    if (type == 'spending_jar') {
      return 'Nhấn để xem Hũ chi tiêu';
    }
    if (type == 'wallet_deposit' ||
        type == 'mobile_topup' ||
        type == 'data_topup' ||
        type == 'bill_payment') {
      return 'Nhấn để xem chi tiết giao dịch';
    }
    return null;
  }

  String _formatTime(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Vừa xong';
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d/$m';
    } catch (_) {
      return dateVal.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header kéo thanh
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Tiêu đề & Đánh dấu đã đọc
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Thông báo',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_unreadCount mới',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_notifications.any((n) => n['isRead'] != true))
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text(
                      'Đọc tất cả',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightBlue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Nội dung danh sách thông báo
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.lightBlue),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFC62828))),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'Bạn chưa có thông báo nào',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _notifications.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _notifications[index];
        final title = item['title']?.toString() ?? 'Thông báo';
        final message = item['message']?.toString() ?? '';
        final isRead = item['isRead'] == true;
        final type = item['type']?.toString() ?? '';
        final timeStr = _formatTime(item['createdAt']);

        final iconColor = _getTypeColor(type);
        final iconData = _getTypeIcon(type);
        final actionLabel = _getActionLabel(type, item['metadata'] as Map<String, dynamic>?);

        return InkWell(
          onTap: () => _handleNotificationTap(item),
          child: Container(
            color: isRead ? Colors.transparent : iconColor.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon thông báo
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Nội dung
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                          fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                      if (actionLabel != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              actionLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: iconColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: iconColor),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Chấm đỏ nếu chưa đọc
                if (!isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC62828),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
