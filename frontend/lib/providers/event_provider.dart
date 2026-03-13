/// EventProvider — manages event list state.
library;

import 'package:flutter/foundation.dart';
import 'package:stall_capture/models/models.dart';
import 'package:stall_capture/services/api_service.dart';

class EventProvider extends ChangeNotifier {
  final ApiService _api;
  EventProvider(this._api);

  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _events = await _api.getEvents();
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Event?> createEvent({
    required String name,
    required String whatsappMessage,
    String mediaUrl = '',
  }) async {
    try {
      final event = await _api.createEvent(
        name: name,
        whatsappMessage: whatsappMessage,
        mediaUrl: mediaUrl,
      );
      _events = [event, ..._events];
      notifyListeners();
      return event;
    } on ApiException {
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    await _api.deleteEvent(eventId);
    _events = _events.where((e) => e.id != eventId).toList();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
