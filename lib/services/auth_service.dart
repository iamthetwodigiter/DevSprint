import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage_service.dart';
import 'user_preferences_service.dart';

class AuthProfile {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;

  const AuthProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
  });
}

class AuthService {
  final SecureStorageService storage;
  final UserPreferencesService preferences;

  AuthService(this.storage, this.preferences);

  bool get isConfigured {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Stream<AuthState>? get onAuthStateChange {
    try {
      return Supabase.instance.client.auth.onAuthStateChange;
    } catch (_) {
      return null;
    }
  }

  /// Initialize Supabase from .env if it hasn't been initialized yet
  Future<bool> initSupabase() async {
    try {
      if (isConfigured) return true;
    } catch (_) {}

    final targetUrl = dotenv.maybeGet('SUPABASE_URL');
    final targetAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');

    if (targetUrl == null ||
        targetUrl.isEmpty ||
        targetAnonKey == null ||
        targetAnonKey.isEmpty) {
      return false;
    }

    try {
      await Supabase.initialize(
        url: targetUrl.trim(),
        publishableKey: targetAnonKey.trim(),
      );
      return true;
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
      return false;
    }
  }

  Future<AuthProfile?> restore() async {
    final supaClient = client;
    if (supaClient == null) return null;

    try {
      final user = supaClient.auth.currentUser;
      if (user != null) {
        final profile = _profileFromSupabase(user);
        await _saveAccount(profile);
        return profile;
      }
    } catch (_) {}

    return null;
  }

  Future<AuthProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final supaClient = client;
    if (supaClient == null) {
      throw StateError('Supabase is not configured.');
    }

    final response = await supaClient.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw StateError('Sign-in failed. Please check your credentials.');
    }

    final profile = _profileFromSupabase(user);
    await _saveAccount(profile);
    return profile;
  }

  Future<AuthProfile> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    final supaClient = client;
    if (supaClient == null) {
      throw StateError('Supabase is not configured.');
    }

    final data = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      data['name'] = name.trim();
      data['full_name'] = name.trim();
    }

    final response = await supaClient.auth.signUp(
      email: email.trim(),
      password: password,
      data: data.isNotEmpty ? data : null,
    );

    final user = response.user;
    if (user == null) {
      throw StateError(
        'Sign-up completed. If email confirmation is enabled, please verify your email before logging in.',
      );
    }

    final profile = _profileFromSupabase(user, fallbackName: name);
    await _saveAccount(profile);
    return profile;
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    final supaClient = client;
    if (supaClient == null) {
      throw StateError('Supabase is not configured.');
    }

    await supaClient.auth.signInWithOAuth(provider);
  }

  AuthProfile _profileFromSupabase(User user, {String? fallbackName}) {
    final metadata = user.userMetadata ?? {};
    final resolvedName =
        metadata['name'] as String? ??
        metadata['full_name'] as String? ??
        fallbackName ??
        (user.email != null && user.email!.contains('@')
            ? user.email!.split('@').first
            : 'Developer');

    final photoUrl =
        metadata['avatar_url'] as String? ?? metadata['picture'] as String?;

    return AuthProfile(
      uid: user.id,
      name: resolvedName,
      email: user.email ?? '',
      photoUrl: photoUrl,
    );
  }

  Future<void> _saveAccount(AuthProfile profile) async {
    await preferences.saveAccount(
      uid: profile.uid,
      name: profile.name,
      email: profile.email,
      photoUrl: profile.photoUrl ?? '',
    );
  }

  Future<void> signOut() async {
    try {
      await client?.auth.signOut();
    } catch (_) {}
    await preferences.clearAccount();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(secureStorageServiceProvider),
    UserPreferencesService(),
  );
});
