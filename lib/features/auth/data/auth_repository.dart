import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<User?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((event) => event.session?.user);

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign in did not return a user');
    }
    return _fetchProfile(user.id);
  }

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign up did not return a user');
    }
    return _fetchProfile(user.id);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.youdo.youdo://login-callback',
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Stream<AppUser?> watchCurrentUser(String uid) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isEmpty ? null : AppUser.fromJson(rows.single));
  }

  Future<void> updateUserField(String uid, Map<String, dynamic> fields) async {
    await _client.from('profiles').update(fields).eq('id', uid);
  }

  Future<AppUser> _fetchProfile(String uid) async {
    final data = await _client.from('profiles').select().eq('id', uid).single();
    return AppUser.fromJson(data);
  }
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authRepositoryProvider).watchCurrentUser(user.id);
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});
