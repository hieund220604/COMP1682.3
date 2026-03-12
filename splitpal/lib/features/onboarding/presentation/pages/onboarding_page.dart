import 'package:flutter/material.dart';
import 'package:splitpal/features/home/presentation/pages/home_shell_page.dart';
import '../../../../core/constants/app_colors.dart';

class OnboardingPage extends StatefulWidget {
  static const routeName = '/onboarding';

  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentIndex = 0;

  final _colors = const <String, Color>{
    'clouds': Color(0xFFECF0F1),
    'silver': Color(0xFFBDC3C7),
    'concrete': Color(0xFF95A5A6),
    'asbestos': Color(0xFF7F8C8D),
    'midnight': Color(0xFF2C3E50),
    'alizarin': Color(0xFFE74C3C),
    'pomegranate': Color(0xFFC0392B),
    'white': Colors.white,
  };

  void _next() {
    if (_currentIndex < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    Navigator.of(context).pushReplacementNamed(HomeShellPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _colors['clouds'],
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          physics: const ClampingScrollPhysics(), // Prevent overscroll for custom feel
          children: [
            _ManageSubscriptionsSlide(
              colors: _colors,
              onNext: _next,
              onSkip: _finish,
            ),
            _SmartAutoSplitSlide(
              colors: _colors,
              onNext: _finish,
              onBack: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
              onSkip: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageSubscriptionsSlide extends StatelessWidget {
  final Map<String, Color> colors;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _ManageSubscriptionsSlide({
    required this.colors,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors['alizarin'],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SplitPal',
                    style: TextStyle(
                      color: colors['midnight'],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: colors['concrete'],
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                child: const Text('SKIP'),
              ),
            ],
          ),
        ),
        
        // Main Visual Area
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background Blur Circles
              Positioned(
                top: 40,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors['silver']!.withOpacity(0.3)),
                  ),
                ),
              ),
              // Main Card
              Center(
                child: Container(
                  width: 320,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colors['midnight']!.withOpacity(0.1),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                        spreadRadius: -10,
                      ),
                    ],
                    border: Border.all(color: colors['silver']!.withOpacity(0.2)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                    children: [
                      // Card Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: colors['clouds']!.withOpacity(0.3),
                          border: Border(bottom: BorderSide(color: colors['silver']!.withOpacity(0.2))),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: colors['alizarin'],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: colors['midnight']!.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 48,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: colors['silver'],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                border: Border.all(color: colors['concrete']!.withOpacity(0.3), width: 2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: colors['concrete'],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Card List
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildListItem(
                              colors,
                              Icons.movie,
                              colors['white']!,
                              colors['concrete']!,
                              false,
                            ),
                            const SizedBox(height: 16),
                            _buildHighlightListItem(colors),
                            const SizedBox(height: 16),
                            _buildListItem(
                              colors,
                              Icons.school,
                              colors['clouds']!,
                              colors['concrete']!,
                              true,
                            ),
                          ],
                        ),
                      ),
                      // Card Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: colors['clouds']!.withOpacity(0.3),
                          border: Border(top: BorderSide(color: colors['silver']!.withOpacity(0.2))),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL MONTHLY',
                              style: TextStyle(
                                color: colors['concrete'],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              '\$25.98',
                              style: TextStyle(
                                color: colors['midnight'],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
              // Action Req Badge (simplified animation - sticking to static for stability or simple bounce if easy)
              Positioned(
                top: 40, // Adjust based on layout
                right: 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: colors['midnight']!.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: colors['silver']!.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: colors['pomegranate'],
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        'ACTION REQ.',
                        style: TextStyle(
                          color: colors['midnight'],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Sheet
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.5))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 40,
                offset: const Offset(0, -10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Manage Subscriptions',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Stop chasing roommates for their share. Track family plans and recurring digital services in one professional dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors['asbestos'],
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              // Dots - Middle Active (Silver, Red, Silver) as per visual even if pages are 2
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors['silver'],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 6, // line
                    decoration: BoxDecoration(
                      color: colors['alizarin'],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                   const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors['silver'],
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors['alizarin'],
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: colors['alizarin']!.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(
      Map<String, Color> colors, IconData icon, Color bg, Color iconColor, bool faded) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors['clouds']!.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors['silver']!.withOpacity(0.2)),
      ),
      child: opacity(
        opacity: faded ? 0.4 : 1.0,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors['silver']!.withOpacity(0.3)),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors['concrete']!.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 40,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors['silver']!.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget opacity({required double opacity, required Widget child}) {
    return Opacity(opacity: opacity, child: child);
  }

  Widget _buildHighlightListItem(Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors['alizarin']!),
        boxShadow: [
            BoxShadow(
              color: colors['midnight']!.withOpacity(0.05),
              offset: const Offset(0, 4),
              blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40, 
            height: 40,
            decoration: BoxDecoration(
              color: colors['alizarin'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10), // Reduced gap for space
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                         Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors['midnight'],
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          Text(
                            '\$9.99',
                            style: TextStyle(
                                color: colors['alizarin'],
                                fontSize: 11,
                                fontWeight: FontWeight.bold
                            ),
                          )
                    ]
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors['clouds'],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors['silver']!.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                            Icon(Icons.check, size: 12, color: colors['midnight']),
                            const SizedBox(width: 4),
                            Text('PAID', style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colors['midnight']!.withOpacity(0.7)
                            )),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 24,
                      child: Stack(
                          children: [
                              Positioned(
                                  left: 0,
                                  child: Container(
                                      width: 24, height: 24,
                                      decoration: BoxDecoration(
                                          color: colors['clouds'],
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                      ),
                                  )
                              ),
                              Positioned(
                                  left: 16,
                                  child: Container(
                                      width: 24, height: 24,
                                      decoration: BoxDecoration(
                                          color: colors['alizarin'],
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Center(
                                          child: Text('ME', style: TextStyle(
                                              color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold
                                          )),
                                      ),
                                  )
                              ),
                          ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartAutoSplitSlide extends StatelessWidget {
  final Map<String, Color> colors;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _SmartAutoSplitSlide({
    required this.colors,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors['silver']!),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: colors['concrete']),
                  onPressed: onBack,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                ),
              ),
              TextButton(
                onPressed: onSkip,
                child: Text('Skip', style: TextStyle(
                   color: colors['concrete'],
                   fontSize: 14,
                   fontWeight: FontWeight.w600,
                )),
              ),
            ],
          ),
        ),

        // Main Content
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow Effect
              Positioned(
                top: 100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: colors['alizarin']!.withOpacity(0.05),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors['alizarin']!.withOpacity(0.05),
                        blurRadius: 80, 
                        spreadRadius: 20
                      )
                    ]
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        // Card
                        Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colors['silver']!.withOpacity(0.8)),
                                boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 4),
                                    )
                                ]
                            ),
                            child: Column(
                                children: [
                                    // Header
                                    Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                                Row(
                                                    children: [
                                                        Container(
                                                            width: 44, height: 44,
                                                            decoration: BoxDecoration(
                                                                color: colors['clouds']!.withOpacity(0.5),
                                                                borderRadius: BorderRadius.circular(12),
                                                                border: Border.all(color: colors['silver']!.withOpacity(0.3)),
                                                            ),
                                                            child: Icon(Icons.pie_chart, color: colors['alizarin']),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                                Text('TOTAL AMOUNT', style: TextStyle(
                                                                    fontSize: 10, fontWeight: FontWeight.bold,
                                                                    letterSpacing: 1.0, color: colors['concrete']
                                                                )),
                                                                Text('\$100.00', style: TextStyle(
                                                                    fontSize: 20, fontWeight: FontWeight.bold,
                                                                    color: colors['midnight']
                                                                )),
                                                            ],
                                                        )
                                                    ],
                                                ),
                                                Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                        color: colors['alizarin']!.withOpacity(0.05),
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(color: colors['alizarin']!.withOpacity(0.2)),
                                                    ),
                                                    child: Row(
                                                        children: [
                                                            Icon(Icons.auto_awesome, size: 14, color: colors['alizarin']),
                                                            const SizedBox(width: 4),
                                                            Text('AI Split', style: TextStyle(
                                                                fontSize: 11, fontWeight: FontWeight.w600,
                                                                color: colors['alizarin']
                                                            )),
                                                        ],
                                                    ),
                                                )
                                            ],
                                        ),
                                    ),
                                    
                                    // Graph Area
                                    Container(
                                        color: colors['clouds']!.withOpacity(0.3),
                                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                                        height: 220,
                                        width: double.infinity,
                                        child: Stack(
                                            alignment: Alignment.topCenter,
                                            children: [
                                                // Connection Lines using CustomPaint
                                                CustomPaint(
                                                    size: const Size(double.infinity, 200),
                                                    painter: _TreeConnectionPainter(
                                                        color: colors['silver']!,
                                                    ),
                                                ),
                                                
                                                // Avatars
                                                Positioned(
                                                    top: 24, // Start of vertical lines + length
                                                    left: 0,
                                                    right: 0,
                                                    child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                            // Left Avatar (25%)
                                                            Expanded(child: _buildAvatar(colors, '25%', '\$25.00', false)),
                                                            // Center Avatar (50% - Big)
                                                            Expanded(child: Padding(
                                                              padding: const EdgeInsets.only(top: 10.0), // Push down slightly
                                                              child: _buildAvatar(colors, '50%', '\$50.00', true),
                                                            )),
                                                            // Right Avatar (25%)
                                                            Expanded(child: _buildAvatar(colors, '25%', '\$25.00', false)),
                                                        ],
                                                    ),
                                                )
                                            ],
                                        ),
                                    ),
                                    
                                    // Footer info
                                    Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border(top: BorderSide(color: colors['silver']!.withOpacity(0.2))),
                                        ),
                                        child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Icon(Icons.info_outline, size: 20, color: colors['silver']),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                    child: RichText(
                                                        text: TextSpan(
                                                            style: TextStyle(color: colors['asbestos'], fontSize: 12, height: 1.5), 
                                                            children: [
                                                                const TextSpan(text: 'Split calculated by '),
                                                                TextSpan(text: 'Income Ratio', style: TextStyle(
                                                                    color: colors['midnight'], fontWeight: FontWeight.bold
                                                                )),
                                                                const TextSpan(text: '. Adjustments can be made manually in settings.'),
                                                            ]
                                                        )
                                                    ),
                                                )
                                            ],
                                        ),
                                    )
                                ],
                            ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Text
                        const Text(
                            'Smart auto-split',
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold,
                            ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                            'Let our AI instantly calculate ratios or slots. No more math, just fair shares.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15, color: colors['concrete'], height: 1.5
                            ),
                        )
                    ],
                ),
              )
            ],
          ),
        ),

        // Footer
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
                children: [
                     // Dots - Last Active
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(color: colors['silver']!.withOpacity(0.5), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(color: colors['silver']!.withOpacity(0.5), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                             Container(
                                width: 32, height: 6,
                                decoration: BoxDecoration(color: colors['alizarin'], borderRadius: BorderRadius.circular(3)),
                            ),
                        ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                            onPressed: onNext,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: colors['alizarin'],
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: colors['alizarin']!.withOpacity(0.25),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Text('Get Started', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 20, fontWeight: FontWeight.bold),
                                ],
                            ),
                        ),
                    )
                ],
            ),
        )
      ],
    );
  }

  Widget _buildAvatar(Map<String, Color> colors, String percent, String amount, bool highlight) {
      final size = highlight ? 64.0 : 40.0;
      final fontSize = highlight ? 11.0 : 10.0;
      final amountSize = highlight ? 18.0 : 12.0;
      final amountColor = highlight ? colors['alizarin'] : colors['concrete'];
      // final topMargin = highlight ? 0.0 : 20.0; // Managed by Padding in parent
      
      return Column( // Removed Expanded/SizedBox here to let parent control layout
          mainAxisSize: MainAxisSize.min,
          children: [
              Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                      Container(
                          width: size, height: size,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors['silver'],
                              border: Border.all(color: Colors.white, width: highlight ? 4 : 2),
                              boxShadow: highlight ? [
                                  BoxShadow(color: colors['alizarin']!.withOpacity(0.25), blurRadius: 20)
                              ] : []
                          ),
                          child: Icon(Icons.person, color: Colors.white, size: size * 0.6),
                      ),
                      Positioned(
                          bottom: -8,
                          child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: highlight ? colors['alizarin'] : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: highlight ? Colors.white : colors['silver']!),
                              ),
                              child: Text(percent, style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: highlight ? Colors.white : colors['concrete']
                              )),
                          )
                      )
                  ],
              ),
              const SizedBox(height: 16),
              Text(amount, style: TextStyle(
                  fontSize: amountSize,
                  fontWeight: FontWeight.bold,
                  color: amountColor
              ))
          ],
      );
  }
}

