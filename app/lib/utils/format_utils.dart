/// Hàm định dạng tiền tệ VND: 0 -> '0 đ', 1000000 -> '1.000.000 đ'
String formatVnd(dynamic amount) {
  if (amount == null) return '0 đ';
  final n = num.tryParse(amount.toString()) ?? 0;
  final s = n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
  return '$s đ';
}
