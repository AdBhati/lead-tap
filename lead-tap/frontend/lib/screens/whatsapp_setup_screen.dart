/// WhatsApp Setup Screen — shown once on first login.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stall_capture/providers/auth_provider.dart';
import 'package:stall_capture/theme.dart';

class WhatsAppSetupScreen extends StatefulWidget {
  const WhatsAppSetupScreen({super.key});

  @override
  State<WhatsAppSetupScreen> createState() => _WhatsAppSetupScreenState();
}

class _WhatsAppSetupScreenState extends State<WhatsAppSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    print('[DEBUG] _save called.');
    if (!_formKey.currentState!.validate()) {
      print('[DEBUG] Form validation failed.');
      return;
    }
    print('[DEBUG] Form validation passed. Number: ${_numberController.text}');
    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    try {
       print('[DEBUG] Calling auth.saveWhatsAppNumber');
      await auth.saveWhatsAppNumber(_numberController.text.trim());
      print('[DEBUG] Successfully saved number via API.');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on Exception catch (e) {
      print('[DEBUG] Error saving number: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 24),
                const Text(
                  'Your WhatsApp Number',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Leads will be sent a WhatsApp message from this number.\nInclude your country code (e.g. +91 9876543210).',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _numberController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number',
                    hintText: '+91 9876543210',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your WhatsApp number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save & Continue',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
