import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

extension StringCasingExtension on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : '';
}

void main() {
  runApp(const BiosearchApp());
}

class BiosearchApp extends StatelessWidget {
  const BiosearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2D5F3F),
        scaffoldBackgroundColor: const Color(0xFFF4FFF5),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D5F3F)),
        useMaterial3: true,
      ),
      home: const MainSlurryScreen(),
    );
  }
}

// ==================== DATA MODELS ====================

class RankedCrop {
  final String crop;
  final double matchScore;
  final Map<String, double> ideal;
  final Map<String, double> gap;

  RankedCrop({
    required this.crop,
    required this.matchScore,
    required this.ideal,
    required this.gap,
  });

  factory RankedCrop.fromJson(Map<String, dynamic> json) {
    Map<String, double> toDoubleMap(Map<String, dynamic>? raw) {
      if (raw == null) return {};
      return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    return RankedCrop(
      crop: json['crop'] ?? '',
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0.0,
      ideal: toDoubleMap(json['ideal'] as Map<String, dynamic>?),
      gap: toDoubleMap(json['gap'] as Map<String, dynamic>?),
    );
  }
}

class AnalysisResult {
  final String mlRecommendedCrop;
  final String targetCrop;
  final List<RankedCrop> rankedCrops;
  final List<String> allCrops;
  final Map<String, dynamic> currentValues;
  final Map<String, dynamic> idealValues;
  final double suitabilityScore;
  final Map<String, dynamic> aiGuidance;

  AnalysisResult({
    required this.mlRecommendedCrop,
    required this.targetCrop,
    required this.rankedCrops,
    required this.allCrops,
    required this.currentValues,
    required this.idealValues,
    required this.suitabilityScore,
    required this.aiGuidance,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawRanked = json['ranked_crops'] as List<dynamic>? ?? [];
    final ranked = rawRanked
        .map((e) => RankedCrop.fromJson(e as Map<String, dynamic>))
        .toList();

    final allAvailable = List<String>.from(
        json['crop_options']?['all_available'] ?? []);

    return AnalysisResult(
      mlRecommendedCrop: json['ml_recommendation']?['crop'] ?? 'Unknown',
      targetCrop: json['selected_crop'] ?? 'Unknown',
      rankedCrops: ranked,
      allCrops: allAvailable,
      currentValues: json['sensor_data'] ?? {},
      idealValues: json['ideal_values'] ?? {},
      suitabilityScore: (json['suitability_score'] ?? 0).toDouble(),
      aiGuidance: json['ai_guidance'] ?? {},
    );
  }

  Map<String, dynamic> toContextMap() => {
        'guidance': aiGuidance,
        'target_crop': targetCrop,
        'ideal_values': idealValues,
        'current_values': currentValues,
      };
}

// ==================== MAIN SCREEN ====================

class MainSlurryScreen extends StatefulWidget {
  const MainSlurryScreen({super.key});

  @override
  State<MainSlurryScreen> createState() => _MainSlurryScreenState();
}

class _MainSlurryScreenState extends State<MainSlurryScreen> {
  static const String API_BASE_URL = 'http://127.0.0.1:8000';

  // Controllers default to '0' to strictly use hardware data
  final _nController           = TextEditingController(text: '0');
  final _pController           = TextEditingController(text: '0');
  final _kController           = TextEditingController(text: '0');
  final _phController          = TextEditingController(text: '0');
  final _methaneController     = TextEditingController(text: '0');
  final _temperatureController = TextEditingController(text: '38');
  final _familyController      = TextEditingController(text: '4');
  final _chatController        = TextEditingController();
  final ScrollController _guidanceScrollController = ScrollController();

  bool _loading        = false;
  bool _chatLoading    = false;
  bool _methaneLoading = false;

  String _chatAnswer = '';
  String _language = 'English';
  final List<String> _languages = ['English', 'Malayalam', 'Tamil', 'Hindi'];

