import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/customer_wallet_model.dart';
import '../../data/repositories/customer_wallet_repository.dart';

final customerWalletRepositoryProvider = Provider<CustomerWalletRepository>((ref) {
  return CustomerWalletRepository();
});

class CustomerWalletState {
  final CustomerWallet? wallet;
  final List<WalletTransaction> transactions;
  final bool isLoading;
  final bool isProvisioning;
  final bool isPinUpdating;
  final String? errorMessage;
  final String? successMessage;

  const CustomerWalletState({
    this.wallet,
    this.transactions = const [],
    this.isLoading = false,
    this.isProvisioning = false,
    this.isPinUpdating = false,
    this.errorMessage,
    this.successMessage,
  });

  CustomerWalletState copyWith({
    CustomerWallet? wallet,
    List<WalletTransaction>? transactions,
    bool? isLoading,
    bool? isProvisioning,
    bool? isPinUpdating,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CustomerWalletState(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isProvisioning: isProvisioning ?? this.isProvisioning,
      isPinUpdating: isPinUpdating ?? this.isPinUpdating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class CustomerWalletNotifier extends StateNotifier<CustomerWalletState> {
  final CustomerWalletRepository _repository;

  CustomerWalletNotifier(this._repository) : super(const CustomerWalletState());

  Future<void> fetchWallet({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final data = await _repository.getWallet();
      state = state.copyWith(
        wallet: data.wallet,
        transactions: data.transactions,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      final cleanErr = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(
        isLoading: false,
        errorMessage: cleanErr,
      );
    }
  }

  Future<bool> provisionWallet({
    String? phone,
    String? bvn,
    String? nin,
  }) async {
    state = state.copyWith(isProvisioning: true, clearError: true, clearSuccess: true);
    try {
      final data = await _repository.provisionWallet(
        phone: phone,
        bvn: bvn,
        nin: nin,
      );
      state = state.copyWith(
        wallet: data.wallet,
        transactions: data.transactions,
        isProvisioning: false,
        successMessage: 'Dedicated bank account generated successfully!',
      );
      return true;
    } catch (e) {
      final cleanErr = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(
        isProvisioning: false,
        errorMessage: cleanErr,
      );
      return false;
    }
  }

  Future<bool> setPin(String pin) async {
    state = state.copyWith(isPinUpdating: true, clearError: true, clearSuccess: true);
    try {
      final res = await _repository.setPin(pin);
      final msg = res['message']?.toString() ?? '4-digit wallet payment PIN set successfully.';
      await fetchWallet(silent: true);
      state = state.copyWith(
        isPinUpdating: false,
        successMessage: msg,
      );
      return true;
    } catch (e) {
      final cleanErr = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(
        isPinUpdating: false,
        errorMessage: cleanErr,
      );
      return false;
    }
  }

  Future<bool> changePin({required String pin, required String currentPin}) async {
    state = state.copyWith(isPinUpdating: true, clearError: true, clearSuccess: true);
    try {
      final res = await _repository.changePin(pin: pin, currentPin: currentPin);
      final msg = res['message']?.toString() ?? 'Payment PIN changed successfully.';
      await fetchWallet(silent: true);
      state = state.copyWith(
        isPinUpdating: false,
        successMessage: msg,
      );
      return true;
    } catch (e) {
      final cleanErr = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(
        isPinUpdating: false,
        errorMessage: cleanErr,
      );
      return false;
    }
  }

  Future<bool> resetPin({required String pin, required String accountPassword}) async {
    state = state.copyWith(isPinUpdating: true, clearError: true, clearSuccess: true);
    try {
      final res = await _repository.resetPin(pin: pin, accountPassword: accountPassword);
      final msg = res['message']?.toString() ?? 'Payment PIN reset successfully.';
      await fetchWallet(silent: true);
      state = state.copyWith(
        isPinUpdating: false,
        successMessage: msg,
      );
      return true;
    } catch (e) {
      final cleanErr = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(
        isPinUpdating: false,
        errorMessage: cleanErr,
      );
      return false;
    }
  }
}

final customerWalletProvider =
    StateNotifierProvider<CustomerWalletNotifier, CustomerWalletState>((ref) {
  final repo = ref.watch(customerWalletRepositoryProvider);
  return CustomerWalletNotifier(repo);
});
