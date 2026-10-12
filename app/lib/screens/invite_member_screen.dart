import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/back_label.dart';

/// Màn hình Mời thành viên (Use Case 06 - Đào Ngọc Đình)
class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({
    super.key,
    required this.fund,
  });

  final Map<String, dynamic> fund;

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _candidates = [];
  bool _hasSearched = false;

  String get _fundId =>
      widget.fund['_id']?.toString() ?? widget.fund['id']?.toString() ?? '';
  String get _fundName => widget.fund['name']?.toString() ?? 'Quỹ';
  String get _fundType => widget.fund['fundType']?.toString() ?? 'Hội nhóm';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasSearched) {
      _hasSearched = true;
      _loadCandidates();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadCandidates(query: _searchController.text.trim());
    });
  }

  Future<void> _loadCandidates({String? query}) async {
    if (_fundId.isEmpty) return;

    // Ngoại lệ 1.2 / E2: Quỹ là quỹ cá nhân
    if (_fundType == 'Cá nhân') {
      setState(() {
        _errorMessage = 'Quỹ cá nhân không thể mời thành viên';
        _isLoading = false;
        _candidates = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AppScope.of(context).fetchFundCandidates(
        fundId: _fundId,
        query: query,
      );
      if (!mounted) return;

      final dataList = res['data'];
      final rawCode = res['code'];
      final rawMsg = res['message'] ?? res['error'];

      if (rawCode == 'NO_USER_FOUND' || (query != null && query.isNotEmpty && dataList is List && dataList.isEmpty)) {
        setState(() {
          _candidates = [];
          _errorMessage = rawMsg?.toString() ?? 'Không tìm thấy người dùng phù hợp';
          _isLoading = false;
        });
        return;
      }

      if (dataList is List) {
        setState(() {
          _candidates = dataList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where((c) {
                final role = c['role']?.toString().toLowerCase();
                final name = c['name']?.toString().trim().toLowerCase();
                final email = c['email']?.toString().trim().toLowerCase();
                return role != 'admin' &&
                    name != 'admin' &&
                    !(email?.startsWith('admin@') ?? false);
              })
              .toList();
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _candidates = [];
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _candidates = [];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải danh sách người dùng';
        _candidates = [];
        _isLoading = false;
      });
    }
  }

  /// Mở hộp thoại xác nhận và gửi lời mời
  Future<void> _confirmAndSendInvite(Map<String, dynamic> candidate) async {
    final candidateName = candidate['name']?.toString() ?? 'Người dùng';
    final candidatePhone = candidate['phoneNumber']?.toString() ?? '';
    final candidateId = candidate['id']?.toString() ?? candidate['_id']?.toString() ?? '';

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppColors.lightBlue),
            SizedBox(width: 8),
            Text('Xác nhận lời mời', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có muốn mời $candidateName tham gia vào quỹ "$_fundName" không?'),
            if (candidatePhone.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Số điện thoại: $candidatePhone', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Gửi lời mời'),
          ),
        ],
      ),
    );

    if (shouldSend != true) return;

    // Gửi lời mời qua API
    try {
      final res = await AppScope.of(context).sendFundInvite(
        fundId: _fundId,
        inviteeId: candidateId.isNotEmpty ? candidateId : null,
        phoneNumber: candidatePhone.isNotEmpty ? candidatePhone : null,
      );

      if (!mounted) return;

      final successMsg = res['message']?.toString() ?? 'Gửi lời mời thành công';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(successMsg)),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Cập nhật lại trạng thái của ứng viên này trong danh sách
      setState(() {
        for (var c in _candidates) {
          final cId = c['id']?.toString() ?? c['_id']?.toString() ?? '';
          if (cId == candidateId || (candidatePhone.isNotEmpty && c['phoneNumber'] == candidatePhone)) {
            c['hasPendingInvite'] = true;
            c['canInvite'] = false;
          }
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(e.message)),
            ],
          ),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Gửi lời mời không thành công')),
            ],
          ),
          backgroundColor: Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersonalFund = _fundType == 'Cá nhân';

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  // Thanh điều hướng trên cùng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BackLabel(
                        text: 'Quỹ',
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

                  // Tiêu đề & Tên quỹ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mời thành viên',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Quỹ: $_fundName',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.lightBlueDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isPersonalFund
                              ? Colors.grey.shade200
                              : AppColors.lightBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _fundType,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isPersonalFund ? Colors.grey.shade700 : AppColors.lightBlueDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ngoại lệ 1.2 / E2: Cảnh báo Quỹ cá nhân
                  if (isPersonalFund)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEF9A9A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFFC62828), size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Quỹ cá nhân không thể mời thành viên',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC62828),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Thanh tìm kiếm người dùng theo tên hoặc số điện thoại
                  if (!isPersonalFund) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        enabled: !isPersonalFund,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm theo tên hoặc số điện thoại...',
                          hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.lightBlue),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadCandidates();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        onSubmitted: (val) => _loadCandidates(query: val.trim()),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Tiêu đề danh sách
                  if (!isPersonalFund)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _searchController.text.trim().isEmpty
                                ? 'Danh sách đề xuất'
                                : 'Kết quả tìm kiếm',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_candidates.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${_candidates.length} người dùng',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 10),

                  // Nội dung danh sách ứng viên
                  Expanded(
                    child: _buildBody(isPersonalFund),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isPersonalFund) {
    if (isPersonalFund) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_person_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Chức năng mời thành viên chỉ áp dụng cho Quỹ Cặp đôi, Tích lũy hoặc Hội nhóm.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.lightBlue),
      );
    }

    // Hiển thị lỗi E1, E3 hoặc lỗi mạng
    if (_errorMessage != null && _candidates.isEmpty) {
      final isNotFound = _errorMessage == 'Không tìm thấy người dùng phù hợp';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNotFound ? Icons.search_off_rounded : Icons.error_outline_rounded,
                size: 50,
                color: isNotFound ? Colors.grey.shade400 : const Color(0xFFC62828),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isNotFound ? AppColors.textPrimary : const Color(0xFFC62828),
                ),
              ),
              if (isNotFound) ...[
                const SizedBox(height: 6),
                const Text(
                  'Vui lòng kiểm tra lại tên hoặc số điện thoại tìm kiếm.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'Không có người dùng nào để hiển thị',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadCandidates(query: _searchController.text.trim()),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _candidates.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _candidates[index];
          final name = item['name']?.toString() ?? 'Người dùng';
          final phone = item['phoneNumber']?.toString() ?? '';
          final email = item['email']?.toString() ?? '';
          final isMember = item['isMember'] == true;
          final hasPendingInvite = item['hasPendingInvite'] == true;
          final canInvite = item['canInvite'] == true;

          final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Avatar tròn
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.lightBlue.withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lightBlueDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Thông tin tên và số điện thoại
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        phone.isNotEmpty ? phone : email,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Nút hành động hoặc nhãn trạng thái
                if (isMember)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Đã là thành viên',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (hasPendingInvite)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: const Text(
                      'Đã gửi lời mời',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFF57F17),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('Mời', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => _confirmAndSendInvite(item),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
