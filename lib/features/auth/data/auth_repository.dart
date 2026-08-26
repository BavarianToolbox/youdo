import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';

abstract interface class AuthGateway {
  Stream<User?> get authStateChanges;

  Future<String?> signInWithEmail({
    required String email,
    required String password,
  });

  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signInWithGoogle();
  Future<void> signOut();
  Stream<Map<String, dynamic>?> watchProfile(String uid);
  Future<Map<String, dynamic>> fetchProfile(String uid);
  Future<void> updateProfile(String uid, Map<String, dynamic> fields);
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  Stream<User?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((event) => event.session?.user);

  @override
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user?.id;
  }

  @override
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    return response.user?.id;
  }

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.youdo.youdo://login-callback',
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Stream<Map<String, dynamic>?> watchProfile(String uid) => _client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map((rows) => rows.isEmpty ? null : rows.single);

  @override
  Future<Map<String, dynamic>> fetchProfile(String uid) =>
      _client.from('profiles').select().eq('id', uid).single();

  @override
  Future<void> updateProfile(String uid, Map<String, dynamic> fields) async {
    await _client.from('profiles').update(fields).eq('id', uid);
  }
}

class AuthRepository {
  AuthRepository(SupabaseClient client)
    : this.gateway(SupabaseAuthGateway(client));

  AuthRepository.gateway(this._gateway);

  final AuthGateway _gateway;

  Stream<User?> get authStateChanges => _gateway.authStateChanges;

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final uid = await _gateway.signInWithEmail(
      email: email,
      password: password,
    );
    if (uid == null) {
      throw const AuthException('Sign in did not return a user');
    }
    return _fetchProfile(uid);
  }

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final uid = await _gateway.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    if (uid == null) {
      throw const AuthException('Sign up did not return a user');
    }
    return _fetchProfile(uid);
  }

  Future<void> signInWithGoogle() => _gateway.signInWithGoogle();

  Future<void> signOut() => _gateway.signOut();

  Stream<AppUser?> watchCurrentUser(String uid) {
    return _gateway
        .watchProfile(uid)
        .map((data) => data == null ? null : AppUser.fromJson(data));
  }

  Future<void> updateUserField(String uid, Map<String, dynamic> fields) async {
    await _gateway.updateProfile(uid, fields);
  }

  Future<AppUser> _fetchProfile(String uid) async {
    final data = await _gateway.fetchProfile(uid);
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
