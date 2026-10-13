import 'api_client.dart';

/// Service quản lý toàn bộ các API liên quan đến Quỹ và Lời mời quỹ (Use Case 04, 05, 06)
class FundService {
  FundService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Lấy danh sách quỹ người dùng đang tham gia / làm chủ.
  Future<Map<String, dynamic>> funds(String token) =>
      _client.get('/funds', token: token);

  /// Tạo một quỹ mới (Use Case 04).
  /// Với quỹ "Cặp đôi" bắt buộc phải truyền [partnerId] là người dùng khác
  /// được chọn ngay từ lúc lập quỹ.
  Future<Map<String, dynamic>> createFund({
    required String token,
    required String name,
    required String fundType,
    double? targetAmount,
    DateTime? completionDate,
    String? partnerId,
  }) =>
      _client.post(
        '/funds',
        token: token,
        body: {
          'name': name,
          'fundType': fundType,
          if (targetAmount != null) 'targetAmount': targetAmount,
          if (completionDate != null)
            'completionDate': completionDate.toIso8601String(),
          if (partnerId != null && partnerId.isNotEmpty) 'partnerId': partnerId,
        },
      );

  /// Xoá quỹ theo ID.
  Future<Map<String, dynamic>> deleteFund({
    required String token,
    required String fundId,
  }) =>
      _client.delete('/funds/$fundId', token: token);

  /// Rời quỹ theo ID (dành cho thành viên quỹ).
  Future<Map<String, dynamic>> leaveFund({
    required String token,
    required String fundId,
  }) =>
      _client.post('/funds/$fundId/leave', token: token);

  /// Lấy thông tin chi tiết một quỹ (Use Case 05).
  Future<Map<String, dynamic>> fundDetails({
    required String token,
    required String fundId,
  }) =>
      _client.get('/funds/$fundId', token: token);

  /// Góp tiền vào quỹ (Use Case 05).
  Future<Map<String, dynamic>> contributeFund({
    required String token,
    required String fundId,
    required double amount,
    String? note,
  }) =>
      _client.post(
        '/funds/$fundId/contributions',
        token: token,
        body: {
          'amount': amount,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

  /// Rút tiền từ quỹ về ví cá nhân (chỉ chủ quỹ).
  Future<Map<String, dynamic>> withdrawFund({
    required String token,
    required String fundId,
    required double amount,
    String? note,
  }) =>
      _client.post(
        '/funds/$fundId/withdraw',
        token: token,
        body: {
          'amount': amount,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

/// Danh sách người dùng để chọn làm người cùng lập quỹ cặp đôi.
  Future<Map<String, dynamic>> partnerCandidates({
    required String token,
    String? query,
  }) {
    final queryParam = (query != null && query.trim().isNotEmpty)
        ? '?query=${Uri.encodeComponent(query.trim())}'
        : '';
    return _client.get('/funds/partner-candidates$queryParam', token: token);
  }

/// Lấy danh sách ứng viên có thể mời vào quỹ (hoặc tìm kiếm theo query) (Use Case 06).
  Future<Map<String, dynamic>> fundCandidates({
    required String token,
    required String fundId,
    String? query,
  }) {
    final queryParam = (query != null && query.trim().isNotEmpty)
        ? '?query=${Uri.encodeComponent(query.trim())}'
        : '';
    return _client.get('/funds/$fundId/candidates$queryParam', token: token);
  }

  /// Gửi lời mời tham gia quỹ (Use Case 06).
  Future<Map<String, dynamic>> sendFundInvite({
    required String token,
    required String fundId,
    String? inviteeId,
    String? phoneNumber,
    String? name,
  }) =>
      _client.post(
        '/funds/$fundId/invitations',
        token: token,
        body: {
          if (inviteeId != null) 'inviteeId': inviteeId,
          if (phoneNumber != null) 'phoneNumber': phoneNumber,
          if (name != null) 'name': name,
        },
      );

  /// Lấy danh sách lời mời mà quỹ đã gửi đi.
  Future<Map<String, dynamic>> fundInvitations({
    required String token,
    required String fundId,
  }) =>
      _client.get('/funds/$fundId/invitations', token: token);

  /// Lấy danh sách lời mời nhận được (Use Case 06).
  Future<Map<String, dynamic>> myInvitations({
    required String token,
    String? status,
  }) {
    final queryParam = (status != null && status.isNotEmpty)
        ? '?status=${Uri.encodeComponent(status)}'
        : '';
    return _client.get('/invitations$queryParam', token: token);
  }

  /// Chấp nhận lời mời tham gia quỹ (Use Case 06).
  Future<Map<String, dynamic>> acceptInvitation({
    required String token,
    required String invitationId,
  }) =>
      _client.post('/invitations/$invitationId/accept', token: token);

  /// Từ chối lời mời tham gia quỹ (Use Case 06).
  Future<Map<String, dynamic>> rejectInvitation({
    required String token,
    required String invitationId,
  }) =>
      _client.post('/invitations/$invitationId/reject', token: token);
}
