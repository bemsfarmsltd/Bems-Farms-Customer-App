import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import '../../data/models/address_model.dart';
import '../../data/repositories/address_repository.dart';

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(tokenStorage: ref.read(tokenStorageProvider));
});

class AddressNotifier extends StateNotifier<AsyncValue<List<Address>>> {
  final AddressRepository _repository;

  AddressNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    state = const AsyncValue.loading();
    try {
      final addresses = await _repository.getAddresses();
      state = AsyncValue.data(addresses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addAddress(Address address) async {
    try {
      final newAddress = await _repository.addAddress(address);
      if (state.hasValue) {
        state = AsyncValue.data([...state.value!, newAddress]);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateAddress(Address address) async {
    try {
      final updated = await _repository.updateAddress(address);
      if (state.hasValue) {
        state = AsyncValue.data([
          for (final a in state.value!)
            if (a.id == updated.id) updated else a
        ]);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      await _repository.deleteAddress(id);
      if (state.hasValue) {
        state = AsyncValue.data([
          for (final a in state.value!)
            if (a.id != id) a
        ]);
      }
    } catch (e) {
      rethrow;
    }
  }
}

final addressProvider = StateNotifierProvider<AddressNotifier, AsyncValue<List<Address>>>((ref) {
  return AddressNotifier(ref.read(addressRepositoryProvider));
});
