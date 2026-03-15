/// AuthProvider manages the authentication state: user profile, sign-in/out,
/// and WhatsApp number setup.
library;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stall_capture/models/models.dart';
import 'package:stall_capture/services/api_service.dart';

enum AuthState { unknown, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  final ApiService _api;

  AuthProvider(this._api);

  AuthState _state = AuthState.unknown;
  AppUser? _user;
  String? _error;
  bool _isLoading = false;

  AuthState get state => _state;
  AppUser? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _state == AuthState.authenticated;

  final _googleSignIn = GoogleSignIn(
    // NOTE: For web, clientId is REQUIRED here or in index.html.
    clientId: '985181918245-5uutie190iqdcj464q1bu7pqm6fob0hh.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  /// Check if user is already signed in on app start.
  Future<void> checkAuthStatus() async {
    final token = await _api.getAccessToken();
    if (token == null) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      _user = await _api.getMe();
      _state = AuthState.authenticated;
    } catch (_) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  /// Sign in with Google. Returns true if WhatsApp setup is needed.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken ?? '';
      final accessToken = auth.accessToken ?? '';

      final data = await _api.googleAuth(
        idToken: idToken,
        accessToken: accessToken,
      );

      _user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      _state = AuthState.authenticated;
      _isLoading = false;
      notifyListeners();

      // Return true if this user needs to set up WhatsApp number
      return !_user!.hasWhatsApp;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Sign-in failed. Please try again.';
      _isLoading = false;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> saveWhatsAppNumber(String number) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.saveWhatsAppNumber(number);
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _api.clearTokens();
    _user = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
