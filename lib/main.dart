import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnv();
  runApp(const BmiApp());
}

// -----------------------------------------------------------------------------
// GEMINI API CONFIG — key is loaded at startup from the bundled .env file
// -----------------------------------------------------------------------------
// Your .env file should contain a line like:
//   GEMINI_API_KEY=your_real_key_here
//
// Make sure pubspec.yaml lists .env as an asset:
//   flutter:
//     assets:
//       - .env
//
// And make sure .env is listed in .gitignore so the key never gets committed.
String geminiApiKey = '';
const String geminiModel = 'gemini-2.5-flash';

/// Reads the bundled .env asset and pulls out GEMINI_API_KEY=... .
/// If the file is missing or the key isn't found, geminiApiKey stays empty
/// and the UI shows a clear, actionable error instead of crashing.
Future<void> _loadEnv() async {
  try {
    final content = await rootBundle.loadString('.env');
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final eqIndex = line.indexOf('=');
      if (eqIndex == -1) continue;

      final key = line.substring(0, eqIndex).trim();
      var value = line.substring(eqIndex + 1).trim();

      // Strip surrounding quotes if the value was quoted in the .env file
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }

      if (key == 'GEMINI_API_KEY') {
        geminiApiKey = value;
      }
    }
  } catch (_) {
    // .env not found / not declared as an asset / unreadable.
    // geminiApiKey stays '' — _fetchHealthPlan() will surface a clear error.
  }
}

class BmiApp extends StatelessWidget {
  const BmiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMI Body Visualizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const BmiHomePage(),
    );
  }
}

enum Gender { female, male }

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------
Color colorForBmi(double bmi) {
  const Color underweightColor = Color(0xFF3B82F6); // blue
  const Color normalColor = Color(0xFF22C55E); // green
  const Color overweightColor = Color(0xFFF97316); // orange
  const Color obeseColor = Color(0xFFEF4444); // red

  if (bmi <= 18.5) return underweightColor;
  if (bmi <= 25) {
    final t = (bmi - 18.5) / (25 - 18.5);
    return Color.lerp(underweightColor, normalColor, t)!;
  }
  if (bmi <= 30) {
    final t = (bmi - 25) / (30 - 25);
    return Color.lerp(normalColor, overweightColor, t)!;
  }
  if (bmi <= 40) {
    final t = (bmi - 30) / (40 - 30);
    return Color.lerp(overweightColor, obeseColor, t)!;
  }
  return obeseColor;
}

String categoryForBmi(double bmi) {
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Normal';
  if (bmi < 30) return 'Overweight';
  return 'Obese';
}

double mapRange(double value, double inMin, double inMax, double outMin, double outMax) {
  final clamped = value.clamp(inMin, inMax);
  return outMin + (clamped - inMin) / (inMax - inMin) * (outMax - outMin);
}

// -----------------------------------------------------------------------------
// CUSTOM PAINTER: Highly Accurate Illustrated Character Model
// -----------------------------------------------------------------------------
class BodyPainter extends CustomPainter {
  final double bmi;
  final Gender gender;
  final Color outfitColor;

  BodyPainter({required this.bmi, required this.gender, required this.outfitColor});

  static const Color skinColor = Color(0xFFF2C299);
  static const Color hairColor = Color(0xFF632B11);
  static const Color strokeColor = Color(0xFF261208);

