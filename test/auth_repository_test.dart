import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youdo/features/auth/data/auth_repository.dart';

void main() {
  late FakeAuthGateway gateway;
  late AuthRepository repository;

  setUp(() {
    gateway = FakeAuthGateway();
    repository = AuthRepository.gateway(gateway);
  });

  test(
    'sign in forwards credentials and returns the database profile',
    () async {
      gateway.nextUserId = 'user-1';
      gateway.profiles['user-1'] = _profile('user-1');

      final user = await repository.signInWithEmail(
        email: 'dev@example.com',
        password: 'secret',
      );

      expect(gateway.lastEmail, 'dev@example.com');
      expect(gateway.lastPassword, 'secret');
      expect(gateway.fetchedUid, 'user-1');
      expect(user.uid, 'user-1');
      expect(user.displayName, 'Dev User');
    },
  );

  test('sign in rejects a response without a user', () async {
    expect(
      repository.signInWithEmail(email: 'dev@example.com', password: 'secret'),
      throwsA(isA<AuthException>()),
    );
  });

  test(
    'sign up forwards display name and returns the database profile',
    () async {
      gateway.nextUserId = 'user-2';
      gateway.profiles['user-2'] = _profile('user-2');

      final user = await repository.signUpWithEmail(
        email: 'new@example.com',
        password: 'secret',
        displayName: 'New User',
      );

      expect(gateway.lastDisplayName, 'New User');
      expect(user.uid, 'user-2');
    },
  );

  test('profile stream maps rows and preserves a missing profile', () async {
    gateway.profileStream = Stream.fromIterable([_profile('user-1'), null]);

    final users = await repository.watchCurrentUser('user-1').toList();

    expect(users.first?.email, 'dev@example.com');
    expect(users.last, isNull);
  });

  test('profile updates are forwarded without changing their fields', () async {
    final fields = {'notifications_enabled': false};

    await repository.updateUserField('user-1', fields);

    expect(gateway.updatedUid, 'user-1');
    expect(gateway.updatedFields, fields);
  });
}

Map<String, dynamic> _profile(String id) => {
  'id': id,
  'email': 'dev@example.com',
  'display_name': 'Dev User',
};

class FakeAuthGateway implements AuthGateway {
  String? nextUserId;
  String? lastEmail;
  String? lastPassword;
  String? lastDisplayName;
  String? fetchedUid;
  String? updatedUid;
  Map<String, dynamic>? updatedFields;
  final profiles = <String, Map<String, dynamic>>{};
  Stream<Map<String, dynamic>?> profileStream = const Stream.empty();

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    return nextUserId;
  }

  @override
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    lastEmail = email;
    lastPassword = password;
    lastDisplayName = displayName;
    return nextUserId;
  }

  @override
  Future<Map<String, dynamic>> fetchProfile(String uid) async {
    fetchedUid = uid;
    return profiles[uid]!;
  }

  @override
  Stream<Map<String, dynamic>?> watchProfile(String uid) => profileStream;

  @override
  Future<void> updateProfile(String uid, Map<String, dynamic> fields) async {
    updatedUid = uid;
    updatedFields = fields;
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}
