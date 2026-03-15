/// Leads List Screen — read-only list of all leads for an event.
/// Data is stored in GSheet, this is just for quick on-device review.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:stall_capture/models/models.dart';
import 'package:stall_capture/services/api_service.dart';
import 'package:stall_capture/theme.dart';

class LeadsListScreen extends StatefulWidget {
  const LeadsListScreen({super.key});

  @override
  State<LeadsListScreen> createState() => _LeadsListScreenState();
}

class _LeadsListScreenState extends State<LeadsListScreen> {
  List<Lead> _leads = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLeads());
  }

  Future<void> _loadLeads() async {
    final event = ModalRoute.of(context)!.settings.arguments as Event;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final leads = await api.getLeads(event.id);
      setState(() {
        _leads = leads;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
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
            const Text('Leads',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(event.name,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: Builder(
        builder: (context) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton(
                      onPressed: _loadLeads, child: const Text('Retry')),
                ],
              ),
            );
          }
          if (_leads.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_search_outlined,
                      size: 64, color: AppColors.surfaceBorder),
                  SizedBox(height: 16),
                  Text('No leads captured yet',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('Go to Lead Capture to add leads',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline_rounded,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${_leads.length} lead${_leads.length == 1 ? '' : 's'} captured',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      'Also in Google Sheets ↗',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadLeads,
                  child: ListView.separated(
                    itemCount: _leads.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, index) =>
                        _LeadTile(lead: _leads[index]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  final Lead lead;
  const _LeadTile({required this.lead});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        child: Text(
          lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(
        lead.name,
        style: const TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.phone_outlined,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(lead.mobileNumber,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          if (lead.comment.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              lead.comment,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
      trailing: Text(
        DateFormat('d MMM\nHH:mm').format(lead.createdAt),
        textAlign: TextAlign.right,
        style:
            const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}
