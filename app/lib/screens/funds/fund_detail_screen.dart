import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/back_label.dart';
import '../../utils/format_utils.dart' show formatVnd;
import 'contribute_fund_screen.dart';
import 'invite_member_screen.dart';
import 'withdraw_fund_screen.dart';

/// Màn hình Chi tiết quỹ (Có giao diện riêng khi ấn vào quỹ tương ứng)
class FundDetailScreen extends StatefulWidget {
  const FundDetailScreen({super.key, required this.fund});

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
      MaterialPageRoute(builder: (_) => ContributeFundScreen(fund: _fund)),
    );

    if (result != null) {
      if (result is Map<String, dynamic>) {
        setState(() => _fund = result);
      }
      _loadDetails();
    }
  }

  /// Mở màn hình Rút tiền từ quỹ (chỉ chủ quỹ)
  Future<void> _openWithdrawScreen() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WithdrawFundScreen(fund: _fund)));

    if (result != null) {
      if (result is Map<String, dynamic>) {
        setState(() => _fund = result);
      }
      _loadDetails();
    }
  }

  /// Mở màn hình Mời thành viên - Use Case 06
  void _openInviteScreen() {
    final fundType = _fund['fundType']?.toString() ?? '';
    if (fundType == 'Cá nhân') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Quỹ cá nhân không thể mời thành viên')),
            ],
          ),
          backgroundColor: Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Quỹ cặp đôi chỉ có tối đa 2 người dùng
    if (fundType == 'Cặp đôi') {
      if (_fundStatus == 'pending_partner') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Quỹ cặp đôi đang chờ người được chọn đồng ý'),
                ),
              ],
            ),
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_members.length >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Quỹ cặp đôi chỉ có 2 người dùng')),
              ],
            ),
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => InviteMemberScreen(fund: _fund)));
  }

  String get _fundStatus => _fund['status']?.toString() ?? 'active';

  /// Quỹ cặp đôi chỉ được có tối đa 2 người dùng
  bool get _canInviteMore {
    if (_fund['fundType']?.toString() != 'Cặp đôi') return true;
    if (_fundStatus == 'pending_partner') return false;
    return _members.length < 2;
  }

  String get _ownerId {
    final ownerRaw = _fund['userId'];
    if (ownerRaw is Map) {
      return ownerRaw['_id']?.toString() ?? ownerRaw['id']?.toString() ?? '';
    }
    return ownerRaw?.toString() ?? '';
  }

  List<Map<String, dynamic>> get _members {
    final raw = _fund['members'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  String _getMemberUserId(Map<String, dynamic> member) {
    final u = member['userId'];
    if (u is Map) {
      return u['_id']?.toString() ?? u['id']?.toString() ?? '';
    }
    return u?.toString() ?? '';
  }

  String _getMemberName(Map<String, dynamic> member) {
    final u = member['userId'];
    if (u is Map) {
      final name = u['name']?.toString() ?? '';
      if (name.isNotEmpty) return name;
    }
    if (member['role'] == 'owner') return 'Chủ quỹ';
    return 'Thành viên quỹ';
  }

  String _getMemberSubtitle(Map<String, dynamic> member) {
    final u = member['userId'];
    if (u is Map) {
      final phone = u['phoneNumber']?.toString() ?? '';
      if (phone.isNotEmpty) return phone;
      final email = u['email']?.toString() ?? '';
      if (email.isNotEmpty) return email;
    }
    return '';
  }

  bool _isCurrentUserOwner(String currentUserId) {
    if (currentUserId.isEmpty) return false;
    final ownerId = _ownerId;
    if (ownerId.isNotEmpty && ownerId == currentUserId) return true;
    for (final m in _members) {
      final mId = _getMemberUserId(m);
      if (mId == currentUserId && m['role'] == 'owner') {
        return true;
      }
    }
    return false;
  }

  /// Xác nhận và xoá quỹ (Chỉ dành cho Chủ quỹ)
  Future<void> _confirmDeleteFund() async {
    final fundName = _fund['name']?.toString() ?? 'quỹ này';
    final currentAmount = (_fund['currentAmount'] as num?)?.toDouble() ?? 0;

    // Quỹ chỉ được xoá khi số dư còn 0đ
    if (currentAmount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chỉ được xoá quỹ khi số dư quỹ bằng 0. Quỹ đang có ${formatVnd(currentAmount)}',
          ),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFC62828),
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Xác nhận xoá quỹ',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xoá quỹ "$fundName" không? '
          'Hành động này không thể hoàn tác và tất cả lịch sử giao dịch sẽ bị xoá.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Huỷ', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Xoá quỹ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final fundId = _fund['_id']?.toString() ?? _fund['id']?.toString() ?? '';
    if (fundId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await AppScope.of(context).deleteFund(fundId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xoá quỹ "$fundName" thành công'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop({'deleted': true, 'fundId': fundId});
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'FUND_NOT_EMPTY'
                ? 'Chỉ được xoá quỹ khi số dư quỹ bằng 0'
                : e.message,
          ),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Xác nhận và rời quỹ (Dành cho thành viên quỹ)
  Future<void> _confirmLeaveFund() async {
    final fundName = _fund['name']?.toString() ?? 'quỹ này';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Color(0xFFC62828), size: 24),
            SizedBox(width: 8),
            Text(
              'Rời khỏi quỹ?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn rời khỏi quỹ "$fundName"? '
          'Bạn sẽ không còn theo dõi hay thực hiện các hoạt động trong quỹ này.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Huỷ', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Rời quỹ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final fundId = _fund['_id']?.toString() ?? _fund['id']?.toString() ?? '';
    if (fundId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await AppScope.of(context).leaveFund(fundId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bạn đã rời khỏi quỹ "$fundName" thành công'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop({'left': true, 'fundId': fundId});
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
    final currentUserId = AppScope.of(context).user?.id ?? '';
    final isOwner = _isCurrentUserOwner(currentUserId);
    final name = _fund['name']?.toString() ?? 'Chi tiết quỹ';
    final fundType = _fund['fundType']?.toString() ?? 'Tiết kiệm';
    final currentAmount = (_fund['currentAmount'] as num?)?.toDouble() ?? 0;
    final targetAmount = (_fund['targetAmount'] as num?)?.toDouble() ?? 0;
    final hasTarget = targetAmount > 0;
    final progress = hasTarget
        ? (currentAmount / targetAmount).clamp(0.0, 1.0)
        : 0.0;
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
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
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
                                  color: const Color(0xFFE53935)
                                      .withValues(alpha: 0.3),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE53935)
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
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

                            // Quỹ cặp đôi đang chờ người được chọn đồng ý
                            if (_fundStatus == 'pending_partner') ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFFE082),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.hourglass_top_rounded,
                                      color: Color(0xFFF57F17),
                                      size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Quỹ cặp đôi đang chờ người được chọn đồng ý',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFF57F17),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Các nút hành động
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    text: '+ Góp quỹ',
                                    icon: Icons.add_circle_outline_rounded,
                                    height: 48,
                                    fontSize: 14.5,
                                    onPressed: _openContributeScreen,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.lightBlue,
                                      side: const BorderSide(
                                        color: AppColors.lightBlue,
                                        width: 1.4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      minimumSize: const Size(0, 48),
                                    ),
                                    icon: const Icon(
                                      Icons.person_add_rounded,
                                      size: 19,
                                    ),
                                    label: const Text(
                                      'Mời thành viên',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: _canInviteMore
                                        ? _openInviteScreen
                                        : null,
                                  ),
                                ),
                              ],
                            ),

                            // Nút Rút tiền (chỉ chủ quỹ và quỹ đang có tiền)
                            if (isOwner) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                key: const ValueKey('withdraw_fund_button'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2E7D32),
                                  side: const BorderSide(
                                    color: Color(0xFFA5D6A7),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(double.infinity, 42),
                                  backgroundColor: const Color(0xFFE8F5E9)
                                      .withValues(alpha: 0.6),
                                ),
                                icon: const Icon(
                                  Icons.savings_outlined,
                                  size: 19,
                                ),
                                label: const Text(
                                  'Rút tiền về ví',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: currentAmount > 0
                                    ? _openWithdrawScreen
                                    : null,
                              ),
                            ],

                            // Nút Xoá quỹ (Chủ quỹ) hoặc Rời quỹ (Thành viên)
                            if (isOwner) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                key: const ValueKey('delete_fund_button'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: currentAmount > 0
                                      ? Colors.grey.shade500
                                      : const Color(0xFFC62828),
                                  side: BorderSide(
                                    color: currentAmount > 0
                                        ? Colors.grey.shade300
                                        : const Color(0xFFEF9A9A),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(double.infinity, 42),
                                  backgroundColor: currentAmount > 0
                                      ? Colors.grey.shade100
                                      : const Color(0xFFFFEBEE)
                                            .withValues(alpha: 0.5),
                                ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 19,
                                ),
                                label: Text(
                                  currentAmount > 0
                                      ? 'Rút hết tiền mới xoá được quỹ'
                                      : 'Xoá quỹ này',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _confirmDeleteFund,
                              ),
                            ] else ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                key: const ValueKey('leave_fund_button'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD84315),
                                  side: const BorderSide(
                                    color: Color(0xFFFFCCBC),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(double.infinity, 42),
                                  backgroundColor: const Color(0xFFFBE9E7)
                                      .withValues(alpha: 0.5),
                                ),
                                icon: const Icon(
                                  Icons.exit_to_app_rounded,
                                  size: 19,
                                ),
                                label: const Text(
                                  'Rời khỏi quỹ',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _confirmLeaveFund,
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Tiêu đề Thành viên quỹ
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Thành viên quỹ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_members.length} thành viên',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Danh sách thành viên quỹ
                            if (_members.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.people_outline_rounded,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Chưa có danh sách thành viên',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _members.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final m = _members[index];
                                  final mId = _getMemberUserId(m);
                                  final mName = _getMemberName(m);
                                  final mSubtitle = _getMemberSubtitle(m);
                                  final isThisOwner =
                                      m['role'] == 'owner' ||
                                      (mId.isNotEmpty && mId == _ownerId);
                                  final isMe =
                                      currentUserId.isNotEmpty &&
                                      mId == currentUserId;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isThisOwner
                                              ? const Color(0xFFFFF3E0)
                                              : const Color(0xFFE3F2FD),
                                          child: Text(
                                            mName.isNotEmpty
                                                ? mName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: isThisOwner
                                                  ? const Color(0xFFE65100)
                                                  : const Color(0xFF1976D2),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      mName,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 1.5,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .lightBlue
                                                            .withValues(
                                                              alpha: 0.12,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: const Text(
                                                        'Bạn',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: AppColors
                                                              .lightBlueDark,
                                                        ),
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 1.5,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFE8F5E9,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: const Text(
                                                        'Góp quỹ',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                            0xFF2E7D32,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if (mSubtitle.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  mSubtitle,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isThisOwner
                                                ? const Color(0xFFFFF3E0)
                                                : const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: isThisOwner
                                                  ? const Color(0xFFFFB74D)
                                                  : const Color(0xFFE0E0E0),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isThisOwner
                                                    ? Icons.stars_rounded
                                                    : Icons.person_rounded,
                                                size: 13,
                                                color: isThisOwner
                                                    ? const Color(0xFFE65100)
                                                    : const Color(0xFF616161),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isThisOwner
                                                    ? 'Chủ quỹ'
                                                    : 'Thành viên',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isThisOwner
                                                      ? const Color(0xFFE65100)
                                                      : const Color(0xFF616161),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 20),

                            // Tiêu đề Lịch sử giao dịch của quỹ
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Lịch sử giao dịch',
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
                                      'Chưa có giao dịch nào với quỹ',
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
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final txn = _transactions[index];
                                  final amt = txn['amount'];
                                  final sender =
                                      txn['sender']?.toString() ?? 'Thành viên';
                                  final note = txn['note']?.toString() ?? '';
                                  final date = _formatDate(txn['createdAt']);
                                  final isWithdrawal =
                                      txn['type']?.toString() ==
                                      'fund_withdrawal';

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                (isWithdrawal
                                                        ? const Color(
                                                            0xFFC62828,
                                                          )
                                                        : const Color(
                                                            0xFF2E7D32,
                                                          ))
                                                    .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isWithdrawal
                                                ? Icons.arrow_upward_rounded
                                                : Icons.arrow_downward_rounded,
                                            color: isWithdrawal
                                                ? const Color(0xFFC62828)
                                                : const Color(0xFF2E7D32),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      sender,
                                                      style: const TextStyle(
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isWithdrawal) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 1.5,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFFFEBEE,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: const Text(
                                                        'Rút tiền',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                            0xFFC62828,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if (note.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  note,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                          '${isWithdrawal ? '-' : '+'}${formatVnd(amt)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isWithdrawal
                                                ? const Color(0xFFC62828)
                                                : const Color(0xFF2E7D32),
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
