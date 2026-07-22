import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'match_page.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key, this.onGoToPremium});

  final VoidCallback? onGoToPremium;

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  late final SupabaseClient _client;
  late Future<List<Map<String, dynamic>>> _future;
  String _userTier = 'free';
  RealtimeChannel? _roomsChannel;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _future = _fetchRooms();
    _loadTier();
    _subscribeRoomList();
  }

  void _subscribeRoomList() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    _roomsChannel = _client
        .channel('my_rooms_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'room_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _refresh(),
        )
        ..subscribe();
  }

  @override
  void dispose() {
    _roomsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadTier() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await _client
          .from('user_profiles')
          .select('tier')
          .eq('id', userId)
          .limit(1);
      if (rows.isNotEmpty && mounted) {
        setState(() {
          _userTier = rows.first['tier'] as String? ?? 'free';
        });
      }
    } catch (e) {
      debugPrint('Error loading user tier: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRooms() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await _client
          .from('room_participants')
          .select('role, room:rooms ( id, name, status, created_at, owner_id )')
          .eq('user_id', userId)
          .order('joined_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetchRooms();
    });
  }

  Future<void> _createRoom() async {
    if (_userTier != 'subscriber') {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Subscription required'),
          content: const Text(
            'Creating rooms is an Onemoviex Plus feature (£4.99/month). '
            'Subscribe to host movie nights for your group.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onGoToPremium?.call();
              },
              child: const Text('See plans'),
            ),
          ],
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final messenger = ScaffoldMessenger.of(context);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create room'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Room name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(nameController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      // Ensure profile row exists
      try {
        await _client
            .from('user_profiles')
            .upsert({'id': userId, 'tier': 'free'}, onConflict: 'id');
      } catch (_) {}

      final insertedRooms = await _client.from('rooms').insert({
        'owner_id': userId,
        'name': name,
      }).select('id').limit(1);

      if (insertedRooms.isEmpty) {
        throw Exception('Room creation failed');
      }
      final roomId = insertedRooms.first['id'] as String;

      await _client.from('room_participants').insert({
        'room_id': roomId,
        'user_id': userId,
        'role': 'owner',
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Room created')),
      );
      if (mounted) await _refresh();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error creating room: $error')),
      );
    }
  }

  Future<void> _joinRoom() async {
    final idController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final roomId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join room'),
        content: TextField(
          controller: idController,
          decoration: const InputDecoration(
            labelText: 'Room ID',
            helperText: 'Paste the room ID you were given',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(idController.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (roomId == null || roomId.isEmpty) return;

    try {
      // Ensure profile row exists (guards against missing trigger / direct SQL users)
      try {
        await _client
            .from('user_profiles')
            .upsert({'id': userId, 'tier': 'free'}, onConflict: 'id');
      } catch (_) {
        // Profile may already exist or RLS may reject insert (safe to ignore —
        // the FK check below will catch if the row truly doesn't exist)
      }

      await _client.from('room_participants').upsert({
        'room_id': roomId,
        'user_id': userId,
        'role': 'participant',
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Successfully joined room!')),
      );
      if (mounted) await _refresh();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error joining room: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Join room',
            onPressed: _joinRoom,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRoom,
        icon: const Icon(Icons.add),
        label: const Text('Create room'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error loading rooms:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'You are not in any rooms yet.\nCreate a room or join one using a room ID.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = items[index];
                final role = row['role'] as String? ?? 'participant';
                final room = row['room'] as Map<String, dynamic>? ?? {};
                final name = room['name'] as String? ?? 'Untitled room';
                final status = room['status'] as String? ?? 'active';
                final id = room['id'] as String? ?? '';

                final isClosed = status == 'closed';
                return ListTile(
                  title: Text(
                    name,
                    style: TextStyle(
                      color: isClosed ? Colors.white38 : Colors.white,
                      decoration: isClosed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        role == 'owner' ? 'You • Host' : 'Member',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isClosed
                              ? Colors.white10
                              : const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isClosed ? 'Closed' : 'Active',
                          style: TextStyle(
                            fontSize: 10,
                            color: isClosed ? Colors.white38 : const Color(0xFF7C4DFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: isClosed
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoomDetailPage(
                                roomId: id,
                                roomName: name,
                                isOwner: role == 'owner',
                              ),
                            ),
                          ).then((_) => _refresh());
                        },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class RoomDetailPage extends StatefulWidget {
  const RoomDetailPage({
    super.key,
    required this.roomId,
    required this.roomName,
    this.isOwner = false,
  });

  final String roomId;
  final String roomName;
  final bool isOwner;

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  late final SupabaseClient _client;
  List<Map<String, dynamic>> _participants = [];
  RealtimeChannel? _participantsChannel;
  RealtimeChannel? _roundsChannel;
  RealtimeChannel? _roomDeletedChannel;
  bool _roundStartedByMe = false;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _loadParticipants();
    _subscribeParticipants();
    _subscribeRoundStart();
    _subscribeRoomDeleted();
  }

  @override
  void dispose() {
    _participantsChannel?.unsubscribe();
    _roundsChannel?.unsubscribe();
    _roomDeletedChannel?.unsubscribe();
    super.dispose();
  }

  // Watches for the room being deleted by the owner.
  // Participants get kicked back to the rooms list with a notification.
  void _subscribeRoomDeleted() {
    if (widget.isOwner) return; // owner is the one deleting — no need to watch
    _roomDeletedChannel = _client
        .channel('room_deleted_${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'rooms',
          callback: (payload) {
            // oldRecord contains the deleted row — check it's our room
            final deletedId = payload.oldRecord['id'] as String?;
            if (deletedId != widget.roomId) return;
            if (!mounted) return;
            // Pop back to rooms list and inform the user
            Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('The host deleted this room.'),
                duration: Duration(seconds: 4),
              ),
            );
          },
        )
        ..subscribe();
  }

  Future<void> _deleteRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete room?'),
        content: const Text(
          'This will permanently delete the room and remove all participants. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      // Delete participants first (FK order), then the room.
      // Supabase may cascade this automatically — deleting room last ensures
      // real-time DELETE event fires on the rooms table for participants.
      await _client
          .from('room_participants')
          .delete()
          .eq('room_id', widget.roomId);
      await _client.from('rooms').delete().eq('id', widget.roomId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting room: $e')),
        );
      }
    }
  }

  Future<void> _leaveRoom() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave room?'),
        content: const Text('You will be removed from this room.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _client
          .from('room_participants')
          .delete()
          .eq('room_id', widget.roomId)
          .eq('user_id', userId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving room: $e')),
        );
      }
    }
  }

  Future<void> _loadParticipants() async {
    try {
      final data = await _client
          .from('room_participants')
          .select('user_id, role')
          .eq('room_id', widget.roomId);
      if (mounted) setState(() => _participants = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  void _subscribeParticipants() {
    _participantsChannel = _client
        .channel('participants_${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'room_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (_) => _loadParticipants(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'room_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (_) => _loadParticipants(),
        )
        ..subscribe();
  }

  void _subscribeRoundStart() {
    _roundsChannel = _client
        .channel('rounds_insert_${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rounds',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (payload) async {
            if (_roundStartedByMe) {
              _roundStartedByMe = false;
              return;
            }
            final newRoundId = payload.newRecord['id'] as String?;
            final roundNumber = payload.newRecord['round_number'] as int? ?? 1;
            if (newRoundId == null || !mounted) return;

            // Wait briefly for round_movies to be populated
            await Future.delayed(const Duration(milliseconds: 1500));
            if (!mounted) return;

            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF101216),
                title: const Row(
                  children: [
                    Icon(Icons.play_circle_rounded, color: Color(0xFF7C4DFF)),
                    SizedBox(width: 8),
                    Text('Round started!'),
                  ],
                ),
                content: Text('Round $roundNumber has begun. Join the swiping now!'),
                actions: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SwipingPage(
                            roomId: widget.roomId,
                            roundId: newRoundId,
                            roundNumber: roundNumber,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.swipe_rounded),
                    label: const Text('Start swiping!'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                    ),
                  ),
                ],
              ),
            );
          },
        )
        ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        actions: [
          if (widget.isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete room',
              color: Colors.redAccent,
              onPressed: _deleteRoom,
            )
          else
            TextButton.icon(
              onPressed: _leaveRoom,
              icon: const Icon(Icons.exit_to_app_rounded, size: 18),
              label: const Text('Leave'),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invite card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.link_rounded, size: 16, color: Color(0xFF7C4DFF)),
                          SizedBox(width: 6),
                          Text(
                            'Invite friends',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF7C4DFF),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.roomId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Room ID copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text('Copy ID'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      widget.roomId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share this ID with friends. They go to Rooms → Join room → paste this ID.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Live participants bar
            _ParticipantsBar(participants: _participants),
            const SizedBox(height: 16),
            _WinnerRealtimeBanner(roomId: widget.roomId),
            const SizedBox(height: 16),
            Text(
              'Rounds & swiping',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a round so everyone in the room can swipe. A winner is found when all participants like the same movie.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _roundStartedByMe = true);
                try {
                  final rounds = await client
                      .from('rounds')
                      .select('round_number')
                      .eq('room_id', widget.roomId)
                      .order('round_number', ascending: false)
                      .limit(1);

                  final nextRoundNumber =
                      rounds.isEmpty ? 1 : ((rounds.first['round_number'] as int?) ?? 0) + 1;

                  final insertedRounds = await client
                      .from('rounds')
                      .insert({
                        'room_id': widget.roomId,
                        'round_number': nextRoundNumber,
                      })
                      .select('id, round_number')
                      .limit(1);

                  if (insertedRounds.isEmpty) throw Exception('Failed to create round');

                  final roundId = insertedRounds.first['id'] as String;

                  final movies = await client
                      .from('movies')
                      .select('id')
                      .order('title')
                      .limit(50);

                  var position = 0;
                  for (final movie in movies) {
                    final movieId = movie['id'] as String;
                    await client.from('round_movies').insert({
                      'round_id': roundId,
                      'movie_id': movieId,
                      'position': position,
                      'source_type': 'normal',
                    });
                    position += 1;
                    if (position >= 20) break;
                  }

                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SwipingPage(
                        roomId: widget.roomId,
                        roundId: roundId,
                        roundNumber: nextRoundNumber,
                      ),
                    ),
                  );
                } catch (error) {
                  if (mounted) setState(() => _roundStartedByMe = false);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error starting round: $error')),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start swiping round'),
            ),
            const SizedBox(height: 24),
            _WinnerSection(roomId: widget.roomId),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Participants live bar ───────────────────────────────────────────────────

class _ParticipantsBar extends StatelessWidget {
  const _ParticipantsBar({required this.participants});
  final List<Map<String, dynamic>> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.people_rounded, size: 15, color: Colors.white54),
        const SizedBox(width: 6),
        Text(
          '${participants.length} ${participants.length == 1 ? 'person' : 'people'} in this room',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 8),
        ...participants.take(5).map((p) {
          final isOwner = p['role'] == 'owner';
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: CircleAvatar(
              radius: 10,
              backgroundColor: isOwner
                  ? const Color(0xFF7C4DFF).withValues(alpha: 0.3)
                  : Colors.white12,
              child: Icon(
                isOwner ? Icons.star_rounded : Icons.person,
                size: 11,
                color: isOwner ? const Color(0xFF7C4DFF) : Colors.white54,
              ),
            ),
          );
        }),
        if (participants.length > 5)
          Text(
            '+${participants.length - 5}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
      ],
    );
  }
}

