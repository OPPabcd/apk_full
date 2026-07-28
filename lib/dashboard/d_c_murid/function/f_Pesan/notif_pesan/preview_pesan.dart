import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apk/dashboard/d_c_murid/database/db_grup_sekolah.dart';
import 'package:apk/dashboard/d_c_murid/database/db_grup_kelas.dart';
import 'package:apk/dashboard/d_c_murid/database/db_pesan_private.dart';

// Ortu/Murid navigation targets
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/grup_sekolah.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/grup_kelas.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/chat_admin.dart';
import 'package:apk/dashboard/d_c_murid/function/f_Pesan/dash_pesan.dart';
import 'package:apk/dashboard/d_c_murid/function/p_pengumuman.dart/preview_p.dart';

class PreviewPesan extends StatefulWidget {
  const PreviewPesan({super.key});

  @override
  State<PreviewPesan> createState() => _PreviewPesanState();
}

class _PreviewPesanState extends State<PreviewPesan> {
  String? _currentUserId;
  String? _currentUserRole;
  String? _currentClassId;
  String? _idAdmin;
  bool _isLoading = true;

  final Map<String, int> _counts = {
    'sekolah': 0,
    'kelas': 0,
    'admin': 0,
    'guru': 0,
    'pengumuman': 0,
  };

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _idAdmin = prefs.getString('user_id_admin');

      final info = await DbGrupKelas.getCurrentUserRoleAndId();
      if (info != null) {
        _currentUserId = info['id'];
        _currentUserRole = info['role'];
        _currentClassId = info['id_class'];
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateCount(String key, int count) {
    if (_counts[key] != count) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _counts[key] = count;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUserId == null || _currentUserRole == null) {
      return const Scaffold(
        body: Center(child: Text('Harap login terlebih dahulu.')),
      );
    }

    final totalUnread = _counts.values.fold<int>(0, (sum, val) => sum + val);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Image.asset('lib/assets/icons/Button.png', width: 30, height: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: -5,
        title: const Text("Notifikasi"),
        titleTextStyle: const TextStyle(
          fontFamily: "Inter",
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      body: totalUnread == 0
          ? Center(
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
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Pesan & Informasi Masuk',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      fontFamily: 'Inter',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // ──── KATEGORI NOTIFIKASI ORTU/MURID ────
                // 1. Grup Sekolah
                GrupSekolahNotificationCard(
                  currentUserId: _currentUserId!,
                  currentUserRole: _currentUserRole!,
                  onCountChanged: (count) => _updateCount('sekolah', count),
                ),
                // 2. Grup Kelas
                if (_currentClassId != null && _currentClassId!.isNotEmpty)
                  GrupKelasNotificationCard(
                    idClass: _currentClassId!,
                    currentUserId: _currentUserId!,
                    currentUserRole: _currentUserRole!,
                    onCountChanged: (count) => _updateCount('kelas', count),
                  ),
                // 3. Admin Sekolah
                if (_idAdmin != null)
                  AdminSekolahNotificationCard(
                    idMurid: _currentUserId!,
                    idAdmin: _idAdmin!,
                    onCountChanged: (count) => _updateCount('admin', count),
                  ),
                // 4. Pesan ke Guru
                PesanGuruNotificationCard(
                  idMurid: _currentUserId!,
                  onCountChanged: (count) => _updateCount('guru', count),
                ),
                // 5. Pengumuman (Hanya untuk Ortu/Murid)
                PengumumanNotificationCard(
                  onCountChanged: (count) => _updateCount('pengumuman', count),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER CARD: ORTU/MURID VERSION
// ─────────────────────────────────────────────────────────────────────────────

class GrupSekolahNotificationCard extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;
  final ValueChanged<int> onCountChanged;

  const GrupSekolahNotificationCard({
    super.key,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onCountChanged,
  });

  @override
  State<GrupSekolahNotificationCard> createState() =>
      _GrupSekolahNotificationCardState();
}

class _GrupSekolahNotificationCardState
    extends State<GrupSekolahNotificationCard> {
  DateTime? _lastVisited;

  @override
  void initState() {
    super.initState();
    _loadLastVisited();
  }

  Future<void> _loadLastVisited() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisitedStr = prefs.getString('last_visited_grup_sekolah');
    if (mounted) {
      setState(() {
        _lastVisited =
            lastVisitedStr != null ? DateTime.tryParse(lastVisitedStr) : null;
      });
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    final dt = DateTime.tryParse(timeStr)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DbGrupSekolah().getGrupSekolahStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          widget.onCountChanged(0);
          return const SizedBox.shrink();
        }

        int unreadCount = 0;
        String? latestMessagePreview;
        String? latestMessageTime;

        for (final msg in snapshot.data!) {
          final createdAtStr = msg['created_at']?.toString();
          bool isMe = false;
          if (widget.currentUserRole == 'admin') {
            isMe = msg['pengirim_admin']?.toString() == widget.currentUserId;
          } else if (widget.currentUserRole == 'guru') {
            isMe = msg['pengirim_guru']?.toString() == widget.currentUserId;
          } else if (widget.currentUserRole == 'murid') {
            isMe = msg['pengirim_murid']?.toString() == widget.currentUserId;
          }

          if (createdAtStr != null && !isMe) {
            final createdAt = DateTime.tryParse(createdAtStr);
            if (createdAt != null) {
              if (_lastVisited == null || createdAt.isAfter(_lastVisited!)) {
                unreadCount++;
                latestMessagePreview = msg['text']?.toString();
                latestMessageTime = createdAtStr;
              }
            }
          }
        }

        widget.onCountChanged(unreadCount);

        if (unreadCount == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                  'last_visited_grup_sekolah', DateTime.now().toIso8601String());
              widget.onCountChanged(0);
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const GrupSekolah()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              _formatTime(latestMessageTime),
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
        );
      },
    );
  }
}

class GrupKelasNotificationCard extends StatefulWidget {
  final String idClass;
  final String currentUserId;
  final String currentUserRole;
  final ValueChanged<int> onCountChanged;

