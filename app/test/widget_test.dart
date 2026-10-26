// Widget test cho luồng đăng nhập / đăng ký (dùng AuthService giả, không gọi API thật).

import 'package:app/main.dart';
import 'package:app/screens/admin_users_screen.dart';
import 'package:app/screens/change_password_screen.dart';
import 'package:app/screens/create_fund_screen.dart';
import 'package:app/screens/contribute_fund_screen.dart';
import 'package:app/screens/deposit_wallet_screen.dart';
import 'package:app/screens/fund_detail_screen.dart';
import 'package:app/screens/funds_screen.dart';
import 'package:app/screens/invite_member_screen.dart';
import 'package:app/screens/fund_invitations_screen.dart';
import 'package:app/screens/notifications_sheet.dart';
import 'package:app/screens/select_partner_screen.dart';
import 'package:app/screens/withdraw_fund_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/profile_screen.dart';
import 'package:app/screens/register_screen.dart';
import 'package:app/services/api_client.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/state/app_session.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/app_button.dart';
import 'package:app/widgets/back_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AuthService giả: trả về token nếu mật khẩu là "123456", ngược lại báo lỗi.
class FakeAuthService implements AuthService {
  FakeAuthService({required this.acceptedPassword});

  final String acceptedPassword;
  String? currentPassword = 'mat-khau-cu';

  @override
  FundService get fundService => FundService();

  @override
  Future<AuthResult> login({
    required String account,
    required String password,
  }) async {
    if (password != acceptedPassword) {
      throw ApiException(
        'Tài khoản hoặc mật khẩu không đúng',
        code: 'INVALID_CREDENTIALS',
        statusCode: 401,
      );
    }
    return _result(account);
  }

  @override
  Future<AuthResult> register({
    required String account,
    required String password,
  }) async {
    if (account.toLowerCase() == 'admin') {
      throw ApiException(
        'Tài khoản đã tồn tại',
        code: 'USERNAME_EXISTS',
        statusCode: 409,
      );
    }
    return _result(account);
  }

  double mockWalletBalance = 1000000;
  bool shouldFailContribute = false;
  bool shouldNetworkFailContribute = false;
  List<Map<String, dynamic>> mockFundTransactions = [];

  @override
  Future<Map<String, dynamic>> wallet(String token) async => {
    'balance': mockWalletBalance,
    'walletBalance': mockWalletBalance,
    'role': token.toLowerCase().contains('admin') ? 'admin' : 'user',
  };

  @override
  Future<void> logout(String token) async {}

