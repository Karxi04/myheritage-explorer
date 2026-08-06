
part of '../traveler_pages.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final input = TextEditingController();
  final scrollController = ScrollController();
  final messages = <Map<String, String>>[
    {
      'role': 'bot',
      'text':
          'Hi! I\'m your MyHeritage travel assistant. I can help you with itinerary planning, cultural tasks, rewards, companion tracking, SOS, safety reports, and weather reminders.',
    },
  ];

  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'text': text});
      messages.add({'role': 'bot', 'text': answer(text)});
      input.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String answer(String text) {
    final value = text.toLowerCase();
    if (value.contains('itinerary') || value.contains('planner')) {
      return 'To generate an itinerary, go to Planner, select your area, available time, interests, budget range, and travel pace. Then tap Generate Itinerary.';
    }
    if (value.contains('task') || value.contains('culture')) {
      return 'Open Cultural Tasks, choose an available task, complete the activity, and upload a photo. Submissions are reviewed by the administrator.';
    }
    if (value.contains('reward') || value.contains('voucher')) {
      return 'Claim an active voucher using your points. The QR code appears in Voucher Wallet for the vendor to scan.';
    }
    if (value.contains('hazard') || value.contains('safety')) {
      return 'Use Safety & Hazard Reporting to view verified danger zones or submit a GPS-based hazard report.';
    }
    if (value.contains('sos')) {
      return 'Open your Companion group and press SOS. Your latest location and timestamp will be sent to the group.';
    }
    if (value.contains('companion') || value.contains('group')) {
      return 'Create a private travel group or join one using a six-character code. Members can share locations after approval.';
    }
    return 'I can guide you through planning, culture, safety, companion groups and rewards. Try asking “How do I claim a voucher?”';
  }

  @override
  void dispose() {
    input.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Travel Assistant'),
            Text(
              'MyHeritage Explorer Help Bot',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final message = messages[index];
                final user = message['role'] == 'user';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: user
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!user) ...[
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: ExplorerColors.navy,
                          child: Icon(
                            Icons.smart_toy_outlined,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          constraints: const BoxConstraints(maxWidth: 330),
                          decoration: BoxDecoration(
                            color: user
                                ? ExplorerColors.navy
                                : const Color(0xFFDDE8FF),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(user ? 14 : 3),
                              bottomRight: Radius.circular(user ? 3 : 14),
                            ),
                          ),
                          child: Text(
                            message['text']!,
                            style: TextStyle(
                              color: user
                                  ? Colors.white
                                  : ExplorerColors.navy,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: ExplorerColors.border),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your trip...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
