import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chore_store.dart';

class ChoreLoggingScreen extends StatefulWidget {
  const ChoreLoggingScreen({super.key});

  @override
  State<ChoreLoggingScreen> createState() => _ChoreLoggingScreenState();
}

class _ChoreLoggingScreenState extends State<ChoreLoggingScreen>
    with TickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  Offset? _startGlobalPosition;
  Offset? _primaryOrigin;

  String _currentPrimary = 'center';

  Timer? _midnightTimer; // 表示更新用（データ削除しない）

  // record persistence key
  static const String _prefsKey = 'chore_logs_v1';

  // persisted records: each record is a map with keys:
  // { 'ts': int(millisecondsSinceEpoch), 'chore': String, 'dir': String?, 'count': int, 'label': String? }
  final List<Map<String, dynamic>> _records = [];

  // 各 chore をキーにして個別カウントやアクション定義をまとめる
  // 必須キー: label, up, right, left, down.
  // 各方向オブジェクトは { 'label': '...', 'count': n, optional 'cooldownMinutes': m } とする。
  // center は表示されないため定義していない。
  final Map<String, Map<String, dynamic>> _choreActionMap = {
    '朝ご飯': {
      'label': '朝ご飯',
      'up': {'label': '簡単に', 'count': 1},
      'right': {'label': 'しっかり', 'count': 3},
      'left': {'label': '片付け', 'count': 3},
      'down': {'label': '皿洗い', 'count': 5},
    },
    '昼ご飯': {
      'label': '昼ご飯',
      'up': {'label': '簡単に', 'count': 1},
      'right': {'label': 'しっかり', 'count': 3},
      'left': {'label': '片付け', 'count': 3},
      'down': {'label': '皿洗い', 'count': 5},
    },
    '夜ご飯': {
      'label': '夜ご飯',
      'up': {'label': '簡単に', 'count': 3},
      'right': {'label': 'しっかり', 'count': 5},
      'left': {'label': '片付け', 'count': 3},
      'down': {'label': '皿洗い', 'count': 7},
    },
    '掃除': {
      'label': '掃除',
      'up': {'label': '部分掃除', 'count': 2},
      'right': {'label': '掃除機', 'count': 3},
      'left': {'label': '拭き掃除', 'count': 4},
      'down': {'label': 'その他', 'count': 5},
    },
    'キッチン': {
      'label': 'キッチン',
      'up': {'label': '部分清掃', 'count': 2},
      'right': {'label': 'シンク掃除', 'count': 3, 'cooldownMinutes': 180},
      'left': {'label': '床拭き', 'count': 4},
      'down': {'label': 'その他', 'count': 5},
    },

    '洗面所': {
      'label': '洗面所',
      'up': {'label': '鏡磨き', 'count': 1},
      'right': {'label': '掃除', 'count': 2},
      'left': {'label': '整理', 'count': 2},
      'down': {'label': 'その他', 'count': 3},
    },
    '風呂準備': {
      'label': '風呂準備',
      'up': {'label': 'お湯を抜いた', 'count': 1},
      'right': {'label': '浴槽を洗った', 'count': 2},
      'left': {'label': '浴室を洗った', 'count': 2},
      'down': {'label': 'お湯を張った', 'count': 3},
    },
    '洗濯物': {
      'label': '洗濯物',
      'up': {'label': '洗濯機', 'count': 2},
      'right': {'label': '干した', 'count': 10},
      'left': {'label': '畳んだ', 'count': 5},
      'down': {'label': '収納した', 'count': 1},
    },

    'ゴミ出し': {
      'label': 'ゴミ出し',
      'up': {'label': '集めて回った', 'count': 1},
      'right': {'label': '袋をセットした', 'count': 1},
      'left': {'label': '置き場場に持って行った', 'count': 1},
      'down': {'label': 'その他', 'count': 2},
    },
    '買い物': {
      'label': '買い物',
      'up': {'label': '少量', 'count': 1},
      'right': {'label': '通常', 'count': 2},
      'left': {'label': 'まとめ買い', 'count': 5},
      'down': {'label': 'その他', 'count': 1},
    },
    'ペットの世話': {
      'label': 'ペットの世話',
      'up': {'label': '餌', 'count': 1},
      'right': {'label': '散歩', 'count': 1},
      'left': {'label': '掃除', 'count': 2},
      'down': {'label': 'その他', 'count': 1},
    },
  };

  // 最後に実行した時刻を保持する（キー: 'chore|dir'）
  final Map<String, DateTime> _lastPerformed = {};

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? <String>[];
    _records.clear();
    for (var s in list) {
      try {
        final m = json.decode(s) as Map<String, dynamic>;
        _records.add(m);
      } catch (_) {
        // ignore malformed
      }
    }
    _rebuildCountsFromRecords();
    _rebuildLastPerformedFromRecords();
    setState(() {});
  }

  Future<void> _persistRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _records.map((m) => json.encode(m)).toList();
    await prefs.setStringList(_prefsKey, list);
  }

  void _rebuildCountsFromRecords() {
    // reset counts in local choreActionMap
    for (final k in _choreActionMap.keys) {
      // keep the original base label, but reset displayed count to 0
      final entry = _choreActionMap[k];
      if (entry != null) {
        entry['count'] = 0;
      }
    }
    for (final r in _records) {
      final chore = r['chore'] as String?;
      final cnt = (r['count'] is int)
          ? r['count'] as int
          : int.tryParse('${r['count']}') ?? 0;
      if (chore != null && _choreActionMap.containsKey(chore)) {
        final entry = _choreActionMap[chore];
        if (entry != null) {
          final current = entry['count'] is int ? entry['count'] as int : 0;
          entry['count'] = current + cnt;
        }
      }
    }
  }

  void _rebuildLastPerformedFromRecords() {
    _lastPerformed.clear();
    for (final r in _records) {
      final chore = r['chore'] as String?;
      final dir = r['dir'] as String?;
      final ts = r['ts'] is int
          ? r['ts'] as int
          : int.tryParse('${r['ts']}') ?? 0;
      if (chore != null && dir != null) {
        final cd = _cooldownMinutes(chore, dir);
        if (cd != null && cd > 0) {
          final key = '$chore|$dir';
          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
          final prev = _lastPerformed[key];
          if (prev == null || dt.isAfter(prev)) {
            _lastPerformed[key] = dt;
          }
        }
      }
    }
  }

  DateTime _todayMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int _todayTotalPoints() {
    final mid = _todayMidnight();
    var sum = 0;
    for (final r in _records) {
      final ts = r['ts'] is int
          ? r['ts'] as int
          : int.tryParse('${r['ts']}') ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (!dt.isBefore(mid)) {
        final cnt = (r['count'] is int)
            ? r['count'] as int
            : int.tryParse('${r['count']}') ?? 0;
        sum += cnt;
      }
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    // top-right display + main buttons + bottom log list
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // header: today's total on the right
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    '本日の獲得予定ポイント：${_todayTotalPoints()} p',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // main button area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  direction: Axis.horizontal,
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _choreActionMap.keys
                      .map((chore) => _buildChoreButton(chore))
                      .toList(),
                ),
              ),
            ),
            // bottom logs: fixed height showing ~5 rows, vertically scrollable
            Container(
              height: 200, // 約5行分（調整可）
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '履歴',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, size: 20),
                          tooltip: '全件削除',
                          onPressed: _records.isEmpty
                              ? null
                              : () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('全ての履歴を削除しますか？'),
                                      content: const Text(
                                        'この操作は取り消せません。よろしいですか？',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('削除'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    _records.clear();
                                    await _persistRecords();
                                    _rebuildCountsFromRecords();
                                    _rebuildLastPerformedFromRecords();
                                    setState(() {});
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _todayRecords.isEmpty
                        ? const Center(child: Text('まだ記録がありません'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: _todayRecords.length,
                            itemBuilder: (context, idx) {
                              // show newest first (当日分のみ)
                              final i = _todayRecords.length - 1 - idx;
                              final r = _todayRecords[i];
                              final ts = r['ts'] is int
                                  ? r['ts'] as int
                                  : int.tryParse('${r['ts']}') ?? 0;
                              final dt = DateTime.fromMillisecondsSinceEpoch(
                                ts,
                              );
                              final hh = dt.hour.toString().padLeft(2, '0');
                              final mm = dt.minute.toString().padLeft(2, '0');
                              final timeText = '$hh:$mm';
                              final chore = r['chore']?.toString() ?? '';
                              final actionLabel = r['label']?.toString() ?? '';
                              final displayText = actionLabel.isNotEmpty
                                  ? '$chore : $actionLabel'
                                  : chore;

                              final cnt = r['count'] is int
                                  ? r['count'] as int
                                  : int.tryParse('${r['count']}') ?? 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 64,
                                      child: Text(
                                        timeText,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        displayText,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      '+$cnt p',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      // 削除は元の _records インデックスを再計算する
                                      onPressed: () {
                                        final originalIndex = _records.indexOf(
                                          r,
                                        );
                                        if (originalIndex != -1) {
                                          _confirmDeleteRecord(originalIndex);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoreButton(String chore) {
    final count = _choreActionMap[chore]?['count'] ?? 0;
    return GestureDetector(
      onTap: null,
      onLongPressStart: (details) {
        _primaryOrigin = details.globalPosition;
        _startGlobalPosition = details.globalPosition;
        _currentPrimary = 'center';
        _showFlickMenu(details.globalPosition, chore);
      },
      onLongPressMoveUpdate: (details) {
        if (_startGlobalPosition == null) return;
        _handleFlickMove(details.globalPosition, chore);
      },
      onLongPressEnd: (details) {
        _finalizeFlick(chore, details.globalPosition);
        _hideFlickMenu();
        _startGlobalPosition = null;
        _currentPrimary = 'center';
        _primaryOrigin = null;
      },
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text(chore), const SizedBox(height: 4)],
        ),
      ),
    );
  }

  void _handleFlickMove(Offset currentGlobal, String chore) {
    final origin = _primaryOrigin ?? _startGlobalPosition!;
    final primaryDir = _calcDirection(origin, currentGlobal);
    if (primaryDir != _currentPrimary) {
      _currentPrimary = primaryDir;
      _overlayEntry?.markNeedsBuild();
    }
  }

  String _calcDirection(Offset origin, Offset current) {
    final dx = current.dx - origin.dx;
    final dy = current.dy - origin.dy;
    const threshold = 18;
    if (dx.abs() < threshold && dy.abs() < threshold) return 'center';
    if (dx.abs() > dy.abs()) return dx > 0 ? 'right' : 'left';
    return dy > 0 ? 'down' : 'up';
  }

  // cooldown utilities
  int? _cooldownMinutes(String chore, String dir) {
    final entry = _choreActionMap[chore]?[dir];
    if (entry == null) return null;
    final v = entry['cooldownMinutes'];
    return v is int ? v : null;
  }

  Duration? _remainingCooldown(String chore, String dir) {
    final minutes = _cooldownMinutes(chore, dir);
    if (minutes == null) return null;
    final key = '$chore|$dir';
    final last = _lastPerformed[key];
    if (last == null) return null;
    final expiry = last.add(Duration(minutes: minutes));
    final now = DateTime.now();
    if (expiry.isAfter(now)) return expiry.difference(now);
    return null;
  }

  bool _isOnCooldown(String chore, String dir) {
    return _remainingCooldown(chore, dir) != null;
  }

  String _formatRemaining(Duration d) {
    final minutes = d.inMinutes;
    if (minutes < 60) return '${minutes}分後に解放';
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    if (remMin == 0) return '${hours}時間後に解放';
    return '${hours}時間${remMin}分後に解放';
  }

  void _finalizeFlick(String chore, Offset? globalPosition) {
    final dir = _currentPrimary;
    if (dir == 'center') {
      return;
    }

    // 指定方向のエントリと count を取得（必須）
    final dirEntry = _choreActionMap[chore]?[dir];
    final dirCount = (dirEntry != null && dirEntry['count'] is int)
        ? dirEntry['count'] as int
        : null;

    if (dirCount == null) {
      return;
    }

    // cooldown 判定
    final remaining = _remainingCooldown(chore, dir);
    if (remaining != null) {
      // クールダウン中は「ポップアップ（浮かび上がるメッセージ）」を出さない。
      // 代わりにオーバーレイを再描画してグレー表示＋残り時間をオプション上に表示する。
      _overlayEntry?.markNeedsBuild();
      return; // カウントは加算しない
    }

    // 通常はアニメ表示してカウント増加
    if (globalPosition != null) {
      final text = dirCount == 5 ? '+5以上' : '+$dirCount';
      _showFloatingCount(globalPosition, text);
    }

    _recordChore(
      chore,
      dirCount,
      actionLabel: dirEntry['label']?.toString(),
      dir: dir,
    );
  }

  void _recordChore(
    String chore,
    int? count, {
    String? actionLabel,
    String? dir,
  }) async {
    final delta = count ?? 1;

    // persist record
    final rec = <String, dynamic>{
      'ts': DateTime.now().millisecondsSinceEpoch,
      'chore': chore,
      'dir': dir,
      'count': delta,
      'label': actionLabel,
    };
    _records.add(rec);
    await _persistRecords();

    // ローカル表示更新
    setState(() {
      final entry = _choreActionMap[chore];
      if (entry != null) {
        final current = entry['count'] is int ? entry['count'] as int : 0;
        entry['count'] = current + delta;
      }
    });

    // Provider 経由でグローバルに蓄積
    context.read<ChoreStore>().increment(chore, delta);

    // cooldown が設定されていれば lastPerformed を更新して以降の入力をロック
    if (dir != null) {
      final cd = _cooldownMinutes(chore, dir);
      if (cd != null && cd > 0) {
        final key = '$chore|$dir';
        _lastPerformed[key] = DateTime.now();
        // overlay の再描画で灰色表示する
        _overlayEntry?.markNeedsBuild();
      }
    }

    // ignore: avoid_print
    print(
      '$chore を記録しました: +$delta ${actionLabel ?? ''} (local=${_choreActionMap[chore]?['count']}, global=${context.read<ChoreStore>().getCount(chore)})',
    );
    setState(() {}); // update header total and logs
  }

  void _showFloatingCount(Offset globalPosition, String text) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );

    OverlayEntry entry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = animation.value;
            final dy = -40.0 * t;
            final opacity = (1.0 - t).clamp(0.0, 1.0);
            final screenW = MediaQuery.of(context).size.width;
            final screenH = MediaQuery.of(context).size.height;
            double left = globalPosition.dx - 20;
            double top = globalPosition.dy - 20 + dy;
            left = left.clamp(8.0, screenW - 64.0);
            top = top.clamp(8.0, screenH - 64.0);
            return Positioned(
              left: left,
              top: top,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    overlay.insert(entry);
    controller.forward();
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        entry.remove();
        controller.dispose();
      }
    });
  }

  void _showFlickMenu(Offset globalPosition, String chore) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) {
        const double size = 160;
        final left = globalPosition.dx - size / 2;
        final top = globalPosition.dy - size / 2;
        return Positioned(
          left: left.clamp(8.0, MediaQuery.of(context).size.width - size - 8.0),
          top: top.clamp(8.0, MediaQuery.of(context).size.height - size - 8.0),
          width: size,
          height: size,
          child: Material(
            color: Colors.transparent,
            child: StatefulBuilder(
              builder: (context, setStateOverlay) {
                return _buildFlickMenuContent(size, chore);
              },
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildFlickMenuContent(double size, String chore) {
    final itemSize = 54.0;
    final center = size / 2 - itemSize / 2;

    final primaryUpSelected = _currentPrimary == 'up';
    final primaryRightSelected = _currentPrimary == 'right';
    final primaryLeftSelected = _currentPrimary == 'left';
    final primaryDownSelected = _currentPrimary == 'down';

    List<Widget> stack = [
      Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black12.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // 上
      _buildOptionWidget('up', chore, center, itemSize, primaryUpSelected),
      // 右
      _buildOptionWidget(
        'right',
        chore,
        center,
        itemSize,
        primaryRightSelected,
      ),
      // 左
      _buildOptionWidget('left', chore, center, itemSize, primaryLeftSelected),
      // 下
      _buildOptionWidget('down', chore, center, itemSize, primaryDownSelected),
    ];

    // 親 Stack の clip を解除して、子の Positioned が外にはみ出して描画できるようにする
    return Stack(children: stack, clipBehavior: Clip.none);
  }

  Positioned _buildOptionWidget(
    String dir,
    String chore,
    double center,
    double itemSize,
    bool selected,
  ) {
    final label = _labelFor(chore, dir);
    final rem = _remainingCooldown(chore, dir);
    final disabled = rem != null;
    // 選択中かつクールダウン中なら subLabel を表示
    final subLabel = (disabled && selected) ? _formatRemaining(rem!) : null;

    final left =
        (dir == 'left'
                ? center - 48
                : dir == 'right'
                ? center + 48
                : center)
            .clamp(0.0, double.infinity);
    final top =
        (dir == 'up'
                ? center - 48
                : dir == 'down'
                ? center + 48
                : center)
            .clamp(0.0, double.infinity);

    final bgColor = disabled
        ? (selected ? Colors.grey.shade400 : Colors.grey.shade300)
        : (selected ? Colors.blueAccent : Colors.white);
    final textColor = disabled
        ? Colors.black54
        : (selected ? Colors.white : Colors.black87);

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: itemSize,
              height: itemSize,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
                boxShadow: (!disabled && selected)
                    ? const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _shortLabel(label),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor,
                      fontWeight: selected && !disabled
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
            // subLabel をボタンの上に重ねて表示（円の外上方ではなく被せる）
            if (subLabel != null)
              // ボタン中央に重ね、少し上に移動させて被せる
              Positioned(
                top: itemSize * 0.12,
                child: FractionalTranslation(
                  translation: const Offset(0, -0.35),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: itemSize * 1.3),
                      child: Text(
                        subLabel,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _labelFor(String chore, String dir) {
    final map = _choreActionMap[chore];
    if (map != null && map[dir] != null && map[dir]['label'] != null) {
      return map[dir]['label'].toString();
    }
    switch (dir) {
      case 'up':
        return '上';
      case 'right':
        return '右';
      case 'left':
        return '左';
      case 'down':
        return '下';
      default:
        return '';
    }
  }

  String _shortLabel(String label) {
    if (label.length <= 4) return label;
    return label.substring(0, 4);
  }

  void _hideFlickMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _confirmDeleteRecord(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('この記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // delete and rebuild counts/cooldowns
    if (index >= 0 && index < _records.length) {
      _records.removeAt(index);
      await _persistRecords();
      _rebuildCountsFromRecords();
      _rebuildLastPerformedFromRecords();
      setState(() {});
      _overlayEntry?.markNeedsBuild();
    }
  }

  // 当日分のみを抽出（表示専用）
  List<Map<String, dynamic>> get _todayRecords {
    final mid = _todayMidnight();
    return _records.where((r) {
      final ts = r['ts'] is int
          ? r['ts'] as int
          : int.tryParse('${r['ts']}') ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      return !dt.isBefore(mid);
    }).toList();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now) + const Duration(seconds: 1);
    _midnightTimer = Timer(duration, () {
      // 0時を跨いだらUIを再構築（records自体は保持）
      setState(() {});
      _scheduleMidnightRefresh(); // 次の日も再スケジュール
    });
  }
}