// ─── Winner realtime banner ──────────────────────────────────────────────────

class _WinnerRealtimeBanner extends StatefulWidget {
  const _WinnerRealtimeBanner({required this.roomId});

  final String roomId;

  @override
  State<_WinnerRealtimeBanner> createState() => _WinnerRealtimeBannerState();
}

class _WinnerRealtimeBannerState extends State<_WinnerRealtimeBanner> {
  late final SupabaseClient _client;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;

    _channel = _client.channel('room_winner_${widget.roomId}').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'rounds',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: widget.roomId,
      ),
      callback: (payload) async {
        final newWinnerId = payload.newRecord['winner_movie_id'] as String?;
        if (newWinnerId == null || !mounted) return;

        final rows = await _client
            .from('movies')
            .select('title')
            .eq('id', newWinnerId)
            .limit(1);
        final title =
            rows.isNotEmpty ? rows.first['title'] as String? ?? 'Unknown movie' : 'Unknown movie';

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("It's a match! The winner is: $title"),
          ),
        );
      },
    )..subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _WinnerSection extends StatefulWidget {
  const _WinnerSection({required this.roomId});

  final String roomId;

  @override
  State<_WinnerSection> createState() => _WinnerSectionState();
}

class _WinnerSectionState extends State<_WinnerSection> {
  late final SupabaseClient _client;
  Future<Map<String, dynamic>?>? _future;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _future = _loadWinner();
    _subscribeWinnerUpdates();
  }

  void _subscribeWinnerUpdates() {
    _channel = _client
        .channel('winner_section_${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rounds',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (payload) {
            final winnerId = payload.newRecord['winner_movie_id'];
            if (winnerId != null && mounted) {
              setState(() => _future = _loadWinner());
            }
          },
        )
        ..subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadWinner() async {
    // Latest completed round with a winner for this room.
    final rounds = await _client
        .from('rounds')
        .select('id, round_number, winner_movie_id, winner_determined_at')
        .eq('room_id', widget.roomId)
        .not('winner_movie_id', 'is', null)
        .order('winner_determined_at', ascending: false)
        .limit(1);

    if (rounds.isEmpty) return null;

    final round = rounds.first;
    final movieId = round['winner_movie_id'] as String?;
    if (movieId == null) return null;

    final movies = await _client
        .from('movies')
        .select('id, title, source, netflix_id')
        .eq('id', movieId)
        .limit(1);

    if (movies.isEmpty) return null;

        final movie = movies.first;
    return {
      'round': round,
      'movie': movie,
    };
  }

  Future<void> _openCinema(String title) async {
    final query =
        Uri.encodeComponent('$title cinema near me'); // simple search-based URL
    final uri = Uri.parse('https://www.google.com/search?q=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openNetflix(Map<String, dynamic> movie) async {
    final netflixId = movie['netflix_id'] as String?;
    final title = movie['title'] as String? ?? '';

    Uri? uri;

    if (netflixId != null && netflixId.isNotEmpty) {
      // Attempt deep link using the Netflix schema.
      uri = Uri.parse('nflx://www.netflix.com/title/$netflixId');
    } else if (title.isNotEmpty) {
      // Fallback: open Netflix search in browser.
      final query = Uri.encodeComponent(title);
      uri = Uri.parse('https://www.netflix.com/search?q=$query');
    }

    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Error loading winner: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const Text(
            'No winner has been determined yet for this room.',
          );
        }

        final round = data['round'] as Map<String, dynamic>;
        final movie = data['movie'] as Map<String, dynamic>;
        final title = movie['title'] as String? ?? 'Untitled';
        final source = movie['source'] as String? ?? '?';
        final roundNumber = round['round_number'] as int? ?? 0;

        final isCinema = source == 'cinema' || source == 'CINEMA';
        final isNetflix = source == 'netflix' || source == 'NETFLIX';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Winner (latest completed round)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Source: ${source.toUpperCase()} • Round $roundNumber',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (isCinema)
                  FilledButton.icon(
                    onPressed: () => _openCinema(title),
                    icon: const Icon(Icons.local_movies),
                    label: const Text('Book cinema ticket'),
                  ),
                if (isNetflix)
                  OutlinedButton.icon(
                    onPressed: () => _openNetflix(movie),
                    icon: const Icon(Icons.play_circle_fill),
                    label: const Text('Open Netflix'),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    // Show simple runner-up list based on likes in this round.
                    final roundId = round['id'] as String?;
                    if (roundId == null) return;

                    try {
                      final swipeRows = await _client
                          .from('swipes')
                          .select('movie_id, value')
                          .eq('round_id', roundId);

                      if (swipeRows.isEmpty) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No swipes found to compute runner-ups.'),
                            ),
                          );
                        }
                        return;
                      }

                      final Map<String, int> likeCounts = {};
                      for (final row in swipeRows) {
                        final movieId = row['movie_id'] as String;
                        final value = row['value'] as int;
                        if (value == 1) {
                          likeCounts[movieId] = (likeCounts[movieId] ?? 0) + 1;
                        }
                      }

                      // Exclude the winner from runner-ups.
                      likeCounts.remove(movie['id'] as String?);

                      if (likeCounts.isEmpty) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('No runner-up likes found for this round.'),
                            ),
                          );
                        }
                        return;
                      }

                      // Sort movies by like count descending.
                      final sorted = likeCounts.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      // Take top 5 runner-ups.
                      final topRunnerUps = sorted.take(5).toList();
                      final ids = topRunnerUps.map((e) => e.key).toList();

                      final runnerMovies = await _client
                          .from('movies')
                          .select('id, title')
                          .filter('id', 'in', ids);

                      if (!context.mounted) return;

                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Runner-up movies'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'These movies had the next highest number of likes in this round:',
                              ),
                              const SizedBox(height: 8),
                              for (final rm in runnerMovies)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Text('• ${rm['title'] ?? 'Untitled'}'),
                                ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error loading runner-ups: $error',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.leaderboard),
                  label: const Text('Runner-ups'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class SwipingPage extends StatefulWidget {
  const SwipingPage({
    super.key,
    required this.roomId,
    required this.roundId,
    required this.roundNumber,
  });

  final String roomId;
  final String roundId;
  final int roundNumber;

  @override
  State<SwipingPage> createState() => _SwipingPageState();
}

class _SwipingPageState extends State<SwipingPage> {
  late final SupabaseClient _client;
  List<Map<String, dynamic>> _movies = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isCheckingResult = false;
  String? _resultMessage;
  RealtimeChannel? _winnerChannel;
  bool _navigatedToMatch = false;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _loadMovies();
    _subscribeWinner();
  }

  void _subscribeWinner() {
    _winnerChannel = _client
        .channel('round_winner_swipe_${widget.roundId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rounds',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.roundId,
          ),
          callback: (payload) {
            final winnerId = payload.newRecord['winner_movie_id'] as String?;
            if (winnerId != null && mounted && !_navigatedToMatch) {
              _navigatedToMatch = true;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => MatchPage(
                    roomId: widget.roomId,
                    roundId: widget.roundId,
                    movieId: winnerId,
                  ),
                ),
              );
            }
          },
        )
        ..subscribe();
  }

  Future<void> _loadMovies() async {
    try {
      final data = await _client
          .from('round_movies')
          .select('movie:movies ( id, title, overview, source, poster_url, is_netflix, is_cinema )')
          .eq('round_id', widget.roundId)
          .order('position');

      if (mounted) {
        setState(() {
          _movies = List<Map<String, dynamic>>.from(data);
          _currentIndex = 0;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading movies for round: $error')),
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _winnerChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _checkResult() async {
    // Guard against double-navigation on match already found.
    if (_navigatedToMatch) return;
    setState(() {
      _isCheckingResult = true;
      _resultMessage = null;
    });

    try {
      // 1. Load round info (to get started_at for countdown and any existing winner).
      final roundRows = await _client
          .from('rounds')
          .select('id, started_at, winner_movie_id')
          .eq('id', widget.roundId)
          .limit(1);

      if (roundRows.isEmpty) {
        throw Exception('Round not found');
      }

      final round = roundRows.first;
      final winnerMovieId = round['winner_movie_id'] as String?;
      final startedAtStr = round['started_at'] as String?;

      DateTime? startedAt;
      if (startedAtStr != null) {
        startedAt = DateTime.tryParse(startedAtStr);
      }

      // If a winner is already stored, just show it (and navigate to match screen).
      if (winnerMovieId != null) {
        final movieRows = await _client
            .from('movies')
            .select('title')
            .eq('id', winnerMovieId)
            .limit(1);
        final title =
            movieRows.isNotEmpty ? movieRows.first['title'] as String? : null;

        if (mounted) {
          setState(() {
            _resultMessage =
                'Winner (already decided): ${title ?? 'Unknown movie'}';
          });
        }
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MatchPage(
                roomId: widget.roomId,
                roundId: widget.roundId,
                movieId: winnerMovieId,
              ),
            ),
          );
        }
        return;
      }

      // 2. Load participants count for this room.
      final participantsRows = await _client
          .from('room_participants')
          .select('user_id')
          .eq('room_id', widget.roomId);
      final participantIds =
          participantsRows.map<String>((row) => row['user_id'] as String).toSet();
      final participantCount = participantIds.length;

      if (participantCount == 0) {
        throw Exception('No participants in room');
      }

      // 3. Load all swipes for this round.
      final swipeRows = await _client
          .from('swipes')
          .select('movie_id, user_id, value')
          .eq('round_id', widget.roundId);

      if (swipeRows.isEmpty) {
        if (mounted) {
          setState(() {
            _resultMessage =
                'No swipes recorded yet. Everyone needs to swipe before a result can be computed.';
          });
        }
        return;
      }

      // Aggregate likes per movie.
      final Map<String, int> likesPerMovie = {};
      final Map<String, Set<String>> likersPerMovie = {};

      for (final row in swipeRows) {
        final movieId = row['movie_id'] as String;
        final userId = row['user_id'] as String;
        final value = row['value'] as int;

        if (value == 1) {
          likesPerMovie[movieId] = (likesPerMovie[movieId] ?? 0) + 1;
          likersPerMovie.putIfAbsent(movieId, () => <String>{}).add(userId);
        }
      }

      if (likesPerMovie.isEmpty) {
        if (mounted) {
          setState(() {
            _resultMessage =
                'No likes recorded in this round. No winner can be chosen.';
          });
        }
        return;
      }

      // 4. Find unanimous likes — all participants liked the same movie.
      final List<String> unanimousMovies = [];
      likesPerMovie.forEach((movieId, likes) {
        final likers = likersPerMovie[movieId] ?? {};
        if (likes == participantCount &&
            likers.length == participantCount) {
          unanimousMovies.add(movieId);
        }
      });

      String chosenMovieId;
      String explanation;

      if (unanimousMovies.length == 1) {
        // Clear winner — every participant liked this movie.
        chosenMovieId = unanimousMovies.first;
        explanation = 'Winner by unanimous like from all participants.';
      } else {
        // 5. No unanimous winner yet.
        // Before picking ANY fallback winner, every participant must have
        // finished swiping all movies in this round.
        final roundMovieRows = await _client
            .from('round_movies')
            .select('movie_id')
            .eq('round_id', widget.roundId);
        final totalMoviesInRound = roundMovieRows.length;

        for (final participantId in participantIds) {
          final swipesDone = swipeRows
              .where((s) => s['user_id'] == participantId)
              .length;
          if (swipesDone < totalMoviesInRound) {
            // At least one participant hasn't finished — don't pick a winner.
            if (mounted) {
              setState(() {
                _resultMessage =
                    'Waiting for all participants to finish swiping. '
                    'A winner will be chosen once everyone has voted on all movies.';
              });
            }
            return;
          }
        }

        // All participants are done. Find the most-liked movie(s).
        int maxLikes = 0;
        for (final likes in likesPerMovie.values) {
          if (likes > maxLikes) maxLikes = likes;
        }
        final List<String> topMovies = likesPerMovie.entries
            .where((e) => e.value == maxLikes)
            .map((e) => e.key)
            .toList();

        if (topMovies.isEmpty) {
          if (mounted) {
            setState(() {
              _resultMessage =
                  'Nobody liked any movie in this round. No winner.';
            });
          }
          return;
        }

        // 6. Countdown logic for tie-breaking:
        // If multiple top movies are tied, wait 1 hour from round start
        // before randomly picking one.
        if (topMovies.length > 1 && startedAt != null) {
          final now = DateTime.now().toUtc();
          final deadline = startedAt.toUtc().add(const Duration(hours: 1));

          if (now.isBefore(deadline)) {
            final remaining = deadline.difference(now);
            final minutesLeft = remaining.inMinutes + 1;
            if (mounted) {
              setState(() {
                _resultMessage =
                    'There is currently a tie between ${topMovies.length} movies.\n'
                    'A random winner will be selected automatically after the countdown expires.\n'
                    'Time remaining (approx): $minutesLeft minute(s).';
              });
            }
            return;
          }
        }

        // Either no tie, or countdown has expired: pick randomly among top movies.
        topMovies.shuffle();
        chosenMovieId = topMovies.first;
        explanation =
            'Winner selected from the most-liked movies after all participants finished swiping.';
      }

      // 7. Persist winner in the round.
      await _client.from('rounds').update({
        'winner_movie_id': chosenMovieId,
        'winner_determined_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'completed',
      }).eq('id', widget.roundId);

      // 8. Load winner title for display.
      final movieRows = await _client
          .from('movies')
          .select('title')
          .eq('id', chosenMovieId)
          .limit(1);
      final title =
          movieRows.isNotEmpty ? movieRows.first['title'] as String? : null;

      if (mounted) {
        setState(() {
          _resultMessage =
              'Winner: ${title ?? 'Unknown movie'}\n\n$explanation\n\n'
              'Room members will see this winner when they open the room.';
        });
      }
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MatchPage(
              roomId: widget.roomId,
              roundId: widget.roundId,
              movieId: chosenMovieId,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _resultMessage = 'Error computing result: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingResult = false;
        });
      }
    }
  }

  Future<void> _swipe(int value) async {
    if (_currentIndex >= _movies.length) return;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final movie = _movies[_currentIndex]['movie'] as Map<String, dynamic>;
    final movieId = movie['id'] as String;

    await _client.from('swipes').upsert({
      'room_id': widget.roomId,
      'round_id': widget.roundId,
      'user_id': userId,
      'movie_id': movieId,
      'value': value,
    });

    if (mounted) {
      setState(() {
        _currentIndex += 1;
      });
    }

    // After a like, immediately attempt match detection in the background.
    if (value == 1) {
      _checkResult();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _movies.length;
    final remaining = total - _currentIndex;

    return Scaffold(
      backgroundColor: const Color(0xFF050608),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Round ${widget.roundNumber}'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF7C4DFF),
              Color(0xFF050608),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : remaining <= 0
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'You have swiped all movies in this round.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed:
                                _isCheckingResult ? null : () => _checkResult(),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: _isCheckingResult
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Check round result'),
                          ),
                          if (_resultMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _resultMessage!,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    )
                  : _buildCurrentCard(context),
        ),
      ),
    );
  }

  Widget _buildCurrentCard(BuildContext context) {
    final movie = _movies[_currentIndex]['movie'] as Map<String, dynamic>;
    final title = movie['title'] as String? ?? 'Untitled';
    final overview = movie['overview'] as String? ?? 'No description.';
    final source = movie['source'] as String? ?? '?';
    final posterUrl = movie['poster_url'] as String?;
    final isNetflix = movie['is_netflix'] as bool? ?? false;
    final isCinema = movie['is_cinema'] as bool? ?? false;
    final total = _movies.length;
    final indexLabel = '${_currentIndex + 1} / $total';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_movies.length - _currentIndex > 1)
                    Transform.translate(
                      offset: const Offset(0, 18),
                      child: Opacity(
                        opacity: 0.4,
                        child: _MovieCard(
                          title: title,
                          overview: overview,
                          source: source,
                          indexLabel: indexLabel,
                          posterUrl: posterUrl,
                          isNetflix: isNetflix,
                          isCinema: isCinema,
                          isBackground: true,
                        ),
                      ),
                    ),
                  _MovieCard(
                    title: title,
                    overview: overview,
                    source: source,
                    indexLabel: indexLabel,
                    posterUrl: posterUrl,
                    isNetflix: isNetflix,
                    isCinema: isCinema,
                    isBackground: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                onPressed: () => _swipe(-1),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(18),
                ),
                icon: const Icon(Icons.close, color: Colors.redAccent),
                tooltip: 'Dislike',
              ),
              IconButton.filled(
                onPressed: () => _swipe(1),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(18),
                ),
                icon: const Icon(Icons.favorite, color: Colors.white),
                tooltip: 'Like',
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  const _MovieCard({
    required this.title,
    required this.overview,
    required this.source,
    required this.indexLabel,
    required this.isBackground,
    this.posterUrl,
    this.isNetflix = false,
    this.isCinema = false,
  });

  final String title;
  final String overview;
  final String source;
  final String indexLabel;
  final bool isBackground;
  final String? posterUrl;
  final bool isNetflix;
  final bool isCinema;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: isBackground ? 0.94 : 1.0,
      child: Card(
        color: const Color(0xFF101216).withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: isBackground ? 4 : 10,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 520),
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poster
              if (posterUrl != null)
                Image.network(
                  posterUrl!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isNetflix
                            ? const Color(0xFFE50914).withValues(alpha: 0.15)
                            : isCinema
                                ? const Color(0xFFFFC72C).withValues(alpha: 0.15)
                                : Colors.white12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isNetflix
                                ? Icons.play_circle_fill
                                : isCinema
                                    ? Icons.local_movies
                                    : Icons.movie,
                            size: 12,
                            color: isNetflix
                                ? const Color(0xFFE50914)
                                : isCinema
                                    ? const Color(0xFFFFC72C)
                                    : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isNetflix ? 'NETFLIX' : isCinema ? 'CINEMA' : source.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: isNetflix
                                  ? const Color(0xFFE50914)
                                  : isCinema
                                      ? const Color(0xFFFFC72C)
                                      : Colors.white70,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      overview,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        indexLabel,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

      ),
    );
  }
}



