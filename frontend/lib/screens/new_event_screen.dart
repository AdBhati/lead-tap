/// New Event Screen — form to create an event.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stall_capture/providers/event_provider.dart';
import 'package:stall_capture/services/api_service.dart';
import 'package:stall_capture/theme.dart';

class NewEventScreen extends StatefulWidget {
  const NewEventScreen({super.key});

  @override
  State<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends State<NewEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  final _mediaController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    _mediaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final provider = context.read<EventProvider>();
    try {
      final event = await provider.createEvent(
        name: _nameController.text.trim(),
        whatsappMessage: _messageController.text.trim(),
        mediaUrl: _mediaController.text.trim(),
      );
      if (!mounted) return;
      // Navigate directly to lead capture for the new event
      Navigator.of(context).pushReplacementNamed('/lead-capture', arguments: event);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Event',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('Event Name *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. Tech Expo 2026',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Event name is required' : null,
              ),
              const SizedBox(height: 20),
              _SectionLabel('WhatsApp Message *'),
              const SizedBox(height: 4),
              const Text(
                'This message will be pre-filled when opening WhatsApp for a lead.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText:
                      'Hi! Thanks for visiting our stall at Tech Expo 2026.\n\nHere\'s our brochure: [link]\n\nFeel free to reach out anytime!',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'WhatsApp message is required'
                    : null,
              ),
              const SizedBox(height: 20),
              _SectionLabel('Brochure / Media URL (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mediaController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://drive.google.com/...',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 32),
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
                      : const Text('Create Event',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
