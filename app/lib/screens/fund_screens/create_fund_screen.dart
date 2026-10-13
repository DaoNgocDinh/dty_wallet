import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/back_label.dart';
import '../../widgets/error_message.dart';
import 'select_partner_screen.dart';

/// Hằng số độ dài tối đa tên quỹ theo đặc tả Use Case 04
const int kMaxFundNameLength = 60;

/// 4 loại quỹ theo đặc tả Use Case 04
const List<String> kFundTypes = ['Cá nhân', 'Cặp đôi', 'Tích lũy', 'Hội nhóm'];

class CreateFundScreen extends StatefulWidget {
  const CreateFundScreen({
    super.key,
    this.initialFundCount,
  });

  /// Số lượng quỹ người dùng đang làm chủ hiện tại (dùng để kiểm tra điều kiện dưới 10 quỹ).
  final int? initialFundCount;

  @override
  State<CreateFundScreen> createState() => _CreateFundScreenState();
}

class _CreateFundScreenState extends State<CreateFundScreen> {
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();

  String? _selectedFundType;
  DateTime? _selectedCompletionDate;

  // Quỹ cặp đôi: bắt buộc chọn người dùng khác ngay từ lúc lập quỹ
  Map<String, dynamic>? _selectedPartner;

  int? _fundCount;
  bool _isLoadingCount = false;
  bool _isSubmitting = false;

  String? _fundCountError; // E1: Không thể tạo thêm quỹ
  String? _fundTypeError; // E2: Vui lòng chọn loại quỹ
  String? _nameError; // E3: Vui lòng nhập tên quỹ
  String? _targetAmountError; // E5, E6
  String? _completionDateError; // E7: Vui lòng chọn ngày hoàn thành mục tiêu
  String? _partnerError; // E9: Vui lòng chọn người dùng khác để lập quỹ cặp đôi
  String? _generalError; // E8: Vui lòng nhập đầy đủ thông tin

