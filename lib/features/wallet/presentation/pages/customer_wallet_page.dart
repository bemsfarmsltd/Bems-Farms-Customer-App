import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/home/presentation/pages/main_nav_page.dart';
import '../providers/customer_wallet_provider.dart';
import '../widgets/wallet_setup_dialog.dart';

class CustomerWalletPage extends ConsumerStatefulWidget {
  const CustomerWalletPage({super.key});

  @override
  ConsumerState<CustomerWalletPage> createState() => _CustomerWalletPageState();
}

class _CustomerWalletPageState extends ConsumerState<CustomerWalletPage> {
  String _txFilter = 'all'; // 'all', 'topup', 'payment'
  final currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customerWalletProvider.notifier).fetchWallet();
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1B5E20),
        content: Text('✓ $label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(customerWalletProvider);
    final wallet = walletState.wallet;
    final isLoading = walletState.isLoading;
    final transactions = walletState.transactions;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('My Dedicated Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Wallet',
            onPressed: () async {
              await ref.read(customerWalletProvider.notifier).fetchWallet();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1B5E20),
                  content: const Text('✓ Wallet refreshed'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading && wallet == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(customerWalletProvider.notifier).fetchWallet(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Subtitle / Intro with Shop & Pay Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt, color: Color(0xFF2E7D32), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Instant Funding',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B5E20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Zero card fees',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Switch bottom nav to Shop tab (index 1 for logged-in members)
                            ref.read(selectedNavIndexProvider.notifier).state = 1;
                            // Pop all routes back to MainNavPage (the root)
                            Navigator.popUntil(context, (route) => route.isFirst);
                          },
                          icon: const Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.white),
                          label: const Text(
                            'Shop & Pay ➔',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B432A),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Available Balance Card
                    _buildBalanceCard(wallet, transactions.length),
                    const SizedBox(height: 18),

                    // Dedicated Bank Account (NUBAN) Card
                    if (wallet != null && wallet.isActivated)
                      _buildNubanAccountCard(wallet)
                    else
                      _buildActivationCard(),

                    const SizedBox(height: 18),

                    // 3-Step Guide
                    _buildThreeStepGuide(),
                    const SizedBox(height: 18),

                    // Checkout Payment PIN Section
                    _buildPaymentPinCard(wallet),
                    const SizedBox(height: 24),

                    // Recent Wallet Activity
                    _buildTransactionsSection(transactions),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // 1. Available Balance Card (Dark Green)
  Widget _buildBalanceCard(dynamic wallet, int txCount) {
    final balance = wallet?.balance ?? 0.0;
    final totalFunded = wallet?.totalToppedUp ?? 0.0;
    final totalSpent = wallet?.totalSpent ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B432A), Color(0xFF0F2919)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B432A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AVAILABLE WALLET BALANCE',
                style: TextStyle(
                  color: Color(0xFFA5D6A7),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, color: Color(0xFF81C784), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'CBN Insured',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Big Balance Text
          Text(
            currencyFormatter.format(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          // Sub Stats Row (TOTAL FUNDED | TOTAL SPENT | ACTIVITY)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('TOTAL FUNDED', currencyFormatter.format(totalFunded)),
                Container(height: 24, width: 1, color: Colors.white24),
                _buildStatItem('TOTAL SPENT', currencyFormatter.format(totalSpent)),
                Container(height: 24, width: 1, color: Colors.white24),
                _buildStatItem('ACTIVITY', '$txCount txs'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // 2. Dedicated NUBAN Bank Account Card (When Activated)
  Widget _buildNubanAccountCard(dynamic wallet) {
    final bankName = wallet.bankName ?? 'Wema Bank';
    final accountNumber = wallet.accountNumber ?? '';
    final accountName = wallet.accountName ?? 'BEMS CUSTOMER';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC8E6C9), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR DEDICATED BANK ACCOUNT (NUBAN)',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    Text(
                      bankName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF1B5E20), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Account Number with Copy Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFAED581)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ACCOUNT NUMBER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      accountNumber,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: Colors.black87),
                    ),
                    GestureDetector(
                      onTap: () => _copyToClipboard(accountNumber, 'Account number'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Account Name
          Row(
            children: [
              const Text('Account Name: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                accountName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Transfer to this account number from any Nigerian bank app to credit your Bems wallet balance automatically and instantly.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
          ),
        ],
      ),
    );
  }

  // 3. Activation Card (When Not Activated)
  Widget _buildActivationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Activate Dedicated Bank Account',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Provide your BVN or NIN (CBN requirement) to generate your permanent personal NUBAN account number for instant wallet top-ups.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.3),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => WalletSetupDialog.show(context),
              icon: const Icon(Icons.fingerprint, color: Colors.white, size: 18),
              label: const Text(
                'Activate Bems Wallet NUBAN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. 3-Step Guide (Matching Web App)
  Widget _buildThreeStepGuide() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOW BEMS WALLET WORKS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.6),
          ),
          const SizedBox(height: 14),
          _buildStepRow(
            '1',
            'Copy Your NUBAN',
            'Your personal, dedicated BemsFarms account number displayed above.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            '2',
            'Transfer Any Amount',
            'Instant automatic credit from any Nigerian commercial or fintech banking app.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            '3',
            'PIN-Protected Checkout',
            'Pay for farm produce at checkout in 1-tap using your 4-digit security PIN.',
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String number, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Color(0xFF1B432A),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  // 5. Checkout Payment PIN Section
  Widget _buildPaymentPinCard(dynamic wallet) {
    final hasPin = wallet?.hasPaymentPin ?? false;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasPin ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasPin ? Icons.lock_outline : Icons.lock_open,
                      color: hasPin ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checkout Payment PIN',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        hasPin ? 'PIN Active' : 'No PIN Set',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasPin ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () {
                  if (hasPin) {
                    _showPinOptionsSheet(context);
                  } else {
                    _showSetPinDialog(context);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  hasPin ? 'Change / Reset' : 'Set PIN',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your 4-digit Payment PIN is required whenever you select Bems Wallet to place an order at checkout.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
          ),
        ],
      ),
    );
  }

  // 6. Recent Transactions Section
  Widget _buildTransactionsSection(List<dynamic> transactions) {
    final filtered = transactions.where((t) {
      if (_txFilter == 'topup') return t.type == 'credit';
      if (_txFilter == 'payment') return t.type == 'debit';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Wallet Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            // Filter Pills [All | Top-Ups | Payments]
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  _buildTxFilterPill('All', 'all'),
                  _buildTxFilterPill('Top-Ups', 'topup'),
                  _buildTxFilterPill('Payments', 'payment'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    'No wallet transactions yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transfer to your dedicated NUBAN above to fund your wallet instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final tx = filtered[index];
              final isCredit = tx.type == 'credit';
              final dateStr = tx.createdAt != null
                  ? DateFormat('MMM dd, yyyy • hh:mm a').format(tx.createdAt!)
                  : 'Recent';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isCredit ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description ?? (isCredit ? 'Wallet Top-Up' : 'Order Payment'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isCredit ? '+' : '-'}${currencyFormatter.format(tx.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isCredit ? const Color(0xFF2E7D32) : Colors.black87,
                          ),
                        ),
                        if (tx.balanceAfter > 0)
                          Text(
                            'Bal: ${currencyFormatter.format(tx.balanceAfter)}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTxFilterPill(String title, String value) {
    final isSelected = _txFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _txFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : Colors.black54,
          ),
        ),
      ),
    );
  }

  // --- PIN Management Dialogs ---

  void _showPinOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 16),
                const Text('Wallet Security PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.pin, color: AppColors.primary),
                  title: const Text('Change Payment PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Requires your current 4-digit PIN'),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangePinDialog(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.redAccent),
                  title: const Text('Forgot PIN / Reset with Password', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Authorize with your account login password'),
                  onTap: () {
                    Navigator.pop(context);
                    _showResetPinDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSetPinDialog(BuildContext context) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set 4-Digit Payment PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This PIN protects your wallet and will be required at checkout.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 16),
              TextFormField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'New 4-Digit PIN', counterText: ''),
                validator: (val) => val == null || val.length != 4 ? 'Enter 4 digits' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Confirm 4-Digit PIN', counterText: ''),
                validator: (val) => val != pinController.text ? 'PINs do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final success = await ref.read(customerWalletProvider.notifier).setPin(pinController.text.trim());
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Color(0xFF1B5E20), content: Text('✓ 4-digit payment PIN set successfully!')),
                );
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Payment PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Current 4-Digit PIN', counterText: ''),
                validator: (val) => val == null || val.length != 4 ? 'Enter 4 digits' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'New 4-Digit PIN', counterText: ''),
                validator: (val) => val == null || val.length != 4 ? 'Enter 4 digits' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final success = await ref.read(customerWalletProvider.notifier).changePin(
                pin: newController.text.trim(),
                currentPin: currentController.text.trim(),
              );
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Color(0xFF1B5E20), content: Text('✓ Payment PIN changed successfully!')),
                );
              }
            },
            child: const Text('Update PIN'),
          ),
        ],
      ),
    );
  }

  void _showResetPinDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final newController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Forgotten PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your account login password to authorize this PIN reset.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Account Login Password'),
                validator: (val) => val == null || val.isEmpty ? 'Password is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'New 4-Digit PIN', counterText: ''),
                validator: (val) => val == null || val.length != 4 ? 'Enter 4 digits' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final success = await ref.read(customerWalletProvider.notifier).resetPin(
                pin: newController.text.trim(),
                accountPassword: passwordController.text.trim(),
              );
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Color(0xFF1B5E20), content: Text('✓ Payment PIN reset successfully!')),
                );
              }
            },
            child: const Text('Reset PIN'),
          ),
        ],
      ),
    );
  }
}