  @override
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    if (currentPassword != this.currentPassword) {
      throw ApiException(
        'Mật khẩu cũ không đúng',
        code: 'WRONG_PASSWORD',
        statusCode: 400,
      );
    }
    if (newPassword != confirmNewPassword) {
      throw ApiException('Xác thực mật khẩu không khớp', code: 'INVALID_INPUT');
    }
    this.currentPassword = newPassword;
  }

  @override
  Future<void> setPin({
    required String token,
    required String password,
    required String pin,
  }) async {}

  @override
  Future<Map<String, dynamic>> profile(String token) async {
    final isAdmin = token.toLowerCase().contains('admin');
    return {
      'user': {
        'id': '65f0000000000000000000aa',
        'name': isAdmin ? 'admin' : 'nguoidung',
        'email': isAdmin ? 'admin@gmail.com' : 'nguoidung@gmail.com',
        'walletBalance': mockWalletBalance,
        'hasPin': false,
        'role': isAdmin ? 'admin' : 'user',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> transactions(String token) async => {'data': []};

  List<Map<String, dynamic>> mockFunds = [];

  @override
  Future<Map<String, dynamic>> funds(String token) async => {'data': mockFunds};

  @override
  Future<Map<String, dynamic>> createFund({
    required String token,
    required String name,
    required String fundType,
    double? targetAmount,
    DateTime? completionDate,
    String? partnerId,
  }) async {
    if (mockFunds.length >= 10) {
      throw ApiException('Không thể tạo thêm quỹ', code: 'MAX_FUNDS_EXCEEDED');
    }
    // Quỹ cặp đôi bắt buộc phải chọn người dùng khác ngay từ lúc lập quỹ
    if (fundType == 'Cặp đôi' && (partnerId == null || partnerId.isEmpty)) {
      throw ApiException(
        'Vui lòng chọn người dùng khác để lập quỹ cặp đôi',
        code: 'PARTNER_REQUIRED',
        statusCode: 400,
      );
    }
    final newFund = {
      'id': 'fund_${mockFunds.length + 1}',
      'name': name,
      'fundType': fundType,
      'targetAmount': targetAmount ?? 0,
      'currentAmount': 0,
      'status': fundType == 'Cặp đôi' ? 'pending_partner' : 'active',
      'userId': '65f0000000000000000000aa',
      'members': [
        {'userId': '65f0000000000000000000aa', 'role': 'owner'},
      ],
      'completionDate': completionDate?.toIso8601String(),
    };
    mockFunds.add(newFund);
    return {
      'message': fundType == 'Cặp đôi'
          ? 'Đã gửi lời mời, quỹ cặp đôi sẽ được lập khi người được chọn đồng ý'
          : 'Tạo quỹ thành công',
      'data': newFund,
      ...newFund,
    };
  }

  @override
  Future<Map<String, dynamic>> deleteFund({
    required String token,
    required String fundId,
  }) async {
    final fund = mockFunds.firstWhere(
      (item) => (item['id'] ?? item['_id']) == fundId,
      orElse: () => <String, dynamic>{},
    );
    // Quỹ chỉ được xoá khi số dư còn 0đ
    if (((fund['currentAmount'] as num?)?.toDouble() ?? 0) > 0) {
      throw ApiException(
        'Chỉ được xoá quỹ khi số dư quỹ bằng 0',
        code: 'FUND_NOT_EMPTY',
        statusCode: 400,
      );
    }
    mockFunds.removeWhere((item) => (item['id'] ?? item['_id']) == fundId);
    return {'message': 'Xoá quỹ thành công', 'id': fundId};
  }

  @override
  Future<Map<String, dynamic>> withdrawFund({
    required String token,
    required String fundId,
    required double amount,
    String? note,
  }) async {
    final fundIndex = mockFunds.indexWhere(
      (item) => (item['id'] ?? item['_id']) == fundId,
    );
    if (fundIndex == -1) {
      throw ApiException(
        'Quỹ không tồn tại',
        code: 'FUND_NOT_FOUND',
        statusCode: 404,
      );
    }

    final fund = Map<String, dynamic>.from(mockFunds[fundIndex]);
    final current = (fund['currentAmount'] as num?)?.toDouble() ?? 0;
    if (amount < 1000) {
      throw ApiException(
        'Tối thiểu 1000đ',
        code: 'MIN_AMOUNT_1000',
        statusCode: 400,
      );
    }
    if (amount > current) {
      throw ApiException(
        'Số dư quỹ không đủ để rút',
        code: 'INSUFFICIENT_FUND_BALANCE',
        statusCode: 400,
      );
    }

    fund['currentAmount'] = current - amount;
    mockFunds[fundIndex] = fund;

    mockWalletBalance += amount;
    final txn = {
      'id': 'txn_${mockFundTransactions.length + 1}',
      'fundId': fundId,
      'type': 'fund_withdrawal',
      'amount': amount,
      'sender': fund['name'],
      'recipient': 'Ví cá nhân',
      'note': note ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    };
    mockFundTransactions.insert(0, txn);

    return {
      'message': 'Rút tiền thành công',
      'fund': fund,
      'walletBalance': mockWalletBalance,
      'transaction': txn,
    };
  }

  @override
  Future<Map<String, dynamic>> partnerCandidates({
    required String token,
    String? query,
  }) async {
    final available = mockCandidates.where((c) {
      final role = c['role']?.toString().toLowerCase();
      final name = c['name']?.toString().trim().toLowerCase();
      final email = c['email']?.toString().trim().toLowerCase();
      return role != 'admin' &&
          name != 'admin' &&
          !(email?.startsWith('admin@') ?? false);
    }).toList();

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      final filtered = available.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['phoneNumber'] ?? '').toString();
        final email = (c['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || email.contains(q);
      }).toList();
      if (filtered.isEmpty) {
        return {
          'count': 0,
          'data': [],
          'message': 'Không tìm thấy người dùng phù hợp',
          'code': 'NO_USER_FOUND',
        };
      }
      return {'count': filtered.length, 'data': filtered};
    }
    return {'count': available.length, 'data': available};
  }

  @override
  Future<Map<String, dynamic>> leaveFund({
    required String token,
    required String fundId,
  }) async {
    final fund = mockFunds.firstWhere(
      (item) => (item['id'] ?? item['_id']) == fundId,
      orElse: () => <String, dynamic>{},
    );
    if (fund.isNotEmpty && fund['members'] is List) {
      (fund['members'] as List).removeWhere((m) {
        final uid = (m['userId'] is Map)
            ? (m['userId']['_id'] ?? m['userId']['id'])
            : m['userId'];
        return uid == '65f0000000000000000000aa';
      });
    }
    return {'message': 'Rời quỹ thành công', 'fundId': fundId};
  }

  @override
  Future<Map<String, dynamic>> fundDetails({
    required String token,
    required String fundId,
  }) async {
    final fund = mockFunds.firstWhere(
      (item) => (item['id'] ?? item['_id']) == fundId,
      orElse: () => {
        'id': fundId,
        'name': 'Quỹ du lịch Phú Quốc',
        'fundType': 'Cá nhân',
        'currentAmount': 0,
        'targetAmount': 10000000,
      },
    );
    final txns = mockFundTransactions
        .where((t) => (t['fundId'] ?? t['metadata']?['fundId']) == fundId)
        .toList();
    return {'fund': fund, 'transactions': txns};
  }

  @override
  Future<Map<String, dynamic>> contributeFund({
    required String token,
    required String fundId,
    required double amount,
    String? note,
  }) async {
    if (shouldNetworkFailContribute) {
      throw ApiException('Không thể thực hiện giao dịch. Vui lòng thử lại sau');
    }
    if (shouldFailContribute) {
      throw ApiException(
        'Góp quỹ không thành công',
        code: 'CONTRIBUTION_FAILED',
        statusCode: 500,
      );
    }
    if (amount <= 0) {
      throw ApiException(
        'Số tiền không hợp lệ',
        code: 'INVALID_AMOUNT',
        statusCode: 400,
      );
    }
    if (amount < 1000) {
      throw ApiException(
        'Tối thiểu 1000đ',
        code: 'MIN_AMOUNT_1000',
        statusCode: 400,
      );
    }
    if (amount > mockWalletBalance) {
      throw ApiException(
        'Số dư ví không đủ để thực hiện giao dịch',
        code: 'INSUFFICIENT_BALANCE',
        statusCode: 400,
      );
    }

    final fundIndex = mockFunds.indexWhere(
      (item) => (item['id'] ?? item['_id']) == fundId,
    );
    Map<String, dynamic> fund;
    if (fundIndex != -1) {
      fund = Map<String, dynamic>.from(mockFunds[fundIndex]);
      final current = (fund['currentAmount'] as num?)?.toDouble() ?? 0;
      fund['currentAmount'] = current + amount;
      mockFunds[fundIndex] = fund;
    } else {
      fund = {
        'id': fundId,
        'name': 'Quỹ du lịch Phú Quốc',
        'fundType': 'Cá nhân',
        'currentAmount': amount,
      };
      mockFunds.add(fund);
    }

    mockWalletBalance -= amount;
    final txn = {
      'id': 'txn_${mockFundTransactions.length + 1}',
      'fundId': fundId,
      'amount': amount,
      'sender': 'admin',
      'recipient': fund['name'],
      'note': note ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    };
    mockFundTransactions.insert(0, txn);

    return {
      'message': 'Góp tiền thành công',
      'fund': fund,
      'walletBalance': mockWalletBalance,
      'transaction': txn,
    };
  }

  List<Map<String, dynamic>> mockSpendingJars = [];

  @override
  Future<Map<String, dynamic>> spendingJars(String token) async => {
    'data': mockSpendingJars,
    'count': mockSpendingJars.length,
  };

  @override
  Future<Map<String, dynamic>> spendingJarDetails({
    required String token,
    required String jarId,
    required int year,
    required int month,
    int page = 1,
  }) async => {
    'jar': mockSpendingJars.firstWhere(
      (jar) => (jar['id'] ?? jar['_id']) == jarId,
      orElse: () => <String, dynamic>{'id': jarId, 'name': 'Hũ kiểm thử'},
    ),
    'count': 1,
    'page': page,
    'pageSize': 10,
    'totalPages': 1,
    'transactions': [
      {
        'type': 'jar_contribution',
        'amount': 100000,
        'balanceAfter': 100000,
        'createdAt': DateTime(year, month, 1).toIso8601String(),
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> createSpendingJar({
    required String token,
    required String name,
    required double amount,
  }) async {
    mockWalletBalance -= amount;
    return {
      'jar': {'name': name, 'balance': amount},
      'walletBalance': mockWalletBalance,
    };
  }

  @override
  Future<Map<String, dynamic>> deposit({
    required String token,
    required double amount,
    required String source,
    required String paymentMethod,
  }) async => {'message': 'Deposit success'};

  @override
  Future<Map<String, dynamic>> demoDeposit({
    required String token,
    required double amount,
    required String source,
  }) async {
    mockWalletBalance += amount;
    return {
      'message': 'Nạp tiền demo thành công',
      'walletBalance': mockWalletBalance,
    };
  }

  @override
  Future<Map<String, dynamic>> mobileTopup({
    required String token,
    required String carrier,
    required String phoneNumber,
    required double amount,
    required String pin,
    String? dataPackage,
  }) async => {'message': 'Topup success'};

  @override
  Future<Map<String, dynamic>> payBill({
    required String token,
    required String billType,
    required String customerCode,
    required double amount,
    required String paymentMethod,
    required String pin,
    String? content,
  }) async => {'message': 'Bill paid'};

  List<Map<String, dynamic>> mockCandidates = [
    {
      'id': 'user_b',
      '_id': 'user_b',
      'name': 'Trần Văn B',
      'phoneNumber': '0912345678',
      'email': 'tranvanb@gmail.com',
      'isMember': false,
      'hasPendingInvite': false,
      'canInvite': true,
    },
    {
      'id': 'user_d',
      '_id': 'user_d',
      'name': 'Lê Văn D',
      'phoneNumber': '0987654321',
      'email': 'levand@gmail.com',
      'isMember': true,
      'hasPendingInvite': false,
      'canInvite': false,
    },
    {
      'id': 'user_e',
      '_id': 'user_e',
      'name': 'Phạm Văn E',
      'phoneNumber': '0911223344',
      'email': 'phamvane@gmail.com',
      'isMember': false,
      'hasPendingInvite': true,
      'canInvite': false,
    },
  ];

  List<Map<String, dynamic>> mockInvitations = [];
  List<Map<String, dynamic>> mockNotificationsList = [];
  bool shouldFailSendInvite = false;

  @override
  Future<Map<String, dynamic>> fundCandidates({
    required String token,
    required String fundId,
    String? query,
  }) async {
    final fund = mockFunds.firstWhere(
      (f) => (f['id'] ?? f['_id']) == fundId,
      orElse: () => {'fundType': 'Hội nhóm'},
    );
    if (fund['fundType'] == 'Cá nhân') {
      throw ApiException(
        'Quỹ cá nhân không thể mời thành viên',
        code: 'PERSONAL_FUND_CANNOT_INVITE',
        statusCode: 400,
      );
    }
    final availableCandidates = mockCandidates.where((c) {
      final role = c['role']?.toString().toLowerCase();
      final name = c['name']?.toString().trim().toLowerCase();
      final email = c['email']?.toString().trim().toLowerCase();
      return role != 'admin' &&
          name != 'admin' &&
          !(email?.startsWith('admin@') ?? false);
    }).toList();

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      final filtered = availableCandidates.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['phoneNumber'] ?? '').toString();
        return name.contains(q) || phone.contains(q);
      }).toList();
      if (filtered.isEmpty) {
        return {
          'count': 0,
          'data': [],
          'message': 'Không tìm thấy người dùng phù hợp',
          'code': 'NO_USER_FOUND',
        };
      }
      return {'count': filtered.length, 'data': filtered};
    }
    return {'count': availableCandidates.length, 'data': availableCandidates};
  }

  @override
  Future<Map<String, dynamic>> sendFundInvite({
    required String token,
    required String fundId,
    String? inviteeId,
    String? phoneNumber,
    String? name,
  }) async {
    if (shouldFailSendInvite) {
      throw ApiException(
        'Gửi lời mời không thành công',
        code: 'INVITE_FAILED',
        statusCode: 500,
      );
    }
    final candidate = mockCandidates.firstWhere(
      (c) =>
          c['id'] == inviteeId ||
          c['_id'] == inviteeId ||
          c['phoneNumber'] == phoneNumber,
      orElse: () => throw ApiException(
        'Người dùng chưa đăng ký tài khoản ví điện tử hoặc không tồn tại',
        code: 'USER_NOT_FOUND',
        statusCode: 400,
      ),
    );
    if (candidate['isMember'] == true) {
      throw ApiException(
        'Người dùng đã là thành viên của quỹ',
        code: 'ALREADY_MEMBER',
        statusCode: 400,
      );
    }
    if (candidate['hasPendingInvite'] == true) {
      throw ApiException(
        'Người dùng đã có lời mời tham gia quỹ',
        code: 'PENDING_INVITATION_EXISTS',
        statusCode: 400,
      );
    }

    candidate['hasPendingInvite'] = true;
    candidate['canInvite'] = false;

    final invite = {
      'id': 'inv_${mockInvitations.length + 1}',
      '_id': 'inv_${mockInvitations.length + 1}',
      'fundId': fundId,
      'fundName': 'Quỹ Test Hội Nhóm',
      'fundType': 'Hội nhóm',
      'inviterId': 'admin_id',
      'inviterName': 'admin',
      'inviteeId': candidate['id'],
      'inviteeName': candidate['name'],
      'inviteePhone': candidate['phoneNumber'],
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    };
    mockInvitations.insert(0, invite);

    mockNotificationsList.insert(0, {
      'id': 'notif_${mockNotificationsList.length + 1}',
      '_id': 'notif_${mockNotificationsList.length + 1}',
      'title': 'Lời mời tham gia quỹ',
      'message': 'admin đã mời bạn tham gia quỹ "Quỹ Test Hội Nhóm"',
      'type': 'fund_invitation',
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
      'metadata': {'invitationId': invite['id'], 'fundId': fundId},
    });

    return {'message': 'Gửi lời mời thành công', 'data': invite};
  }

  @override
  Future<Map<String, dynamic>> myInvitations({
    required String token,
    String? status,
  }) async {
    var list = mockInvitations;
    if (status != null && status.isNotEmpty) {
      list = list.where((i) => i['status'] == status).toList();
    }
    return {'count': list.length, 'data': list};
  }

  @override
  Future<Map<String, dynamic>> acceptInvitation({
    required String token,
    required String invitationId,
  }) async {
    final inv = mockInvitations.firstWhere(
      (i) => i['id'] == invitationId || i['_id'] == invitationId,
      orElse: () => throw ApiException('Lời mời không tồn tại'),
    );
    inv['status'] = 'accepted';
    return {'message': 'Tham gia quỹ thành công', 'data': inv};
  }

  @override
  Future<Map<String, dynamic>> rejectInvitation({
    required String token,
    required String invitationId,
  }) async {
    final inv = mockInvitations.firstWhere(
      (i) => i['id'] == invitationId || i['_id'] == invitationId,
      orElse: () => throw ApiException('Lời mời không tồn tại'),
    );
    inv['status'] = 'rejected';
    return {'message': 'Đã từ chối lời mời', 'data': inv};
  }

  @override
  Future<Map<String, dynamic>> notifications(String token) async {
    final unread = mockNotificationsList
        .where((n) => n['isRead'] != true)
        .length;
    return {
      'count': mockNotificationsList.length,
      'unreadCount': unread,
      'data': mockNotificationsList,
    };
  }

  @override
  Future<Map<String, dynamic>> markNotificationRead({
    required String token,
    required String notificationId,
  }) async {
    final n = mockNotificationsList.firstWhere(
      (item) => item['id'] == notificationId || item['_id'] == notificationId,
      orElse: () => throw ApiException('Thông báo không tồn tại'),
    );
    n['isRead'] = true;
    final unread = mockNotificationsList
        .where((item) => item['isRead'] != true)
        .length;
    return {'message': 'Đã đánh dấu đã đọc', 'unreadCount': unread};
  }

  @override
  Future<Map<String, dynamic>> markAllNotificationsRead(String token) async {
    for (var n in mockNotificationsList) {
      n['isRead'] = true;
    }
    return {'message': 'Đã đánh dấu tất cả đã đọc', 'unreadCount': 0};
  }

  List<Map<String, dynamic>> mockAdminUsers = [
    {
      'id': 'u1',
      '_id': 'u1',
      'name': 'Administrator',
      'email': 'admin@gmail.com',
      'phoneNumber': '0901234567',
      'password': '123456',
      'role': 'admin',
      'walletBalance': 5000000,
      'createdAt': '2026-03-01T00:00:00.000Z',
    },
    {
      'id': 'u2',
      '_id': 'u2',
      'name': 'Nguyễn Văn A',
      'email': 'nguyenvana@gmail.com',
      'phoneNumber': '0912345678',
      'password': '123456',
      'role': 'user',
      'walletBalance': 1500000,
      'createdAt': '2026-03-05T00:00:00.000Z',
    },
    {
      'id': 'u3',
      '_id': 'u3',
      'name': 'Trần Thị B',
      'email': 'tranthib@gmail.com',
      'phoneNumber': '0987654321',
      'password': '123456',
      'role': 'user',
      'walletBalance': 850000,
      'createdAt': '2026-03-10T00:00:00.000Z',
    },
  ];

  @override
  Future<Map<String, dynamic>> adminUsers(
    String token, {
    String? search,
  }) async {
    var users = List<Map<String, dynamic>>.from(mockAdminUsers);
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      users = users.where((u) {
        final name = (u['name'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final phone = (u['phoneNumber'] ?? '').toString().toLowerCase();
        final role = (u['role'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            email.contains(q) ||
            phone.contains(q) ||
            role.contains(q);
      }).toList();
    }
    final adminCount = users.where((u) => u['role'] == 'admin').length;
    final userCount = users.where((u) => u['role'] == 'user').length;
    return {
      'count': users.length,
      'total': users.length,
      'data': users,
      'users': users,
      'stats': {
        'total': users.length,
        'admins': adminCount,
        'users': userCount,
      },
    };
  }

  AuthResult _result(String account) => AuthResult(
    token: 'fake-jwt-token-for-$account',
    user: AuthUser(
      id: '65f0000000000000000000aa',
      name: account,
      email: '$account@gmail.com',
      walletBalance: 1000000,
      role: account.toLowerCase() == 'admin' ? 'admin' : 'user',
    ),
  );
}

Widget buildApp({FakeAuthService? service}) => MyApp(
  session: AppSession(
    authService: service ?? FakeAuthService(acceptedPassword: '123456'),
  ),
);

/// Cuộn tới nút trước khi bấm (nút có thể nằm ngoài khung nhìn 800x600 của test).
Future<void> tapButton(WidgetTester tester, String text) async {
  final button = find.widgetWithText(AppButton, text);
  await tester.ensureVisible(button);
  await tester.tap(button);
}

void main() {
  testWidgets('Đăng nhập thành công sẽ vào màn hình chính', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets); // tiêu đề + nút
    expect(find.widgetWithText(AppButton, 'Đăng ký'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tapButton(tester, 'Đăng nhập');
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Xin chào, admin'), findsOneWidget);
  });

  testWidgets(
    'Sai mật khẩu thì hiện thông báo lỗi và ở lại màn hình đăng nhập',
    (tester) async {
      await tester.pumpWidget(buildApp());

      await tester.enterText(find.byType(TextFormField).at(0), 'admin');
      await tester.enterText(find.byType(TextFormField).at(1), 'sai-mat-khau');
      await tapButton(tester, 'Đăng nhập');
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Tài khoản hoặc mật khẩu không đúng'), findsOneWidget);
    },
  );

  testWidgets(
    'Đăng ký: nhãn Trở về ở bên trái và quay lại màn hình đăng nhập',
    (tester) async {
      await tester.pumpWidget(buildApp());

      await tapButton(tester, 'Đăng ký');
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Xác thực mật khẩu'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Xác nhận đăng ký'),
        findsOneWidget,
      );

      // Nút "Trở về" đã thay bằng label nằm bên trái.
      final backLabel = find.byType(BackLabel);
      expect(backLabel, findsOneWidget);
      final screenWidth = tester.getSize(find.byType(RegisterScreen)).width;
      expect(tester.getTopLeft(backLabel).dx, lessThan(screenWidth / 3));

      await tester.tap(find.text('Trở về'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(RegisterScreen), findsNothing);
    },
  );

  testWidgets('Đăng ký thành công sẽ quay lại màn hình đăng nhập', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tapButton(tester, 'Đăng ký');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'nguyenvana');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tapButton(tester, 'Xác nhận đăng ký');
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('Đăng ký thành công'), findsOneWidget);

    // Tài khoản vừa tạo được điền sẵn, mật khẩu để trống, chưa tự đăng nhập.
    final accountField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(0),
    );
    final passwordField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(accountField.controller!.text, 'nguyenvana');
    expect(passwordField.controller!.text, isEmpty);
    final session = AppScope.of(tester.element(find.byType(LoginScreen)));
    expect(session.isLoggedIn, isFalse);
  });

  testWidgets('Đăng ký: tài khoản quá dài bị chặn ở client', (tester) async {
    await tester.pumpWidget(buildApp());
    await tapButton(tester, 'Đăng ký');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'a' * (kMaxAccountLength + 1),
    );
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tapButton(tester, 'Xác nhận đăng ký');
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(
      find.text('Tài khoản tối đa $kMaxAccountLength ký tự'),
      findsOneWidget,
    );
  });

  testWidgets('Tài khoản đã tồn tại sẽ hiện lỗi từ server', (tester) async {
    await tester.pumpWidget(buildApp());
    await tapButton(tester, 'Đăng ký');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tapButton(tester, 'Xác nhận đăng ký');
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Tài khoản đã tồn tại'), findsOneWidget);
  });

  testWidgets(
    'Trang chủ có nút Trang cá nhân hình vuông tròn ở góc trên bên phải',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await _login(tester, account: 'admin', password: '123456');

      expect(find.byType(HomeScreen), findsOneWidget);

      final profileBtn = find.byTooltip('Trang cá nhân');
      expect(profileBtn, findsOneWidget);

      final screenWidth = tester.getSize(find.byType(HomeScreen)).width;
      expect(tester.getTopRight(profileBtn).dx, closeTo(screenWidth - 18, 1.5));
    },
  );

  testWidgets('Đăng xuất từ Trang cá nhân quay về màn hình đăng nhập', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    // Mở Trang cá nhân từ góc trên bên phải
    await tester.tap(find.byTooltip('Trang cá nhân'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Cuộn tới nút Đăng xuất tài khoản và bấm
    final logoutBtn = find.widgetWithText(AppButton, 'Đăng xuất tài khoản');
    await tester.ensureVisible(logoutBtn);
    await tester.pumpAndSettle();
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();

    // Xác nhận trên AlertDialog
    final confirmBtn = find.widgetWithText(TextButton, 'Đăng xuất');
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Mở màn hình đổi mật khẩu từ Trang cá nhân', (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    // Mở Trang cá nhân -> Đổi mật khẩu
    await tester.tap(find.byTooltip('Trang cá nhân'));
    await tester.pumpAndSettle();

    final changePwdMenu = find.text('Đổi mật khẩu');
    await tester.ensureVisible(changePwdMenu);
    await tester.pumpAndSettle();
    await tester.tap(changePwdMenu);
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.text('Mật khẩu cũ'), findsOneWidget);
    expect(find.text('Mật khẩu mới'), findsOneWidget);
    expect(find.text('Xác thực mật khẩu'), findsOneWidget);

    // Nhãn trở lại đưa về Trang cá nhân
    await tester.tap(find.text('Trở về'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('Đổi mật khẩu: sai mật khẩu cũ sẽ hiện lỗi của server', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    await tester.tap(find.byTooltip('Trang cá nhân'));
    await tester.pumpAndSettle();
    final changePwdMenu = find.text('Đổi mật khẩu');
    await tester.ensureVisible(changePwdMenu);
    await tester.pumpAndSettle();
    await tester.tap(changePwdMenu);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'khong-dung');
    await tester.enterText(find.byType(TextFormField).at(1), 'matkhau moi');
    await tester.enterText(find.byType(TextFormField).at(2), 'matkhau moi');
    await tapButton(tester, 'Xác nhận đổi mật khẩu');
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.text('Mật khẩu cũ không đúng'), findsOneWidget);
  });

  testWidgets('Đổi mật khẩu: mật khẩu mới khác xác thực sẽ bị chặn', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    await tester.tap(find.byTooltip('Trang cá nhân'));
    await tester.pumpAndSettle();
    final changePwdMenu = find.text('Đổi mật khẩu');
    await tester.ensureVisible(changePwdMenu);
    await tester.pumpAndSettle();
    await tester.tap(changePwdMenu);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'mat-khau-cu');
    await tester.enterText(find.byType(TextFormField).at(1), 'matkhaumoi');
    await tester.enterText(find.byType(TextFormField).at(2), 'matkhaumoi2');
    await tapButton(tester, 'Xác nhận đổi mật khẩu');
    await tester.pumpAndSettle();

    expect(find.text('Xác thực mật khẩu không khớp'), findsOneWidget);
  });

  testWidgets('Đổi mật khẩu thành công sẽ quay về trang cá nhân', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    await tester.tap(find.byTooltip('Trang cá nhân'));
    await tester.pumpAndSettle();
    final changePwdMenu = find.text('Đổi mật khẩu');
    await tester.ensureVisible(changePwdMenu);
    await tester.pumpAndSettle();
    await tester.tap(changePwdMenu);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'mat-khau-cu');
    await tester.enterText(find.byType(TextFormField).at(1), 'matkhau moi');
    await tester.enterText(find.byType(TextFormField).at(2), 'matkhau moi');
    await tapButton(tester, 'Xác nhận đổi mật khẩu');
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.textContaining('Đổi mật khẩu thành công'), findsOneWidget);
  });

  testWidgets(
    'Giao diện hiển thị chuẩn xác trên kích thước màn hình iPhone 18',
    (tester) async {
      tester.view.physicalSize = const Size(kIPhone18Width, kIPhone18Height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildApp());
      expect(find.byType(LoginScreen), findsOneWidget);

      await _login(tester, account: 'admin', password: '123456');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Ví điện tử DTY'), findsOneWidget);
      expect(find.text('1.000.000 đ'), findsOneWidget);

      // Kiểm tra nút Trang cá nhân ở góc trên bên phải
      final profileBtn = find.byTooltip('Trang cá nhân');
      expect(profileBtn, findsOneWidget);
    },
  );

  testWidgets(
    'Trang chủ: có đủ 6 nút tính năng và bấm nút Trang cá nhân mở ProfileScreen',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await _login(tester, account: 'admin', password: '123456');

      expect(find.byType(HomeScreen), findsOneWidget);

      // Kiểm tra đủ 6 tính năng (không có dấu + ở đầu)
      expect(find.text('Nạp ví'), findsOneWidget);
      expect(find.text('Nạp đt/data'), findsOneWidget);
      expect(find.text('L.sử giao dịch'), findsOneWidget);
      expect(find.text('Thanh toán hđ'), findsOneWidget);
      expect(find.text('Quỹ'), findsOneWidget);
      expect(find.text('Hũ chi tiêu'), findsOneWidget);

      // Bấm nút Trang cá nhân trên cùng bên phải
      final profileBtn = find.byTooltip('Trang cá nhân');
      expect(profileBtn, findsOneWidget);
      await tester.tap(profileBtn);
      await tester.pumpAndSettle();

      // Xác nhận đã vào màn hình ProfileScreen
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Trang chủ'), findsOneWidget); // Nút BackLabel
      expect(find.text('Mã PIN giao dịch'), findsOneWidget);
      expect(find.text('Đổi mật khẩu'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Đăng xuất tài khoản'),
        findsOneWidget,
      );

      // Bấm quay lại Trang chủ
      await tester.tap(find.text('Trang chủ'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  test(
    'Định dạng tiền tệ formatVnd: 0 thành 0 đ và 1000000 thành 1.000.000 đ',
    () {
      expect(formatVnd(0), '0 đ');
      expect(formatVnd(1000000), '1.000.000 đ');
      expect(formatVnd(50000), '50.000 đ');
      expect(formatVnd(null), '0 đ');
    },
  );

  testWidgets('Trang chủ: Nút ẩn/hiện số dư nổi bật và hoạt động chính xác', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    expect(find.byType(HomeScreen), findsOneWidget);
    // Ban đầu hiển thị số dư và nút "Ẩn"
    expect(find.text('1.000.000 đ'), findsOneWidget);
    expect(find.text('Ẩn'), findsOneWidget);

    // Bấm nút Ẩn
    await tester.tap(find.text('Ẩn'));
    await tester.pumpAndSettle();

    // Số dư bị che và nút chuyển thành "Hiện"
    expect(find.text('•••••••• đ'), findsOneWidget);
    expect(find.text('Hiện'), findsOneWidget);

    // Bấm nút Hiện
    await tester.tap(find.text('Hiện'));
    await tester.pumpAndSettle();

    // Số dư hiện lại
    expect(find.text('1.000.000 đ'), findsOneWidget);
    expect(find.text('Ẩn'), findsOneWidget);
  });

  testWidgets('Trang chủ: Nút Nạp ví mở màn hình nạp riêng', (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    expect(find.byType(HomeScreen), findsOneWidget);
    final depositBtn = find.text('Nạp ví');
    expect(depositBtn, findsOneWidget);
    expect(find.text('Nạp tiền'), findsNothing);

    await tester.tap(depositBtn);
    await tester.pumpAndSettle();

    expect(find.byType(DepositWalletScreen), findsOneWidget);
    expect(find.text('Nạp ví'), findsNWidgets(2));
    expect(find.text('Nạp tiền vào ví'), findsNothing);
    expect(find.text('Nạp tiền demo'), findsNothing);
  });

  testWidgets('Nạp ví cập nhật số dư và trở về trang chủ', (tester) async {
    final service = FakeAuthService(acceptedPassword: '123456');
    await tester.pumpWidget(buildApp(service: service));
    await _login(tester, account: 'admin', password: '123456');

    await tester.tap(find.text('Nạp ví'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chế độ demo'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Nạp ví'));
    await tester.pumpAndSettle();

    expect(service.mockWalletBalance, 1100000);
    expect(find.text('1.100.000 đ'), findsOneWidget);
    expect(find.text('Nạp ví thành công!'), findsOneWidget);
  });

  testWidgets(
    'Trang chủ: Phần Ưu đãi & Khuyến mãi có 2 phần tử mới tương tác mở Quỹ và Hũ chi tiêu',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await _login(tester, account: 'admin', password: '123456');

      expect(find.byType(HomeScreen), findsOneWidget);

      // Kiểm tra hiển thị phần tử 1: Quỹ tiết kiệm
      final fundPromo = find.text('Lập quỹ tiết kiệm cho bản thân và gia đình');
      await tester.ensureVisible(fundPromo);
      expect(fundPromo, findsOneWidget);
      expect(
        find.text('Tạo quỹ cá nhân, cặp đôi, tích luỹ, ...'),
        findsOneWidget,
      );

      // Kiểm tra hiển thị phần tử 2: Chi tiêu tháng theo thời gian thực và thời gian cập nhật
      final currentMonth = DateTime.now().month;
      final spendingPromo = find.text('Chi tiêu tháng $currentMonth');
      expect(spendingPromo, findsOneWidget);
      expect(find.textContaining('Cập nhật lúc'), findsOneWidget);

      // Bấm vào phần tử Quỹ -> Mở Quỹ tiết kiệm & Đầu tư sheet
      await tester.tap(fundPromo);
      await tester.pumpAndSettle();
      expect(find.text('Quỹ tiết kiệm & Đầu tư'), findsOneWidget);

      // Đóng sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Bấm vào phần tử Chi tiêu tháng -> Mở Hũ chi tiêu sheet
      await tester.tap(spendingPromo);
      await tester.pumpAndSettle();
      expect(find.text('Hũ chi tiêu').last, findsOneWidget);
    },
  );

  testWidgets(
    'Hũ chi tiêu: mở chi tiết và hiển thị giao dịch/số dư sau giao dịch',
    (tester) async {
      final service = FakeAuthService(acceptedPassword: '123456')
        ..mockSpendingJars = [
          {'id': 'jar_1', 'name': 'Ăn uống', 'balance': 100000},
        ];
      await tester.pumpWidget(buildApp(service: service));
      await _login(tester, account: 'admin', password: '123456');

      await tester.tap(find.text('Hũ chi tiêu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống'));
      await tester.pumpAndSettle();

      expect(find.text('Cấp tiền vào hũ'), findsOneWidget);
      expect(find.text('Số dư sau giao dịch'), findsOneWidget);
      expect(find.text('100.000 đ'), findsOneWidget);
    },
  );

  group('Use Case 04: Thêm quỹ', () {
    testWidgets(
      'Từ Trang chủ mở Quỹ và bấm Tạo quỹ sẽ hiển thị giao diện Tạo quỹ',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await _login(tester, account: 'admin', password: '123456');

        final fundPromo = find.text(
          'Lập quỹ tiết kiệm cho bản thân và gia đình',
        );
        await tester.ensureVisible(fundPromo);
        await tester.tap(fundPromo);
        await tester.pumpAndSettle();

        expect(find.text('Quỹ tiết kiệm & Đầu tư'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Tạo quỹ'), findsOneWidget);

        await tester.tap(find.widgetWithText(AppButton, 'Tạo quỹ'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateFundScreen), findsOneWidget);
        expect(find.text('Tạo quỹ'), findsWidgets);
        expect(find.text('Cá nhân'), findsOneWidget);
        expect(find.text('Cặp đôi'), findsOneWidget);
        expect(find.text('Tích lũy'), findsOneWidget);
        expect(find.text('Hội nhóm'), findsOneWidget);
      },
    );

    testWidgets(
      'E1: Người dùng đã làm chủ từ 10 quỹ trở lên hiển thị "Không thể tạo thêm quỹ"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockFunds = List.generate(
          10,
          (i) => {'name': 'Quỹ $i', 'fundType': 'Cá nhân', 'targetAmount': 0},
        );

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(
              home: CreateFundScreen(initialFundCount: 10),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Không thể tạo thêm quỹ'), findsOneWidget);
      },
    );

    testWidgets(
      'E2 & E8: Chưa chọn loại quỹ bấm Tạo quỹ báo "Vui lòng chọn loại quỹ" và "Vui lòng nhập đầy đủ thông tin"',
      (tester) async {
        final session = AppSession(
          authService: FakeAuthService(acceptedPassword: '123456'),
        );
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(
              home: CreateFundScreen(initialFundCount: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tapButton(tester, 'Tạo quỹ');
        await tester.pumpAndSettle();

        expect(find.text('Vui lòng chọn loại quỹ'), findsOneWidget);
        expect(find.text('Vui lòng nhập đầy đủ thông tin'), findsOneWidget);
      },
    );

    testWidgets(
      'E3: Chọn loại quỹ nhưng để trống tên quỹ báo "Vui lòng nhập tên quỹ"',
      (tester) async {
        final session = AppSession(
          authService: FakeAuthService(acceptedPassword: '123456'),
        );
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(
              home: CreateFundScreen(initialFundCount: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Chọn loại Cá nhân
        await tester.tap(find.text('Cá nhân'));
        await tester.pumpAndSettle();

        // Trường Tên quỹ xuất hiện
        expect(find.text('Tên quỹ *'), findsOneWidget);

        await tapButton(tester, 'Tạo quỹ');
        await tester.pumpAndSettle();

        expect(find.text('Vui lòng nhập tên quỹ'), findsOneWidget);
        expect(find.text('Vui lòng nhập đầy đủ thông tin'), findsOneWidget);
      },
    );

    testWidgets(
      'E4: Tên quỹ tối đa 60 ký tự và không cho nhập vượt quá 60 ký tự',
      (tester) async {
        final session = AppSession(
          authService: FakeAuthService(acceptedPassword: '123456'),
        );
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(
              home: CreateFundScreen(initialFundCount: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cá nhân'));
        await tester.pumpAndSettle();

        final nameField = find.byType(TextFormField).first;
        // Nhập chuỗi 70 ký tự
        await tester.enterText(nameField, 'A' * 70);
        await tester.pumpAndSettle();

        final controller = tester.widget<TextFormField>(nameField).controller!;
        expect(controller.text.length, equals(60));
      },
    );

    testWidgets(
      'E5, E6, E7: Quỹ Tích lũy kiểm tra số tiền mục tiêu và ngày hoàn thành',
      (tester) async {
        final session = AppSession(
          authService: FakeAuthService(acceptedPassword: '123456'),
        );
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(
              home: CreateFundScreen(initialFundCount: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Chọn loại Tích lũy
        await tester.tap(find.text('Tích lũy'));
        await tester.pumpAndSettle();

        // Hiển thị cả 3 trường: Tên quỹ, Số tiền mục tiêu, Ngày hoàn thành
        expect(find.text('Tên quỹ *'), findsOneWidget);
        expect(find.text('Số tiền mục tiêu *'), findsOneWidget);
        expect(find.text('Ngày hoàn thành mục tiêu *'), findsOneWidget);

        // Nhập tên quỹ hợp lệ
        await tester.enterText(find.byType(TextFormField).at(0), 'Quỹ mua nhà');

        // Bấm Tạo quỹ khi chưa nhập tiền và chưa chọn ngày
        await tapButton(tester, 'Tạo quỹ');
        await tester.pumpAndSettle();

        expect(find.text('Vui lòng nhập số tiền mục tiêu'), findsOneWidget);
        expect(
          find.text('Vui lòng chọn ngày hoàn thành mục tiêu'),
          findsOneWidget,
        );
        expect(find.text('Vui lòng nhập đầy đủ thông tin'), findsOneWidget);

        // Nhập số tiền = 0 hoặc âm -> E6: Số tiền mục tiêu phải lớn hơn 0
        await tester.enterText(find.byType(TextFormField).at(1), '0');
        await tapButton(tester, 'Tạo quỹ');
        await tester.pumpAndSettle();

        expect(find.text('Số tiền mục tiêu phải lớn hơn 0'), findsOneWidget);
      },
    );

    testWidgets(
      'Luồng thành công 3.1: Tạo quỹ Cá nhân thành công thông báo "Tạo quỹ thành công"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(
              home: CreateFundScreen(initialFundCount: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Chọn loại Cá nhân
        await tester.tap(find.text('Cá nhân'));
        await tester.pumpAndSettle();

        // Nhập tên quỹ
        await tester.enterText(
          find.byType(TextFormField).first,
          'Quỹ cá nhân của tôi',
        );
        await tapButton(tester, 'Tạo quỹ');
        await tester.pumpAndSettle();

        expect(find.text('Tạo quỹ thành công'), findsOneWidget);
        expect(fakeService.mockFunds.length, equals(1));
        expect(
          fakeService.mockFunds.first['name'],
          equals('Quỹ cá nhân của tôi'),
        );
        expect(fakeService.mockFunds.first['fundType'], equals('Cá nhân'));
      },
    );

    testWidgets(
      'Luồng thành công 3.3: Tạo quỹ Tích lũy thành công với số tiền và ngày hoàn thành',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(
              home: CreateFundScreen(initialFundCount: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Chọn loại Tích lũy
        await tester.tap(find.text('Tích lũy'));
        await tester.pumpAndSettle();

        // Nhập tên quỹ
        await tester.enterText(find.byType(TextFormField).at(0), 'Quỹ mua xe');

        // Nhập số tiền mục tiêu hợp lệ (> 0)
        await tester.enterText(find.byType(TextFormField).at(1), '50000000');
        await tester.pumpAndSettle();

        // Chọn ngày hoàn thành mục tiêu
        final datePickerFinder = find.text('Chọn ngày hoàn thành mục tiêu');
        await tester.ensureVisible(datePickerFinder);
        await tester.tap(datePickerFinder);
        await tester.pumpAndSettle();
        // Bấm OK trên DatePicker
        final okBtn = find.text('OK');
        await tester.tap(okBtn);
        await tester.pumpAndSettle();

        // Bấm Tạo quỹ
        await tapButton(tester, 'Tạo quỹ');
        await tester.pumpAndSettle();

        expect(find.text('Tạo quỹ thành công'), findsOneWidget);
        expect(fakeService.mockFunds.length, equals(1));
        expect(fakeService.mockFunds.first['name'], equals('Quỹ mua xe'));
        expect(fakeService.mockFunds.first['fundType'], equals('Tích lũy'));
        expect(fakeService.mockFunds.first['targetAmount'], equals(50000000));
      },
    );

    testWidgets(
      'Giao diện Quỹ là màn hình riêng biệt FundsScreen khi bấm nút Quỹ ở Trang chủ',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await _login(tester, account: 'admin', password: '123456');

        final fundButton = find.text('Quỹ');
        await tester.ensureVisible(fundButton);
        await tester.tap(fundButton);
        await tester.pumpAndSettle();

        // Xác nhận đang ở màn hình riêng biệt FundsScreen (không phải ModalBottomSheet)
        expect(find.byType(FundsScreen), findsOneWidget);
        expect(find.text('Quỹ tiết kiệm & Đầu tư'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Tạo quỹ'), findsOneWidget);
        expect(find.text('Trang chủ'), findsOneWidget);

        // Quay lại Trang chủ
        await tester.tap(find.text('Trang chủ'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Giao diện danh sách quỹ: không hiển thị nút xoá quỹ trực tiếp; việc xoá quỹ được thực hiện trong màn hình Chi tiết quỹ',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockFunds = [
          {
            'id': 'fund_1',
            '_id': 'fund_1',
            'name': 'Quỹ du lịch Phú Quốc',
            'fundType': 'Cá nhân',
            'userId': '65f0000000000000000000aa',
            'targetAmount': 10000000,
          },
        ];

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: FundsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra quỹ hiển thị trong danh sách
        expect(find.text('Quỹ du lịch Phú Quốc'), findsOneWidget);

        // Nút Xoá quỹ KHÔNG CÒN hiển thị trực tiếp ở danh sách quỹ
        expect(find.byTooltip('Xoá quỹ'), findsNothing);
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

        // Bấm vào quỹ để mở Chi tiết quỹ (FundDetailScreen)
        await tester.tap(find.text('Quỹ du lịch Phú Quốc'));
        await tester.pumpAndSettle();

        expect(find.byType(FundDetailScreen), findsOneWidget);

        // Trong Chi tiết quỹ, chủ quỹ có nút "Xoá quỹ này"
        final deleteBtn = find.byKey(const ValueKey('delete_fund_button'));
        expect(deleteBtn, findsOneWidget);

        // Bấm Xoá -> hiện hộp thoại xác nhận -> bấm xác nhận "Xoá quỹ"
        await tester.ensureVisible(deleteBtn);
        await tester.pumpAndSettle();
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(find.text('Xác nhận xoá quỹ'), findsOneWidget);
        final confirmDeleteBtn = find.widgetWithText(ElevatedButton, 'Xoá quỹ');
        await tester.tap(confirmDeleteBtn);
        await tester.pumpAndSettle();

        // Quay lại màn hình danh sách quỹ và quỹ đã bị xoá
        expect(find.byType(FundsScreen), findsOneWidget);
        expect(fakeService.mockFunds.isEmpty, isTrue);
        expect(find.text('Chưa có quỹ nào được tạo'), findsOneWidget);
      },
    );
  });

  group('Chức năng Xem chi tiết quỹ & Góp tiền vào quỹ (Use Case 05)', () {
    testWidgets(
      'Xem chi tiết quỹ: từ FundsScreen bấm vào quỹ sẽ mở giao diện riêng FundDetailScreen với đầy đủ thông tin',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockFunds = [
          {
            'id': 'fund_dl',
            'name': 'Quỹ du lịch Đà Lạt',
            'fundType': 'Tích lũy',
            'currentAmount': 2000000,
            'targetAmount': 10000000,
            'completionDate': '2026-12-31T00:00:00.000Z',
          },
        ];

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: FundsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Bấm vào quỹ trong danh sách
        await tester.tap(find.text('Quỹ du lịch Đà Lạt'));
        await tester.pumpAndSettle();

        // Màn hình chi tiết quỹ riêng biệt được hiển thị
        expect(find.byType(FundDetailScreen), findsOneWidget);
        expect(find.text('Chi tiết quỹ'), findsOneWidget);
        expect(find.text('Quỹ du lịch Đà Lạt'), findsOneWidget);
        expect(find.text('Tích lũy'), findsOneWidget);
        expect(find.text('2.000.000 đ'), findsOneWidget);
        expect(find.text('Mục tiêu: 10.000.000 đ'), findsOneWidget);
        expect(find.text('20.0%'), findsOneWidget);
        expect(find.text('Còn thiếu: 8.000.000 đ'), findsOneWidget);
        expect(find.text('Lịch sử giao dịch'), findsOneWidget);

        // Nút + Góp quỹ hiển thị
        expect(find.widgetWithText(AppButton, '+ Góp quỹ'), findsOneWidget);

        // Bấm + Góp quỹ mở giao diện Góp quỹ
        await tapButton(tester, '+ Góp quỹ');
        await tester.pumpAndSettle();

        expect(find.byType(ContributeFundScreen), findsOneWidget);
        expect(find.text('Góp tiền vào quỹ'), findsOneWidget);
      },
    );

    testWidgets(
      'Use Case 05: E1: Để trống số tiền góp hiển thị "Vui lòng nhập số tiền muốn góp"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = {
          'id': 'fund_1',
          'name': 'Quỹ du lịch',
          'fundType': 'Cá nhân',
          'currentAmount': 100000,
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: ContributeFundScreen(
                fund: fund,
                initialWalletBalance: 1000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Bấm Chuyển tiền khi chưa nhập số tiền
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        expect(find.text('Vui lòng nhập số tiền muốn góp'), findsOneWidget);
      },
    );

    testWidgets(
      'Use Case 05: E2 & Giá trị biên: Nhập 999đ (< 1.000đ) hiển thị "Tối thiểu 1000đ"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = {
          'id': 'fund_1',
          'name': 'Quỹ du lịch',
          'fundType': 'Cá nhân',
          'currentAmount': 100000,
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: ContributeFundScreen(
                fund: fund,
                initialWalletBalance: 1000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nhập 999 (biên không hợp lệ)
        await tester.enterText(find.byType(TextFormField).first, '999');
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        expect(find.text('Tối thiểu 1000đ'), findsOneWidget);
      },
    );

    testWidgets(
      'Use Case 05: E3: Nhập số tiền không phải là số hoặc chứa ký tự không hợp lệ hiển thị "Số tiền không hợp lệ"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = {
          'id': 'fund_1',
          'name': 'Quỹ du lịch',
          'fundType': 'Cá nhân',
          'currentAmount': 100000,
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: ContributeFundScreen(
                fund: fund,
                initialWalletBalance: 1000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nhập "abc"
        await tester.enterText(find.byType(TextFormField).first, 'abc');
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        expect(find.text('Số tiền không hợp lệ'), findsOneWidget);

        // Nhập "10abc"
        await tester.enterText(find.byType(TextFormField).first, '10abc');
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        expect(find.text('Số tiền không hợp lệ'), findsOneWidget);
      },
    );

    testWidgets(
      'Use Case 05: E4 & Giá trị biên: Nhập lớn hơn số dư khả dụng (1.000.001đ khi số dư 1.000.000đ) hiển thị "Số dư ví không đủ để thực hiện giao dịch"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = {
          'id': 'fund_1',
          'name': 'Quỹ du lịch',
          'fundType': 'Cá nhân',
          'currentAmount': 100000,
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: ContributeFundScreen(
                fund: fund,
                initialWalletBalance: 1000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Số dư là 1.000.000đ, nhập số dư + 1đ = 1.000.001đ
        await tester.enterText(find.byType(TextFormField).first, '1000001');
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        expect(
          find.text('Số dư ví không đủ để thực hiện giao dịch'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Use Case 05: E5: Nhập ghi chú quá 200 từ hiển thị "Tối đa 200 từ"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = {
          'id': 'fund_1',
          'name': 'Quỹ du lịch',
          'fundType': 'Cá nhân',
          'currentAmount': 100000,
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: ContributeFundScreen(
                fund: fund,
                initialWalletBalance: 1000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '50000');

        // Nhập 201 từ vào ô ghi chú
        final longNote = List.generate(201, (i) => 'tu$i').join(' ');
        await tester.enterText(find.byType(TextFormField).at(1), longNote);
        await tester.pumpAndSettle();

        expect(find.text('Tối đa 200 từ'), findsOneWidget);
        expect(find.text('201/200 từ'), findsOneWidget);

        // Bấm Chuyển tiền không mở dialog xác nhận
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        expect(find.text('Xác nhận chuyển tiền'), findsNothing);
      },
    );

    testWidgets(
      'Use Case 05: 6.1: Người dùng không xác nhận chuyển tiền (chọn Huỷ giao dịch) thì hệ thống huỷ giao dịch và quay lại giao diện Góp quỹ',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = {
          'id': 'fund_1',
          'name': 'Quỹ du lịch',
          'fundType': 'Cá nhân',
          'currentAmount': 100000,
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: ContributeFundScreen(
                fund: fund,
                initialWalletBalance: 1000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nhập số tiền hợp lệ
        await tester.enterText(find.byType(TextFormField).first, '50000');
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        // Kiểm tra giao diện Chuyển tiền xuất hiện
        expect(find.text('Chuyển tiền'), findsWidgets);
        expect(find.text('Xác nhận chuyển tiền'), findsOneWidget);
        expect(find.text('50.000 đ'), findsWidgets);
        expect(find.text('Huỷ giao dịch'), findsOneWidget);

        // Bấm Huỷ giao dịch (6.1)
        await tester.tap(find.text('Huỷ giao dịch'));
        await tester.pumpAndSettle();

        // Quay lại giao diện Góp quỹ, số dư không đổi
        expect(find.text('Xác nhận chuyển tiền'), findsNothing);
        expect(fakeService.mockWalletBalance, equals(1000000));
      },
    );

    testWidgets(
      'Use Case 05: Luồng thành công Miền 1: Góp tiền thành công và hiển thị thông báo "Góp tiền thành công"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockFunds = [
          {
            'id': 'fund_1',
            'name': 'Quỹ du lịch',
            'fundType': 'Cá nhân',
            'currentAmount': 100000,
          },
        ];

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: ContributeFundScreen(
                fund: fakeService.mockFunds.first,
                initialWalletBalance: 1000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nhập số tiền hợp lệ 50.000đ và ghi chú hợp lệ
        await tester.enterText(find.byType(TextFormField).first, '50000');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Góp tiền tháng 9',
        );
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        // Giao diện Chuyển tiền hiển thị thông tin
        expect(find.text('Xác nhận chuyển tiền'), findsOneWidget);
        expect(find.text('Góp tiền tháng 9'), findsWidgets);

        // Bấm Xác nhận chuyển tiền
        await tapButton(tester, 'Xác nhận chuyển tiền');
        await tester.pumpAndSettle();

        // Hệ thống thông báo "Góp tiền thành công"
        expect(find.text('Góp tiền thành công'), findsOneWidget);
        // Số dư ví bị trừ 50.000đ
        expect(fakeService.mockWalletBalance, equals(950000));
        // Số tiền quỹ tăng 50.000đ
        expect(fakeService.mockFunds.first['currentAmount'], equals(150000));
        // Lưu giao dịch
        expect(fakeService.mockFundTransactions.length, equals(1));
      },
    );

    testWidgets(
      'Use Case 05: Giá trị biên: Góp đúng bằng số dư khả dụng (1.000.000đ) thành công',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockFunds = [
          {
            'id': 'fund_1',
            'name': 'Quỹ dự phòng',
            'fundType': 'Cá nhân',
            'currentAmount': 0,
          },
        ];

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: ContributeFundScreen(
                fund: fakeService.mockFunds.first,
                initialWalletBalance: 1000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nhập số tiền = số dư ví: 1000000
        await tester.enterText(find.byType(TextFormField).first, '1000000');
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        // Bấm Xác nhận chuyển tiền
        await tapButton(tester, 'Xác nhận chuyển tiền');
        await tester.pumpAndSettle();

        expect(find.text('Góp tiền thành công'), findsOneWidget);
        expect(fakeService.mockWalletBalance, equals(0));
        expect(fakeService.mockFunds.first['currentAmount'], equals(1000000));
      },
    );

    testWidgets(
      'Use Case 05: E6: Phát sinh lỗi khi chuyển tiền hiển thị "Góp quỹ không thành công"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.shouldFailContribute = true;

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = {
          'id': 'fund_1',
          'name': 'Quỹ du lịch',
          'fundType': 'Cá nhân',
          'currentAmount': 100000,
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: ContributeFundScreen(
                fund: fund,
                initialWalletBalance: 1000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '50000');
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        await tapButton(tester, 'Xác nhận chuyển tiền');
        await tester.pumpAndSettle();

        expect(find.text('Góp quỹ không thành công'), findsOneWidget);
      },
    );

    testWidgets(
      'Use Case 05: E7: Lỗi kết nối mạng hiển thị "Không thể thực hiện giao dịch. Vui lòng thử lại sau"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.shouldNetworkFailContribute = true;

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = {
          'id': 'fund_1',
          'name': 'Quỹ du lịch',
          'fundType': 'Cá nhân',
          'currentAmount': 100000,
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: ContributeFundScreen(
                fund: fund,
                initialWalletBalance: 1000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '50000');
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        await tapButton(tester, 'Xác nhận chuyển tiền');
        await tester.pumpAndSettle();

        expect(
          find.text('Không thể thực hiện giao dịch. Vui lòng thử lại sau'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Luồng tích hợp hoàn chỉnh: Từ Quỹ -> Chi tiết quỹ -> Góp quỹ -> Cập nhật số tiền',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockFunds = [
          {
            'id': 'fund_100',
            'name': 'Quỹ mua laptop mới',
            'fundType': 'Tích lũy',
            'currentAmount': 5000000,
            'targetAmount': 20000000,
          },
        ];

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: FundsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Bấm vào quỹ để mở Chi tiết quỹ
        await tester.tap(find.text('Quỹ mua laptop mới'));
        await tester.pumpAndSettle();

        expect(find.byType(FundDetailScreen), findsOneWidget);
        expect(find.text('5.000.000 đ'), findsOneWidget);

        // Bấm + Góp quỹ
        await tapButton(tester, '+ Góp quỹ');
        await tester.pumpAndSettle();

        expect(find.byType(ContributeFundScreen), findsOneWidget);

        // Nhập 500.000đ
        await tester.enterText(find.byType(TextFormField).first, '500000');
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        // Xác nhận chuyển tiền
        await tapButton(tester, 'Xác nhận chuyển tiền');
        await tester.pumpAndSettle();

        // Thông báo thành công
        expect(find.text('Góp tiền thành công'), findsOneWidget);

        // Đã quay về Chi tiết quỹ và số tiền hiển thị là 5.500.000 đ
        expect(find.byType(FundDetailScreen), findsOneWidget);
        expect(find.text('5.500.000 đ'), findsOneWidget);
      },
    );

    testWidgets(
      'Góp quỹ thành công: Số dư ví cá nhân bị trừ thật trên giao diện HomeScreen và AppSession',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockWalletBalance = 1000000;
        fakeService.mockFunds = [
          {
            'id': 'fund_abc',
            'name': 'Quỹ du lịch Đà Lạt',
            'fundType': 'Tiết kiệm',
            'currentAmount': 100000,
            'targetAmount': 5000000,
          },
        ];

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra ban đầu HomeScreen hiển thị 1.000.000 đ
        expect(find.text('1.000.000 đ'), findsOneWidget);

        // Bấm vào nút "Quỹ" ở Trang chủ
        await tester.tap(find.text('Quỹ'));
        await tester.pumpAndSettle();

        expect(find.byType(FundsScreen), findsOneWidget);

        // Bấm vào quỹ "Quỹ du lịch Đà Lạt" để mở Chi tiết quỹ
        await tester.tap(find.text('Quỹ du lịch Đà Lạt'));
        await tester.pumpAndSettle();

        expect(find.byType(FundDetailScreen), findsOneWidget);

        // Bấm "+ Góp quỹ"
        await tapButton(tester, '+ Góp quỹ');
        await tester.pumpAndSettle();

        expect(find.byType(ContributeFundScreen), findsOneWidget);
        expect(find.text('Số dư ví khả dụng: '), findsOneWidget);
        expect(find.text('1.000.000 đ'), findsWidgets);

        // Nhập số tiền góp: 200.000 đ
        await tester.enterText(find.byType(TextFormField).first, '200000');
        await tapButton(tester, 'Chuyển tiền');
        await tester.pumpAndSettle();

        // Kiểm tra sheet Chuyển tiền hiển thị số tiền trừ và số dư còn lại sau chuyển (800.000 đ)
        expect(find.text('Xác nhận chuyển tiền'), findsOneWidget);
        expect(find.text('800.000 đ'), findsOneWidget);

        // Xác nhận chuyển tiền
        await tapButton(tester, 'Xác nhận chuyển tiền');
        await tester.pumpAndSettle();

        // Thông báo thành công
        expect(find.text('Góp tiền thành công'), findsOneWidget);

        // Đã quay về Chi tiết quỹ, quỹ tăng lên 300.000 đ (100.000 + 200.000)
        expect(find.byType(FundDetailScreen), findsOneWidget);
        expect(find.text('300.000 đ'), findsOneWidget);

        // Bấm quay về Danh sách quỹ
        await tester.tap(find.text('Danh sách quỹ'));
        await tester.pumpAndSettle();

        expect(find.byType(FundsScreen), findsOneWidget);

        // Bấm quay về Trang chủ
        await tester.tap(find.text('Trang chủ'));
        await tester.pumpAndSettle();

        // Đã về HomeScreen
        expect(find.byType(HomeScreen), findsOneWidget);

        // SỐ DƯ ĐÃ BỊ GIẢM THẬT: Từ 1.000.000 đ giảm còn 800.000 đ
        expect(find.text('800.000 đ'), findsOneWidget);
        expect(find.text('1.000.000 đ'), findsNothing);

        // Xác minh số dư trong session và mock service cũng bị giảm về 800.000
        expect(session.user?.walletBalance, 800000.0);
        expect(fakeService.mockWalletBalance, 800000.0);
      },
    );
  });

  group('Chức năng Mời thành viên & Thông báo lời mời quỹ (Use Case 06)', () {
    testWidgets(
      'Trang chủ: Nút hình chuông bên cạnh avatar và hiển thị chấm đỏ khi có thông báo mới',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockNotificationsList = [
          {
            'id': 'notif_1',
            '_id': 'notif_1',
            'title': 'Lời mời tham gia quỹ',
            'message': 'Đào Ngọc Đình đã mời bạn tham gia quỹ "Quỹ Hội Nhóm"',
            'type': 'fund_invitation',
            'isRead': false,
            'createdAt': DateTime.now().toIso8601String(),
            'metadata': {'invitationId': 'inv_10'},
          },
        ];

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra có nút Chuông Thông báo
        expect(find.byTooltip('Thông báo'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);

        // Bấm vào nút Chuông
        await tester.tap(find.byTooltip('Thông báo'));
        await tester.pumpAndSettle();

        // Mở NotificationsSheet
        expect(find.byType(NotificationsSheet), findsOneWidget);
        expect(find.text('Thông báo'), findsWidgets);
        expect(find.text('Lời mời tham gia quỹ'), findsOneWidget);
        expect(
          find.text('Đào Ngọc Đình đã mời bạn tham gia quỹ "Quỹ Hội Nhóm"'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Thông báo: Khi bấm vào lời mời quỹ sẽ chuyển sang giao diện kiểm tra lời mời hiện có (FundInvitationsScreen)',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockNotificationsList = [
          {
            'id': 'notif_1',
            '_id': 'notif_1',
            'title': 'Lời mời tham gia quỹ',
            'message': 'Đào Ngọc Đình đã mời bạn tham gia quỹ "Quỹ Du Lịch Hè"',
            'type': 'fund_invitation',
            'isRead': false,
            'createdAt': DateTime.now().toIso8601String(),
            'metadata': {'invitationId': 'inv_10'},
          },
        ];
        fakeService.mockInvitations = [
          {
            'id': 'inv_10',
            '_id': 'inv_10',
            'fundId': 'fund_1',
            'fundName': 'Quỹ Du Lịch Hè',
            'fundType': 'Hội nhóm',
            'inviterName': 'Đào Ngọc Đình',
            'status': 'pending',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ];

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Mở thông báo
        await tester.tap(find.byTooltip('Thông báo'));
        await tester.pumpAndSettle();

        // Bấm vào lời mời
        await tester.tap(find.text('Lời mời tham gia quỹ'));
        await tester.pumpAndSettle();

        // Chuyển sang FundInvitationsScreen
        expect(find.byType(FundInvitationsScreen), findsOneWidget);
        expect(find.text('Quỹ Du Lịch Hè'), findsOneWidget);
        expect(
          find.text('Đào Ngọc Đình đã mời bạn tham gia quỹ này'),
          findsOneWidget,
        );
        expect(find.text('Đồng ý'), findsOneWidget);
        expect(find.text('Từ chối'), findsOneWidget);
      },
    );

    testWidgets(
      'Kiểm tra lời mời hiện có (FundInvitationsScreen): Đồng ý tham gia quỹ',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockInvitations = [
          {
            'id': 'inv_1',
            '_id': 'inv_1',
            'fundId': 'fund_1',
            'fundName': 'Quỹ Cặp Đôi',
            'fundType': 'Cặp đôi',
            'inviterName': 'Đào Ngọc Đình',
            'status': 'pending',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ];

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: FundInvitationsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Quỹ Cặp Đôi'), findsOneWidget);
        expect(find.text('Chờ xử lý'), findsWidgets);

        // Bấm Đồng ý
        await tester.tap(find.text('Đồng ý'));
        await tester.pumpAndSettle();

        expect(find.text('Tham gia quỹ thành công'), findsOneWidget);
        expect(find.text('Đã tham gia'), findsOneWidget);
        expect(fakeService.mockInvitations.first['status'], 'accepted');
      },
    );

    testWidgets(
      'Kiểm tra lời mời hiện có (FundInvitationsScreen): Từ chối lời mời',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockInvitations = [
          {
            'id': 'inv_2',
            '_id': 'inv_2',
            'fundId': 'fund_2',
            'fundName': 'Quỹ Hội Nhóm',
            'fundType': 'Hội nhóm',
            'inviterName': 'Nguyễn Văn A',
            'status': 'pending',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ];

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: FundInvitationsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Bấm Từ chối
        await tester.tap(find.text('Từ chối'));
        await tester.pumpAndSettle();

        // Xuất hiện dialog xác nhận từ chối
        expect(find.text('Từ chối lời mời'), findsWidgets);
        expect(
          find.text(
            'Bạn có chắc chắn muốn từ chối lời mời tham gia quỹ "Quỹ Hội Nhóm" không?',
          ),
          findsOneWidget,
        );

        // Xác nhận từ chối trong dialog
        await tester.tap(find.widgetWithText(ElevatedButton, 'Từ chối'));
        await tester.pumpAndSettle();

        expect(find.text('Đã từ chối lời mời'), findsOneWidget);
        expect(find.text('Đã từ chối'), findsOneWidget);
        expect(fakeService.mockInvitations.first['status'], 'rejected');
      },
    );

    testWidgets(
      'Chi tiết quỹ: Quỹ không phải cá nhân có nút "Mời thành viên", bấm vào mở giao diện riêng InviteMemberScreen',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final groupFund = {
          'id': 'fund_group_1',
          'name': 'Quỹ Hội Nhóm Phượt',
          'fundType': 'Hội nhóm',
          'currentAmount': 2000000,
          'targetAmount': 10000000,
        };
        fakeService.mockFunds = [groupFund];

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: FundDetailScreen(fund: groupFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra cả 2 nút + Góp quỹ và Mời thành viên đều có mặt
        expect(find.text('+ Góp quỹ'), findsOneWidget);
        expect(find.text('Mời thành viên'), findsOneWidget);

        // Bấm Mời thành viên
        await tester.tap(find.text('Mời thành viên'));
        await tester.pumpAndSettle();

        // Mở giao diện riêng InviteMemberScreen
        expect(find.byType(InviteMemberScreen), findsOneWidget);
        expect(find.text('Quỹ: Quỹ Hội Nhóm Phượt'), findsOneWidget);
      },
    );

    testWidgets(
      'Use Case 06: Ngoại lệ 1.2 / E2: Quỹ cá nhân ấn Mời thành viên báo "Quỹ cá nhân không thể mời thành viên"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final personalFund = {
          'id': 'fund_p_1',
          'name': 'Quỹ Cá Nhân',
          'fundType': 'Cá nhân',
          'currentAmount': 1000000,
        };
        fakeService.mockFunds = [personalFund];

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: FundDetailScreen(fund: personalFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Bấm Mời thành viên trên quỹ Cá nhân
        await tester.tap(find.text('Mời thành viên'));
        await tester.pumpAndSettle();

        // Thông báo Exception E2
        expect(
          find.text('Quỹ cá nhân không thể mời thành viên'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Use Case 06: Luồng 4.1 & Gợi ý: Hiển thị danh sách đề xuất người dùng khi mở màn hình',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final groupFund = {
          'id': 'fund_group_1',
          'name': 'Quỹ Du Lịch Hè',
          'fundType': 'Hội nhóm',
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: InviteMemberScreen(fund: groupFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Hiển thị danh sách đề xuất
        expect(find.text('Danh sách đề xuất'), findsOneWidget);
        expect(find.text('Trần Văn B'), findsOneWidget);
        expect(find.text('Lê Văn D'), findsOneWidget);
        expect(find.text('Phạm Văn E'), findsOneWidget);

        // Ngoại lệ 6.1 / E4: Lê Văn D đã là thành viên của quỹ
        expect(find.text('Đã là thành viên'), findsOneWidget);

        // Ngoại lệ 6.2 / E5: Phạm Văn E đã có lời mời đang chờ xử lý
        expect(find.text('Đã gửi lời mời'), findsOneWidget);

        // Miền 1: Trần Văn B có nút "Mời"
        expect(find.text('Mời'), findsOneWidget);
      },
    );

    testWidgets(
      'Ẩn admin khỏi danh sách đề xuất: Tài khoản admin không xuất hiện trong danh sách đề xuất ứng viên',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        // Thêm một tài khoản admin vào danh sách mock
        fakeService.mockCandidates = [
          ...fakeService.mockCandidates,
          {
            'id': 'user_admin',
            '_id': 'user_admin',
            'name': 'admin',
            'phoneNumber': '0901234567',
            'email': 'admin@gmail.com',
            'role': 'admin',
            'isMember': false,
            'hasPendingInvite': false,
            'canInvite': true,
          },
        ];
        final session = AppSession(authService: fakeService);
        await session.login(account: 'user1', password: '123456');

        final groupFund = {
          'id': 'fund_group_1',
          'name': 'Quỹ Du Lịch Hè',
          'fundType': 'Hội nhóm',
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: InviteMemberScreen(fund: groupFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Danh sách đề xuất hiển thị người dùng thường, nhưng KHÔNG hiển thị admin
        expect(find.text('Danh sách đề xuất'), findsOneWidget);
        expect(find.text('Trần Văn B'), findsOneWidget);
        expect(find.text('admin'), findsNothing);
        expect(find.text('admin@gmail.com'), findsNothing);
      },
    );

    testWidgets(
      'Use Case 06: Ngoại lệ 4.2 / E3: Tìm kiếm không có kết quả hiển thị "Không tìm thấy người dùng phù hợp"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final groupFund = {
          'id': 'fund_group_1',
          'name': 'Quỹ Du Lịch Hè',
          'fundType': 'Hội nhóm',
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: InviteMemberScreen(fund: groupFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Nhập tìm kiếm không tồn tại
        await tester.enterText(find.byType(TextField), 'Nguyễn Văn XYZ');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Hiển thị thông báo E3
        expect(find.text('Không tìm thấy người dùng phù hợp'), findsOneWidget);
      },
    );

    testWidgets(
      'Use Case 06: Luồng con 4.1 & 4.2: Tìm kiếm theo tên hoặc SĐT hiển thị người dùng phù hợp',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final groupFund = {
          'id': 'fund_group_1',
          'name': 'Quỹ Du Lịch Hè',
          'fundType': 'Hội nhóm',
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: InviteMemberScreen(fund: groupFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Tìm theo SĐT 0912345678
        await tester.enterText(find.byType(TextField), '0912345678');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text('Trần Văn B'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('0912345678'),
          ),
          findsOneWidget,
        );
        expect(find.text('Lê Văn D'), findsNothing);
      },
    );

    testWidgets(
      'Use Case 06: Luồng thành công Miền 1: Mời Trần Văn B, hiện hộp thoại xác nhận và thông báo "Gửi lời mời thành công"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final groupFund = {
          'id': 'fund_group_1',
          'name': 'Quỹ Du Lịch Hè',
          'fundType': 'Hội nhóm',
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: InviteMemberScreen(fund: groupFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Bấm nút Mời trên Trần Văn B
        await tester.tap(find.text('Mời'));
        await tester.pumpAndSettle();

        // Hiện dialog xác nhận
        expect(find.text('Xác nhận lời mời'), findsOneWidget);
        expect(
          find.text(
            'Bạn có muốn mời Trần Văn B tham gia vào quỹ "Quỹ Du Lịch Hè" không?',
          ),
          findsOneWidget,
        );

        // Bấm Gửi lời mời trong dialog
        await tester.tap(find.text('Gửi lời mời'));
        await tester.pumpAndSettle();

        // Thông báo thành công
        expect(find.text('Gửi lời mời thành công'), findsOneWidget);

        // Trần Văn B đổi trạng thái thành "Đã gửi lời mời"
        expect(
          find.text('Đã gửi lời mời'),
          findsNWidgets(2),
        ); // Phạm Văn E + Trần Văn B
      },
    );

    testWidgets(
      'Use Case 06: Ngoại lệ 7.1 / E6: Xảy ra lỗi khi gửi lời mời hiển thị "Gửi lời mời không thành công"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.shouldFailSendInvite = true;

        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final groupFund = {
          'id': 'fund_group_1',
          'name': 'Quỹ Du Lịch Hè',
          'fundType': 'Hội nhóm',
        };

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: InviteMemberScreen(fund: groupFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Bấm Mời
        await tester.tap(find.text('Mời'));
        await tester.pumpAndSettle();

        // Bấm Gửi lời mời trong dialog
        await tester.tap(find.text('Gửi lời mời'));
        await tester.pumpAndSettle();

        // Thông báo E6
        expect(find.text('Gửi lời mời không thành công'), findsOneWidget);
      },
    );
  });

  group('Tính năng Role Admin & Xem danh sách tài khoản', () {
    testWidgets(
      'Tài khoản admin: HomeScreen hiển thị bảng điều khiển admin và mở màn hình Danh sách tài khoản',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await _login(tester, account: 'admin', password: '123456');

        expect(find.byType(HomeScreen), findsOneWidget);

        // Nút DS tài khoản trong lưới tính năng
        final adminFeatureBtn = find.text('DS tài khoản');
        await tester.ensureVisible(adminFeatureBtn);
        expect(adminFeatureBtn, findsOneWidget);

        // Cuộn để tìm banner Bảng điều khiển Quản trị viên
        final adminBanner = find.text('Bảng điều khiển Quản trị viên');
        await tester.ensureVisible(adminBanner);
        expect(adminBanner, findsOneWidget);
        expect(
          find.text('Xem danh sách tài khoản & tra cứu người dùng'),
          findsOneWidget,
        );

        // Bấm vào banner
        await tester.tap(adminBanner);
        await tester.pumpAndSettle();

        // Đã mở AdminUsersScreen
        expect(find.byType(AdminUsersScreen), findsOneWidget);
        expect(find.text('Danh sách tài khoản'), findsOneWidget);

        // Hiển thị thống kê KPI
        expect(find.text('Tổng tài khoản'), findsOneWidget);
        expect(find.text('Người dùng'), findsWidgets);

        // Hiển thị danh sách các tài khoản mock
        expect(find.text('Administrator'), findsOneWidget);
        expect(find.text('Nguyễn Văn A'), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -150));
        await tester.pumpAndSettle();
        expect(find.text('Trần Thị B'), findsOneWidget);
      },
    );

    testWidgets(
      'Tài khoản admin: bấm nút tính năng DS tài khoản trong lưới mở màn hình AdminUsersScreen',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await _login(tester, account: 'admin', password: '123456');

        expect(find.byType(HomeScreen), findsOneWidget);

        // Bấm trực tiếp vào nút tính năng DS tài khoản
        final adminFeatureBtn = find.text('DS tài khoản');
        await tester.ensureVisible(adminFeatureBtn);
        await tester.tap(adminFeatureBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AdminUsersScreen), findsOneWidget);
        expect(find.text('Danh sách tài khoản'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminUsersScreen: Tìm kiếm và bộ lọc vai trò hoạt động chính xác',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: AdminUsersScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('admin@gmail.com'), findsOneWidget);
        expect(find.text('nguyenvana@gmail.com'), findsOneWidget);

        // Nhập từ khoá tìm kiếm
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'Nguyễn Văn A');
        await tester.pumpAndSettle();

        expect(find.text('nguyenvana@gmail.com'), findsOneWidget);
        expect(find.text('admin@gmail.com'), findsNothing);

        // Xoá tìm kiếm
        await tester.enterText(searchField, '');
        await tester.pumpAndSettle();
        expect(find.text('admin@gmail.com'), findsOneWidget);

        // Bấm chip lọc vai trò "Admin (1)"
        final adminFilterChip = find.text('Admin (1)');
        await tester.tap(adminFilterChip);
        await tester.pumpAndSettle();

        expect(find.text('admin@gmail.com'), findsOneWidget);
        expect(find.text('nguyenvana@gmail.com'), findsNothing);

        // Hiển thị mật khẩu trên thẻ người dùng
        expect(find.text('MK: '), findsOneWidget);
        expect(find.text('123456'), findsOneWidget);

        // Bấm vào thẻ để mở chi tiết người dùng
        await tester.tap(find.text('Administrator'));
        await tester.pumpAndSettle();

        // Trong bảng chi tiết có dòng Mật khẩu
        expect(find.text('Chi tiết tài khoản'), findsOneWidget);
        expect(find.text('Mật khẩu'), findsOneWidget);
      },
    );

    testWidgets(
      'Tài khoản admin: ProfileScreen hiển thị huy hiệu Quản trị viên và menu Danh sách tài khoản',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Huy hiệu admin
        expect(find.text('Quản trị viên (Admin)'), findsOneWidget);

        // Menu Danh sách tài khoản
        final adminMenuRow = find.text('Danh sách tài khoản');
        await tester.ensureVisible(adminMenuRow);
        expect(adminMenuRow, findsOneWidget);

        // Bấm vào menu mở AdminUsersScreen
        await tester.tap(adminMenuRow);
        await tester.pumpAndSettle();

        expect(find.byType(AdminUsersScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Tài khoản thường (role: user): không hiển thị bảng điều khiển admin trên Home và Profile',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        // Đăng nhập với tài khoản người dùng bình thường
        await session.login(account: 'user1', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Không hiển thị nút và banner Quản trị viên
        expect(find.text('DS tài khoản'), findsNothing);
        expect(find.text('Bảng điều khiển Quản trị viên'), findsNothing);

        // Vào ProfileScreen
        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Không hiển thị badge admin và menu Danh sách tài khoản
        expect(find.text('Quản trị viên (Admin)'), findsNothing);
        expect(find.text('Tài khoản đã xác thực'), findsOneWidget);
        expect(find.text('Danh sách tài khoản'), findsNothing);
      },
    );
  });

  group('Thành viên quỹ, Rời quỹ và Xoá quỹ trong Chi tiết quỹ', () {
    testWidgets(
      'Chi tiết quỹ: Hiển thị đầy đủ danh sách thành viên với huy hiệu Chủ quỹ, Thành viên và (Bạn)',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final testFund = {
          'id': 'fund_with_members',
          '_id': 'fund_with_members',
          'name': 'Quỹ Du Lịch Hội Nhóm',
          'fundType': 'Hội nhóm',
          'userId': {
            '_id': '65f0000000000000000000aa',
            'name': 'admin',
            'email': 'admin@gmail.com',
          },
          'members': [
            {
              'userId': {
                '_id': '65f0000000000000000000aa',
                'name': 'admin',
                'email': 'admin@gmail.com',
              },
              'role': 'owner',
            },
            {
              'userId': {
                '_id': '65f0000000000000000000bb',
                'name': 'Trần Văn B',
                'phoneNumber': '0912345678',
              },
              'role': 'member',
            },
          ],
        };

        fakeService.mockFunds = [testFund];

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: FundDetailScreen(fund: testFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra khối "Thành viên quỹ"
        expect(find.text('Thành viên quỹ'), findsOneWidget);
        expect(find.text('2 thành viên'), findsOneWidget);

        // Hiển thị tên thành viên
        expect(find.text('admin'), findsOneWidget);
        expect(find.text('Trần Văn B'), findsOneWidget);
        expect(find.text('0912345678'), findsOneWidget);

        // Huy hiệu vai trò
        expect(find.text('Chủ quỹ'), findsOneWidget);
        expect(find.text('Thành viên'), findsOneWidget);
        expect(find.text('Bạn'), findsOneWidget);
      },
    );

    testWidgets(
      'Chủ quỹ: Hiển thị nút "Xoá quỹ này", bấm vào hiện hộp thoại xác nhận và xoá quỹ thành công',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final ownerFund = {
          'id': 'fund_owner_1',
          '_id': 'fund_owner_1',
          'name': 'Quỹ Cần Xoá',
          'fundType': 'Hội nhóm',
          'userId': '65f0000000000000000000aa',
          'members': [
            {'userId': '65f0000000000000000000aa', 'role': 'owner'},
          ],
        };

        fakeService.mockFunds = [ownerFund];

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: FundDetailScreen(fund: ownerFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Chủ quỹ nhìn thấy nút "Xoá quỹ này" và không thấy nút "Rời khỏi quỹ"
        expect(
          find.byKey(const ValueKey('delete_fund_button')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('leave_fund_button')), findsNothing);

        // Bấm nút "Xoá quỹ này"
        await tester.tap(find.byKey(const ValueKey('delete_fund_button')));
        await tester.pumpAndSettle();

        // Xuất hiện hộp thoại xác nhận
        expect(find.text('Xác nhận xoá quỹ'), findsOneWidget);
        expect(find.text('Xoá quỹ'), findsOneWidget);

        // Bấm nút "Xoá quỹ" trong dialog
        await tester.tap(find.text('Xoá quỹ'));
        await tester.pumpAndSettle();

        // Đã gọi xoá quỹ thành công trong mockFunds
        expect(fakeService.mockFunds.isEmpty, isTrue);
      },
    );

    testWidgets(
      'Thành viên thường: Hiển thị nút "Rời khỏi quỹ", bấm vào hiện hộp thoại xác nhận và rời quỹ thành công',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final memberFund = {
          'id': 'fund_member_1',
          '_id': 'fund_member_1',
          'name': 'Quỹ Của Người Khác',
          'fundType': 'Hội nhóm',
          'userId': 'different_owner_id',
          'members': [
            {'userId': 'different_owner_id', 'role': 'owner'},
            {'userId': '65f0000000000000000000aa', 'role': 'member'},
          ],
        };

        fakeService.mockFunds = [memberFund];

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: FundDetailScreen(fund: memberFund)),
          ),
        );
        await tester.pumpAndSettle();

        // Thành viên thường nhìn thấy nút "Rời khỏi quỹ" và không thấy nút "Xoá quỹ này"
        expect(find.byKey(const ValueKey('leave_fund_button')), findsOneWidget);
        expect(find.byKey(const ValueKey('delete_fund_button')), findsNothing);

        // Bấm nút "Rời khỏi quỹ"
        await tester.tap(find.byKey(const ValueKey('leave_fund_button')));
        await tester.pumpAndSettle();

        // Xuất hiện hộp thoại xác nhận
        expect(find.text('Rời khỏi quỹ?'), findsOneWidget);
        expect(find.text('Rời quỹ'), findsOneWidget);

        // Bấm nút "Rời quỹ" trong dialog
        await tester.tap(find.text('Rời quỹ'));
        await tester.pumpAndSettle();

        // Kiểm tra trong mockFunds xem user đã được gỡ khỏi danh sách thành viên chưa
        final updatedFund = fakeService.mockFunds.firstWhere(
          (f) => f['id'] == 'fund_member_1',
        );
        final members = updatedFund['members'] as List;
        final isStillMember = members.any((m) {
          final uid = (m['userId'] is Map) ? m['userId']['_id'] : m['userId'];
          return uid == '65f0000000000000000000aa';
        });
        expect(isStillMember, isFalse);
      },
    );
  });

  group('Quỹ cặp đôi: bắt buộc chọn người dùng khác & tối đa 2 người', () {
    testWidgets(
      'E9: Chọn loại Cặp đôi hiện trường "Người cùng lập quỹ", chưa chọn thì bấm Tạo quỹ báo lỗi',
      (tester) async {
        final session = AppSession(
          authService: FakeAuthService(acceptedPassword: '123456'),
        );
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(
              home: CreateFundScreen(initialFundCount: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cặp đôi'));
        await tester.pumpAndSettle();

        // Trường chọn người cùng lập quỹ xuất hiện ngay khi chọn loại quỹ
        expect(find.text('Người cùng lập quỹ *'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('pick_partner_button')),
          findsOneWidget,
        );
        expect(find.text('Chọn người dùng khác...'), findsOneWidget);

        // Nhập tên quỹ nhưng chưa chọn người cùng lập quỹ
        await tester.enterText(find.byType(TextFormField).first, 'Quỹ cặp đôi');
        await tapButton(tester, 'Tạo quỹ');
        await tester.pumpAndSettle();

        expect(
          find.text('Vui lòng chọn người dùng khác để lập quỹ cặp đôi'),
          findsOneWidget,
        );
        expect(find.text('Vui lòng nhập đầy đủ thông tin'), findsOneWidget);
      },
    );

    testWidgets(
      'Chọn người cùng lập quỹ qua màn hình SelectPartnerScreen và tạo quỹ cặp đôi thành công',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: const MaterialApp(
              home: CreateFundScreen(initialFundCount: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cặp đôi'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'Quỹ cặp đôi Hà Nội',
        );

        // Mở màn hình chọn người cùng lập quỹ
        await tester.ensureVisible(
          find.byKey(const ValueKey('pick_partner_button')),
        );
        await tester.tap(find.byKey(const ValueKey('pick_partner_button')));
        await tester.pumpAndSettle();

        expect(find.byType(SelectPartnerScreen), findsOneWidget);
        expect(find.text('Chọn người cùng lập quỹ'), findsOneWidget);

        // Chọn "Trần Văn B"
        await tester.tap(find.text('Trần Văn B'));
        await tester.pumpAndSettle();

        // Đã quay lại màn hình Tạo quỹ và hiển thị người đã chọn
        expect(find.byType(CreateFundScreen), findsOneWidget);
        expect(find.text('Trần Văn B'), findsOneWidget);

        await tapButton(tester, 'Tạo quỹ');
        await tester.pumpAndSettle();

        expect(find.text('Đã gửi lời mời lập quỹ cặp đôi'), findsOneWidget);
        expect(fakeService.mockFunds.length, equals(1));
        expect(fakeService.mockFunds.first['fundType'], equals('Cặp đôi'));
        expect(
          fakeService.mockFunds.first['status'],
          equals('pending_partner'),
        );
      },
    );

    testWidgets('Quỹ cặp đôi đã đủ 2 người dùng thì không mời thêm được nữa', (
      tester,
    ) async {
      final fakeService = FakeAuthService(acceptedPassword: '123456');
      final session = AppSession(authService: fakeService);
      await session.login(account: 'admin', password: '123456');

      final coupleFund = {
        'id': 'fund_couple',
        '_id': 'fund_couple',
        'name': 'Quỹ Cặp Đôi',
        'fundType': 'Cặp đôi',
        'status': 'active',
        'currentAmount': 1000000,
        'userId': '65f0000000000000000000aa',
        'members': [
          {'userId': '65f0000000000000000000aa', 'role': 'owner'},
          {'userId': '65f0000000000000000000bb', 'role': 'member'},
        ],
      };
      fakeService.mockFunds = [coupleFund];

      await tester.pumpWidget(
        AppScope(
          session: session,
          child: MaterialApp(home: FundDetailScreen(fund: coupleFund)),
        ),
      );
      await tester.pumpAndSettle();

      // Nút "Mời thành viên" bị vô hiệu hoá vì quỹ đã có đủ 2 người dùng
      final inviteBtn = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Mời thành viên'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(inviteBtn.onPressed, isNull);
      expect(find.text('2 thành viên'), findsOneWidget);
    });

    testWidgets(
      'Quỹ cặp đôi đang chờ đồng ý hiển thị cảnh báo và không mời thêm được',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final pendingFund = {
          'id': 'fund_couple_pending',
          '_id': 'fund_couple_pending',
          'name': 'Quỹ Cặp Đôi Mới',
          'fundType': 'Cặp đôi',
          'status': 'pending_partner',
          'currentAmount': 0,
          'userId': '65f0000000000000000000aa',
          'members': [
            {'userId': '65f0000000000000000000aa', 'role': 'owner'},
          ],
        };
        fakeService.mockFunds = [pendingFund];

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: FundDetailScreen(fund: pendingFund)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Quỹ cặp đôi đang chờ người được chọn đồng ý'),
          findsOneWidget,
        );
      },
    );
  });

  group('Tính năng Rút tiền từ quỹ (chỉ chủ quỹ)', () {
    Map<String, dynamic> buildOwnerFund({double currentAmount = 2000000}) => {
      'id': 'fund_withdraw_1',
      '_id': 'fund_withdraw_1',
      'name': 'Quỹ Cần Rút Tiền',
      'fundType': 'Cặp đôi',
      'currentAmount': currentAmount,
      'userId': '65f0000000000000000000aa',
      'members': [
        {'userId': '65f0000000000000000000aa', 'role': 'owner'},
        {'userId': '65f0000000000000000000bb', 'role': 'member'},
      ],
    };

    testWidgets(
      'Chủ quỹ thấy nút "Rút tiền về ví" và mở được màn hình rút tiền',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = buildOwnerFund();
        fakeService.mockFunds = [fund];

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: FundDetailScreen(fund: fund)),
          ),
        );
        await tester.pumpAndSettle();

        final withdrawBtn = find.byKey(const ValueKey('withdraw_fund_button'));
        expect(withdrawBtn, findsOneWidget);

        await tester.ensureVisible(withdrawBtn);
        await tester.pumpAndSettle();
        await tester.tap(withdrawBtn);
        await tester.pumpAndSettle();

        expect(find.byType(WithdrawFundScreen), findsOneWidget);
        expect(find.text('Rút tiền từ quỹ'), findsOneWidget);
        expect(find.text('Số dư quỹ: 2.000.000 đ'), findsOneWidget);
      },
    );

    testWidgets('Thành viên (không phải chủ quỹ) không thấy nút rút tiền', (
      tester,
    ) async {
      final fakeService = FakeAuthService(acceptedPassword: '123456');
      final session = AppSession(authService: fakeService);
      await session.login(account: 'admin', password: '123456');

      final fund = {
        'id': 'fund_member_withdraw',
        '_id': 'fund_member_withdraw',
        'name': 'Quỹ Của Chủ Khác',
        'fundType': 'Hội nhóm',
        'currentAmount': 2000000,
        'userId': '65f0000000000000000000ff',
        'members': [
          {'userId': '65f0000000000000000000ff', 'role': 'owner'},
          {'userId': '65f0000000000000000000aa', 'role': 'member'},
        ],
      };
      fakeService.mockFunds = [fund];

      await tester.pumpWidget(
        AppScope(
          session: session,
          child: MaterialApp(home: FundDetailScreen(fund: fund)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('withdraw_fund_button')), findsNothing);
      expect(find.byKey(const ValueKey('leave_fund_button')), findsOneWidget);
    });

    testWidgets(
      'E1: Để trống số tiền rút hiển thị "Vui lòng nhập số tiền muốn rút"',
      (tester) async {
        final session = AppSession(
          authService: FakeAuthService(acceptedPassword: '123456'),
        );
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: WithdrawFundScreen(fund: buildOwnerFund()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tapButton(tester, 'Rút tiền');
        await tester.pumpAndSettle();

        expect(find.text('Vui lòng nhập số tiền muốn rút'), findsOneWidget);
        expect(find.text('Xác nhận rút tiền'), findsNothing);
      },
    );

    testWidgets(
      'E2 & E3: Nhập số tiền không hợp lệ hoặc dưới 1.000đ hiển thị thông báo tương ứng',
      (tester) async {
        final session = AppSession(
          authService: FakeAuthService(acceptedPassword: '123456'),
        );
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: WithdrawFundScreen(fund: buildOwnerFund()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, 'abc');
        await tapButton(tester, 'Rút tiền');
        await tester.pumpAndSettle();
        expect(find.text('Số tiền không hợp lệ'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField).first, '999');
        await tapButton(tester, 'Rút tiền');
        await tester.pumpAndSettle();
        expect(find.text('Tối thiểu 1000đ'), findsOneWidget);
      },
    );

    testWidgets(
      'E4: Rút số tiền lớn hơn số dư quỹ hiển thị "Số dư quỹ không đủ để rút"',
      (tester) async {
        final session = AppSession(
          authService: FakeAuthService(acceptedPassword: '123456'),
        );
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: WithdrawFundScreen(fund: buildOwnerFund()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '2000001');
        await tapButton(tester, 'Rút tiền');
        await tester.pumpAndSettle();

        expect(find.text('Số dư quỹ không đủ để rút'), findsOneWidget);
      },
    );

    testWidgets(
      'Luồng thành công: Rút 500.000đ, quỹ giảm và ví cá nhân tăng tương ứng',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        fakeService.mockWalletBalance = 1000000;
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = buildOwnerFund();
        fakeService.mockFunds = [fund];

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: WithdrawFundScreen(fund: fund)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '500000');
        await tapButton(tester, 'Rút tiền');
        await tester.pumpAndSettle();

        // Sheet xác nhận hiển thị đầy đủ thông tin
        expect(find.text('Xác nhận rút tiền'), findsOneWidget);
        expect(find.text('Quỹ rút tiền:'), findsOneWidget);
        expect(find.text('Nơi nhận:'), findsOneWidget);

        await tapButton(tester, 'Xác nhận rút tiền');
        await tester.pumpAndSettle();

        expect(find.text('Rút tiền thành công'), findsOneWidget);
        // Quỹ còn 1.500.000đ, ví tăng từ 1.000.000đ lên 1.500.000đ
        expect(fakeService.mockFunds.first['currentAmount'], equals(1500000));
        expect(fakeService.mockWalletBalance, equals(1500000));
        expect(session.user?.walletBalance, 1500000.0);
        expect(
          fakeService.mockFundTransactions.first['type'],
          equals('fund_withdrawal'),
        );
      },
    );

    testWidgets(
      'Chi tiết quỹ hiển thị giao dịch rút tiền với dấu trừ và nhãn "Rút tiền"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = buildOwnerFund();
        fakeService.mockFunds = [fund];
        fakeService.mockFundTransactions = [
          {
            'id': 'txn_1',
            'fundId': 'fund_withdraw_1',
            'type': 'fund_withdrawal',
            'amount': 500000,
            'sender': 'Quỹ Cần Rút Tiền',
            'note': 'Rút chi phí gia đình',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ];

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: FundDetailScreen(fund: fund)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rút tiền'), findsOneWidget);
        expect(find.text('-500.000 đ'), findsOneWidget);
        expect(find.text('Rút chi phí gia đình'), findsOneWidget);
      },
    );

    testWidgets(
      'Quỹ còn tiền không xoá được: hiển thị thông báo "Chỉ được xoá quỹ khi số dư quỹ bằng 0"',
      (tester) async {
        final fakeService = FakeAuthService(acceptedPassword: '123456');
        final session = AppSession(authService: fakeService);
        await session.login(account: 'admin', password: '123456');

        final fund = buildOwnerFund(currentAmount: 2000000);
        fakeService.mockFunds = [fund];

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(home: FundDetailScreen(fund: fund)),
          ),
        );
        await tester.pumpAndSettle();

        // Nhãn nút xoá đổi thành nhắc rút hết tiền
        expect(find.text('Rút hết tiền mới xoá được quỹ'), findsOneWidget);

        final deleteBtn = find.byKey(const ValueKey('delete_fund_button'));
        await tester.ensureVisible(deleteBtn);
        await tester.pumpAndSettle();
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Chỉ được xoá quỹ khi số dư quỹ bằng 0. Quỹ đang có 2.000.000 đ',
          ),
          findsOneWidget,
        );
        expect(find.text('Xác nhận xoá quỹ'), findsNothing);
        expect(fakeService.mockFunds.length, equals(1));
      },
    );

    testWidgets('Quỹ về 0đ thì xoá được quỹ', (tester) async {
      final fakeService = FakeAuthService(acceptedPassword: '123456');
      final session = AppSession(authService: fakeService);
      await session.login(account: 'admin', password: '123456');

      final fund = buildOwnerFund(currentAmount: 0);
      fakeService.mockFunds = [fund];

      await tester.pumpWidget(
        AppScope(
          session: session,
          child: MaterialApp(home: FundDetailScreen(fund: fund)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xoá quỹ này'), findsOneWidget);
      // Không có nút rút tiền vì quỹ không còn tiền
      expect(
        find.byKey(const ValueKey('withdraw_fund_button')),
        findsOneWidget,
      );

      final deleteBtn = find.byKey(const ValueKey('delete_fund_button'));
      await tester.ensureVisible(deleteBtn);
      await tester.pumpAndSettle();
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận xoá quỹ'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xoá quỹ'));
      await tester.pumpAndSettle();

      expect(fakeService.mockFunds.isEmpty, isTrue);
    });

    testWidgets(
      'Màn hình rút tiền: quỹ dưới 1.000đ hiển thị cảnh báo và khoá nút rút',
      (tester) async {
        final session = AppSession(
          authService: FakeAuthService(acceptedPassword: '123456'),
        );
        await session.login(account: 'admin', password: '123456');

        await tester.pumpWidget(
          AppScope(
            session: session,
            child: MaterialApp(
              home: WithdrawFundScreen(
                fund: buildOwnerFund(currentAmount: 500),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Quỹ cần có ít nhất 1.000đ mới có thể rút tiền'),
          findsOneWidget,
        );

        final withdrawBtn = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Rút tiền'),
        );
        expect(withdrawBtn.onPressed, isNull);
      },
    );
  });
}

/// Đăng nhập từ màn hình đăng nhập với tài khoản cho trước.
Future<void> _login(
  WidgetTester tester, {
  required String account,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), account);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tapButton(tester, 'Đăng nhập');
  await tester.pumpAndSettle();
}