  @override
  void paint(Canvas canvas, Size size) {
    final fillSkin = Paint()..color = skinColor..style = PaintingStyle.fill;
    final fillHair = Paint()..color = hairColor..style = PaintingStyle.fill;
    final fillOutfit = Paint()..color = outfitColor..style = PaintingStyle.fill;
    final fillShoes = Paint()..color = const Color(0xFF2A3142)..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final h = size.height;
    final centerX = size.width / 2;

    final widthFactor = mapRange(bmi, 14, 40, 0.70, 1.45);

    final headRadius = h * 0.068;
    final headCenterY = h * 0.15 + headRadius;
    final neckTop = headCenterY + headRadius - 1;
    final neckHeight = h * 0.025;
    final torsoTop = neckTop + neckHeight;
    final torsoBottom = h * 0.54;
    final legBottom = h * 0.88;

    final shoulderWidth = h * (gender == Gender.female ? 0.16 : 0.19) * widthFactor;
    final waistWidth = h * 0.14 * widthFactor;
    final hipWidth = h * (gender == Gender.female ? 0.18 : 0.17) * widthFactor;
    final armLength = h * 0.22;
    final armThickness = h * 0.032;

    if (gender == Gender.female) {
      final hairBackPath = Path()
        ..moveTo(centerX, headCenterY - headRadius * 1.1)
        ..cubicTo(centerX - headRadius * 1.3, headCenterY - headRadius * 1.0,
                  centerX - headRadius * 1.4, headCenterY + headRadius * 1.2,
                  centerX - headRadius * 1.0, headCenterY + headRadius * 2.2)
        ..quadraticBezierTo(centerX, headCenterY + headRadius * 2.5,
                            centerX + headRadius * 1.0, headCenterY + headRadius * 2.2)
        ..cubicTo(centerX + headRadius * 1.4, headCenterY + headRadius * 1.2,
                  centerX + headRadius * 1.3, headCenterY - headRadius * 1.0,
                  centerX, headCenterY - headRadius * 1.1)
        ..close();
      canvas.drawPath(hairBackPath, fillHair);
      canvas.drawPath(hairBackPath, outlinePaint);
    }

    final leftArmPath = Path()
      ..moveTo(centerX - shoulderWidth / 2, torsoTop + 2)
      ..lineTo(centerX - shoulderWidth / 2 - armLength, torsoTop + 5)
      ..quadraticBezierTo(centerX - shoulderWidth / 2 - armLength - 12, torsoTop + 7,
                          centerX - shoulderWidth / 2 - armLength - 15, torsoTop + 9)
      ..quadraticBezierTo(centerX - shoulderWidth / 2 - armLength - 10, torsoTop + 14,
                          centerX - shoulderWidth / 2 - armLength, torsoTop + armThickness - 2)
      ..lineTo(centerX - shoulderWidth / 2, torsoTop + armThickness)
      ..close();

    final rightArmPath = Path()
      ..moveTo(centerX + shoulderWidth / 2, torsoTop + 2)
      ..lineTo(centerX + shoulderWidth / 2 + armLength, torsoTop + 5)
      ..quadraticBezierTo(centerX + shoulderWidth / 2 + armLength + 12, torsoTop + 7,
                          centerX + shoulderWidth / 2 + armLength + 15, torsoTop + 9)
      ..quadraticBezierTo(centerX + shoulderWidth / 2 + armLength + 10, torsoTop + 14,
                          centerX + shoulderWidth / 2 + armLength, torsoTop + armThickness - 2)
      ..lineTo(centerX + shoulderWidth / 2, torsoTop + armThickness)
      ..close();

    canvas.drawPath(leftArmPath, fillSkin);
    canvas.drawPath(leftArmPath, outlinePaint);
    canvas.drawPath(rightArmPath, fillSkin);
    canvas.drawPath(rightArmPath, outlinePaint);

    final outfitPath = Path();
    if (gender == Gender.female) {
      outfitPath.moveTo(centerX - shoulderWidth * 0.35, torsoTop);
      outfitPath.quadraticBezierTo(centerX, torsoTop + 12, centerX + shoulderWidth * 0.35, torsoTop);
      outfitPath.lineTo(centerX + shoulderWidth * 0.45, torsoTop + armThickness);
      outfitPath.quadraticBezierTo(centerX + shoulderWidth * 0.52, (torsoTop + torsoBottom) / 2, centerX + waistWidth / 2, torsoTop + (torsoBottom - torsoTop) * 0.65);
      outfitPath.quadraticBezierTo(centerX + hipWidth * 0.52, torsoBottom - 10, centerX + hipWidth / 2, torsoBottom);
      outfitPath.lineTo(centerX - hipWidth / 2, torsoBottom);
      outfitPath.quadraticBezierTo(centerX - hipWidth * 0.52, torsoBottom - 10, centerX - waistWidth / 2, torsoTop + (torsoBottom - torsoTop) * 0.65);
      outfitPath.quadraticBezierTo(centerX - shoulderWidth * 0.52, (torsoTop + torsoBottom) / 2, centerX - shoulderWidth * 0.45, torsoTop + armThickness);
      outfitPath.close();
    } else {
      outfitPath.moveTo(centerX - shoulderWidth * 0.5, torsoTop);
      outfitPath.quadraticBezierTo(centerX, torsoTop + 5, centerX + shoulderWidth * 0.5, torsoTop);
      outfitPath.lineTo(centerX + shoulderWidth * 0.5, torsoTop + armThickness * 1.2);
      outfitPath.lineTo(centerX + waistWidth * 0.55, torsoBottom);
      outfitPath.lineTo(centerX - waistWidth * 0.55, torsoBottom);
      outfitPath.lineTo(centerX - shoulderWidth * 0.5, torsoTop + armThickness * 1.2);
      outfitPath.close();
    }
    canvas.drawPath(outfitPath, fillOutfit);
    canvas.drawPath(outfitPath, outlinePaint);

    final seamY = torsoTop + (torsoBottom - torsoTop) * 0.65;
    canvas.drawLine(Offset(centerX - waistWidth * 0.48, seamY), Offset(centerX + waistWidth * 0.48, seamY), outlinePaint);

    final neckPath = Path()
      ..moveTo(centerX - h * 0.015, torsoTop + 3)
      ..lineTo(centerX - h * 0.015, neckTop)
      ..lineTo(centerX + h * 0.015, neckTop)
      ..lineTo(centerX + h * 0.015, torsoTop + 3)
      ..close();
    canvas.drawPath(neckPath, fillSkin);
    canvas.drawPath(neckPath, outlinePaint);

    final headRect = Rect.fromCenter(center: Offset(centerX, headCenterY), width: headRadius * 1.8, height: headRadius * 2.0);
    canvas.drawOval(headRect, fillSkin);
    canvas.drawOval(headRect, outlinePaint);

    final hairCapPath = Path()
      ..addArc(Rect.fromCenter(center: Offset(centerX, headCenterY - 3), width: headRadius * 1.86, height: headRadius * 2.05), 3.14, 3.14);
    if (gender == Gender.female) {
      hairCapPath.quadraticBezierTo(centerX + headRadius * 0.8, headCenterY, centerX + headRadius * 0.5, headCenterY + 4);
      hairCapPath.quadraticBezierTo(centerX, headCenterY - 8, centerX - headRadius * 0.5, headCenterY + 4);
      hairCapPath.quadraticBezierTo(centerX - headRadius * 0.8, headCenterY, centerX - headRadius * 0.9, headCenterY - 10);
    } else {
      hairCapPath.quadraticBezierTo(centerX, headCenterY - 5, centerX - headRadius * 0.9, headCenterY - 5);
    }
    canvas.drawPath(hairCapPath, fillHair);
    canvas.drawPath(hairCapPath, outlinePaint);

    final legGap = (h * 0.016 * widthFactor).clamp(6.0, 22.0);
    final trouserWidth = (hipWidth / 2) - (legGap / 2);

    final leftLegRect = Rect.fromLTWH(centerX - hipWidth / 2, torsoBottom - 1, trouserWidth, legBottom - torsoBottom);
    final rightLegRect = Rect.fromLTWH(centerX + legGap / 2, torsoBottom - 1, trouserWidth, legBottom - torsoBottom);

    final pantsPaint = gender == Gender.male ? (Paint()..color = Color.lerp(outfitColor, Colors.black, 0.12)!..style = PaintingStyle.fill) : fillOutfit;

    canvas.drawRect(leftLegRect, pantsPaint);
    canvas.drawRect(leftLegRect, outlinePaint);
    canvas.drawRect(rightLegRect, pantsPaint);
    canvas.drawRect(rightLegRect, outlinePaint);

    final pocketY = torsoBottom + 8;
    canvas.drawLine(Offset(centerX - hipWidth / 2 + 3, pocketY), Offset(centerX - hipWidth / 2 + trouserWidth * 0.4, pocketY + 12), outlinePaint);
    canvas.drawLine(Offset(centerX + hipWidth / 2 - 3, pocketY), Offset(centerX + hipWidth / 2 - trouserWidth * 0.4, pocketY + 12), outlinePaint);

    final shoeWidth = trouserWidth * 1.1;
    final shoeHeight = h * 0.026;

    final leftShoePath = Path()
      ..moveTo(centerX - legGap / 2, legBottom)
      ..lineTo(centerX - legGap / 2 - shoeWidth, legBottom)
      ..quadraticBezierTo(centerX - legGap / 2 - shoeWidth - 4, legBottom + shoeHeight * 0.6, centerX - legGap / 2 - shoeWidth + 2, legBottom + shoeHeight)
      ..lineTo(centerX - legGap / 2, legBottom + shoeHeight)
      ..close();

    final rightShoePath = Path()
      ..moveTo(centerX + legGap / 2, legBottom)
      ..lineTo(centerX + legGap / 2 + shoeWidth, legBottom)
      ..quadraticBezierTo(centerX + legGap / 2 + shoeWidth + 4, legBottom + shoeHeight * 0.6, centerX + legGap / 2 + shoeWidth - 2, legBottom + shoeHeight)
      ..lineTo(centerX + legGap / 2, legBottom + shoeHeight)
      ..close();

    canvas.drawPath(leftShoePath, fillShoes);
    canvas.drawPath(leftShoePath, outlinePaint);
    canvas.drawPath(rightShoePath, fillShoes);
    canvas.drawPath(rightShoePath, outlinePaint);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(Rect.fromCenter(center: Offset(centerX, legBottom + shoeHeight + 2), width: hipWidth * 1.45, height: 7), shadowPaint);
  }

