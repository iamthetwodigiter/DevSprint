import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../services/auth_service.dart';

class AuthState {
  final bool loading;
  final bool isConfigured;
  final bool signedIn;
  final String? uid;
  final String? name;
  final String? email;
  final String? photoUrl;
  final String? error;

  const AuthState({
    this.loading = false,
    this.isConfigured = false,
    this.signedIn = false,
    this.uid,
    this.name,
    this.email,
    this.photoUrl,
    this.error,
  });

  AuthState copyWith({
    bool? loading,
    bool? isConfigured,
    bool? signedIn,
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      loading: loading ?? this.loading,
      isConfigured: isConfigured ?? this.isConfigured,
      signedIn: signedIn ?? this.signedIn,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _service;
  StreamSubscription? _authSubscription;

  @override
  AuthState build() {
    _service = ref.watch(authServiceProvider);
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    _listenToAuthChanges();
    _restore();
    return const AuthState(loading: true);
  }

  void _listenToAuthChanges() {
    final stream = _service.onAuthStateChange;
    if (stream != null) {
      _authSubscription?.cancel();
      _authSubscription = stream.listen((data) {
        final session = data.session;
        if (session != null) {
          _restore();
        } else if (data.event == supa.AuthChangeEvent.signedOut) {
          state = AuthState(isConfigured: _service.isConfigured);
        }
      });
    }
  }

  Future<void> _restore() async {
    final configured = _service.isConfigured;
    if (!configured) {
      final success = await _service.initSupabase();
      if (!success) {
        if (ref.mounted) {
          state = const AuthState(loading: false, isConfigured: false);
        }
        return;
      }
    }

    final profile = await _service.restore();
    if (!ref.mounted) return;
    state = AuthState(
      loading: false,
      isConfigured: true,
      signedIn: profile != null,
      uid: profile?.uid,
      name: profile?.name,
      email: profile?.email,
      photoUrl: profile?.photoUrl,
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final profile = await _service.signInWithEmail(
        email: email,
        password: password,
      );
      if (!ref.mounted) return;
      state = AuthState(
        loading: false,
        isConfigured: true,
        signedIn: true,
        uid: profile.uid,
        name: profile.name,
        email: profile.email,
        photoUrl: profile.photoUrl,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final profile = await _service.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      if (!ref.mounted) return;
      state = AuthState(
        loading: false,
        isConfigured: true,
        signedIn: true,
        uid: profile.uid,
        name: profile.name,
        email: profile.email,
        photoUrl: profile.photoUrl,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  Future<void> signInWithOAuth(supa.OAuthProvider provider) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _service.signInWithOAuth(provider);
      if (!ref.mounted) return;
      state = state.copyWith(loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    if (!ref.mounted) return;
    state = AuthState(isConfigured: _service.isConfigured);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
