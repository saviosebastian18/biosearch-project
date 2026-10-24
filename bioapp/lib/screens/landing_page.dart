import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../screens/main_slurry_screen.dart'; // Import the target screen

// --- Wrapper to manage the screen state (Landing vs. AuthForm) ---
class LandingPage extends StatelessWidget {
  final String backgroundAsset;
  final Widget mainScreen;
  const LandingPage({super.key, required this.backgroundAsset, required this.mainScreen});

  @override
  Widget build(BuildContext context) {
    return _LandingViewState(backgroundAsset: backgroundAsset, mainScreen: mainScreen);
  }
}

class _LandingViewState extends StatefulWidget {
  final String backgroundAsset;
  final Widget mainScreen;
  const _LandingViewState({required this.backgroundAsset, required this.mainScreen});

  @override
  State<_LandingViewState> createState() => _LandingViewStateState();
}

class _LandingViewStateState extends State<_LandingViewState> {
  // State to track if the authentication forms should be shown
  // null: show intro buttons, true: show login, false: show signup
  bool? _showAuthForm;

  // Helper method for navigation after successful login/signup
  void _navigateToMainScreen(BuildContext context) {
    // TODO: Add Firebase auth check here before navigating
    // Once login/signup is complete and successful, navigate:
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => widget.mainScreen),
    );
  }

  // Helper method to reset the view to the initial state
  void _resetView() {
    setState(() {
      _showAuthForm = null;
    });
  }
  
  // Method to set the view to the login form
  void _startAuthProcess() {
    setState(() {
      _showAuthForm = true; // Default to showing the Login view first
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Determine the content to display based on the state
    Widget content;
    if (_showAuthForm == null) {
      // Initial View: Show the large Intro Card with the main button
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          // Pass the navigation function to the IntroCard
          child: IntroCard(onStart: _startAuthProcess), 
        ),
      );
    } else {
      // Auth Form View: Show the focused Login/Signup Form
      content = Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Button to go back to the intro view
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _resetView,
                  ),
                ),
                const SizedBox(height: 20),
                // The focused form
                LoginSignupForeground(
                  onLoginSuccess: () => _navigateToMainScreen(context),
                  initialViewIsLogin: _showAuthForm!, // Pass true for login, false for signup
                  // The form should allow switching between login and signup
                  onToggleSignup: (isLogin) {
                    setState(() {
                      _showAuthForm = isLogin;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      // Wrap in SafeArea to respect notches/cutouts
      body: SafeArea(
        child: CustomScrollView(
          // Only allow scrolling if the auth form is shown (in case it overflows)
          physics: _showAuthForm == null 
              ? const NeverScrollableScrollPhysics() 
              : const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true, // Keep the background fixed for a 'next page' feel
              delegate: FullCoverParallaxHeader(
                maxExtentHeight: screenHeight, 
                minExtentHeight: screenHeight,
                backgroundAsset: widget.backgroundAsset,
                parallaxFactor: 0.0, // Disable parallax to keep the screen fixed
                foreground: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Parallax Delegate (Retained and modified for simplicity) ---

class FullCoverParallaxHeader extends SliverPersistentHeaderDelegate {
  final double maxExtentHeight;
  final double minExtentHeight;
  final String backgroundAsset;
  final double parallaxFactor;
  final Widget foreground;

  FullCoverParallaxHeader({
    required this.maxExtentHeight,
    required this.minExtentHeight,
    required this.backgroundAsset,
    required this.foreground,
    this.parallaxFactor = 0.0, // Fixed to 0.0 for this design
  });

  @override
  double get minExtent => minExtentHeight;

  @override
  double get maxExtent => maxExtentHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // The Parallax logic is simplified when maxExtent == minExtent
    final double imageHeight = maxExtent;
    
    return SizedBox(
      height: maxExtent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill( // Use Positioned.fill when translateY is 0
            child: Image.asset(
              backgroundAsset,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade800,
                  alignment: Alignment.center,
                  child: const Text('Image Asset Not Found: farmer1.jpg', style: TextStyle(color: Colors.white70)),
                );
              },
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.35)),
          // The content changes based on _showAuthForm state
          foreground,
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant FullCoverParallaxHeader oldDelegate) {
    return oldDelegate.backgroundAsset != backgroundAsset ||
        oldDelegate.maxExtentHeight != maxExtentHeight ||
        oldDelegate.minExtentHeight != minExtentHeight ||
        oldDelegate.minExtentHeight != minExtentHeight ||
        oldDelegate.foreground != foreground;
  }
}

// --- Intro Card (Now bigger and includes the action button) ---

class IntroCard extends StatelessWidget {
  final VoidCallback onStart;
  const IntroCard({super.key, required this.onStart});
  
  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.of(context).size.width * 0.9, 420.0);
    return Container(
      width: width,
      padding: const EdgeInsets.all(32), // Increased padding for bigger look
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // More rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2), // Stronger shadow
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            radius: 40, // Increased radius for bigger logo
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          Text('Biosearch',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)), // Bigger font
          const SizedBox(height: 12),
          const Text(
            'AI & IoT powered Biogas and Fertilizer Assistant',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 32),
          // --- Single Action Button ---
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.arrow_forward_ios),
            label: const Text('continue to Biosearch', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 8,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Login/Signup Form Wrapper ---

class LoginSignupForeground extends StatelessWidget {
  final VoidCallback onLoginSuccess;
  final bool initialViewIsLogin;
  final Function(bool isLogin) onToggleSignup; // Added function to allow toggle up
  
  const LoginSignupForeground({
    super.key, 
    required this.onLoginSuccess, 
    required this.initialViewIsLogin,
    required this.onToggleSignup,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: _RightPanel(
        onLoginSuccess: onLoginSuccess, 
        initialViewIsLogin: initialViewIsLogin,
        onToggleSignup: onToggleSignup,
      ),
    );
  }
}

class _RightPanel extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final bool initialViewIsLogin;
  final Function(bool isLogin) onToggleSignup;
  
  const _RightPanel({required this.onLoginSuccess, required this.initialViewIsLogin, required this.onToggleSignup});

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  // Use a nullable bool for cleaner state management of the view selection
  late bool _isLoginView;

  @override
  void initState() {
    super.initState();
    // Ensure the initial view state is set from the parent widget
    _isLoginView = widget.initialViewIsLogin;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Tab Selection (Login/Signup Buttons) ---
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  // Update state and notify parent (if required for logging)
                  onPressed: () => setState(() {
                    _isLoginView = true;
                    widget.onToggleSignup(true);
                  }),
                  style: ElevatedButton.styleFrom(
                    shape: const StadiumBorder(),
                    backgroundColor: _isLoginView ? Theme.of(context).primaryColor : Colors.grey[200],
                    foregroundColor: _isLoginView ? Colors.white : Colors.grey[600],
                    elevation: _isLoginView ? 4 : 0,
                  ),
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  // Update state and notify parent (if required for logging)
                  onPressed: () => setState(() {
                    _isLoginView = false;
                    widget.onToggleSignup(false);
                  }),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: BorderSide(color: !_isLoginView ? Theme.of(context).primaryColor : Colors.grey.shade400),
                    backgroundColor: _isLoginView ? Colors.white : Theme.of(context).primaryColor.withOpacity(0.1),
                    foregroundColor: !_isLoginView ? Theme.of(context).primaryColor : Colors.grey[600],
                  ),
                  child: const Text('Signup'),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            
            // --- Forms ---
            if (_isLoginView)
              _buildLoginForm()
            else
              _buildSignupForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Add Firebase Login logic here
            widget.onLoginSuccess(); // Navigate on button press
          },
          icon: const Icon(Icons.login),
          label: const Text('Login'),
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Enter OTP',
            prefixIcon: const Icon(Icons.pin_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: TextButton(
              onPressed: () {
                // TODO: Add OTP generation logic here
              },
              child: const Text('Get OTP'),
            )
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Add Firebase Signup logic here
          },
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Create Account'),
        ),
      ],
    );
  }
}