  @override
  void initState() {
    super.initState();
    _fundCount = widget.initialFundCount;
    if (_fundCount != null && _fundCount! >= 10) {
      _fundCountError = 'Không thể tạo thêm quỹ';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fundCount == null && !_isLoadingCount) {
      _checkFundCount();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _checkFundCount() async {
    _isLoadingCount = true;
    try {
      final res = await AppScope.of(context).fetchFunds();
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _fundCount = list.length;
        if (_fundCount! >= 10) {
          _fundCountError = 'Không thể tạo thêm quỹ';
        }
      });
    } catch (_) {
      // Nếu không lấy được số lượng quỹ, vẫn cho phép tiếp tục và server sẽ kiểm tra
    } finally {
      if (mounted) {
        setState(() => _isLoadingCount = false);
      }
    }
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _pickCompletionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCompletionDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedCompletionDate = picked;
        _completionDateError = null;
        if (_generalError != null) _generalError = null;
      });
    }
  }

  String get _selectedPartnerId {
    final partner = _selectedPartner;
    if (partner == null) return '';
    return partner['id']?.toString() ?? partner['_id']?.toString() ?? '';
  }

  String get _selectedPartnerName =>
      _selectedPartner?['name']?.toString() ?? '';

  String get _selectedPartnerPhone =>
      _selectedPartner?['phoneNumber']?.toString() ?? '';

  /// Mở màn hình chọn người dùng khác làm người cùng lập quỹ cặp đôi
  Future<void> _pickPartner() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SelectPartnerScreen()),
    );

    if (result is Map<String, dynamic> && mounted) {
      setState(() {
        _selectedPartner = result;
        _partnerError = null;
        if (_generalError != null) _generalError = null;
      });
    }
  }

  Future<void> _handleSubmit() async {
    // 1. Kiểm tra Pre-condition: Người dùng đã làm chủ từ 10 quỹ trở lên (Exceptions 1.1)
    if (_fundCount != null && _fundCount! >= 10) {
      setState(() {
        _fundCountError = 'Không thể tạo thêm quỹ';
      });
      return;
    }

    String? fundTypeError;
    String? nameError;
    String? targetAmountError;
    String? completionDateError;
    String? partnerError;
    bool hasMissingRequiredInfo = false;

    // 2. Kiểm tra loại quỹ (Exceptions 3.1: E2)
    if (_selectedFundType == null || _selectedFundType!.isEmpty) {
      fundTypeError = 'Vui lòng chọn loại quỹ';
      hasMissingRequiredInfo = true;
    }

    // 3. Kiểm tra tên quỹ (Exceptions 5.1: E3)
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      nameError = 'Vui lòng nhập tên quỹ';
      hasMissingRequiredInfo = true;
    }

    // 4. Kiểm tra đối với quỹ Tích lũy (Exceptions 5.3, 5.4, 5.5)
    double? targetAmount;
    if (_selectedFundType == 'Tích lũy') {
      final amountStr = _targetAmountController.text.trim();
      if (amountStr.isEmpty) {
        targetAmountError = 'Vui lòng nhập số tiền mục tiêu'; // E5
        hasMissingRequiredInfo = true;
      } else {
        final parsed = double.tryParse(amountStr.replaceAll(',', '').replaceAll('.', ''));
        if (parsed == null || parsed <= 0) {
          targetAmountError = 'Số tiền mục tiêu phải lớn hơn 0'; // E6
          hasMissingRequiredInfo = true;
        } else {
          targetAmount = parsed;
        }
      }

      if (_selectedCompletionDate == null) {
        completionDateError = 'Vui lòng chọn ngày hoàn thành mục tiêu'; // E7
        hasMissingRequiredInfo = true;
      }
    }

    // 4b. Quỹ Cặp đôi: bắt buộc chọn người dùng khác ngay từ lúc lập quỹ (E9)
    if (_selectedFundType == 'Cặp đôi' && _selectedPartner == null) {
      partnerError = 'Vui lòng chọn người dùng khác để lập quỹ cặp đôi'; // E9
      hasMissingRequiredInfo = true;
    }

    // 5. Kiểm tra đầy đủ thông tin (Exceptions 5.6: E8)
    String? generalError;
    if (hasMissingRequiredInfo) {
      generalError = 'Vui lòng nhập đầy đủ thông tin'; // E8
    }

    setState(() {
      _fundTypeError = fundTypeError;
      _nameError = nameError;
      _targetAmountError = targetAmountError;
      _completionDateError = completionDateError;
      _partnerError = partnerError;
      _generalError = generalError;
    });

    if (hasMissingRequiredInfo) {
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await AppScope.of(context).createFund(
        name: name,
        fundType: _selectedFundType!,
        targetAmount: targetAmount,
        completionDate: _selectedCompletionDate,
        partnerId: _selectedFundType == 'Cặp đôi' ? _selectedPartnerId : null,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _selectedFundType == 'Cặp đôi'
                ? 'Đã gửi lời mời lập quỹ cặp đôi'
                : 'Tạo quỹ thành công',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      if (navigator.canPop()) {
        navigator.pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'PARTNER_REQUIRED') {
        setState(() {
          _partnerError = 'Vui lòng chọn người dùng khác để lập quỹ cặp đôi';
          _generalError = null;
        });
      } else if (e.code == 'CANNOT_INVITE_SELF') {
        setState(() {
          _partnerError = 'Bạn không thể chọn chính mình làm người cùng lập quỹ';
          _generalError = null;
        });
      } else if (e.code == 'USER_NOT_FOUND' || e.code == 'CANNOT_INVITE_ADMIN') {
        setState(() {
          _partnerError = e.message;
          _generalError = null;
        });
      } else if (e.message.contains('Không thể tạo thêm quỹ') || e.code == 'MAX_FUNDS_EXCEEDED') {
        setState(() => _fundCountError = 'Không thể tạo thêm quỹ');
      } else {
        setState(() => _generalError = e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _generalError = 'Không thể tạo quỹ, vui lòng thử lại');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kIPhone18Width),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nút Trở về
                  BackLabel(
                    text: 'Trở về',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 12),

                  // Tiêu đề chức năng
                  const Text(
                    'Tạo quỹ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Khởi tạo quỹ tài chính cá nhân, cặp đôi, tích lũy hoặc hội nhóm',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Ngoại lệ 1.1: Người dùng đã làm chủ từ 10 quỹ trở lên (E1)
                  if (_fundCountError != null) ...[
                    ErrorMessage(message: _fundCountError!),
                    const SizedBox(height: 16),
                  ],

                  // Ngoại lệ 5.6: Người dùng chưa nhập đầy đủ thông tin (E8)
                  if (_generalError != null) ...[
                    ErrorMessage(message: _generalError!),
                    const SizedBox(height: 16),
                  ],

                  // 1. CHỌN LOẠI QUỸ
                  const Text(
                    'Loại quỹ *',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kFundTypes.map((type) {
                      final isSelected = _selectedFundType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: AppColors.lightBlue,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13.5,
                        ),
                        onSelected: _fundCountError != null
                            ? null
                            : (val) {
                                setState(() {
                                  _selectedFundType = val ? type : null;
                                  _fundTypeError = null;
                                  if (type != 'Cặp đôi') {
                                    _selectedPartner = null;
                                    _partnerError = null;
                                  }
                                  if (_generalError != null) _generalError = null;
                                });
                              },
                      );
                    }).toList(),
                  ),
                  // Thông báo lỗi E2 dưới phần chọn loại quỹ
                  if (_fundTypeError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _fundTypeError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12.5,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 2. TRƯỜNG THÔNG TIN TƯƠNG ỨNG THEO LOẠI QUỸ
                  // Theo Luồng con 3.1, 3.2, 3.3, 3.4: Khi chọn loại quỹ, hiển thị các trường tương ứng
                  if (_selectedFundType != null) ...[
                    // Tên quỹ (Bắt buộc cho mọi loại quỹ)
                    const Text(
                      'Tên quỹ *',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      enabled: _fundCountError == null,
                      maxLength: kMaxFundNameLength,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(kMaxFundNameLength),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Nhập tên quỹ (tối đa $kMaxFundNameLength ký tự)',
                        prefixIcon: const Icon(
                          Icons.drive_file_rename_outline_rounded,
                          color: AppColors.lightBlue,
                        ),
                        counterText: '${_nameController.text.length}/$kMaxFundNameLength',
                      ),
                      onChanged: (text) {
                        setState(() {
                          if (text.trim().isNotEmpty && _nameError != null) {
                            _nameError = null;
                          }
                          if (_generalError != null) _generalError = null;
                        });
                      },
                    ),
                    // Thông báo lỗi E3 ngay dưới ô nhập tên quỹ
                    if (_nameError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _nameError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12.5,
                        ),
                      ),
                    ],

                    // 3. QUỸ CẶP ĐÔI: bắt buộc chọn người dùng khác ngay từ lúc lập quỹ
                    if (_selectedFundType == 'Cặp đôi') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Người cùng lập quỹ *',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Quỹ cặp đôi chỉ có 2 người dùng. Người được chọn sẽ nhận lời mời và quỹ chính thức được lập khi họ đồng ý.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedPartner != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.lightBlue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.lightBlue
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  _selectedPartnerName.isNotEmpty
                                      ? _selectedPartnerName
                                          .substring(0, 1)
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.lightBlueDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedPartnerName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_selectedPartnerPhone.isNotEmpty)
                                      Text(
                                        _selectedPartnerPhone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                tooltip: 'Bỏ chọn',
                                onPressed: () => setState(() {
                                  _selectedPartner = null;
                                  _partnerError = null;
                                }),
                              ),
                            ],
                          ),
                        )
                      else
                        InkWell(
                          key: const ValueKey('pick_partner_button'),
                          onTap: _fundCountError != null ? null : _pickPartner,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _partnerError != null
                                    ? AppColors.error
                                    : AppColors.border,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.person_search_rounded,
                                  color: AppColors.lightBlue,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Chọn người dùng khác...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Thông báo lỗi E9 ngay dưới ô chọn người cùng lập quỹ
                      if (_partnerError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _partnerError!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],

                    // 3. Quỹ Tích lũy (Luồng con 3.3)
                    if (_selectedFundType == 'Tích lũy') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Số tiền mục tiêu *',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _targetAmountController,
                        enabled: _fundCountError == null,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Ví dụ: 10000000',
                          suffixText: 'VND',
                          prefixIcon: Icon(
                            Icons.monetization_on_outlined,
                            color: AppColors.lightBlue,
                          ),
                        ),
                        onChanged: (_) {
                          if (_targetAmountError != null) {
                            setState(() => _targetAmountError = null);
                          }
                          if (_generalError != null) {
                            setState(() => _generalError = null);
                          }
                        },
                      ),
                      // Thông báo lỗi E5 hoặc E6 ngay dưới ô nhập số tiền mục tiêu
                      if (_targetAmountError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _targetAmountError!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12.5,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Text(
                        'Ngày hoàn thành mục tiêu *',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _fundCountError != null ? null : _pickCompletionDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            hintText: 'Chọn ngày hoàn thành',
                            prefixIcon: Icon(
                              Icons.calendar_today_rounded,
                              color: AppColors.lightBlue,
                            ),
                            suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                          ),
                          child: Text(
                            _selectedCompletionDate != null
                                ? _formatDate(_selectedCompletionDate!)
                                : 'Chọn ngày hoàn thành mục tiêu',
                            style: TextStyle(
                              color: _selectedCompletionDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      // Thông báo lỗi E7 ngay dưới ô chọn ngày hoàn thành mục tiêu
                      if (_completionDateError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _completionDateError!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ],

                  const SizedBox(height: 30),

                  // Nút Tạo quỹ
                  AppButton(
                    text: 'Tạo quỹ',
                    isLoading: _isSubmitting,
                    onPressed: _fundCountError != null ? null : _handleSubmit,
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
