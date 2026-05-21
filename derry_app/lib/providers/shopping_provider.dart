import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shopping_item_model.dart';
import '../models/loyalty_card_model.dart';
import '../services/shopping_service.dart';

final shoppingServiceProvider = Provider<ShoppingService>((ref) => ShoppingService());

final activeShoppingItemsProvider = StreamProvider<List<ShoppingItemModel>>((ref) {
  return ref.watch(shoppingServiceProvider).watchActiveItems();
});

final archivedShoppingItemsProvider = StreamProvider<List<ShoppingItemModel>>((ref) {
  return ref.watch(shoppingServiceProvider).watchArchivedItems();
});

final shoppingCategoriesProvider = StreamProvider<List<ShoppingCategoryModel>>((ref) {
  return ref.watch(shoppingServiceProvider).watchCategories();
});

final loyaltyCardsProvider = StreamProvider<List<LoyaltyCardModel>>((ref) {
  return ref.watch(shoppingServiceProvider).watchLoyaltyCards();
});
