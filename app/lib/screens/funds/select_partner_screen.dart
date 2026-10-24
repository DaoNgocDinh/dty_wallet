import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_label.dart';

/// Màn hình chọn người dùng khác làm người cùng lập quỹ "Cặp đôi".
/// Trả về Map thông tin người dùng đã chọn qua Navigator.pop.
class SelectPartnerScreen extends StatefulWidget {
  const SelectPartnerScreen({super.key});

  @override
  State<SelectPartnerScreen> createState() => _SelectPartnerScreenState();
}

class _SelectPartnerScreenState extends State<SelectPartnerScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _users = [];
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      _hasLoaded = true;
      _loadUsers();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadUsers(query: value.trim());
    });
  }

  Future<void> _loadUsers({String? query}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AppScope.of(context).fetchPartnerCandidates(query: query);
      if (!mounted) return;

      final data = res['data'];
      final code = res['code']?.toString();
      final message = (res['message'] ?? res['error'])?.toString();

      if (code == 'NO_USER_FOUND' ||
          (query != null && query.isNotEmpty && data is List && data.isEmpty)) {
        setState(() {
          _users = [];
          _errorMessage = message ?? 'Không tìm thấy người dùng phù hợp';
          _isLoading = false;
        });
        return;
      }

      if (data is List) {
        final list = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((u) {
              final role = u['role']?.toString().toLowerCase();
              final name = u['name']?.toString().trim().toLowerCase();
              final email = u['email']?.toString().trim().toLowerCase();
              return role != 'admin' &&
                  name != 'admin' &&
                  !(email?.startsWith('admin@') ?? false);
            })
            .toList();
        setState(() {
          _users = list;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _users = [];
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _users = [];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải danh sách người dùng';
        _users = [];
        _isLoading = false;
      });
    }
  }

  void _confirmSelect(Map<String, dynamic> user) {
    Navigator.of(context).pop(user);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BackLabel(
                        text: 'Tạo quỹ',
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

                  const Text(
                    'Chọn người cùng lập quỹ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Quỹ cặp đôi chỉ có 2 người dùng. Người được chọn sẽ nhận lời mời và quỹ chính thức được lập khi họ đồng ý.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // Ô tìm kiếm người dùng theo tên / số điện thoại / email
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên, số điện thoại hoặc email...',
                        hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.lightBlue),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadUsers();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      onSubmitted: (value) => _loadUsers(query: value.trim()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          hasQuery ? 'Kết quả tìm kiếm' : 'Danh sách gợi ý',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_users.isNotEmpty)
                        Text(
                          '${_users.length} người dùng',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Expanded(child: _buildBody(hasQuery)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool hasQuery) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.lightBlue),
      );
    }

    if (_errorMessage != null && _users.isEmpty) {
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
                color: isNotFound ? Colors.grey.shade400 : AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isNotFound ? AppColors.textPrimary : AppColors.error,
                ),
              ),
              if (isNotFound) ...[
                const SizedBox(height: 6),
                const Text(
                  'Vui lòng kiểm tra lại tên, số điện thoại hoặc email.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Text(
          hasQuery ? 'Không có kết quả phù hợp' : 'Chưa có người dùng nào',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadUsers(query: _searchController.text.trim()),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _users.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final user = _users[index];
          final name = user['name']?.toString() ?? 'Người dùng';
          final phone = user['phoneNumber']?.toString() ?? '';
          final email = user['email']?.toString() ?? '';
          final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

          return InkWell(
            onTap: () => _confirmSelect(user),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Chọn',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}