import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SettingsPage extends StatefulWidget {
  final String apiBaseUrl;
  final String businessId;
  final Map<String, dynamic>? initialBusiness;
  final ValueChanged<Map<String, dynamic>> onBusinessUpdated;
  final VoidCallback onConfirmLogout;

  const SettingsPage({
    super.key,
    required this.apiBaseUrl,
    required this.businessId,
    required this.onBusinessUpdated,
    required this.onConfirmLogout,
    this.initialBusiness,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _industryController = TextEditingController();
  final _currencyController = TextEditingController();
  final _bufferController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialBusiness != null) {
      _fillBusiness(widget.initialBusiness!);
      _loading = false;
    }
    _loadBusiness();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _industryController.dispose();
    _currencyController.dispose();
    _bufferController.dispose();
    super.dispose();
  }

  void _fillBusiness(Map<String, dynamic> business) {
    _nameController.text = (business['name'] ?? '').toString();
    _industryController.text = (business['industry'] ?? '').toString();
    _currencyController.text = (business['currency'] ?? '').toString();
    final threshold = business['safety_buffer_threshold'];
    _bufferController.text = threshold == null ? '' : threshold.toString();
  }

  Future<void> _loadBusiness() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${widget.apiBaseUrl}/api/businesses/${widget.businessId}',
            ),
          )
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['error'] ?? 'Failed to load business');
      }
      final business =
          (body['data'] as Map<String, dynamic>)['business']
              as Map<String, dynamic>;
      _fillBusiness(business);
      widget.onBusinessUpdated(business);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final Map<String, dynamic> payload = {
        'name': _nameController.text.trim(),
        'industry': _industryController.text.trim(),
        'currency': _currencyController.text.trim(),
      };

      final bufferText = _bufferController.text.trim();
      if (bufferText.isNotEmpty) {
        payload['safety_buffer_threshold'] = num.parse(bufferText);
      }

      final response = await http
          .patch(
            Uri.parse(
              '${widget.apiBaseUrl}/api/businesses/${widget.businessId}',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['error'] ?? 'Failed to save business');
      }

      final business =
          (body['data'] as Map<String, dynamic>)['business']
              as Map<String, dynamic>;
      widget.onBusinessUpdated(business);

      if (!mounted) return;
      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Business details updated')));
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = err.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('You will be redirected to the login page.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onConfirmLogout();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 80),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: widget.businessId,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Business ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Business Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Business name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _industryController,
                  decoration: const InputDecoration(
                    labelText: 'Industry',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _currencyController,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Currency is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bufferController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Safety Buffer Threshold (RM)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 28,
          right: 28,
          child: ElevatedButton(
            onPressed: _showLogoutConfirmation,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Logout'),
          ),
        ),
      ],
    );
  }
}