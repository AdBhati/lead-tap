/// Lead Capture Screen — the most-used screen, optimized for speed.
///
/// Flow:
/// 1. POST lead to API (save to DB + GSheet in background)
/// 2. Open WhatsApp via wa.me deep link
/// 3. Clear form instantly, ready for next lead
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stall_capture/models/models.dart';
import 'package:stall_capture/services/api_service.dart';
import 'package:stall_capture/theme.dart';

class LeadCaptureScreen extends StatefulWidget {
  const LeadCaptureScreen({super.key});

  @override
  State<LeadCaptureScreen> createState() => _LeadCaptureScreenState();
}

class _LeadCaptureScreenState extends State<LeadCaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _commentController = TextEditingController();

  // Focus nodes for quick keyboard navigation
  final _mobileFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _commentFocus = FocusNode();

  bool _isSending = false;
  int _capturedCount = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _commentController.dispose();
    _mobileFocus.dispose();
    _emailFocus.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _mobileController.clear();
    _emailController.clear();
    _commentController.clear();
    _formKey.currentState?.reset();
  }

  Future<void> _openWhatsApp(String mobile, String message) async {
    // Strip non-digit characters from mobile
    final clean = mobile.replaceAll(RegExp(r'[^\d+]'), '');
    final encoded = Uri.encodeComponent(message);
    final waUrl = Uri.parse('https://wa.me/$clean?text=$encoded');
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendAndSave(Event event) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);

    final api = context.read<ApiService>();
    final mobile = _mobileController.text.trim();
    final message = event.whatsappMessage;

    try {
      await api.createLead(
        eventId: event.id,
        name: _nameController.text.trim(),
        mobileNumber: mobile,
        email: _emailController.text.trim(),
        comment: _commentController.text.trim(),
      );

      // Open WhatsApp BEFORE clearing form so UX feels instant
      await _openWhatsApp(mobile, message);

      _clearForm();
      setState(() {
        _capturedCount++;
        _isSending = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Lead saved! Total: $_capturedCount'),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ModalRoute.of(context)!.settings.arguments as Event;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Capture Lead',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(event.name,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/leads-list', arguments: event),
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: Text('$_capturedCount',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_mobileFocus),
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'Visitor\'s name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // Mobile field
              TextFormField(
                controller: _mobileController,
                focusNode: _mobileFocus,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_emailFocus),
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  hintText: '+91 9876543210',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Mobile number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email (optional)
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_commentFocus),
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'visitor@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Comment (optional)
              TextFormField(
                controller: _commentController,
                focusNode: _commentFocus,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Interested in product X, follow up next week...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: Icon(Icons.notes_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Send & Save button (BIG — primary action)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : () => _sendAndSave(event),
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSending ? 'Sending...' : 'Send & Save',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Saves to database + Google Sheets\nand opens WhatsApp instantly',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
