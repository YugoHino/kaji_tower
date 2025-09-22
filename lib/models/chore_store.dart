import 'package:flutter/foundation.dart';

class ChoreStore extends ChangeNotifier {
  ChoreStore._internal();
  static final ChoreStore instance = ChoreStore._internal();

  // 各 chore の累積 count を保持
  final Map<String, int> _counts = {};

  // 現在の全 counts を返す（コピー）
  Map<String, int> getAllCounts() => Map<String, int>.from(_counts);

  int getCount(String chore) => _counts[chore] ?? 0;

  // 指定 chore を delta 分増やす（存在しなければ作成）
  void increment(String chore, int delta) {
    final cur = _counts[chore] ?? 0;
    _counts[chore] = cur + delta;
    notifyListeners();
  }

  // 直接セット（必要なら）
  void setCount(String chore, int value) {
    _counts[chore] = value;
    notifyListeners();
  }

  // JSON 用の簡易シリアライズ/復元（任意）
  Map<String, dynamic> toJson() => _counts.map((k, v) => MapEntry(k, v));
  void fromJson(Map<String, dynamic> json) {
    _counts.clear();
    json.forEach((k, v) {
      final iv = v is int ? v : int.tryParse('$v') ?? 0;
      _counts[k] = iv;
    });
    notifyListeners();
  }
}
