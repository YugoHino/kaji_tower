import 'package:flutter/material.dart';

class ChoreLoggingScreen extends StatefulWidget {
  const ChoreLoggingScreen({super.key});

  @override
  State<ChoreLoggingScreen> createState() => _ChoreLoggingScreenState();
}

class _ChoreLoggingScreenState extends State<ChoreLoggingScreen> {
  // TODO: Move to a separate data model class
  final List<String> _basicChores = [
    '掃除機',
    'トイレ掃除',
    'ご飯を作った',
    '風呂掃除',
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
  String _currentDirection = 'center'; // 'center','up','right','left','down'

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        direction: Axis.horizontal,
        spacing: 8.0, // 横間隔
        runSpacing: 8.0, // 折り返し時の縦間隔
        children: _basicChores
            .map((chore) => _buildChoreButton(chore))
            .toList(),
      ),
    );
  }

  Widget _buildChoreButton(String chore) {
    return GestureDetector(
      onTap: () {
        // 短押しは1部屋
        _recordChore(chore, 1);
      },
      onLongPressStart: (details) {
        _startGlobalPosition = details.globalPosition;
        _currentDirection = 'center';
        _showFlickMenu(details.globalPosition);
      },
      onLongPressMoveUpdate: (details) {
        if (_startGlobalPosition != null) {
          _updateFlickSelection(details.globalPosition);
        }
      },
      onLongPressEnd: (details) {
        // 長押し終了で確定
        _hideFlickMenu();
        final count = _directionToCount(_currentDirection);
        _recordChore(chore, count);
        _startGlobalPosition = null;
        _currentDirection = 'center';
      },
      child: ElevatedButton(
        onPressed: null, // GestureDetectorで処理するため null にして高階層で制御
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Text(chore),
      ),
    );
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
        return 5; // 5部屋以上を表す。必要なら別扱いに
      case 'center':
      default:
        return 1;
    }
  }

  void _recordChore(String chore, int count) {
    // TODO: 実際の記録ロジックへ差し替え
    final label = (count == 5) ? '5以上' : '$count';
    print('$chore を記録しました: $label 部屋');
    // 例えば setStateでUI反映や DB 書き込みを行う
  }

  void _showFlickMenu(Offset globalPosition) {
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
            child: _buildFlickMenuContent(size),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildFlickMenuContent(double size) {
    final itemSize = 44.0;
    final center = size / 2 - itemSize / 2;
    Widget option(String dir, IconData icon, String label) {
      final bool selected = _currentDirection == dir;
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
            child: Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // 背景の薄い丸
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
        option('up', Icons.keyboard_arrow_up, '2部屋'),
        option('right', Icons.keyboard_arrow_right, '3部屋'),
        option('left', Icons.keyboard_arrow_left, '4部屋'),
        option('down', Icons.keyboard_arrow_down, '5以上'),
        option('center', Icons.circle, '1部屋'),
      ],
    );
  }

  void _updateFlickSelection(Offset currentGlobal) {
    if (_startGlobalPosition == null) return;
    final dx = currentGlobal.dx - _startGlobalPosition!.dx;
    final dy = currentGlobal.dy - _startGlobalPosition!.dy;
    const threshold = 20; // この閾値以上の移動で方向判定
    String dir = 'center';
    if (dx.abs() < threshold && dy.abs() < threshold) {
      dir = 'center';
    } else {
      if (dx.abs() > dy.abs()) {
        dir = dx > 0 ? 'right' : 'left';
      } else {
        dir = dy > 0 ? 'down' : 'up';
      }
    }
    if (dir != _currentDirection) {
      _currentDirection = dir;
      // overlay を再描画
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _hideFlickMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
