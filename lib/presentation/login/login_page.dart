import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  final Future<void> Function(String businessId) onLoginSuccess;

  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  final TextEditingController _businessIdController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _industryController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController(
    text: 'MYR',
  );
  final TextEditingController _safetyBufferController = TextEditingController();
  final http.Client _client = http.Client();
  bool _loading = false;
  bool _createMode = false;
  String? _error;

  static final RegExp _businessIdPattern = RegExp(r'^[a-zA-Z0-9_-]{3,64}$');
  static final RegExp _currencyPattern = RegExp(r'^[A-Za-z]{3}$');

  @override
  void dispose() {
    _businessIdController.dispose();
    _businessNameController.dispose();
    _industryController.dispose();
    _currencyController.dispose();
    _safetyBufferController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _submit() async {
    final businessId = _businessIdController.text.trim();
    if (businessId.isEmpty) {
      setState(() {
        _error =
            'Business ID is required. Expected 3-64 characters using letters, numbers, _ or -.';
      });
      return;
    }

    if (!_businessIdPattern.hasMatch(businessId)) {
      setState(() {
        _error =
            'Business ID is invalid. Expected 3-64 characters using letters, numbers, _ or -.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_createMode) {
        final name = _businessNameController.text.trim();
        final currency = _currencyController.text.trim();
        if (name.isEmpty) {
          throw Exception(
            'Business Name is required. Expected a non-empty name.',
          );
        }
        if (!_currencyPattern.hasMatch(currency)) {
          throw Exception(
            'Currency is invalid. Expected a 3-letter code such as MYR or SGD.',
          );
        }

        final Map<String, dynamic> payload = {
          '_id': businessId,
          'name': name,
          'industry': _industryController.text.trim(),
          'currency': currency,
        };

        final bufferText = _safetyBufferController.text.trim();
        if (bufferText.isNotEmpty) {
          final safetyBuffer = num.tryParse(bufferText);
          if (safetyBuffer == null || safetyBuffer < 0) {
            throw Exception(
              'Safety Buffer Threshold (RM) is invalid. Expected a number greater than or equal to 0.',
            );
          }
          payload['safety_buffer_threshold'] = safetyBuffer;
        }

        final response = await _client
            .post(
              Uri.parse('$_baseUrl/api/businesses'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 20));
        final body = _parseJsonObject(response.body);
        if (response.statusCode != 201 || body['success'] != true) {
          throw Exception(
            _buildHttpErrorMessage(
              response.statusCode,
              response.body,
              body['error']?.toString() ?? 'Unable to create account',
            ),
          );
        }
      } else {
        final response = await _client
            .get(Uri.parse('$_baseUrl/api/businesses/$businessId'))
            .timeout(const Duration(seconds: 20));
        final body = _parseJsonObject(response.body);
        if (response.statusCode != 200 || body['success'] != true) {
          throw Exception(
            _buildHttpErrorMessage(
              response.statusCode,
              response.body,
              body['error']?.toString() ?? 'Business ID not found',
            ),
          );
        }
      }

      await widget.onLoginSuccess(businessId);
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error =
            'Server response format error. Expected JSON from $_baseUrl, but received non-JSON content (for example HTML). Ensure backend API is running at $_baseUrl.';
        _loading = false;
      });
      return;
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Map<String, dynamic> _parseJsonObject(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Expected JSON object');
  }

  String _buildHttpErrorMessage(
    int statusCode,
    String rawBody,
    String defaultMessage,
  ) {
    final trimmed = rawBody.trimLeft();
    if (trimmed.startsWith('<!DOCTYPE html') || trimmed.startsWith('<html')) {
      return 'Server returned HTML instead of JSON (HTTP $statusCode). Ensure backend API is running at $_baseUrl and endpoint /api/businesses is reachable.';
    }
    if (statusCode == 409) {
      return 'Business ID already exists. Please use a different Business ID (3-64 chars, letters/numbers/_/-).';
    }
    return defaultMessage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 42,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(height: 16),
                const Text(
                  'FinSight',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _createMode
                      ? 'Sign up to continue'
                      : 'Enter your Business ID to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _businessIdController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Business ID',
                    hintText: 'your_business_id',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                if (_createMode) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _businessNameController,
                    decoration: InputDecoration(
                      labelText: 'Business Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _industryController,
                    decoration: InputDecoration(
                      labelText: 'Industry',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _safetyBufferController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Safety Buffer Threshold (RM)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_createMode ? 'Create Account' : 'Continue'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _error = null;
                            _createMode = !_createMode;
                          });
                        },
                  child: Text(_createMode ? 'Back to Login' : 'Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
