import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk/dashboard/a_admin/database/db_grup_sekolah.dart';
import 'package:apk/dashboard/a_admin/function/f_pesan/grup_sekolah.dart';

class GrupSekolahP extends StatefulWidget {
  const GrupSekolahP({super.key});

  @override
  State<GrupSekolahP> createState() => _GrupSekolahPState();
}

class _GrupSekolahPState extends State<GrupSekolahP> {
  late Future<DateTime?> _lastVisitedFuture;

  @override
  void initState() {
    super.initState();
    _lastVisitedFuture = _loadLastVisited();
  }

  Future<DateTime?> _loadLastVisited() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisitedStr = prefs.getString('last_visited_grup_sekolah');
    if (lastVisitedStr != null) {
      return DateTime.tryParse(lastVisitedStr);
    }
    return null;
  }

  Future<void> _markAsReadAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final nowStr = DateTime.now().toIso8601String();
    await prefs.setString('last_visited_grup_sekolah', nowStr);
    if (!mounted) return;
    // Update the future so the UI reacts
    setState(() {
      _lastVisitedFuture = Future.value(DateTime.tryParse(nowStr));
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GrupSekolah()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Harap login terlebih dahulu.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<DateTime?>(
        future: _lastVisitedFuture,
        builder: (context, prefSnapshot) {
          // Tampilkan loading saat SharedPreferences belum siap
          if (prefSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final lastVisited = prefSnapshot.data;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: DbGrupSekolah().getGrupSekolahStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              int unreadCount = 0;
              String? latestMessagePreview;
              String? latestMessageTime;

              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;

              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                for (final msg in snapshot.data!) {
                  final createdAtStr = msg['created_at']?.toString();
                  final senderId = msg['pengirim_admin']?.toString() ??
                      msg['pengirim_guru']?.toString() ??
                      msg['pengirim_murid']?.toString();

                  // Hanya hitung pesan dari orang lain
                  if (createdAtStr != null && senderId != currentUserId) {
                    final createdAt = DateTime.tryParse(createdAtStr);
                    if (createdAt != null) {
                      if (lastVisited == null ||
                          createdAt.isAfter(lastVisited)) {
                        unreadCount++;
                        latestMessagePreview = msg['text']?.toString();
                        latestMessageTime = createdAtStr;
                      }
                    }
                  }
                }
              }

              if (unreadCount == 0) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada notifikasi baru',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Format waktu pesan terakhir
              String timeLabel = '';
              if (latestMessageTime != null) {
                final dt = DateTime.tryParse(latestMessageTime)?.toLocal();
                if (dt != null) {
                  final now = DateTime.now();
                  final diff = now.difference(dt);
                  if (diff.inMinutes < 1) {
                    timeLabel = 'Baru saja';
                  } else if (diff.inHours < 1) {
                    timeLabel = '${diff.inMinutes} menit lalu';
                  } else if (diff.inDays < 1) {
                    timeLabel = '${diff.inHours} jam lalu';
                  } else {
                    timeLabel = '${diff.inDays} hari lalu';
                  }
                }
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Pesan Masuk',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        fontFamily: 'Inter',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _markAsReadAndNavigate,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: Color(0xFF2563EB),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Text content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Grup Sekolah',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF1E293B),
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      Text(
                                        timeLabel,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$unreadCount pesan baru',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFDC2626),
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                  if (latestMessagePreview != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      latestMessagePreview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFCBD5E1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
