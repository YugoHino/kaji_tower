import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

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
  final double _worldWidthFactor = 2.0; // 背景ARが未取得時のフォールバック
  final double _canvasMinHeight = 620; // キャンバスの最低高さ（背景を fitHeight する）
  final double _groundBottom = 16; // 背景の「地面」に相当する下の余白
  final double _buildingBottom = 80; // 建物画像を地面からどれだけ上に置くか
  final double _buildingHeight = 500; // 建物表示の高さ（5階想定）
  final double _buildingWidth = 350; // 建物の概算横幅（レイアウト計算に使用）
  final double _arrowSize = 28;
  final double _arrowLeftGap = 18; // 矢印を建物の左に少し離して置く
  // 背景の固定描画高さ（画面サイズに依存させない）
  final double _bgFixedHeight = 560;

  int _totalPoints = 0;

  // 現在の建物(0=1st,1=2nd,2=3rd)と階(1..5)
  int _currentBuilding = 0;
  int _currentFloor = 1;

  bool _didInitialJump = false;
  double? _bgAspectRatio; // 背景画像のAR（width/height）

  @override
  void initState() {
    super.initState();
    _loadBgAspectRatio();
    _loadTotalPoints();
  }

  // 背景画像の実寸からアスペクト比を取得
  Future<void> _loadBgAspectRatio() async {
    final provider = const AssetImage('assets/images/kaji_local_town_bg.png');
    final completer = Completer<ImageInfo>();
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        completer.complete(info);
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    try {
      final info = await completer.future;
      final ar = info.image.width / info.image.height;
      if (mounted) {
        setState(() {
          _bgAspectRatio = ar;
          _didInitialJump = false; // AR反映後に再調整
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToCurrentBuildingIfNeeded();
        });
      }
    } catch (_) {
      // 取得失敗時はフォールバックの _worldWidthFactor を使用
    }
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
    // 背景は固定高さで描画。横幅は固定高さ×AR（フォールバック含む）
    double worldW = (_bgAspectRatio != null && _bgAspectRatio!.isFinite)
        ? _bgFixedHeight * _bgAspectRatio!
        : screenW * _worldWidthFactor;
    if (!worldW.isFinite || worldW <= 0) {
      worldW = screenW; // 最終フォールバック
    }

    final positions = _buildingLeftPositions(worldW);
    final left = positions[_currentBuilding];
    final centerX = left + (_buildingWidth / 2);

    final maxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    double target = centerX - screenW / 2;
    if (!target.isFinite) target = 0;
    target = target.clamp(0.0, maxExtent);

    _scrollController.jumpTo(target);
    _didInitialJump = true;
  }

  List<double> _buildingLeftPositions(double worldW) {
    if (!worldW.isFinite || worldW <= 0) {
      worldW = 1; // ゼロ除算防止のダミー
    }
    // 1/6, 3/6, 5/6 の位置に建物の中心を置く → left は中心 - 幅/2
    final centers = <double>[
      worldW * (1 / 6),
      worldW * (3 / 6),
      worldW * (5 / 6),
    ];
    final rawLefts = centers
        .map((cx) => cx - _buildingWidth / 2)
        .toList(growable: false);
    // 背景の左右からはみ出さないようにクランプ
    final maxLeft = math.max(0.0, worldW - _buildingWidth);
    return rawLefts.map((l) => l.clamp(0.0, maxLeft)).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final viewH = MediaQuery.of(context).size.height; // 画面の実高さ（親の高さ）

    // 背景は固定高さで描画。横幅は固定高さ×AR（未取得時はフォールバック）
    double worldW = (_bgAspectRatio != null && _bgAspectRatio!.isFinite)
        ? _bgFixedHeight * _bgAspectRatio!
        : screenW * _worldWidthFactor;
    if (!worldW.isFinite || worldW <= 0) {
      worldW = screenW; // 最終フォールバック
    }

    final buildingLefts = _buildingLeftPositions(worldW);
    double floorCenterFromBottom(int floor) {
      final floorH = _buildingHeight / 5;
      return _buildingBottom + (floor - 0.5) * floorH;
    }

    // スクロール領域幅（worldW が画面幅より小さい場合の安定化）
    final scrollContentW = math.max(worldW, screenW);

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
                width: scrollContentW,
                height: viewH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 背景（固定高さ／下揃え、足りない上側は白でカバー）
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: SizedBox(
                        width: worldW,
                        height: _bgFixedHeight,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Image.asset(
                            'assets/images/kaji_local_town_bg.png',
                            height: _bgFixedHeight,
                            fit: BoxFit.fitHeight,
                            alignment: Alignment.bottomLeft,
                          ),
                        ),
                      ),
                    ),

                    // 1st/2nd/3rd を地面から一定距離に均等配置（左右はクランプ済み）
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
                      left: () {
                        double v =
                            buildingLefts[_currentBuilding] - _arrowLeftGap;
                        if (!v.isFinite) v = 0;
                        final maxX = math.max(0.0, worldW);
                        return v.clamp(0.0, maxX);
                      }(),
                      bottom: floorCenterFromBottom(_currentFloor),
                      child: Transform.translate(
                        offset: const Offset(0, -14),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
