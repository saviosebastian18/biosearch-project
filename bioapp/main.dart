// This is a complete, single-file Flutter application (main.dart)
// It provides a user-friendly UI skeleton for the Biosage project.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const BiosageApp());
}

// --- Mock Data Structure ---
class SlurryResult {
  final String recommendedCrop;
  final String adviceEnglish;
  final String adviceMalayalam;
  final String adviceTamil;
  final double phLevel;
  final double nValue;
  final double pValue;
  final double kValue;
  final String healthStatus; // e.g., 'Ideal', 'High Nitrogen'
  
  SlurryResult({
    this.recommendedCrop = 'Tomato (Recommended)',
    this.adviceEnglish = 'To optimize your slurry for Rice, consider adding nitrogen-rich waste like fresh grass clippings to increase N and wood ash to balance pH.',
    this.adviceMalayalam = 'ചോറിന് അനുയോജ്യമാക്കാൻ, നൈട്രജൻ കൂടുതലുള്ള പച്ചപ്പുല്ല് പോലുള്ളവ ചേർക്കുക, pH സന്തുലിതമാക്കാൻ ചാരം ചേർക്കുക.',
    this.adviceTamil = 'அரிசிக்கு உகந்ததாக, நைட்ரஜன் நிறைந்த புற்களைச் சேர்க்கவும், மேலும் pH ஐ சமப்படுத்த மர சாம்பலைச் சேர்க்கவும்.',
    this.phLevel = 6.4,
    this.nValue = 95.0,
    this.pValue = 45.0,
    this.kValue = 42.0,
    this.healthStatus = 'Needs Adjustment (High N)',
  });
}

class BiosageApp extends StatelessWidget {
  const BiosageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biosage AI',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8), // Light background
        fontFamily: GoogleFonts.inter().fontFamily,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20), // Dark Green for AppBar
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
      ),
      home: const BiosageHomeScreen(),
    );
  }
}

class BiosageHomeScreen extends StatefulWidget {
  const BiosageHomeScreen({super.key});

  @override
  State<BiosageHomeScreen> createState() => _BiosageHomeScreenState();
}

class _BiosageHomeScreenState extends State<BiosageHomeScreen> {
  final SlurryResult _result = SlurryResult();
  String? _selectedLanguage = 'English'; // Default output language

  // TextEditingControllers for mock sensor input
  final TextEditingController _nController = TextEditingController(text: '115');
  final TextEditingController _pController = TextEditingController(text: '70');
  final TextEditingController _kController = TextEditingController(text: '100');
  final TextEditingController _phController = TextEditingController(text: '6.5');
  final TextEditingController _preferredCropController = TextEditingController(text: 'Pomegranate');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BioSage AI: Slurry Optimizer'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildInputCard(context),
            const SizedBox(height: 20),
            _buildOutputCard(context),
            const SizedBox(height: 20),
            _buildAdviceCard(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildInputCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Current Slurry Analysis (Sensor Input)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(),
            _buildTextFieldRow('Nitrogen (N)', 'mg/kg', _nController, Colors.red.shade900),
            _buildTextFieldRow('Phosphorus (P)', 'mg/kg', _pController, Colors.orange.shade900),
            _buildTextFieldRow('Potassium (K)', 'mg/kg', _kController, Colors.blue.shade900),
            _buildTextFieldRow('pH Value', 'pH', _phController, Colors.purple.shade900),
            const SizedBox(height: 16),
            TextField(
              controller: _preferredCropController,
              decoration: const InputDecoration(
                labelText: '2. Your Preferred Crop',
                hintText: 'e.g., Rice, Tomato, Coconut',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.grass, color: Colors.green),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement sensor data read and API call logic here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Analyzing Slurry... (Integration Point)')),
                  );
                },
                icon: const Icon(Icons.science),
                label: const Text('ANALYZE SLURRY', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldRow(String label, String unit, TextEditingController controller, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                suffixText: unit,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputCard(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3. Biosage Prediction & Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(),
            // Slurry Health Status (Color coded)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade400),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Slurry Status: ${_result.healthStatus}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // Recommended Crop
            _buildResultRow(
              'Model\'s Recommendation',
              _result.recommendedCrop,
              Icons.done_all,
              Colors.green.shade700,
            ),
            const SizedBox(height: 10),
            // Sensor Values Summary
            Text('Current NPK/pH Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            _buildResultRow('N: ${_result.nValue} | P: ${_result.pValue} | K: ${_result.kValue}', 'pH: ${_result.phLevel}', Icons.bubble_chart, Colors.grey.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label1, String label2, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label1 | $label2',
              style: TextStyle(fontSize: 14, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '4. Slurry Adjustment Guide (AI-Generated)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(),
            // Language Selector
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedLanguage = newValue;
                      });
                    },
                    items: <String>['English', 'Malayalam', 'Tamil']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text('View Advice in: $value', style: const TextStyle(fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Advice Output Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getTranslatedAdvice(),
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTranslatedAdvice() {
    switch (_selectedLanguage) {
      case 'Malayalam':
        return _result.adviceMalayalam;
      case 'Tamil':
        return _result.adviceTamil;
      case 'English':
      default:
        return _result.adviceEnglish;
    }
  }
}
