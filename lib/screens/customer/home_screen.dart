import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../utils/constants.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/service_card.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String? _category;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ServiceQuery(category: _category, search: _search);
    final services = ref.watch(browseServicesProvider(query));
    final firstName = (ref.watch(currentProfileProvider).valueOrNull?.name ?? '').split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(firstName.isEmpty ? 'Explore' : 'Hi, $firstName'),
        actions: const [NotificationBell()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by name or area',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                      setState(() {});
                    },
                  ),
              ],
              onChanged: (v) {
                setState(() {}); // show/hide the clear button
                _onSearchChanged(v);
              },
              elevation: const WidgetStatePropertyAll(0),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final c in serviceCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(iconForCategory(c), size: 18),
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (sel) => setState(() => _category = sel ? c : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(browseServicesProvider(query).future),
              child: AsyncValueView(
                value: services,
                onRetry: () => ref.invalidate(browseServicesProvider(query)),
                data: (list) {
                  if (list.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 48),
                        EmptyState(
                          icon: Icons.search_off,
                          title: _search.isEmpty && _category == null
                              ? 'No venues listed yet'
                              : 'Nothing matches your search',
                          message: _search.isEmpty && _category == null
                              ? 'Check back soon — new places are being added.'
                              : 'Try a different name, area or category.',
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: list.length,
                    itemBuilder: (context, i) => ServiceCard(
                      service: list[i],
                      onTap: () => context.push('/home/service/${list[i].id}'),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
