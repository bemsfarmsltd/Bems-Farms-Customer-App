import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/models/product_model.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';

// Shares the same TokenStorage instance as auth so only one token source exists
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(tokenStorage: ref.read(tokenStorageProvider));
});

final freshProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.read(productRepositoryProvider).getFreshProducts();
});

final dealProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.read(productRepositoryProvider).getDealProducts();
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(productRepositoryProvider).getCategories();
});

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final allProductsProvider = FutureProvider<List<Product>>((ref) async {
  final category = ref.watch(selectedCategoryProvider);
  final result = await ref.read(productRepositoryProvider).getAllProducts(category: category, limit: 100);
  final items = result['products'] ?? result['results'] ?? [];
  return (items as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
});

final productDetailProvider =
    FutureProvider.family<Product, String>((ref, productId) {
  return ref.read(productRepositoryProvider).getProductById(productId);
});

final searchProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, query) {
  if (query.isEmpty) return Future.value([]);
  return ref.read(productRepositoryProvider).searchProducts(query);
});

final productReviewsProvider =
    FutureProvider.family<List<ProductReview>, String>((ref, productId) {
  return ref.read(productRepositoryProvider).getProductReviews(productId);
});