  @override
  bool shouldRepaint(covariant BodyPainter oldDelegate) {
    return oldDelegate.bmi != bmi || oldDelegate.gender != gender || oldDelegate.outfitColor != outfitColor;
  }
}

// -----------------------------------------------------------------------------
// MAIN PAGE WIDGET IMPLEMENTATION
// -----------------------------------------------------------------------------
class BmiHomePage extends StatefulWidget {
  const BmiHomePage({super.key});

  @override
  State<BmiHomePage> createState() => _BmiHomePageState();
}

class _BmiHomePageState extends State<BmiHomePage> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  Gender _gender = Gender.female;
  double? _bmi;
  double _targetBmi = 22;
  double _weight = 0;
  bool _hasResult = false;
  String? _errorText;

  // ---- Gemini AI plan state ----
  bool _isLoadingPlan = false;
  String? _dietPlan;
  String? _exercisePlan;
  String? _planError;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _calculateBmi() {
    FocusScope.of(context).unfocus();

    final weight = double.tryParse(_weightController.text.trim());
    final heightCm = double.tryParse(_heightController.text.trim());

    if (weight == null || heightCm == null) {
      setState(() => _errorText = 'Please enter valid numbers for weight and height.');
      return;
    }
    if (weight <= 1 || weight > 300) {
      setState(() => _errorText = 'Enter a realistic weight between 1 and 300 kg.');
      return;
    }
    if (heightCm <= 50 || heightCm > 250) {
      setState(() => _errorText = 'Enter a realistic height between 50 and 250 cm.');
      return;
    }

    final heightM = heightCm / 100;
    final bmi = weight / (heightM * heightM);

    setState(() {
      _errorText = null;
      _bmi = bmi;
      _weight = weight;
      _targetBmi = bmi;
      _hasResult = true;
      // Clear any previous AI plan since it belongs to the old numbers
      _dietPlan = null;
      _exercisePlan = null;
      _planError = null;
    });
  }

  void _reset() {
    setState(() {
      _weightController.clear();
      _heightController.clear();
      _bmi = null;
      _weight = 0;
      _hasResult = false;
      _errorText = null;
      _targetBmi = 22;
      _dietPlan = null;
      _exercisePlan = null;
      _planError = null;
      _isLoadingPlan = false;
    });
  }

  // ---------------------------------------------------------------------------
  // GEMINI API CALL — pure dart:io/dart:convert/dart:async, no extra packages.
  // ---------------------------------------------------------------------------
  Future<void> _fetchHealthPlan() async {
    if (_bmi == null) return;

    if (geminiApiKey.isEmpty) {
      setState(() {
        _planError = 'No Gemini API key found. Make sure your .env file has '
            'a line like GEMINI_API_KEY=your_key, and that .env is listed '
            'under flutter: assets: in pubspec.yaml.';
      });
      return;
    }

    setState(() {
      _isLoadingPlan = true;
      _planError = null;
      _dietPlan = null;
      _exercisePlan = null;
    });

    HttpClient? client;
    try {
      final category = categoryForBmi(_bmi!);
      final genderLabel = _gender == Gender.female ? 'female' : 'male';

      final prompt =
          'You are a certified nutrition and fitness assistant. A $genderLabel user '
          'has a BMI of ${_bmi!.toStringAsFixed(1)}, which falls in the "$category" '
          'category, at a weight of ${_weight.toStringAsFixed(1)} kg. Give practical, '
          'safe, general-wellness suggestions — this is not medical advice, and you '
          'should not diagnose any condition. Respond in EXACTLY this plain-text '
          'format, with no markdown asterisks and no extra commentary before or after:\n\n'
          'DIET:\n'
          '- tip one\n'
          '- tip two\n'
          '- tip three\n'
          '- tip four\n\n'
          'EXERCISE:\n'
          '- tip one\n'
          '- tip two\n'
          '- tip three\n'
          '- tip four';

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent',
      );

      client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('x-goog-api-key', geminiApiKey);
      request.add(utf8.encode(jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
      })));

      final response = await request.close().timeout(const Duration(seconds: 30));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Gemini returned status ${response.statusCode}. ${_shortError(body)}');
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini returned no candidates. It may have blocked this prompt.');
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      final text = (parts != null && parts.isNotEmpty) ? (parts.first['text'] as String? ?? '') : '';

      if (text.trim().isEmpty) {
        throw Exception('Gemini returned an empty response.');
      }

      final dietMatch = RegExp(r'DIET:(.*?)(EXERCISE:|$)', dotAll: true).firstMatch(text);
      final exerciseMatch = RegExp(r'EXERCISE:(.*)$', dotAll: true).firstMatch(text);

      setState(() {
        _dietPlan = dietMatch != null ? dietMatch.group(1)!.trim() : text.trim();
        _exercisePlan = exerciseMatch != null ? exerciseMatch.group(1)!.trim() : '';
        _isLoadingPlan = false;
      });
    } on SocketException {
      setState(() {
        _planError = 'No internet connection. Check your network and try again.';
        _isLoadingPlan = false;
      });
    } on TimeoutException {
      setState(() {
        _planError = 'The request timed out. Try again.';
        _isLoadingPlan = false;
      });
    } catch (e) {
      setState(() {
        _planError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingPlan = false;
      });
    } finally {
      client?.close(force: true);
    }
  }

  String _shortError(String body) {
    if (body.length <= 200) return body;
    return '${body.substring(0, 200)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'BMI Body Visualizer',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter your details to see your body shape',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              const SizedBox(height: 24),
              _buildGenderField(),
              const SizedBox(height: 16),
              _buildInputCard(),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _hasResult
                    ? _buildResultSection(key: const ValueKey('result'))
                    : _buildPlaceholder(key: const ValueKey('placeholder')),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderField() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gender', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _genderOption(Gender.female, 'Female', Icons.female_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _genderOption(Gender.male, 'Male', Icons.male_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _genderOption(Gender value, String label, IconData icon) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.tealAccent.withOpacity(0.15) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.tealAccent : Colors.white.withOpacity(0.08), width: 1.4),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.tealAccent : Colors.white54, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.tealAccent : Colors.white54,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField(_weightController, 'Weight', 'kg', Icons.monitor_weight_outlined)),
              const SizedBox(width: 14),
              Expanded(child: _buildTextField(_heightController, 'Height', 'cm', Icons.height_rounded)),
            ],
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(_errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  onPressed: _calculateBmi,
                  child: const Text('CALCULATE BMI', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _reset,
                  child: const Text('RESET', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String unit, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: '$label ($unit)',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.tealAccent, size: 20),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.tealAccent, width: 1.5),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildPlaceholder({Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.accessibility_new_rounded, size: 72, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 12),
          Text(
            'Your animated body preview will appear here',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection({Key? key}) {
    final bmi = _bmi ?? 22;
    final category = categoryForBmi(bmi);

    final computedCalories = (_weight * 30).round();
    final computedProtein = (_weight * 1.6).round();

    return Column(
      key: key,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 22, end: _targetBmi),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
          builder: (context, animatedBmi, child) {
            final animatedColor = colorForBmi(animatedBmi);
            return Container(
              height: 380,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: animatedColor.withOpacity(0.4), width: 1.5),
              ),
              child: CustomPaint(
                size: const Size(double.infinity, 380),
                painter: BodyPainter(bmi: animatedBmi, gender: _gender, outfitColor: animatedColor),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(bmi.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
            const Padding(
              padding: EdgeInsets.only(bottom: 10, left: 4),
              child: Text('BMI', style: TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: colorForBmi(bmi).withOpacity(0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: colorForBmi(bmi), width: 1.2),
          ),
          child: Text(category.toUpperCase(), style: TextStyle(color: colorForBmi(bmi), fontWeight: FontWeight.w800, letterSpacing: 1)),
        ),
        const SizedBox(height: 24),
        _buildBmiGauge(bmi),
        const SizedBox(height: 28),

        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Recommended Daily Intake Target',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildIntakeCard(
                title: 'Calories',
                value: '$computedCalories',
                unit: 'kcal',
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF97316),
                subtitle: 'Maintenance Target',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildIntakeCard(
                title: 'Protein',
                value: '$computedProtein',
                unit: 'g',
                icon: Icons.fitness_center_rounded,
                iconColor: const Color(0xFF3B82F6),
                subtitle: 'Active Athlete Target',
              ),
            ),
          ],
        ),

        _buildAiPlanSection(),
      ],
    );
  }

  Widget _buildAiPlanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'AI Diet & Exercise Plan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
            ),
            if (!_isLoadingPlan)
              TextButton.icon(
                onPressed: _fetchHealthPlan,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                icon: Icon(_dietPlan == null ? Icons.auto_awesome_rounded : Icons.refresh_rounded, size: 16, color: Colors.tealAccent),
                label: Text(
                  _dietPlan == null ? 'Generate' : 'Regenerate',
                  style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingPlan)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2.5)),
                SizedBox(height: 12),
                Text('Asking Gemini for your plan...', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          )
        else if (_planError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_planError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, height: 1.4))),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _fetchHealthPlan,
                    child: const Text('Retry', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          )
        else if (_dietPlan != null) ...[
          _buildPlanCard('Diet Suggestions', Icons.restaurant_rounded, const Color(0xFF22C55E), _dietPlan!),
          const SizedBox(height: 14),
          _buildPlanCard('Exercise Suggestions', Icons.fitness_center_rounded, const Color(0xFF3B82F6), _exercisePlan ?? ''),
          const SizedBox(height: 10),
          Text(
            'AI-generated general wellness suggestions — not medical advice.',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.white38, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap "Generate" for a personalized diet & exercise plan powered by Gemini.',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPlanCard(String title, IconData icon, Color color, String content) {
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => l.replaceFirst(RegExp(r'^[-•*]\s*'), ''))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          if (lines.isEmpty)
            Text('No suggestions returned.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12))
          else
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(line, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntakeCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600)),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: TextStyle(fontSize: 13, color: iconColor, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBmiGauge(double bmi) {
    final position = mapRange(bmi, 15, 35, 0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 14,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF22C55E), Color(0xFFF97316), Color(0xFFEF4444)],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                SizedBox(width: constraints.maxWidth, height: 16),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment(position * 2 - 1, 0),
                  child: const Icon(Icons.arrow_drop_up_rounded, color: Colors.white, size: 30),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Underweight', style: TextStyle(color: Colors.white38, fontSize: 10)),
            Text('Normal', style: TextStyle(color: Colors.white38, fontSize: 10)),
            Text('Overweight', style: TextStyle(color: Colors.white38, fontSize: 10)),
            Text('Obese', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}