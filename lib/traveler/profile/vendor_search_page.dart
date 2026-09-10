part of '../traveler_pages.dart';

class VendorSearchPage extends StatefulWidget {
  const VendorSearchPage({super.key});

  @override
  State<VendorSearchPage> createState() => _VendorSearchPageState();
}

class _VendorSearchPageState extends State<VendorSearchPage> {
  static const int _pageSize = 25;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _allVendors = [];
  String? _errorMessage;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchVendors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVendors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await AppServices.db.collection('vendors').get();

      final vendors = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final uid = data['uid'] ?? doc.id;
        final status = '${data['status'] ?? ''}'.toLowerCase();
        if (status == 'deactivated' || status == 'disabled' || status == 'inactive') {
          continue;
        }

        vendors.add({
          ...data,
          'uid': uid,
        });
      }

      if (mounted) {
        setState(() {
          _allVendors = vendors;
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredVendors {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _allVendors;
    }
    return _allVendors.where((vendor) {
      final name = '${vendor['businessName'] ?? ''}'.toLowerCase();
      final owner = '${vendor['ownerName'] ?? ''}'.toLowerCase();
      final category = '${vendor['category'] ?? ''}'.toLowerCase();
      final location = '${vendor['shopLocation'] ?? ''}'.toLowerCase();
      final desc = '${vendor['businessDescription'] ?? ''}'.toLowerCase();

      return name.contains(query) ||
          owner.contains(query) ||
          category.contains(query) ||
          location.contains(query) ||
          desc.contains(query);
    }).toList();
  }

  int get _totalPages {
    final count = _filteredVendors.length;
    if (count == 0) return 1;
    return (count / _pageSize).ceil();
  }

  List<Map<String, dynamic>> get _pagedVendors {
    final filtered = _filteredVendors;
    if (filtered.isEmpty) return [];
    final start = (_currentPage - 1) * _pageSize;
    if (start >= filtered.length) return [];
    final end = (start + _pageSize < filtered.length) ? start + _pageSize : filtered.length;
    return filtered.sublist(start, end);
  }

  Widget _buildPaginationControls(int totalCount) {
    if (totalCount <= _pageSize) return const SizedBox.shrink();

    final startItem = (_currentPage - 1) * _pageSize + 1;
    final endItem = (_currentPage * _pageSize < totalCount)
        ? _currentPage * _pageSize
        : totalCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ExplorerColors.border)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Previous'),
          ),
          Expanded(
            child: Text(
              'Showing $startItem–$endItem of $totalCount\n(Page $_currentPage of $_totalPages)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: ExplorerColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: _currentPage < _totalPages
                ? () => setState(() => _currentPage++)
                : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Next'),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVendors;
    final pagedResults = _pagedVendors;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Search Vendors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Vendors',
            onPressed: _fetchVendors,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Type down words to search vendors...',
                prefixIcon:
                    const Icon(Icons.storefront, color: ExplorerColors.navy),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _currentPage = 1;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: ExplorerColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() {
                _searchQuery = val;
                _currentPage = 1;
              }),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: ExplorerColors.danger),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: ExplorerColors.muted),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchVendors,
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.storefront_outlined,
                                      size: 56, color: ExplorerColors.muted),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No registered vendors found.'
                                        : 'No vendors matching "$_searchQuery"',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: ExplorerColors.navy,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Try searching for business name, category, or location.',
                                    style: TextStyle(
                                        color: ExplorerColors.muted,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: _fetchVendors,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: pagedResults.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final vendor = pagedResults[index];
                                      final name =
                                          '${vendor['businessName'] ?? 'Vendor Shop'}';
                                      final category =
                                          '${vendor['category'] ?? 'General'}';
                                      final location =
                                          '${vendor['shopLocation'] ?? 'Location unavailable'}';

                                      return ExplorerCard(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _VendorDetailPage(vendor: vendor),
                                            ),
                                          );
                                        },
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 26,
                                              backgroundColor: ExplorerColors.goldDark
                                                  .withOpacity(0.15),
                                              foregroundColor: ExplorerColors.goldDark,
                                              child: const Icon(Icons.storefront,
                                                  size: 26),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          name,
                                                          style: const TextStyle(
                                                            color: ExplorerColors.navy,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 8,
                                                            vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: ExplorerColors
                                                              .navySoft,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  12),
                                                        ),
                                                        child: Text(
                                                          category,
                                                          style: const TextStyle(
                                                            color:
                                                                ExplorerColors.navy,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    location,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: ExplorerColors.muted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: ExplorerColors.muted,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              _buildPaginationControls(filtered.length),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class _VendorDetailPage extends StatelessWidget {
  const _VendorDetailPage({required this.vendor});

  final Map<String, dynamic> vendor;

  @override
  Widget build(BuildContext context) {
    final name = '${vendor['businessName'] ?? 'Vendor Shop'}';
    final owner = '${vendor['ownerName'] ?? ''}';
    final category = '${vendor['category'] ?? 'General'}';
    final location = '${vendor['shopLocation'] ?? ''}';
    final contact = '${vendor['contactNumber'] ?? ''}';
    final hours = '${vendor['businessHours'] ?? ''}';
    final description = '${vendor['businessDescription'] ?? ''}';
    final vendorId = '${vendor['uid'] ?? vendor['id'] ?? ''}';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: Text(name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExplorerCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: ExplorerColors.goldDark.withOpacity(0.15),
                  foregroundColor: ExplorerColors.goldDark,
                  child: const Icon(Icons.storefront, size: 40),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: ExplorerColors.navySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                if (owner.isNotEmpty)
                  _detailRow(Icons.person_outline, 'Owner', owner),
                if (contact.isNotEmpty)
                  _detailRow(Icons.phone_outlined, 'Contact', contact),
                if (hours.isNotEmpty)
                  _detailRow(Icons.access_time_outlined, 'Hours', hours),
                if (location.isNotEmpty)
                  _detailRow(Icons.location_on_outlined, 'Location', location),
              ],
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'ABOUT BUSINESS',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 8),
            ExplorerCard(
              child: Text(
                description,
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (vendorId.isNotEmpty)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ExplorerColors.danger,
                side: const BorderSide(color: ExplorerColors.danger),
              ),
              onPressed: () {
                showReportDialog(
                  context,
                  targetId: vendorId,
                  targetName: name,
                  targetType: 'vendor',
                );
              },
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report Vendor'),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ExplorerColors.muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: ExplorerColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