  double? _targetMethanePpm;
  String? _methaneAdvice;
  double? _wasteToAddKg;

  Timer? _liveDataTimer;
  String? _selectedCrop;
  List<String> _allCrops = [];
  AnalysisResult? _result;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _loadCrops();
      _performInitialAnalysis();
    });
    
    // Live hardware fetching timer
    _liveDataTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _fetchLiveHardwareData(),
    );
  }

  @override
  void dispose() {
    _liveDataTimer?.cancel();
    for (final c in [
      _nController, _pController, _kController, _phController,
      _methaneController, _temperatureController, _familyController,
      _chatController,
    ]) {
      c.dispose();
    }
    _guidanceScrollController.dispose();
    super.dispose();
  }

  // ── Network helpers ───────────────────────────────────────────────────────

  Future<void> _fetchLiveHardwareData() async {
    try {
      final response =
          await http.get(Uri.parse('$API_BASE_URL/live_hardware_data'));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          final d = result['data'];
          setState(() {
            _nController.text       = d['N'].toString();
            _pController.text       = d['P'].toString();
            _kController.text       = d['K'].toString();
            _phController.text      = d['ph'].toString();
            _methaneController.text = d['methane_ppm'].toString();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCrops() async {
    try {
      final response =
          await http.get(Uri.parse('$API_BASE_URL/get_crops'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _allCrops = List<String>.from(data['crops']));
      }
    } catch (_) {
      setState(() => _allCrops = [
            'rice', 'maize', 'banana', 'coconut', 'coffee', 'cotton'
          ]);
    }
  }

  Future<void> _performInitialAnalysis() async {
    // Await live data before analyzing so it uses real hardware values immediately
    await _fetchLiveHardwareData();
    await Future.delayed(const Duration(milliseconds: 500));
    await _analyzeSlurry();
  }

  Future<void> _analyzeSlurry() async {
    setState(() => _loading = true);
    try {
      final body = {
        'N':           double.tryParse(_nController.text) ?? 0,
        'P':           double.tryParse(_pController.text) ?? 0,
        'K':           double.tryParse(_kController.text) ?? 0,
        'ph':          double.tryParse(_phController.text) ?? 0,
        'methane':     double.tryParse(_methaneController.text) ?? 0,
        'temperature': double.tryParse(_temperatureController.text) ?? 38,
        'language':    _language,
        'selected_crop': _selectedCrop,
        'top_n':       10,
      };

      final response = await http.post(
        Uri.parse('$API_BASE_URL/analyze_slurry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _result = AnalysisResult.fromJson(data);
          _chatAnswer = '';
          if (_selectedCrop == null && _result!.rankedCrops.isNotEmpty) {
            _selectedCrop = _result!.rankedCrops.first.crop;
          }
          if (_result!.allCrops.isNotEmpty) {
            _allCrops = _result!.allCrops;
          }
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          if (_guidanceScrollController.hasClients) {
            _guidanceScrollController.animateTo(
              _guidanceScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (_) {
      _showError('Connection error. Is Python server running?');
    }
    setState(() => _loading = false);
  }

  Future<void> _calculateMethaneTarget() async {
    final familyText = _familyController.text.trim();
    if (familyText.isEmpty) {
      _showError('Please enter the number of family members.');
      return;
    }
    final familyCount = int.tryParse(familyText);
    if (familyCount == null || familyCount <= 0) {
      _showError('Please enter a valid number of family members (e.g. 4).');
      return;
    }

    setState(() => _methaneLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/calculate_methane'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'family_members':  familyCount,
          'current_methane': double.tryParse(_methaneController.text) ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _targetMethanePpm =
              (data['data']['target_methane_ppm'] as num).toDouble();
          _methaneAdvice = data['data']['ai_advice'];
          _wasteToAddKg =
              (data['data']['waste_to_add_kg'] as num?)?.toDouble();
        });
      } else {
        _showError('AI Error: Could not calculate methane target.');
      }
    } catch (e) {
      _showError('Methane calculation failed: $e');
    }
    setState(() => _methaneLoading = false);
  }

  Future<void> _askAI() async {
    if (_chatController.text.trim().isEmpty) return;
    setState(() => _chatLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/farmer_chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': _chatController.text,
          'context':  _result?.toContextMap() ?? {},
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _chatAnswer = data['answer']);
      }
    } catch (e) {
      _showError('Chat failed: $e');
    }
    setState(() => _chatLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _guidanceScrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildWelcomeBanner()),
            SliverToBoxAdapter(child: _buildSensorCards()),
            if (_result != null) ...[
              SliverToBoxAdapter(child: _buildRankedCropsSection()),
              SliverToBoxAdapter(child: _buildAIGuidanceCard()),
            ],
            SliverToBoxAdapter(child: _buildSensorInputs()),
            SliverToBoxAdapter(child: _buildMethaneTargetSection()),
            SliverToBoxAdapter(child: _buildChatSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  // ── Header / Banner ───────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.eco, color: Color(0xFF2D5F3F), size: 28),
          const SizedBox(width: 8),
          const Text('Biosearch',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D5F3F))),
          const Spacer(),
          DropdownButton<String>(
            value: _language,
            icon: const Icon(Icons.language, color: Colors.green),
            underline: Container(),
            onChanged: (v) {
              setState(() => _language = v!);
              if (_result != null) _analyzeSlurry();
            },
            items: _languages
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hello, Farmer',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              Text('Analyzing your soil health...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
          CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: const Icon(Icons.person, color: Colors.green),
          ),
        ],
      ),
    );
  }

  // ── Sensor Cards ──────────────────────────────────────────────────────────

  Widget _buildSensorCards() {
    final nValue = _result?.currentValues['N']?.toString() ?? _nController.text;
    final pValue = _result?.currentValues['P']?.toString() ?? _pController.text;
    final kValue = _result?.currentValues['K']?.toString() ?? _kController.text;
    final phValue = _result?.currentValues['ph']?.toString() ?? _phController.text;
    final methaneValue = _result?.currentValues['methane']?.toString() ?? _methaneController.text;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _sensorCard('Methane',
                '$methaneValue ppm',
                Icons.local_fire_department, Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _sensorCard(
                'NPK',
                '$nValue-$pValue-$kValue',
                Icons.science, Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _sensorCard('pH Level', phValue,
                Icons.water_drop, Colors.purple),
          ),
        ],
      ),
    );
  }

  Widget _sensorCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Ranked Crops Section ─────────────────────────────────────────────

  Widget _buildRankedCropsSection() {
    final ranked = _result!.rankedCrops;
    if (ranked.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Crop Match Rankings',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5F3F)),
              ),
              TextButton(
                onPressed: _showCropSelectionDialog,
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ranked by how well your current slurry matches each crop\'s needs.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          _buildTopCropCard(ranked.first),
          const SizedBox(height: 12),
          if (ranked.length > 1)
            ...ranked.skip(1).toList().asMap().entries.map(
                  (entry) => _buildRankedCropTile(
                      entry.value, entry.key + 2),
                ),
        ],
      ),
    );
  }

  Widget _buildTopCropCard(RankedCrop crop) {
    final isSelected = _selectedCrop == crop.crop;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCrop = crop.crop);
        _analyzeSlurry();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [const Color(0xFF2D5F3F), const Color(0xFF4CAF50)]
                : [const Color(0xFF388E3C), const Color(0xFF66BB6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.green.shade200,
                blurRadius: 12,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('🥇',
                  style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Best Match',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  Text(
                    crop.crop.capitalize(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  _buildScoreBar(crop.matchScore, light: true),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                '${crop.matchScore.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankedCropTile(RankedCrop crop, int rank) {
    final isSelected = _selectedCrop == crop.crop;
    final medals = {2: '🥈', 3: '🥉'};
    final medal = medals[rank];

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCrop = crop.crop);
        _analyzeSlurry();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.shade50
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.green.shade400
                : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: medal != null
                  ? Text(medal,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center)
                  : Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle),
                      child: Text(
                        '$rank',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                crop.crop.capitalize(),
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isSelected
                        ? const Color(0xFF2D5F3F)
                        : Colors.black87),
              ),
            ),
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Expanded(child: _buildScoreBar(crop.matchScore)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '${crop.matchScore.toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _scoreColor(crop.matchScore)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showGapDialog(crop),
              child: Icon(Icons.info_outline,
                  size: 18, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBar(double score, {bool light = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 6,
            backgroundColor:
                light ? Colors.white30 : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
                light ? Colors.white : _scoreColor(score)),
          ),
        ),
      ],
    );
  }

  Color _scoreColor(double score) {
    if (score >= 70) return Colors.green.shade600;
    if (score >= 40) return Colors.orange.shade600;
    return Colors.red.shade400;
  }

  String _fmtNPK(dynamic v) {
    if (v == null) return '–';
    return (v as num).round().toString();
  }

  String _fmtPH(dynamic v) {
    if (v == null) return '–';
    return (v as num).toStringAsFixed(1);
  }

  String _fmtGap(String nutrient, double gap) {
    final sign = gap > 0 ? '+' : '';
    if (nutrient == 'ph') return '$sign${gap.toStringAsFixed(1)}';
    return '$sign${gap.round()}';
  }

  void _showGapDialog(RankedCrop crop) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${crop.crop.capitalize()} – Nutrient Gap'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Positive = excess in your slurry\nNegative = deficit in your slurry',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ...['N', 'P', 'K', 'ph'].map((nutrient) {
              final gap   = crop.gap[nutrient] ?? 0.0;
              final ideal = crop.ideal[nutrient] ?? 0.0;
              final isExcess  = gap > 0;
              final isDeficit = gap < 0;
              final displayLabel = nutrient == 'ph' ? 'pH' : nutrient;
              final idealStr = nutrient == 'ph'
                  ? _fmtPH(ideal)
                  : _fmtNPK(ideal);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(displayLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Text('Ideal: $idealStr'),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isExcess
                            ? Colors.orange.shade50
                            : isDeficit
                                ? Colors.red.shade50
                                : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _fmtGap(nutrient, gap),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isExcess
                                ? Colors.orange.shade700
                                : isDeficit
                                    ? Colors.red.shade700
                                    : Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedCrop = crop.crop);
              _analyzeSlurry();
            },
            child: Text('Get AI Guide for ${crop.crop.capitalize()}'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showCropSelectionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('All Available Crops'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _allCrops.length,
            itemBuilder: (context, index) {
              final crop = _allCrops[index];
              return ListTile(
                title: Text(crop.capitalize()),
                onTap: () {
                  setState(() => _selectedCrop = crop);
                  Navigator.pop(context);
                  _analyzeSlurry();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ── AI Guidance Card ──────────────────────────────────────────────────────

  Widget _buildAIGuidanceCard() {
    final aiData = _result?.aiGuidance;
    if (aiData == null || aiData.isEmpty) return const SizedBox.shrink();

    final current = (aiData['current'] is Map)
        ? Map<String, dynamic>.from(aiData['current'] as Map)
        : Map<String, dynamic>.from(_result!.currentValues);
    final ideal = (aiData['ideal'] is Map)
        ? Map<String, dynamic>.from(aiData['ideal'] as Map)
        : Map<String, dynamic>.from(_result!.idealValues);
    final adjustments = (aiData['adjustments'] is List)
        ? aiData['adjustments'] as List<dynamic>
        : <dynamic>[];
    final appOrder = (aiData['application_order'] is List)
        ? aiData['application_order'] as List<dynamic>
        : <dynamic>[];
    final rawWarnings = (aiData['warnings'] is List)
        ? List<String>.from(aiData['warnings'] as List)
        : <String>[];
    if (aiData.containsKey('error') &&
        aiData['error'] != null &&
        aiData['error'].toString().isNotEmpty) {
      rawWarnings.add('Note: ${aiData['error']}');
    }
    final warnings = rawWarnings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.green.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF2D5F3F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Slurry Adjustment Guide — ${_result!.targetCrop.capitalize()}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('📊 Current vs Ideal'),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _npkTableRow(
                          'Nutrient', 'Current', 'Ideal', 'Gap',
                          isHeader: true,
                        ),
                        const Divider(height: 1, thickness: 1),
                        _npkTableRow(
                          'N',
                          _fmtNPK(current['N']),
                          _fmtNPK(ideal['N']),
                          _fmtGapColored('N', current['N'], ideal['N']),
                        ),
                        _npkTableRow(
                          'P',
                          _fmtNPK(current['P']),
                          _fmtNPK(ideal['P']),
                          _fmtGapColored('P', current['P'], ideal['P']),
                        ),
                        _npkTableRow(
                          'K',
                          _fmtNPK(current['K']),
                          _fmtNPK(ideal['K']),
                          _fmtGapColored('K', current['K'], ideal['K']),
                        ),
                        _npkTableRow(
                          'pH',
                          _fmtPH(current['ph']),
                          _fmtPH(ideal['ph']),
                          _fmtGapColored('ph', current['ph'], ideal['ph']),
                        ),
                      ],
                    ),
                  ),
                  if (adjustments.isEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'AI advice unavailable. Use the table above to adjust your slurry manually.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                  if (adjustments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('🧪 What to Add / Remove (per 100L slurry)'),
                    ...adjustments.asMap().entries.map((entry) {
                      final i    = entry.key;
                      final step = entry.value as Map<String, dynamic>;
                      final status   = step['status'] as String? ?? '';
                      final nutrient = step['nutrient'] as String? ?? '';
                      final action   = step['action'] as String? ?? '';
                      final qty      = step['quantity_per_100L'] as String? ?? '';
                      final reason   = step['reason'] as String? ?? '';
                      final isDeficit = status == 'DEFICIT';
                      final isExcess  = status == 'EXCESS';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDeficit
                              ? Colors.red.shade50
                              : isExcess
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDeficit
                                ? Colors.red.shade200
                                : isExcess
                                    ? Colors.orange.shade200
                                    : Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDeficit
                                    ? Colors.red.shade400
                                    : isExcess
                                        ? Colors.orange.shade400
                                        : Colors.green.shade400,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        nutrient == 'ph' ? 'pH' : nutrient,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDeficit
                                              ? Colors.red.shade100
                                              : isExcess
                                                  ? Colors.orange.shade100
                                                  : Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDeficit
                                                  ? Colors.red.shade700
                                                  : isExcess
                                                      ? Colors.orange.shade700
                                                      : Colors.green.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black87),
                                      children: [
                                        TextSpan(
                                            text: '$action ',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        TextSpan(
                                            text: '— $qty',
                                            style: TextStyle(
                                                color: Colors.grey.shade700)),
                                      ],
                                    ),
                                  ),
                                  if (reason.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(reason,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            height: 1.4)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (appOrder.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionTitle('📋 Application Order'),
                    ...appOrder.asMap().entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.arrow_right,
                                  color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  entry.value.toString(),
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...warnings.map((w) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.amber.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(w.toString(),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade900)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _npkTableRow(
    String nutrient,
    String current,
    String ideal,
    dynamic gap, {
    bool isHeader = false,
  }) {
    final style = isHeader
        ? TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600)
        : const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text(nutrient, style: style)),
          Expanded(child: Text(current, style: style, textAlign: TextAlign.center)),
          Expanded(child: Text(ideal,   style: style, textAlign: TextAlign.center)),
          Expanded(
            child: isHeader
                ? Text(gap as String, style: style, textAlign: TextAlign.center)
                : gap as Widget,
          ),
        ],
      ),
    );
  }

  Widget _fmtGapColored(String nutrient, dynamic currentVal, dynamic idealVal) {
    if (currentVal == null || idealVal == null) {
      return const Text('–', textAlign: TextAlign.center);
    }
    final c = (currentVal as num).toDouble();
    final i = (idealVal   as num).toDouble();
    final gap = c - i;

    final isOk      = gap.abs() < 0.05;
    final isExcess  = gap > 0;
    final label     = isOk
        ? '✓ OK'
        : (isExcess ? '+' : '') + (nutrient == 'ph'
            ? gap.toStringAsFixed(1)
            : gap.round().toString());

    final color = isOk
        ? Colors.green.shade600
        : isExcess
            ? Colors.orange.shade700
            : Colors.red.shade600;

    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 13, color: color),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D5F3F))),
    );
  }

  // ── RESTORED: Sensor Inputs ──────────────────────────────

  Widget _buildSensorInputs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text("Manual Sensor Adjustments",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(width: 70, child: _buildSmallInput(_nController, "N")),
                    SizedBox(width: 70, child: _buildSmallInput(_pController, "P")),
                    SizedBox(width: 70, child: _buildSmallInput(_kController, "K")),
                    SizedBox(width: 70, child: _buildSmallInput(_phController, "pH")),
                    SizedBox(width: 80, child: _buildSmallInput(_methaneController, "M(ppm)")),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loading ? null : _analyzeSlurry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5F3F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 20),
                label: const Text(
                  'Recalculate Slurry',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallInput(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Methane Target Section ────────────────────────────────────────────────

  Widget _buildMethaneTargetSection() {
    final currentMethane =
        double.tryParse(_methaneController.text) ?? 0;
    double progress = 0;
    if (_targetMethanePpm != null && _targetMethanePpm! > 0) {
      progress =
          (currentMethane / _targetMethanePpm!).clamp(0.0, 1.0);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Methane Requirement AI',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Family Members',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2D5F3F))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _familyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g. 4',
                            isDense: true,
                            prefixIcon: const Icon(
                                Icons.family_restroom,
                                size: 20),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFF2D5F3F),
                                  width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter number of people in your household',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [2, 4, 6].map((n) {
                      final isActive =
                          _familyController.text == '$n';
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _familyController.text = '$n'),
                          child: Container(
                            width: 44,
                            padding: const EdgeInsets.symmetric(
                                vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF2D5F3F)
                                  : Colors.grey.shade100,
                              borderRadius:
                                  BorderRadius.circular(8),
                              border: Border.all(
                                  color: isActive
                                      ? const Color(0xFF2D5F3F)
                                      : Colors.grey.shade300),
                            ),
                            child: Text(
                              '$n',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.grey.shade700),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed:
                      _methaneLoading ? null : _calculateMethaneTarget,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _methaneLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.analytics),
                  label: const Text('Analyze Target'),
                ),
              ),
              if (_targetMethanePpm != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'Current: ${currentMethane.toInt()} ppm',
                        style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold)),
                    Text(
                        'Target: ${_targetMethanePpm!.toInt()} ppm',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    color: progress >= 1.0
                        ? Colors.green
                        : Colors.green.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}% of target',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
                const SizedBox(height: 16),
                if (_wasteToAddKg != null && _wasteToAddKg! > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Action Required: Add '
                            '${_wasteToAddKg!.toStringAsFixed(1)} kg '
                            'of organic waste to reach target gas levels.',
                            style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_methaneAdvice != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_methaneAdvice!,
                              style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontSize: 13,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Chat Section ──────────────────────────────────────────────────────────

  Widget _buildChatSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('👨‍🌾 Ask the Expert',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'E.g., How to add Urea?',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF2E7D32),
                child: IconButton(
                  icon: _chatLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _askAI,
                ),
              ),
            ],
          ),
          if (_chatAnswer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_chatAnswer),
            ),
          ],
        ],
      ),
    );
  }
}