import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/billing_repository.dart';
import '../models/invoice.dart';
import 'billing_format.dart';
import 'invoice_detail_screen.dart';
import 'record_payment_sheet.dart';

enum _DueFilter { all, overdue, upcoming }

extension on _DueFilter {
  String get label {
    switch (this) {
      case _DueFilter.all:
        return 'All';
      case _DueFilter.overdue:
        return 'Overdue';
      case _DueFilter.upcoming:
        return 'Upcoming';
    }
  }
}

enum _LoadStatus { loading, loaded, error }

/// Unpaid invoices, soonest-due first. Server-side: `status=unpaid` +
/// `ordering=due_date` + `search=` (all real filterset/ordering/search
/// params on StudentInvoiceViewSet — billing/views.py). "Overdue"/"Upcoming"
/// chips and balance-sort are applied client-side on the loaded page(s) only
/// — see BillingApi doc comment for why balance can't be sorted server-side.
class UnpaidInvoicesListScreen extends StatefulWidget {
  const UnpaidInvoicesListScreen({super.key, required this.repository});

  final BillingRepository repository;

  @override
  State<UnpaidInvoicesListScreen> createState() =>
      _UnpaidInvoicesListScreenState();
}

class _UnpaidInvoicesListScreenState extends State<UnpaidInvoicesListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  _DueFilter _filter = _DueFilter.all;
  bool _sortByBalance = false;
  _LoadStatus _status = _LoadStatus.loading;
  List<Invoice> _invoices = const [];
  Timer? _debounce;

  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_status != _LoadStatus.loaded || !_hasMore || _loadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load({bool isRefresh = false}) async {
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _status = _LoadStatus.loading;
      }
    });
    try {
      final result = await widget.repository.fetchUnpaidInvoices(
        search: _searchController.text.trim(),
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _invoices = result.invoices;
        _page = 1;
        _hasMore = result.hasMore;
        _status = _LoadStatus.loaded;
        _refreshing = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint(
        'BillingRepository.fetchUnpaidInvoices failed: $error\n$stackTrace',
      );
      setState(() {
        _status = _LoadStatus.error;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await widget.repository.fetchUnpaidInvoices(
        search: _searchController.text.trim(),
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _invoices = [..._invoices, ...result.invoices];
        _page = nextPage;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  List<Invoice> get _visibleInvoices {
    var list = _invoices;
    if (_filter != _DueFilter.all) {
      list = list.where((inv) {
        final overdue = dueMetaFor(inv.dueDate).isOverdue;
        return _filter == _DueFilter.overdue ? overdue : !overdue;
      }).toList();
    }
    if (_sortByBalance) {
      list = [...list]..sort((a, b) => b.balance.compareTo(a.balance));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleInvoices;

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Unpaid Invoices',
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.refresh,
                    size: 20,
                    color: AppColors.textMuted3,
                  ),
            onPressed: _refreshing ? null : () => _load(isRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchAndFilters(
            controller: _searchController,
            onSearchChanged: _onSearchChanged,
            filter: _filter,
            onFilterSelected: (f) => setState(() => _filter = f),
            sortByBalance: _sortByBalance,
            onSortToggle: () =>
                setState(() => _sortByBalance = !_sortByBalance),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.cardWhite,
            child: Text(
              '${visible.length} of ${_invoices.length} invoices',
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: AppColors.textMuted2,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          Expanded(child: _buildBody(visible)),
        ],
      ),
    );
  }

  Widget _buildBody(List<Invoice> visible) {
    switch (_status) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return _ErrorState(onRetry: () => _load());
      case _LoadStatus.loaded:
        if (visible.isEmpty) {
          return _EmptyState(
            hasSearch:
                _searchController.text.trim().isNotEmpty ||
                _filter != _DueFilter.all,
          );
        }
        return RefreshIndicator(
          onRefresh: () => _load(isRefresh: true),
          child: ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: visible.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.rowDivider),
            itemBuilder: (context, index) {
              if (index >= visible.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return _InvoiceRow(
                invoice: visible[index],
                repository: widget.repository,
                onChanged: () => _load(isRefresh: true),
              );
            },
          ),
        );
    }
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.onSearchChanged,
    required this.filter,
    required this.onFilterSelected,
    required this.sortByBalance,
    required this.onSortToggle,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final _DueFilter filter;
  final ValueChanged<_DueFilter> onFilterSelected;
  final bool sortByBalance;
  final VoidCallback onSortToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: const Color(0xFF2D1A1A),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search name or invoice #',
              hintStyle: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: AppColors.iconMuted,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AppColors.iconMuted,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _DueFilter.values) ...[
                        _FilterChip(
                          label: f.label,
                          selected: f == filter,
                          onTap: () => onFilterSelected(f),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSortToggle,
                child: Text(
                  sortByBalance ? 'Sort: Balance' : 'Sort: Due Date',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textMuted2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.neutralPillBg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: selected ? null : Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textMuted1,
          ),
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.repository,
    required this.onChanged,
  });

  final Invoice invoice;
  final BillingRepository repository;
  final VoidCallback onChanged;

  Future<void> _quickRecordPayment(BuildContext context) async {
    final updated = await showModalBottomSheet<Invoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          RecordPaymentSheet(invoice: invoice, repository: repository),
    );
    if (updated != null) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final enrollment = invoice.enrollmentDetail;
    final dueMeta = dueMetaFor(invoice.dueDate);
    final overdueCount = invoice.overdueInstallmentCount;

    return InkWell(
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                InvoiceDetailScreen(invoice: invoice, repository: repository),
          ),
        );
        if (changed == true) onChanged();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFDF3F2),
              ),
              child: Center(
                child: Text(
                  enrollment?.initials ?? '?',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enrollment?.studentName ?? 'Unknown student',
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      fontStyle: enrollment == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: enrollment == null
                          ? AppColors.textMuted3
                          : AppColors.headingDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    invoice.invoiceNo,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textMuted3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (overdueCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$overdueCount of ${invoice.installments.length} installments overdue',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dangerText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPeso(invoice.balance),
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dangerText,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: dueMeta.background,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    dueMeta.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: dueMeta.textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.payments_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              tooltip: 'Record Payment',
              visualDensity: VisualDensity.compact,
              onPressed: () => _quickRecordPayment(context),
            ),
            const Icon(Icons.chevron_right, size: 13, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search : Icons.receipt_long_outlined,
              size: 28,
              color: const Color(0xFFD8B8B4),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch ? 'No matching invoices' : 'No unpaid invoices',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasSearch
                  ? 'Try a different name, invoice #, or filter'
                  : "Everything's settled for now",
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: AppColors.textMuted3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 28, color: Color(0xFFD8B8B4)),
            const SizedBox(height: 8),
            Text(
              "Couldn't load invoices",
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted1,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
