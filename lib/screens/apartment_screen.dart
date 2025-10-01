import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApartmentScreen extends StatefulWidget {
  const ApartmentScreen({super.key});

  @override
  State<ApartmentScreen> createState() => _ApartmentScreenState();
}

class _ApartmentScreenState extends State<ApartmentScreen> {
  static const String _prefsKey = 'chore_logs_v1';

  final ScrollController _scrollController = ScrollController();

  // 表示レイアウト用定数
  final double _worldWidthFactor = 3.0; // 画面幅の何倍をキャンバス幅にするか
  final double _canvasMinHeight = 620; // キャンバスの最低高さ（背景を fitHeight する）
  final double _groundBottom = 16; // 背景の「地面」に相当する下の余白
  final double _buildingBottom = 24; // 建物画像を地面からどれだけ上に置くか
  final double _buildingHeight = 420; // 建物表示の高さ（5階想定）
  final double _buildingWidth = 280; // 建物の概算横幅（レイアウト計算に使用）
  final double _arrowSize = 28;
  final double _arrowLeftGap = 18; // 矢印を建物の左に少し離して置く

  int _totalPoints = 0;

  // 現在の建物(0=1st,1=2nd,2=3rd)と階(1..5)
  int _currentBuilding = 0;
  int _currentFloor = 1;

  bool _didInitialJump = false;

  @override
  void initState() {
    super.initState();
    _loadTotalPoints();
  }

  Future<void> _loadTotalPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? const <String>[];
    int sum = 0;
    for (final s in list) {
      try {
        final m = json.decode(s) as Map<String, dynamic>;
        final c = m['count'];
        if (c is int) {
          sum += c;
        } else {
          sum += int.tryParse('$c') ?? 0;
        }
      } catch (_) {
        // ignore malformed
      }
    }
    setState(() {
      _totalPoints = sum;
      _computeProgress();
    });
    // 初期位置へスクロール
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToCurrentBuildingIfNeeded();
    });
  }

  // 100ptごとに1階、5階まで行ったら次の建物へ
  // 0〜100=1F, 101〜200=2F, ..., 401〜500=5F, 501〜600=2nd 1F ...
  void _computeProgress() {
    final p = _totalPoints;
    int stage;
    if (p <= 100) {
      stage = 0; // 1st 1F
    } else {
      stage = ((p - 1) ~/ 100); // 101〜200 => 1, 201〜300 => 2, ...
    }
    final floorsPerBuilding = 5;
    int b = stage ~/ floorsPerBuilding; // 0-based building index
    int f = (stage % floorsPerBuilding) + 1; // 1..5

    // 建物は 0..2 にクランプ（3棟）
    if (b < 0) b = 0;
    if (b > 2) b = 2;

    _currentBuilding = b;
    _currentFloor = f;
  }

  void _jumpToCurrentBuildingIfNeeded() {
    if (_didInitialJump || !_scrollController.hasClients) return;

    final screenW = MediaQuery.of(context).size.width;
    final worldW = screenW * _worldWidthFactor;

    final positions = _buildingLeftPositions(worldW);
    final left = positions[_currentBuilding];
    final centerX = left + (_buildingWidth / 2);
    final target = (centerX - screenW / 2).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.jumpTo(target);
    _didInitialJump = true;
  }

  List<double> _buildingLeftPositions(double worldW) {
    // 1/6, 3/6, 5/6 の位置に建物の中心を置く → left は中心 - 幅/2
    final centers = <double>[
      worldW * (1 / 6),
      worldW * (3 / 6),
      worldW * (5 / 6),
    ];
    return centers.map((cx) => cx - _buildingWidth / 2).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final canvasH = MediaQuery.of(
      context,
    ).size.height.clamp(_canvasMinHeight, double.infinity);
    final worldW = screenW * _worldWidthFactor;

    final buildingLefts = _buildingLeftPositions(worldW);

    // 矢印のY（下基準）: 各階は建物高さを5分割し、その中央付近に配置
    double floorCenterFromBottom(int floor) {
      // floor: 1..5
      final floorH = _buildingHeight / 5;
      return _buildingBottom + (floor - 0.5) * floorH;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('タワー'),
        actions: [
          IconButton(
            onPressed: _loadTotalPoints,
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: Column(
        children: [
          // 上部に総獲得ポイント表示
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  '総獲得ポイント：$_totalPoints p',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: worldW,
                height: canvasH.toDouble(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 背景（下揃えで横スクロールに追従）
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Image.asset(
                          'assets/images/kaji_local_town_bg.png',
                          height: canvasH.toDouble() - _groundBottom,
                          fit: BoxFit.fitHeight,
                          alignment: Alignment.bottomLeft,
                        ),
                      ),
                    ),

                    // 1st/2nd/3rd を地面から一定距離に均等配置
                    Positioned(
                      left: buildingLefts[0],
                      bottom: _buildingBottom,
                      child: Image.asset(
                        'assets/images/kaji_local_town_1st.png',
                        width: _buildingWidth,
                        height: _buildingHeight,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                    Positioned(
                      left: buildingLefts[1],
                      bottom: _buildingBottom,
                      child: Image.asset(
                        'assets/images/kaji_local_town_2nd.png',
                        width: _buildingWidth,
                        height: _buildingHeight,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                    Positioned(
                      left: buildingLefts[2],
                      bottom: _buildingBottom,
                      child: Image.asset(
                        'assets/images/kaji_local_town_3rd.png',
                        width: _buildingWidth,
                        height: _buildingHeight,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),

                    // ポイントに応じた矢印（建物の左側、該当階の高さ）
                    Positioned(
                      left: (buildingLefts[_currentBuilding] - _arrowLeftGap)
                          .clamp(0.0, worldW),
                      bottom: floorCenterFromBottom(_currentFloor),
                      child: Transform.translate(
                        offset: const Offset(0, -14), // 見た目微調整
                        child: Icon(
                          Icons.arrow_right,
                          color: Colors.redAccent,
                          size: _arrowSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
