import 'package:flutter/material.dart';

class ChoreLoggingScreen extends StatefulWidget {
  const ChoreLoggingScreen({super.key});

  @override
  State<ChoreLoggingScreen> createState() => _ChoreLoggingScreenState();
}

class _ChoreLoggingScreenState extends State<ChoreLoggingScreen> {
  final List<String> _basicChores = [
    '掃除',
    'ご飯を作った',
    'キッチン',
    '洗面所',
    '玄関の靴を揃えた',
    '洗濯機を回した',
    '洗濯物',
    'ゴミ出し',
    '買い物',
    'ペットの世話',
  ];

  OverlayEntry? _overlayEntry;
  Offset? _startGlobalPosition;
  Offset? _primaryOrigin;
  Offset? _secondaryOrigin;
  // 判定用しきい値
  static const double _primaryReturnRadius = 28.0; // 中心に戻ったと見なす距離
  static const double _primarySwitchDistance = 56.0; // 別の一次方向へ切り替えるのに必要な距離

  // 2段階フリック用状態
  int _flickStage = 0; // 0 = primary, 1 = secondary
  String _currentPrimary = 'center';
  String _currentSecondary = 'center';
  String? _selectedPrimaryDir; // primaryで選ばれ、submenuがある場合にセット

  // chore-specific action mapping (例として "洗濯物" に二段目を用意)
  // primary keys: 'center','up','right','left','down'
  // value: either {'label': '...'} or {'label': '...', 'submenu': { 'up': {...}, 'down': {...} ... }}
  final Map<String, Map<String, dynamic>> _choreActionMap = {
    '洗濯物': {
      'center': {'label': '1回分（既定）'},
      'right': {
        'label': '干した',
        'submenu': {
          'up': {'count': 10, 'label': '10枚以上'},
          'down': {'count': 20, 'label': '20枚以上'},
        },
      },
      'left': {'label': '畳んだ'}, // サブメニューなし
      'up': {
        'label': 'しまった',
        'submenu': {
          'right': {'count': 10, 'label': '8枚以上'},
          'left': {'count': 20, 'label': '16枚以上'},
        },
      },
      'down': {'label': 'その他'},
    },
    // 他の家事はデフォルトの一次のみ（center/dirs -> label）
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        direction: Axis.horizontal,
        spacing: 8.0,
        runSpacing: 8.0,
        children: _basicChores
            .map((chore) => _buildChoreButton(chore))
            .toList(),
      ),
    );
  }

  Widget _buildChoreButton(String chore) {
    return GestureDetector(
      onTap: () {
        // 短押しは1部屋（もしくはデフォルト動作）
        _recordChore(chore, 1, actionLabel: 'short tap');
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
        // 確定処理
        _finalizeFlick(chore);
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
        child: Text(chore),
      ),
    );
  }

  void _handleFlickMove(Offset currentGlobal, String chore) {
    if (_flickStage == 0) {
      // primary 判定は possible primary origin（長押し開始）を優先して使う
      final origin = _primaryOrigin ?? _startGlobalPosition!;
      final primaryDir = _calcDirection(origin, currentGlobal);
      if (primaryDir != _currentPrimary) {
        _currentPrimary = primaryDir;
        // primary が submenu を持っていれば stage を 1 に遷移して基準をリセット
        final primaryHasSub = _hasSubmenu(chore, primaryDir);
        if (primaryHasSub && primaryDir != 'center') {
          _flickStage = 1;
          _selectedPrimaryDir = primaryDir;
          // ここから二次フリックを測るため、secondary origin を今の位置にリセット
          _secondaryOrigin = currentGlobal;
          // primaryOrigin は保持（戻る判定のため）
          // 二次判定用に startGlobalPosition を secondaryOrigin に合わせておく
          _startGlobalPosition = _secondaryOrigin;
          _currentSecondary = 'center';
        } else {
          // 二次オフセットが残っていたらクリア（一次に留まる場合）
          _secondaryOrigin = null;
        }
        _overlayEntry?.markNeedsBuild();
      }
    } else {
      // stage == 1 : secondary の判定（secondaryOrigin を基準）
      final secOrigin = _secondaryOrigin ?? _startGlobalPosition!;
      final secondaryDir = _calcDirection(secOrigin, currentGlobal);

      // 改良: currentGlobal が再び一次起点（primaryOrigin）側へ移動した場合は一次に戻す判定を厳しくする
      if (_primaryOrigin != null) {
        final vecFromPrimary = currentGlobal - _primaryOrigin!;
        final distFromPrimary = vecFromPrimary.distance;

        // 1) 明確に中心に戻った（小さい距離） -> 一次に戻す
        if (distFromPrimary <= _primaryReturnRadius) {
          _flickStage = 0;
          _currentPrimary = 'center';
          _selectedPrimaryDir = null;
          _secondaryOrigin = null;
          _currentSecondary = 'center';
          _startGlobalPosition = _primaryOrigin;
          _overlayEntry?.markNeedsBuild();
          return;
        }

        // 2) 十分に離れていて、一次方向が明確に変わった（かつ距離がある）場合のみ一次切替を許可
        final primaryFromPrimaryOrigin = _calcDirection(
          _primaryOrigin!,
          currentGlobal,
        );
        if (primaryFromPrimaryOrigin != _selectedPrimaryDir &&
            distFromPrimary >= _primarySwitchDistance) {
          _flickStage = 0;
          _currentPrimary = primaryFromPrimaryOrigin;
          _selectedPrimaryDir = null;
          _secondaryOrigin = null;
          _currentSecondary = 'center';
          _startGlobalPosition = _primaryOrigin;
          _overlayEntry?.markNeedsBuild();
          return;
        }
      }

      if (secondaryDir != _currentSecondary) {
        _currentSecondary = secondaryDir;
        _overlayEntry?.markNeedsBuild();
      }
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

  bool _hasSubmenu(String chore, String primaryDir) {
    final map = _choreActionMap[chore];
    if (map == null) return false;
    final entry = map[primaryDir];
    if (entry == null) return false;
    return entry['submenu'] != null;
  }

  void _finalizeFlick(String chore) {
    // 二段階があれば二次選択を優先して処理
    if (_flickStage == 1 && _selectedPrimaryDir != null) {
      final primaryMap = _choreActionMap[chore]?[_selectedPrimaryDir!];
      if (primaryMap != null && primaryMap['submenu'] != null) {
        final submenu = Map<String, dynamic>.from(primaryMap['submenu']);
        final sec = submenu[_currentSecondary] ?? submenu['center'];
        if (sec != null) {
          final label =
              sec['label']?.toString() ??
              primaryMap['label']?.toString() ??
              chore;
          final count = sec['count'] is int ? sec['count'] as int : null;
          _recordChore(
            chore,
            count ?? _directionToCount(_selectedPrimaryDir!),
            actionLabel: '${primaryMap['label']} → $label',
          );
          return;
        }
      }
    }

    // 二段階でない場合やサブが無い場合は一次のみで処理
    final primaryLabel = _choreActionMap[chore]?[_currentPrimary]?['label'];
    if (primaryLabel != null) {
      // 一次ラベルがあれば使う
      _recordChore(
        chore,
        _directionToCount(_currentPrimary),
        actionLabel: primaryLabel.toString(),
      );
    } else {
      // デフォルト: 一次方向から部屋数にマップ
      final count = _directionToCount(_currentPrimary);
      _recordChore(chore, count);
    }
  }

  int _directionToCount(String dir) {
    switch (dir) {
      case 'up':
        return 2;
      case 'right':
        return 3;
      case 'left':
        return 4;
      case 'down':
        return 5;
      case 'center':
      default:
        return 1;
    }
  }

  void _recordChore(String chore, int? count, {String? actionLabel}) {
    // 実際は DB や state 更新へ接続してください
    final labelCount = (count == null) ? '' : (count == 5 ? '5以上' : '$count');
    final labelAction = actionLabel != null ? ' / $actionLabel' : '';
    print('$chore を記録しました: $labelCount 部屋$labelAction');
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
                // Overlay 内での描画は親 State のプロパティを参照する（markNeedsBuildで更新）
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
                ? [
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

    // Primary options
    final primaryUpSelected = _currentPrimary == 'up' && _flickStage == 0;
    final primaryRightSelected = _currentPrimary == 'right' && _flickStage == 0;
    final primaryLeftSelected = _currentPrimary == 'left' && _flickStage == 0;
    final primaryDownSelected = _currentPrimary == 'down' && _flickStage == 0;
    final primaryCenterSelected =
        _currentPrimary == 'center' && _flickStage == 0;

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
      option('up', _labelFor(chore, 'up'), selected: primaryUpSelected),
      option(
        'right',
        _labelFor(chore, 'right'),
        selected: primaryRightSelected,
      ),
      option('left', _labelFor(chore, 'left'), selected: primaryLeftSelected),
      option('down', _labelFor(chore, 'down'), selected: primaryDownSelected),
      option(
        'center',
        _labelFor(chore, 'center'),
        selected: primaryCenterSelected,
      ),
    ];

    // 二次ステージなら、選んだ primary の周りにサブオプションを描画
    if (_flickStage == 1 && _selectedPrimaryDir != null) {
      final primaryMap = _choreActionMap[chore]?[_selectedPrimaryDir!];
      final submenu = primaryMap != null
          ? primaryMap['submenu'] as Map<String, dynamic>?
          : null;
      if (submenu != null) {
        final secCenterOffset = _offsetForPrimary(_selectedPrimaryDir!, center);
        submenu.forEach((secDir, secVal) {
          final secSelected = _currentSecondary == secDir;
          final left =
              (secCenterOffset.dx +
                      (secDir == 'left'
                          ? -48
                          : secDir == 'right'
                          ? 48
                          : 0))
                  .clamp(0.0, size - itemSize);
          final top =
              (secCenterOffset.dy +
                      (secDir == 'up'
                          ? -48
                          : secDir == 'down'
                          ? 48
                          : 0))
                  .clamp(0.0, size - itemSize);
          stack.add(
            Positioned(
              left: left,
              top: top,
              child: Container(
                width: itemSize,
                height: itemSize,
                decoration: BoxDecoration(
                  color: secSelected ? Colors.orangeAccent : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
                alignment: Alignment.center,
                child: Tooltip(
                  message: secVal['label']?.toString() ?? secDir,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      _shortLabel(secVal['label']?.toString() ?? secDir),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: secSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      }
    }

    return Stack(children: stack);
  }

  // primary 方向に対応するラベル（chore固有の一次ラベルがあれば優先）
  String _labelFor(String chore, String dir) {
    final map = _choreActionMap[chore];
    if (map != null && map[dir] != null && map[dir]['label'] != null) {
      return map[dir]['label'].toString();
    }
    switch (dir) {
      case 'up':
        return '2部屋';
      case 'right':
        return '3部屋';
      case 'left':
        return '4部屋';
      case 'down':
        return '5以上';
      case 'center':
      default:
        return '1部屋';
    }
  }

  Offset _offsetForPrimary(String dir, double center) {
    // center は size/2 - itemSize/2 を受け取る。返すは dx,dy。
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
