import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import 'transaction_model.dart';

class HistoryRepository {
  HistoryRepository(this._client);

  final SupabaseClient _client;

  Stream<List<TransactionModel>> watchTransactions(String userId) {
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(TransactionModel.fromJson).toList());
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(supabaseClientProvider));
});

final transactionListProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(historyRepositoryProvider).watchTransactions(user.id);
});
