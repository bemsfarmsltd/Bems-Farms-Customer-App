import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/orders/data/models/order_model.dart';
import 'package:bems_farms/features/orders/presentation/providers/order_providers.dart';
import 'package:bems_farms/features/orders/presentation/pages/order_detail_page.dart';

class Transaction {
  final String id;
  final String reference;
  final String type;
  final double amount;
  final DateTime date;
  final String status; // 'Successful', 'Failed', 'Pending'
  final String paymentMethod;
  final Order? order;

  const Transaction({
    required this.id,
    required this.reference,
    required this.type,
    required this.amount,
    required this.date,
    required this.status,
    required this.paymentMethod,
    this.order,
  });

  String get formattedAmount {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '₦$formatted';
  }
}

class TransactionHistoryPage extends ConsumerStatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  ConsumerState<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends ConsumerState<TransactionHistoryPage> {
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('Could not load transactions: $err', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => ref.refresh(ordersProvider),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
        data: (orders) {
          final transactions = orders.map((order) {
            final ps = order.rawJson?['payment_status']?.toString().toLowerCase();
            String status = 'Successful';
            if (ps == 'failed' || ps == 'cancelled' || order.status == OrderStatus.cancelled) {
              status = 'Failed';
            } else if (order.paymentMethod.toLowerCase().contains('cod') || order.paymentMethod.toLowerCase().contains('cash')) {
              status = order.status == OrderStatus.delivered ? 'Successful' : 'Pending';
            } else if (ps == 'pending') {
              status = 'Pending';
            }

            String paymentMethodName = 'Card Payment';
            final pm = order.paymentMethod.toLowerCase();
            if (pm.contains('cod') || pm.contains('cash')) {
              paymentMethodName = 'Cash on Delivery';
            } else if (pm.contains('transfer') || pm.contains('bank')) {
              paymentMethodName = 'Instant Bank Transfer';
            } else if (pm.contains('ussd')) {
              paymentMethodName = 'USSD Payment';
            }

            final refCode = order.rawJson?['payment_reference']?.toString() ??
                order.rawJson?['reference']?.toString() ??
                order.rawJson?['tx_ref']?.toString() ??
                'TXN-${order.id.replaceAll('#', '').toUpperCase()}';

            return Transaction(
              id: order.id,
              reference: refCode,
              type: 'Order Payment (${order.shortId})',
              amount: order.total,
              date: order.createdAt,
              status: status,
              paymentMethod: paymentMethodName,
              order: order,
            );
          }).toList();

          final filteredTransactions = transactions.where((t) {
            if (_activeFilter == 'All') return true;
            return t.status == _activeFilter;
          }).toList();

          return Column(
            children: [
              _buildFilterTabs(),
              const SizedBox(height: 8),
              Expanded(
                child: filteredTransactions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => ref.refresh(ordersProvider),
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredTransactions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildTransactionCard(filteredTransactions[index]);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['All', 'Successful', 'Pending', 'Failed'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _activeFilter == filter;
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(Transaction txn) {
    final isSuccess = txn.status == 'Successful';
    final isPending = txn.status == 'Pending';
    final isRefund = txn.type.contains('Refund');

    Color amountColor;
    if (isRefund) {
      amountColor = Colors.green.shade700;
    } else if (isSuccess) {
      amountColor = AppColors.textPrimary;
    } else if (isPending) {
      amountColor = Colors.orange.shade800;
    } else {
      amountColor = Colors.red.shade700;
    }

    final amountPrefix = isRefund ? '+' : '-';

    return GestureDetector(
      onTap: () => _showTransactionDetails(txn),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isRefund
                    ? Colors.green.shade50
                    : isSuccess
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : isPending
                            ? Colors.orange.shade50
                            : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRefund
                    ? Icons.call_received_rounded
                    : isSuccess
                        ? Icons.payment_rounded
                        : isPending
                            ? Icons.hourglass_top_rounded
                            : Icons.error_outline_rounded,
                color: isRefund
                    ? Colors.green.shade700
                    : isSuccess
                        ? AppColors.primary
                        : isPending
                            ? Colors.orange.shade800
                            : Colors.red.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.type,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(txn.date),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountPrefix${txn.formattedAmount}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? Colors.green.shade50
                        : isPending
                            ? Colors.orange.shade50
                            : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    txn.status,
                    style: TextStyle(
                      color: isSuccess
                          ? Colors.green.shade700
                          : isPending
                              ? Colors.orange.shade800
                              : Colors.red.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_activeFilter.toLowerCase()} transactions',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Any orders you place will show their payment transactions here.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(Transaction txn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isSuccess = txn.status == 'Successful';
        final isPending = txn.status == 'Pending';
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Transaction Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              _detailRow('Transaction Type', txn.type),
              _detailRow('Amount', txn.formattedAmount, isBold: true),
              _detailRow('Reference', txn.reference),
              _detailRow('Payment Method', txn.paymentMethod),
              _detailRow('Date & Time', _formatDateLong(txn.date)),
              _detailRow(
                'Status',
                txn.status,
                customValue: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? Colors.green.shade50
                        : isPending
                            ? Colors.orange.shade50
                            : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    txn.status,
                    style: TextStyle(
                      color: isSuccess
                          ? Colors.green.shade700
                          : isPending
                              ? Colors.orange.shade800
                              : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (txn.order != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: txn.id)),
                      );
                    },
                    icon: const Icon(Icons.receipt_outlined, size: 18),
                    label: const Text('View Full Order & Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Widget? customValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          customValue ??
              Text(
                value,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$min $ampm';
  }

  String _formatDateLong(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:$min';
  }
}
