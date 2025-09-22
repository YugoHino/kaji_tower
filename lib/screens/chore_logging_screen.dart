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

  // 2段階フリック用状態
  int _flickStage = 0; // 0 = primary, 1 = secondary
  String _currentPrimary = 'center';
  String _currentSecondary = 'center';
  String? _selectedPrimaryDir; // primaryで選ばれ、submenuがある場合にセット

  // 各 chore をキーにして個別カウントやアクション定義をまとめる
  // 'count' が各家事の独立した累積値になります。
  final Map<String, Map<String, dynamic>> _choreActionMap = {
    '掃除': {
      'label': '掃除',
      'count': 0,
      'center': {'label': '1回分（既定）'},
      'up': {'label': '部分掃除'},
      'right': {'label': '掃除機'},
      'left': {'label': '拭き掃除'},
      'down': {'label': 'その他'},
    },
    'ご飯を作った': {
      'label': 'ご飯を作った',
      'count': 0,
      'center': {'label': '1回分'},
    },
    'キッチン': {
      'label': 'キッチン',
      'count': 0,
      'center': {'label': '1回分'},
    },
    '洗面所': {
      'label': '洗面所',
      'count': 0,
      'center': {'label': '1回分'},
    },
    '玄関の靴を揃えた': {
      'label': '玄関の靴を揃えた',
      'count': 0,
      'center': {'label': '1回分'},
    },
    // 洗濯物はサブメニューの例
    '洗濯物': {
      'label': '洗濯物',
      'count': 0,
      'center': {'label': '1回分（既定）'},
      'right': {
        'label': '干した',
        'submenu': {
          'up': {'count': 10, 'label': '10枚以上'},
          'down': {'count': 20, 'label': '20枚以上'},
          'center': {'count': 5, 'label': '5枚'},
        },
      },
      'left': {'label': '畳んだ'},
      'up': {'label': 'しまった'},
      'down': {'label': 'その他'},
    },
    '洗濯機を回した': {
      'label': '洗濯機を回した',
      'count': 0,
      'center': {'label': '1回分'},
    },
    'ゴミ出し': {
      'label': 'ゴミ出し',
      'count': 0,
      'center': {'label': '1回分'},
    },
    '買い物': {
      'label': '買い物',
      'count': 0,
      'center': {'label': '1回分'},
    },
    'ペットの世話': {
      'label': 'ペットの世話',
      'count': 0,
      'center': {'label': '1回分'},
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
    if (_flickStage == 0) {
      final origin = _primaryOrigin ?? _startGlobalPosition!;
      final primaryDir = _calcDirection(origin, currentGlobal);
      if (primaryDir != _currentPrimary) {
        _currentPrimary = primaryDir;
        final primaryHasSub = _hasSubmenu(chore, primaryDir);
        if (primaryHasSub && primaryDir != 'center') {
          _flickStage = 1;
          _selectedPrimaryDir = primaryDir;
          _secondaryOrigin = currentGlobal;
          _startGlobalPosition = _secondaryOrigin;
          _currentSecondary = 'center';
        } else {
          _secondaryOrigin = null;
        }
        _overlayEntry?.markNeedsBuild();
      }
    } else {
      final secOrigin = _secondaryOrigin ?? _startGlobalPosition!;
      final secondaryDir = _calcDirection(secOrigin, currentGlobal);

      if (_primaryOrigin != null) {
        final vecFromPrimary = currentGlobal - _primaryOrigin!;
        final distFromPrimary = vecFromPrimary.distance;

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

  void _finalizeFlick(String chore, Offset? globalPosition) {
    int? finalCount;
    String? finalLabel;

    if (_flickStage == 1 && _selectedPrimaryDir != null) {
      final primaryMap = _choreActionMap[chore]?[_selectedPrimaryDir!];
      if (primaryMap != null && primaryMap['submenu'] != null) {
        final submenu = Map<String, dynamic>.from(primaryMap['submenu']);
        final sec = submenu[_currentSecondary] ?? submenu['center'];
        if (sec != null) {
          finalLabel =
              sec['label']?.toString() ??
              primaryMap['label']?.toString() ??
              chore;
          finalCount = sec['count'] is int ? sec['count'] as int : null;
          if (globalPosition != null) {
            final text = finalCount != null
                ? (finalCount == 5 ? '+5以上' : '+$finalCount')
                : '+1';
            _showFloatingCount(globalPosition, text);
          }
          _recordChore(
            chore,
            finalCount ?? _directionToCount(_selectedPrimaryDir!),
            actionLabel: '${primaryMap['label']} → $finalLabel',
          );
          return;
        }
      }
    }

    final primaryLabel = _choreActionMap[chore]?[_currentPrimary]?['label'];
    if (primaryLabel != null) {
      finalCount = _directionToCount(_currentPrimary);
      if (globalPosition != null) {
        final text = (finalCount == 5) ? '+5以上' : '+$finalCount';
        _showFloatingCount(globalPosition, text);
      }
      _recordChore(chore, finalCount, actionLabel: primaryLabel.toString());
    } else {
      final count = _directionToCount(_currentPrimary);
      if (globalPosition != null) {
        final text = (count == 5) ? '+5以上' : '+$count';
        _showFloatingCount(globalPosition, text);
      }
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

    final labelCount = (count == null) ? '' : (count == 5 ? '5以上' : '$count');
    final labelAction = actionLabel != null ? ' / $actionLabel' : '';
    // デバッグ用ログ
    // ignore: avoid_print
    print(
      '$chore を記録しました: $labelCount$labelAction (local=${_choreActionMap[chore]?['count']}, global=${context.read<ChoreStore>().getCount(chore)})',
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
