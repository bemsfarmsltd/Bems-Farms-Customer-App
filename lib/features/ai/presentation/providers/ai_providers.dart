import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ai_repository.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';

final aiRepositoryProvider = Provider<AIRepository>((ref) {
  return AIRepository(tokenStorage: ref.read(tokenStorageProvider));
});

final recommendationsProvider = FutureProvider.family<Map<String, dynamic>, Map<String, String>>((ref, params) {
  return ref.read(aiRepositoryProvider).getRecommendations(
        dietaryNeed: params['dietary_need'] ?? '',
        budget: params['budget'] ?? '',
        familySize: params['family_size'] ?? '',
      );
});

final coPurchaseProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, productId) {
  return ref.read(aiRepositoryProvider).getCoPurchases(productId);
});

class ConversationsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final AIRepository repo;
  final String botType;

  ConversationsNotifier({required this.repo, required this.botType}) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final data = await repo.getConversations(botType: botType);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void addLocalConversation(String id, String title) {
    if (state is AsyncData) {
      final currentList = state.value ?? [];
      final newList = [
        {'_id': id, 'title': title},
        ...currentList,
      ];
      state = AsyncValue.data(newList);
    }
  }
}

final conversationsProvider = StateNotifierProvider.family<ConversationsNotifier, AsyncValue<List<dynamic>>, String>((ref, botType) {
  return ConversationsNotifier(
    repo: ref.read(aiRepositoryProvider),
    botType: botType,
  );
});

final conversationDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(aiRepositoryProvider).getConversationById(id);
});
