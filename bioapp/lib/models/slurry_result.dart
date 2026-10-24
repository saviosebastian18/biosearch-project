import 'package:flutter/material.dart';

@immutable
class SlurryResult {
  // --- Current Slurry Values (Used for Metric Cards) ---
  final double currentN;
  final double currentP;
  final double currentK;
  final double currentPh;

  // --- Ideal Target Values (Used for Comparison/Advice Prompt) ---
  final double idealN;
  final double idealP;
  final double idealK;
  final double idealPh;
  
  // --- AI Results & Status ---
  final String recommendedCrop;
  final String healthStatus;
  
  // --- Multilingual Advice ---
  final String adviceEnglish;
  final String adviceMalayalam;
  final String adviceTamil;
  final String adviceHindi; // ADDED: Hindi support

  SlurryResult({
    // Mock Data for Initial UI Load
    this.currentN = 90.0,
    this.currentP = 42.0,
    this.currentK = 40.0,
    this.currentPh = 6.8,
    this.idealN = 80.0,
    this.idealP = 45.0,
    this.idealK = 40.0,
    this.idealPh = 6.4,
    this.recommendedCrop = 'Rice',
    this.healthStatus = 'Needs Adjustment (High N)',
    this.adviceEnglish = 'Biogas slurry is slightly high in nitrogen for rice. Add composted manure to stabilize N and reduce pH slightly.',
    this.adviceMalayalam = 'നിലവിലെ വളം നെല്ലിന് അല്പം കൂടുതലാണ്. നൈട്രജൻ സ്ഥിരപ്പെടുത്തുന്നതിന് കമ്പോസ്റ്റഡ് വളം ചേർക്കുക, pH അല്പം കുറയ്ക്കുക.',
    this.adviceTamil = 'நெல் சாகுபடிக்கு உரம் சற்று அதிகமாக உள்ளது. நைட்ரஜனை நிலைப்படுத்த உரம் சேர்க்கவும் மற்றும் pH-ஐ சற்று குறைக்கவும்.',
    this.adviceHindi = 'चावल की फसल के लिए नाइट्रोजन थोड़ा अधिक है। एन को स्थिर करने के लिए खाद डालें और पीएच को थोड़ा कम करें।',
  });

  // --- Factory Constructor for API Response ---
  // FIX 1: Creates the 'SlurryResult.fromApi' constructor
  factory SlurryResult.fromApi(Map<String, dynamic> json) {
    // Helper function to safely cast values
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return SlurryResult(
      // Current values from API response
      currentN: parseDouble(json['current_n']),
      currentP: parseDouble(json['current_p']),
      currentK: parseDouble(json['current_k']),
      currentPh: parseDouble(json['current_ph']),
      
      // Ideal values from API response
      idealN: parseDouble(json['ideal_n']),
      idealP: parseDouble(json['ideal_p']),
      idealK: parseDouble(json['ideal_k']),
      idealPh: parseDouble(json['ideal_ph']),
      
      // Predicted and status fields
      recommendedCrop: json['recommended_crop'] as String,
      healthStatus: json['health_status'] as String,
      
      // Multilingual Advice
      adviceEnglish: json['advice_english'] as String,
      adviceMalayalam: json['advice_malayalam'] as String,
      adviceTamil: json['advice_tamil'] as String,
      adviceHindi: json['advice_hindi'] as String, // FIX 2: Includes the Hindi field
    );
  }
}
