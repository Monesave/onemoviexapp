import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@onemoviex.com',
      query: 'subject=OnemovieX Support Request',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ & Help'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _FAQItem(
            question: '🎬 What is OnemovieX?',
            answer:
                'OnemovieX helps you quickly agree on one movie to watch, whether you\'re alone or with friends, family, or a partner.',
          ),
          const _FAQItem(
            question: '👉 How does it work?',
            answer:
                'You swipe through movie cards:\nRight to like\nLeft to skip\n\nWhen everyone in a group likes the same movie, you\'ve got your winner.',
          ),
          const _FAQItem(
            question: '👥 What are Rooms?',
            answer:
                'Rooms let you decide together. Invite others, swipe on movies, and OnemovieX finds the movie you all agree on.',
          ),
          const _FAQItem(
            question: '🎭 How do mood-based suggestions work?',
            answer:
                'Pick a mood (funny, chill, intense, romantic, etc.), and the app recommends movies that match the vibe.',
          ),
          const _FAQItem(
            question: '💾 What is the Shortlist?',
            answer:
                'Movies you like are saved to your Shortlist so you can come back to them later. Shortlists automatically expire after 30 days.',
          ),
          const _FAQItem(
            question: '🎫 Can I watch or book tickets from the app?',
            answer:
                'Yes. Once you choose a movie, you can:\n\nOpen it directly on Netflix\n\nOr go straight to cinema ticket booking',
          ),
          const _FAQItem(
            question: '📱 Do I need to download an app?',
            answer:
                'No download needed. OnemovieX runs directly in your web browser — just open the link and go.',
          ),
          const _FAQItem(
            question: '🆓 Is OnemovieX free to use?',
            answer:
                'Yes. You can browse movies, swipe, save to your shortlist, and join any room for free. Creating rooms and using mood-based suggestions requires an Onemoviex Plus subscription (£4.99/month) — but only the host needs one; everyone else joins free.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.email,
                    size: 48,
                    color: Color(0xFF7C4DFF),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Need more help?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contact our support team',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.email),
                    label: const Text('Email Support'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _sendEmail,
                    child: const Text('support@onemoviex.com'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          widget.question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.answer,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

