import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  Offset? _secondaryOrigin;
  // 判定用しきい値
  static const double _primaryReturnRadius = 28.0;
  static const double _primarySwitchDistance = 56.0;

  // 2段階フリック用状態（現在はサブメニューなし）
  int _flickStage = 0; // 0 = primary
  String _currentPrimary = 'center';
  String _currentSecondary = 'center';
  String? _selectedPrimaryDir;

  // 各 chore をキーにして個別カウントやアクション定義をまとめる
  // 必須キー: label, up, right, left, down. 各方向オブジェクトは { 'label': '...', 'count': n } とする。
  // center は存在してもよいが、center 選択ではカウントアップしない。
  final Map<String, Map<String, dynamic>> _choreActionMap = {
    '掃除': {
      'label': '掃除',

      'up': {'label': '部分掃除', 'count': 2},
      'right': {'label': '掃除機', 'count': 3},
      'left': {'label': '拭き掃除', 'count': 4},
      'down': {'label': 'その他', 'count': 5},
    },
    '朝ご飯': {
      'label': '朝ご飯',

      'up': {'label': '簡単に', 'count': 1},
      'right': {'label': 'しっかり', 'count': 2},
      'left': {'label': '片付け', 'count': 1},
      'down': {'label': 'その他', 'count': 3},
    },
    'キッチン': {
      'label': 'キッチン',

      'up': {'label': '部分清掃', 'count': 2},
      'right': {'label': 'シンク掃除', 'count': 3},
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
    '玄関の靴を揃えた': {
      'label': '玄関の靴を揃えた',

      'up': {'label': '片付け', 'count': 1},
      'right': {'label': '整列', 'count': 1},
      'left': {'label': '掃除', 'count': 2},
      'down': {'label': 'その他', 'count': 3},
    },
    '洗濯物': {
      'label': '洗濯物',

      'up': {'label': 'しまった', 'count': 2},
      'right': {'label': '干した', 'count': 10},
      'left': {'label': '畳んだ', 'count': 5},
      'down': {'label': 'その他', 'count': 1},
    },
    '洗濯機を回した': {
      'label': '洗濯機を回した',

      'up': {'label': '短', 'count': 1},
      'right': {'label': '通常', 'count': 1},
      'left': {'label': '長', 'count': 2},
      'down': {'label': 'その他', 'count': 1},
    },
    'ゴミ出し': {
      'label': 'ゴミ出し',

      'up': {'label': '可燃', 'count': 1},
      'right': {'label': '不燃', 'count': 1},
      'left': {'label': '資源', 'count': 1},
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        direction: Axis.horizontal,
        spacing: 8.0,
        runSpacing: 8.0,
        children: _choreActionMap.keys
            .map((chore) => _buildChoreButton(chore))
            .toList(),
      ),
    );
  }

  Widget _buildChoreButton(String chore) {
    final count = _choreActionMap[chore]?['count'] ?? 0;
    return GestureDetector(
      onTap: () {
        // 短押しは従来どおり 1 カウント（必要なら挙動変更可）
        _recordChore(chore, 1, actionLabel: 'tap');
      },
      onLongPressStart: (details) {
        _primaryOrigin = details.globalPosition;
        _startGlobalPosition = details.globalPosition;
        _flickStage = 0;
        _currentPrimary = 'center';
        _currentSecondary = 'center';
        _selectedPrimaryDir = null;
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
        _flickStage = 0;
        _currentPrimary = 'center';
        _currentSecondary = 'center';
        _selectedPrimaryDir = null;
        _primaryOrigin = null;
        _secondaryOrigin = null;
      },
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(chore),
            const SizedBox(height: 4),
            Text(
              '${count}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  void _handleFlickMove(Offset currentGlobal, String chore) {
    // サブメニューは廃止したので一次判定のみ（center/up/right/left/down）
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

  void _finalizeFlick(String chore, Offset? globalPosition) {
    final dir = _currentPrimary;
    // center はカウントアップしない
    if (dir == 'center') {
      // 必要ならここで別の UI を出す（例: ラベル表示） — 今は何もしない
      return;
    }

    // マップから指定方向の count を取得（必須）
    final dirEntry = _choreActionMap[chore]?[dir];
    final dirCount = (dirEntry != null && dirEntry['count'] is int)
        ? dirEntry['count'] as int
        : null;

    if (dirCount == null) {
      // 指定方向に count が無い場合は無視
      return;
    }

    // アニメ表示
    if (globalPosition != null) {
      final text = dirCount == 5 ? '+5以上' : '+$dirCount';
      _showFloatingCount(globalPosition, text);
    }

    _recordChore(chore, dirCount, actionLabel: dirEntry['label']?.toString());
  }

  void _recordChore(String chore, int? count, {String? actionLabel}) {
    final delta = count ?? 1;
    setState(() {
      final entry = _choreActionMap[chore];
      if (entry != null) {
        final current = entry['count'] is int ? entry['count'] as int : 0;
        entry['count'] = current + delta;
      }
    });

    // Provider 経由でグローバルに蓄積
    context.read<ChoreStore>().increment(chore, delta);

    // ignore: avoid_print
    print(
      '$chore を記録しました: +$delta ${actionLabel ?? ''} (local=${_choreActionMap[chore]?['count']}, global=${context.read<ChoreStore>().getCount(chore)})',
    );
  }

  // フリック確定時に指の近くで浮かび上がるアニメーション表示
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
        const double size = 140;
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
    final itemSize = 44.0;
    final center = size / 2 - itemSize / 2;

    Widget option(String dir, String label, {bool selected = false}) {
      return Positioned(
        left: dir == 'left'
            ? center - 48
            : dir == 'right'
            ? center + 48
            : center,
        top: dir == 'up'
            ? center - 48
            : dir == 'down'
            ? center + 48
            : center,
        child: Container(
          width: itemSize,
          height: itemSize,
          decoration: BoxDecoration(
            color: selected ? Colors.blueAccent : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
            boxShadow: selected
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
          child: Tooltip(
            message: label,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                _shortLabel(label),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // center は表示しないため center 選択フラグは作らない（ハイライトされない）
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
      // center を含めず、上下左右のみ表示
      option('up', _labelFor(chore, 'up'), selected: primaryUpSelected),
      option(
        'right',
        _labelFor(chore, 'right'),
        selected: primaryRightSelected,
      ),
      option('left', _labelFor(chore, 'left'), selected: primaryLeftSelected),
      option('down', _labelFor(chore, 'down'), selected: primaryDownSelected),
    ];

    return Stack(children: stack);
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
      case 'center':
      default:
        return '中';
    }
  }

  Offset _offsetForPrimary(String dir, double center) {
    final dx = dir == 'left'
        ? center - 48
        : dir == 'right'
        ? center + 48
        : center;
    final dy = dir == 'up'
        ? center - 48
        : dir == 'down'
        ? center + 48
        : center;
    return Offset(dx, dy);
  }

  String _shortLabel(String label) {
    if (label.length <= 4) return label;
    return label.substring(0, 4);
  }

  void _hideFlickMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
