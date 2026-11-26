import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/features/product/presentation/providers/product_providers.dart';
import 'package:bems_farms/features/product/data/repositories/product_repository.dart';

class FavoriteNotifier extends StateNotifier<Set<String>> {
  final ProductRepository _repository;

  FavoriteNotifier(this._repository) : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final list = await _repository.getWishlist();
      state = list.toSet();
    } catch (e) {
      // Ignore errors on load or show a snackbar in a real app
    }
  }

  Future<void> toggleFavorite(String productId) async {
    final bool isCurrentlyFavorite = state.contains(productId);
    
    // Optimistic UI update
    if (isCurrentlyFavorite) {
      state = {
        for (final id in state)
          if (id != productId) id,
      };
    } else {
      state = {...state, productId};
    }
    
    try {
      if (isCurrentlyFavorite) {
        await _repository.removeFromWishlist(productId);
      } else {
        await _repository.addToWishlist(productId);
      }
    } catch (e) {
      // Revert on failure
      if (isCurrentlyFavorite) {
        state = {...state, productId};
      } else {
        state = {
          for (final id in state)
            if (id != productId) id,
        };
      }
    }
  }

  bool isFavorite(String productId) => state.contains(productId);
}

final favoriteProvider = StateNotifierProvider<FavoriteNotifier, Set<String>>((ref) {
  final repository = ref.read(productRepositoryProvider);
  return FavoriteNotifier(repository);
});
