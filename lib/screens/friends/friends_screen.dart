import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../models/friendship_model.dart';
import '../../services/friendship_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final FriendshipService _friendshipService = FriendshipService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.userId;

    if (userId == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Requests'),
            Tab(text: 'Leaderboard'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.addFriend);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Friends List (Accepted only)
          _buildFriendsList(userId),
          // Pending Requests
          _buildPendingRequests(userId),
          // Leaderboard
          _buildLeaderboard(userId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.addFriend);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Friend'),
      ),
    );
  }

  Widget _buildFriendsList(String userId) {
    return StreamBuilder<List<FriendshipModel>>(
      stream: _friendshipService.getAcceptedFriendships(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final friendships = snapshot.data ?? [];

        if (friendships.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🤝', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(
                    'No friends yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add friends using their Friend ID to start accountability streaks!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friendships.length,
          itemBuilder: (context, index) {
            final friendship = friendships[index];
            return _buildFriendCard(friendship, userId);
          },
        );
      },
    );
  }

  Widget _buildFriendCard(FriendshipModel friendship, String userId) {
    final friendName = friendship.getFriendName(userId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.accent.withOpacity(0.1),
              child: Text(
                friendName.isNotEmpty ? friendName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Friend info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friendName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        '${friendship.friendshipStreak} day streak',
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Streak number
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: friendship.friendshipStreak > 0
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${friendship.friendshipStreak}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: friendship.friendshipStreak > 0
                      ? AppColors.primary
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequests(String userId) {
    return StreamBuilder<List<FriendshipModel>>(
      stream: _friendshipService.getPendingFriendRequests(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📬', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When someone sends you a friend request, it will appear here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildPendingRequestCard(request, userId);
          },
        );
      },
    );
  }

  Widget _buildPendingRequestCard(FriendshipModel request, String userId) {
    final senderName = request.user1Name;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.accent.withOpacity(0.1),
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Sender info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Friend request pending',
                    style: TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'accept') {
                  try {
                    await _friendshipService.acceptFriendRequest(
                      friendshipId: request.id,
                      userId: userId,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You are now friends with $senderName! 🎉'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                } else if (value == 'reject') {
                  try {
                    await _friendshipService.rejectFriendRequest(
                      friendshipId: request.id,
                      userId: userId,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'accept',
                  child: Row(
                    children: [
                      Icon(Icons.check, color: Colors.green),
                      SizedBox(width: 12),
                      Text('Accept'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      Icon(Icons.close, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Reject'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard(String userId) {
    return FutureBuilder<List<FriendshipModel>>(
      future: _friendshipService.getLeaderboard(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final friendships = snapshot.data ?? [];

        if (friendships.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🏆', style: TextStyle(fontSize: 48)),
                SizedBox(height: 16),
                Text('Add friends to see the leaderboard'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friendships.length,
          itemBuilder: (context, index) {
            final friendship = friendships[index];
            final friendName = friendship.getFriendName(userId);
            final rank = index + 1;

            String rankEmoji;
            Color rankColor;
            switch (rank) {
              case 1:
                rankEmoji = '🥇';
                rankColor = const Color(0xFFFFD700);
                break;
              case 2:
                rankEmoji = '🥈';
                rankColor = const Color(0xFFC0C0C0);
                break;
              case 3:
                rankEmoji = '🥉';
                rankColor = const Color(0xFFCD7F32);
                break;
              default:
                rankEmoji = '#$rank';
                rankColor = AppColors.textSecondaryLight;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: rank <= 3
                    ? Text(rankEmoji, style: const TextStyle(fontSize: 28))
                    : CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                title: Text(
                  friendName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Best: ${friendship.maxFriendshipStreak} days',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      '${friendship.friendshipStreak}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
