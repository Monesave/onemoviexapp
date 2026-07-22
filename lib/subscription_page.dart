import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with WidgetsBindingObserver {
  late final SupabaseClient _client;
  bool _loading = true;
  String _tier = 'free';
  DateTime? _subscriptionEndsAt;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final rows = await _client
          .from('user_profiles')
          .select('tier, subscription_ends_at')
          .eq('id', userId)
          .limit(1);

      if (rows.isNotEmpty) {
        final row = rows.first;
        _tier = row['tier'] as String? ?? 'free';
        final endsAtStr = row['subscription_ends_at'] as String?;
        if (endsAtStr != null) {
          _subscriptionEndsAt = DateTime.tryParse(endsAtStr);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _startCheckout() async {
    setState(() {
      _loading = true;
    });

    try {
      final userId = _client.auth.currentUser?.id;
      final res = await _client.functions.invoke(
        'create-checkout-session',
        body: {
          if (userId != null) 'user_id': userId,
        },
      );
      final data = res.data as Map<String, dynamic>?;
      final urlStr = data?['url'] as String?;
      if (urlStr == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start checkout session.')),
        );
        return;
      }

      final uri = Uri.parse(urlStr);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open checkout in browser.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting checkout: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubscriber = _tier == 'subscriber';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Onemoviex Plus'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: const Color(0xFFFFC72C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Onemoviex Plus',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isSubscriber
                                ? 'You are currently a subscriber.'
                                : 'Unlock room creation, mood-based suggestions,\n'
                                  'and advanced controls for just £4.99/month.',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          if (isSubscriber && _subscriptionEndsAt != null)
                            Text(
                              'Renews on: ${_subscriptionEndsAt!.toLocal().toString().split(" ").first}',
                              style: const TextStyle(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Benefits',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Create rooms and host movie nights.'),
                  const Text('• Use mood-based AI suggestions.'),
                  const Text('• Manage rounds and winners.'),
                  const SizedBox(height: 32),
                  if (!isSubscriber)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _startCheckout,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Upgrade for £4.99/month'),
                      ),
                    )
                  else
                    const Text(
                      'To change or cancel your subscription, use the billing portal link in your Stripe emails for now.',
                      style: TextStyle(color: Colors.white70),
                    ),
                ],
              ),
      ),
    );
  }
}


