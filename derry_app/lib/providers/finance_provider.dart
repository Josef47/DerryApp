import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/finance_entry_model.dart';
import '../services/finance_service.dart';

final financeServiceProvider = Provider<FinanceService>((ref) => FinanceService());

final balanceProvider = StreamProvider<FinanceBalanceModel?>((ref) {
  return ref.watch(financeServiceProvider).watchBalance();
});

final financeEntriesProvider = StreamProvider<List<FinanceEntryModel>>((ref) {
  return ref.watch(financeServiceProvider).watchEntries();
});
