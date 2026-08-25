part of '../traveler_pages.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser?.uid;
    final notificationService = const NotificationService();

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'Notifications',
              subtitle:
                  'Updates about tasks, safety, rewards and your account.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: uid == null
                  ? const ExplorerEmptyState(
                      title: 'Sign in required',
                      subtitle: 'Sign in to view your notifications.',
                      icon: Icons.lock_outline,
                    )
                  : StreamBuilder<List<AppNotification>>(
                      stream: notificationService.watchForUser(uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return ExplorerEmptyState(
                            title: 'Unable to load notifications',
                            subtitle: '${snapshot.error}',
                            icon: Icons.cloud_off_outlined,
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final notifications = snapshot.data!;
                        if (notifications.isEmpty) {
                          return const ExplorerEmptyState(
                            title: 'No notifications yet',
                            subtitle:
                                'Important platform updates will appear here.',
                            icon: Icons.notifications_none_rounded,
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                          itemCount: notifications.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return ExplorerCard(
                              backgroundColor: notification.isRead
                                  ? Colors.white
                                  : ExplorerColors.navySoft,
                              borderColor: notification.isRead
                                  ? ExplorerColors.border
                                  : const Color(0xFFB9CBE2),
                              onTap: () => _openNotification(
                                context,
                                notificationService,
                                notification,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: notification.isRead
                                        ? ExplorerColors.subtle
                                        : ExplorerColors.navy,
                                    foregroundColor: notification.isRead
                                        ? ExplorerColors.muted
                                        : Colors.white,
                                    child: Icon(
                                      notification.isRead
                                          ? Icons.notifications_none
                                          : Icons.notifications_active_outlined,
                                      size: 21,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notification.title,
                                                style: const TextStyle(
                                                  color: ExplorerColors.navy,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (!notification.isRead)
                                              const ExplorerStatusBadge(
                                                label: 'NEW',
                                                tone: ExplorerStatusTone.navy,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          notification.message,
                                          style: const TextStyle(
                                            color: ExplorerColors.text,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          notification.createdAt == null
                                              ? 'Recently'
                                              : DateFormat.yMMMd()
                                                    .add_jm()
                                                    .format(
                                                      notification.createdAt!,
                                                    ),
                                          style: const TextStyle(
                                            color: ExplorerColors.muted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    NotificationService service,
    AppNotification notification,
  ) async {
    try {
      if (!notification.isRead) await service.markRead(notification.id);
      if (!context.mounted) return;
      final hazardId = notification.hazardId;
      if (notification.type.startsWith('hazard') &&
          hazardId != null &&
          hazardId.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HazardDetailPage(hazardId: hazardId, showStatusHistory: true),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          'Unable to open notification: $error',
          error: true,
        );
      }
    }
  }
}
