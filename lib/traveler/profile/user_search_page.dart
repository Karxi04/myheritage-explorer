part of '../traveler_pages.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  static const int _pageSize = 25;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _allUsers = [];
  String? _errorMessage;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUid = AppServices.auth.currentUser?.uid;
      final currentEmail = AppServices.auth.currentUser?.email?.trim().toLowerCase();
      final snapshot = await AppServices.db.collection('travelers').get();

      final users = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final uid = data['uid'] ?? doc.id;
        final email = '${data['email'] ?? ''}'.trim().toLowerCase();

        // Strictly prevent current user from searching or viewing themselves
        if (uid == currentUid ||
            (currentEmail != null && currentEmail.isNotEmpty && email == currentEmail)) {
          continue;
        }
        // Filter out deactivated accounts
        if ('${data['status'] ?? ''}' == 'deactivated') continue;

        users.add({
          ...data,
          'uid': uid,
        });
      }

      if (mounted) {
        setState(() {
          _allUsers = users;
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

  List<Map<String, dynamic>> get _filteredUsers {
    final currentUid = AppServices.auth.currentUser?.uid;
    final currentEmail = AppServices.auth.currentUser?.email?.trim().toLowerCase();
    final query = _searchQuery.trim().toLowerCase();

    final nonSelfUsers = _allUsers.where((user) {
      final uid = user['uid'] ?? user['id'];
      final email = '${user['email'] ?? ''}'.trim().toLowerCase();
      if (uid == currentUid ||
          (currentEmail != null && currentEmail.isNotEmpty && email == currentEmail)) {
        return false;
      }
      return true;
    }).toList();

    if (query.isEmpty) {
      return nonSelfUsers;
    }

    return nonSelfUsers.where((user) {
      final name = '${user['displayName'] ?? ''}'.toLowerCase();
      final email = '${user['email'] ?? ''}'.toLowerCase();
      final interests = (user['travelInterests'] as List<dynamic>?)
              ?.map((e) => '$e'.toLowerCase())
              .join(' ') ??
          '';
      return name.contains(query) ||
          email.contains(query) ||
          interests.contains(query);
    }).toList();
  }

  int get _totalPages {
    final count = _filteredUsers.length;
    if (count == 0) return 1;
    return (count / _pageSize).ceil();
  }

  List<Map<String, dynamic>> get _pagedUsers {
    final filtered = _filteredUsers;
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

  void _showHiddenProfileNotice(
      BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.visibility_off, color: ExplorerColors.danger),
            SizedBox(width: 8),
            Text('Profile Hidden'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user['displayName'] ?? 'User'} set their privacy to hidden.',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: ExplorerColors.navy,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This user has turned off profile viewing by other people. Their profile details, interests, and statistics cannot be viewed.',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openPublicUserProfile(
      BuildContext context, Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OtherUserProfileDetailPage(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    final pagedResults = _pagedUsers;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Search Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Users',
            onPressed: _fetchUsers,
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
                hintText: 'Type down words to search users...',
                prefixIcon:
                    const Icon(Icons.search, color: ExplorerColors.navy),
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
                                onPressed: _fetchUsers,
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
                                  const Icon(Icons.person_search,
                                      size: 56, color: ExplorerColors.muted),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No other registered users found.'
                                        : 'No users matching "$_searchQuery"',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: ExplorerColors.navy,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Try typing a different name, email, or interest.',
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
                                  onRefresh: _fetchUsers,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: pagedResults.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final user = pagedResults[index];
                                      final isHidden =
                                          user['isProfileHidden'] == true;
                                      final name =
                                          '${user['displayName'] ?? 'Traveler'}';
                                      final rank = '${user['rank'] ?? 'Bronze'}';
                                      final email = '${user['email'] ?? ''}';

                                      return ExplorerCard(
                                        onTap: () {
                                          if (isHidden) {
                                            _showHiddenProfileNotice(context, user);
                                          } else {
                                            _openPublicUserProfile(context, user);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 26,
                                                  backgroundColor: isHidden
                                                      ? ExplorerColors.dangerSoft
                                                      : ExplorerColors.navySoft,
                                                  foregroundColor: isHidden
                                                      ? ExplorerColors.danger
                                                      : ExplorerColors.navy,
                                                  child: isHidden
                                                      ? const Icon(
                                                          Icons.lock_outline,
                                                          size: 24)
                                                      : Text(
                                                          name.trim().isEmpty
                                                              ? 'T'
                                                              : name
                                                                  .trim()[0]
                                                                  .toUpperCase(),
                                                          style: const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                ),
                                                if (isHidden)
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(2),
                                                      decoration: const BoxDecoration(
                                                        color: ExplorerColors.danger,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.visibility_off,
                                                        size: 10,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                              ],
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
                                                          style: TextStyle(
                                                            color: isHidden
                                                                ? ExplorerColors.muted
                                                                : ExplorerColors.navy,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                      if (!isHidden)
                                                        Container(
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 8,
                                                              vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: ExplorerColors
                                                                .goldDark
                                                                .withOpacity(0.15),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    12),
                                                          ),
                                                          child: Text(
                                                            rank,
                                                            style: const TextStyle(
                                                              color: ExplorerColors
                                                                  .goldDark,
                                                              fontWeight:
                                                                  FontWeight.w800,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  if (isHidden)
                                                    const Row(
                                                      children: [
                                                        Icon(
                                                          Icons.privacy_tip_outlined,
                                                          size: 13,
                                                          color:
                                                              ExplorerColors.danger,
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'User set their privacy to hidden',
                                                          style: TextStyle(
                                                            color:
                                                                ExplorerColors.danger,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  else
                                                    Text(
                                                      email,
                                                      style: const TextStyle(
                                                        color: ExplorerColors.muted,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              isHidden
                                                  ? Icons.lock
                                                  : Icons.chevron_right,
                                              color: isHidden
                                                  ? ExplorerColors.danger
                                                  : ExplorerColors.muted,
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

class _OtherUserProfileDetailPage extends StatelessWidget {
  const _OtherUserProfileDetailPage({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final name = '${user['displayName'] ?? 'Traveler'}';
    final email = '${user['email'] ?? ''}';
    final rank = '${user['rank'] ?? 'Bronze'}';
    final points = user['points'] ?? 0;
    final impact = user['localImpactScore'] ?? 0;
    final interests = List<String>.from(user['travelInterests'] ?? []);
    final userId = '${user['uid'] ?? user['id'] ?? ''}';

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
                  radius: 44,
                  backgroundColor: ExplorerColors.navySoft,
                  foregroundColor: ExplorerColors.navy,
                  child: Text(
                    name.trim().isEmpty ? 'T' : name.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: ExplorerColors.goldDark.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: ExplorerColors.goldDark.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.military_tech,
                          size: 16, color: ExplorerColors.goldDark),
                      const SizedBox(width: 4),
                      Text(
                        '$rank Member',
                        style: const TextStyle(
                          color: ExplorerColors.goldDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'IMPACT',
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$impact',
                            style: const TextStyle(
                              color: ExplorerColors.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text('pts',
                              style: TextStyle(
                                  color: ExplorerColors.muted, fontSize: 9)),
                        ],
                      ),
                    ),
                    Container(
                        width: 1, height: 40, color: ExplorerColors.border),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'POINTS',
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$points',
                            style: const TextStyle(
                              color: ExplorerColors.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text('pts',
                              style: TextStyle(
                                  color: ExplorerColors.muted, fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'TRAVEL INTERESTS',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 8),
            ExplorerCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: interests
                    .map(
                      (item) => Chip(
                        label: Text(item),
                        backgroundColor: ExplorerColors.navySoft,
                        labelStyle: const TextStyle(
                          color: ExplorerColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (userId.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: () {
                openCompanionPrivateChat(
                  context,
                  otherUserId: userId,
                  otherUserName: name,
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Send Message'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ExplorerColors.danger,
                side: const BorderSide(color: ExplorerColors.danger),
              ),
              onPressed: () {
                showReportDialog(
                  context,
                  targetId: userId,
                  targetName: name,
                  targetType: 'user',
                );
              },
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report User'),
            ),
          ],
        ],
      ),
    );
  }
}