class _TreeConnectionPainter extends CustomPainter {
  final Color color;

  _TreeConnectionPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    // We assume 3 items distributed: Left (center of left third), Middle (center), Right (center of right third)
    // Actually, "SpaceBetween" puts them at start, center, end? No, SpaceArounnd/Evenly?
    // In strict Row MainAxisAlignment.spaceBetween with 3 items:
    // Item 1 center is at: width/6 (ish, depending on item width).
    // Let's assume uniform distribution for the lines or match the avatars.
    
    // Top start point (above the container, logically, but we draw from top of THIS container)
    // The design shows a line coming from TOP center down to a T-junction.
    // Origin is (centerX, 0).
    // It goes down a bit, then splits left and right, then goes down to avatars.
    
    const topStemHeight = 24.0;
    const horizontalSpread = 80.0; // This should match half the distance between outer avatars
    // Assuming the outer avatars are roughly centered at centerX +/- horizontalSpread
    
    // Draw Center Stem
    canvas.drawLine(Offset(centerX, -20), Offset(centerX, 24), paint); // From slightly above
    
    // Draw Horizontal Bar
    canvas.drawLine(Offset(centerX - horizontalSpread, 24), Offset(centerX + horizontalSpread, 24), paint);
    
    // Draw Drops
    // Left
    canvas.drawLine(Offset(centerX - horizontalSpread, 24), Offset(centerX - horizontalSpread, 48), paint);
    // Right
    canvas.drawLine(Offset(centerX + horizontalSpread, 24), Offset(centerX + horizontalSpread, 48), paint);
    // Center (continuation)
    canvas.drawLine(Offset(centerX, 24), Offset(centerX, 48), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
