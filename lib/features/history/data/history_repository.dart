import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction_model.dart';
import '../../auth/data/auth_repository.dart';

class HistoryRepository {
  HistoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<List<TransactionModel>> watchTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TransactionModel.fromFirestore).toList());
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(FirebaseFirestore.instance);
});

final transactionListProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(historyRepositoryProvider).watchTransactions(user.uid);
});