  const GrupKelasNotificationCard({
    super.key,
    required this.idClass,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onCountChanged,
  });

  @override
  State<GrupKelasNotificationCard> createState() =>
      _GrupKelasNotificationCardState();
}

class _GrupKelasNotificationCardState extends State<GrupKelasNotificationCard> {
  DateTime? _lastVisited;

  @override
  void initState() {
    super.initState();
    _loadLastVisited();
  }

  Future<void> _loadLastVisited() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisitedStr = prefs.getString('last_visited_grup_kelas');
    if (mounted) {
      setState(() {
        _lastVisited =
            lastVisitedStr != null ? DateTime.tryParse(lastVisitedStr) : null;
      });
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    final dt = DateTime.tryParse(timeStr)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DbGrupKelas().getGrupKelasStream(widget.idClass),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          widget.onCountChanged(0);
          return const SizedBox.shrink();
        }

        int unreadCount = 0;
        String? latestMessagePreview;
        String? latestMessageTime;

        for (final msg in snapshot.data!) {
          final createdAtStr = msg['created_at']?.toString();
          bool isMe = false;
          if (widget.currentUserRole == 'admin') {
            isMe = msg['pengirim_admin']?.toString() == widget.currentUserId;
          } else if (widget.currentUserRole == 'guru') {
            isMe = msg['pengirim_guru']?.toString() == widget.currentUserId;
          } else if (widget.currentUserRole == 'murid') {
            isMe = msg['pengirim_murid']?.toString() == widget.currentUserId;
          }

          if (createdAtStr != null && !isMe) {
            final createdAt = DateTime.tryParse(createdAtStr);
            if (createdAt != null) {
              if (_lastVisited == null || createdAt.isAfter(_lastVisited!)) {
                unreadCount++;
                latestMessagePreview = msg['text']?.toString();
                latestMessageTime = createdAtStr;
              }
            }
          }
        }

        widget.onCountChanged(unreadCount);

        if (unreadCount == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                  'last_visited_grup_kelas', DateTime.now().toIso8601String());
              widget.onCountChanged(0);
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const GrupKelasPage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      color: Color(0xFF2563EB),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Grup Kelas',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              _formatTime(latestMessageTime),
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
        );
      },
    );
  }
}

class AdminSekolahNotificationCard extends StatefulWidget {
  final String idMurid;
  final String idAdmin;
  final ValueChanged<int> onCountChanged;

  const AdminSekolahNotificationCard({
    super.key,
    required this.idMurid,
    required this.idAdmin,
    required this.onCountChanged,
  });

  @override
  State<AdminSekolahNotificationCard> createState() =>
      _AdminSekolahNotificationCardState();
}

class _AdminSekolahNotificationCardState
    extends State<AdminSekolahNotificationCard> {
  DateTime? _lastVisited;

  @override
  void initState() {
    super.initState();
    _loadLastVisited();
  }

  Future<void> _loadLastVisited() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisitedStr = prefs.getString('last_visited_chat_admin');
    if (mounted) {
      setState(() {
        _lastVisited =
            lastVisitedStr != null ? DateTime.tryParse(lastVisitedStr) : null;
      });
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    final dt = DateTime.tryParse(timeStr)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DbPesanPrivate().getChatWithAdminStream(widget.idMurid, widget.idAdmin),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          widget.onCountChanged(0);
          return const SizedBox.shrink();
        }

        int unreadCount = 0;
        String? latestMessagePreview;
        String? latestMessageTime;

        for (final msg in snapshot.data!) {
          final createdAtStr = msg['created_at']?.toString();
          bool isFromAdmin = msg['pengirim_admin'] == widget.idAdmin;

          if (createdAtStr != null && isFromAdmin) {
            final createdAt = DateTime.tryParse(createdAtStr);
            if (createdAt != null) {
              if (_lastVisited == null || createdAt.isAfter(_lastVisited!)) {
                unreadCount++;
                latestMessagePreview = msg['text']?.toString();
                latestMessageTime = createdAtStr;
              }
            }
          }
        }

        widget.onCountChanged(unreadCount);

        if (unreadCount == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                  'last_visited_chat_admin', DateTime.now().toIso8601String());
              widget.onCountChanged(0);
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ChatAdminPage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Color(0xFF2563EB),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Admin Sekolah',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              _formatTime(latestMessageTime),
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
        );
      },
    );
  }
}

