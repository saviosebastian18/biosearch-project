import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bioapp/screens/landing_page.dart';
import 'package:bioapp/screens/main_slurry_screen.dart';

void main() {
  // Added a default image asset path for safe running
  // You must ensure 'assets/farmer1.jpg' exists in your root assets folder.
  runApp(const MyApp(defaultImagePath: 'assets/farmer1.jpg'));
}

class MyApp extends StatelessWidget {
  final String defaultImagePath;
  const MyApp({super.key, required this.defaultImagePath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioSage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Set a consistent primary color for branding
        primaryColor: const Color(0xFF339343),
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        fontFamily: GoogleFonts.inter().fontFamily,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20), // Dark Green for AppBar
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: false, 
      ),
      // Start with the Landing Page, passing the MainSlurryScreen for navigation
      home: LandingPage(
        backgroundAsset: defaultImagePath,
        mainScreen: const MainSlurryScreen(), 
      ),
    );
  }
}