class PesanGuruNotificationCard extends StatefulWidget {
  final String idMurid;
  final ValueChanged<int> onCountChanged;

  const PesanGuruNotificationCard({
    super.key,
    required this.idMurid,
    required this.onCountChanged,
  });

  @override
  State<PesanGuruNotificationCard> createState() =>
      _PesanGuruNotificationCardState();
}

class _PesanGuruNotificationCardState extends State<PesanGuruNotificationCard> {
  DateTime? _lastVisited;

  @override
  void initState() {
    super.initState();
    _loadLastVisited();
  }

  Future<void> _loadLastVisited() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisitedStr = prefs.getString('last_visited_chat_private');
    if (mounted) {
      setState(() {
        _lastVisited =
            lastVisitedStr != null ? DateTime.tryParse(lastVisitedStr) : null;
      });
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    final dt = DateTime.tryParse(timeStr)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('chat_private')
          .stream(primaryKey: ['id_tabel'])
          .order('created_at', ascending: true)
          .map((data) => data
              .where((e) =>
                  e['penerima_murid']?.toString() == widget.idMurid &&
                  e['pengirim_guru'] != null)
              .toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          widget.onCountChanged(0);
          return const SizedBox.shrink();
        }

        int unreadCount = 0;
        String? latestMessagePreview;
        String? latestMessageTime;

        for (final msg in snapshot.data!) {
          final createdAtStr = msg['created_at']?.toString();

          if (createdAtStr != null) {
            final createdAt = DateTime.tryParse(createdAtStr);
            if (createdAt != null) {
              if (_lastVisited == null || createdAt.isAfter(_lastVisited!)) {
                unreadCount++;
                latestMessagePreview = msg['text']?.toString();
                latestMessageTime = createdAtStr;
              }
            }
          }
        }

        widget.onCountChanged(unreadCount);

        if (unreadCount == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                  'last_visited_chat_private', DateTime.now().toIso8601String());
              widget.onCountChanged(0);
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashPesan()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Color(0xFF2563EB),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pesan dari Guru',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              _formatTime(latestMessageTime),
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
        );
      },
    );
  }
}

class PengumumanNotificationCard extends StatefulWidget {
  final ValueChanged<int> onCountChanged;

  const PengumumanNotificationCard({
    super.key,
    required this.onCountChanged,
  });

  @override
  State<PengumumanNotificationCard> createState() =>
      _PengumumanNotificationCardState();
}

class _PengumumanNotificationCardState
    extends State<PengumumanNotificationCard> {
  DateTime? _lastVisited;

  @override
  void initState() {
    super.initState();
    _loadLastVisited();
  }

  Future<void> _loadLastVisited() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisitedStr = prefs.getString('last_visited_pengumuman');
    if (mounted) {
      setState(() {
        _lastVisited =
            lastVisitedStr != null ? DateTime.tryParse(lastVisitedStr) : null;
      });
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    final dt = DateTime.tryParse(timeStr)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('pengumuman')
          .stream(primaryKey: ['id_tabel'])
          .order('created_at', ascending: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          widget.onCountChanged(0);
          return const SizedBox.shrink();
        }

        int unreadCount = 0;
        String? latestTitle;
        String? latestTime;

        for (final item in snapshot.data!) {
          final createdAtStr = item['created_at']?.toString();

          if (createdAtStr != null) {
            final createdAt = DateTime.tryParse(createdAtStr);
            if (createdAt != null) {
              if (_lastVisited == null || createdAt.isAfter(_lastVisited!)) {
                unreadCount++;
                latestTitle = item['title']?.toString();
                latestTime = createdAtStr;
              }
            }
          }
        }

        widget.onCountChanged(unreadCount);

        if (unreadCount == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                  'last_visited_pengumuman', DateTime.now().toIso8601String());
              widget.onCountChanged(0);
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const PreviewPengumuman()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Color(0xFF2563EB),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pengumuman Baru',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              _formatTime(latestTime),
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
                            '$unreadCount pengumuman baru',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        if (latestTitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            latestTitle,
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
        );
      },
    );
  }
}


