import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:apk/dashboard/d_c_murid/database/db_absensi.dart';

class AbsenHistory extends StatefulWidget {
  final String nis;

  const AbsenHistory({super.key, required this.nis});

  @override
  State<AbsenHistory> createState() => _AbsenHistoryState();
}

class _AbsenHistoryState extends State<AbsenHistory> {
  bool _isLoading = true;
  String _error = '';
  
  List<Map<String, dynamic>> _allAbsen = [];
  int _activeTabIndex = 0; // 0 for Harian, 1 for Mingguan, 2 for Bulanan
  final Set<DateTime> _expandedWeeks = {}; // Keep track of expanded week groups
  final Set<DateTime> _expandedMonths = {}; // Keep track of expanded month groups

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (widget.nis == '...') {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      return;
    }

    if (widget.nis.isEmpty || widget.nis == '-') {
      setState(() {
        _isLoading = false;
        _error = 'NIS tidak ditemukan';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final db = DbAbsensi();
      final data = await db.getAbsensi(widget.nis);
      
      // Urutkan data dari tanggal terbaru ke terlama
      data.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
      
      if (mounted) {
        setState(() {
          _allAbsen = data;
          _isLoading = false;
          
          // Otomatis expand bulan teratas (paling baru)
          if (data.isNotEmpty) {
            try {
              final latestDate = DateTime.parse(data.first['date'].toString());
              final firstOfMonth = DateTime(latestDate.year, latestDate.month, 1);
              _expandedMonths.add(firstOfMonth);
            } catch (_) {}
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir': return Colors.green;
      case 'izin': return Colors.blue;
      case 'sakit': return Colors.orange;
      case 'alpha': return Colors.red;
      case 'terlambat': return Colors.amber;
      case 'libur': return Colors.purple;
      default: return Colors.grey;
    }
  }

  // Helper to group attendance records by calendar week (Monday to Sunday)
  // Hanya menampilkan minggu pada bulan berjalan
  Map<DateTime, List<Map<String, dynamic>>> get _groupedWeeks {
    final Map<DateTime, List<Map<String, dynamic>>> groups = {};
    final now = DateTime.now();
    for (var row in _allAbsen) {
      final dateStr = row['date'].toString();
      try {
        final date = DateTime.parse(dateStr);
        // Filter hanya untuk bulan berjalan
        if (date.year != now.year || date.month != now.month) continue;

        // Find Monday of that date's week
        final monday = DateTime(date.year, date.month, date.day - (date.weekday - 1));
        if (!groups.containsKey(monday)) {
          groups[monday] = [];
        }
        groups[monday]!.add(row);
      } catch (_) {}
    }
    
    // Sort keys descending (latest week first)
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<DateTime, List<Map<String, dynamic>>> sortedGroups = {};
    for (var key in sortedKeys) {
      groups[key]!.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
      sortedGroups[key] = groups[key]!;
    }
    return sortedGroups;
  }

  // Helper to group attendance records by month
  Map<DateTime, List<Map<String, dynamic>>> get _groupedMonths {
    final Map<DateTime, List<Map<String, dynamic>>> groups = {};
    for (var row in _allAbsen) {
      final dateStr = row['date'].toString();
      try {
        final date = DateTime.parse(dateStr);
        final firstOfMonth = DateTime(date.year, date.month, 1);
        if (!groups.containsKey(firstOfMonth)) {
          groups[firstOfMonth] = [];
        }
        groups[firstOfMonth]!.add(row);
      } catch (_) {}
    }
    
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<DateTime, List<Map<String, dynamic>>> sortedGroups = {};
    for (var key in sortedKeys) {
      sortedGroups[key] = groups[key]!;
    }
    return sortedGroups;
  }

  Widget _buildDailyCard(Map<String, dynamic> row) {
    final dateStr = row['date'].toString();
    String displayDate = dateStr;
    String displayDay = '';
    try {
      final d = DateTime.parse(dateStr);
      displayDate = DateFormat('dd MMM yyyy').format(d);
      displayDay = DateFormat('EEEE').format(d);
    } catch (_) {}

    final status = DbAbsensi.getStatus(row);
    final color = _getStatusColor(status);
    final masuk = row['masuk'] ?? '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date Badge
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayDay.length >= 3 ? displayDay.substring(0, 3).toUpperCase() : displayDay.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayDate.length >= 2 ? displayDate.substring(0, 2) : displayDate,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      Text(
                        displayDate,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.login, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        masuk,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyCard(DateTime weekStart, List<Map<String, dynamic>> records) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final isExpanded = _expandedWeeks.contains(weekStart);

    int hadir = 0;
    int sakit = 0;
    int izin = 0;
    int alpha = 0;
    int terlambat = 0;

    for (var r in records) {
      final status = DbAbsensi.getStatus(r).toLowerCase();
      if (status == 'hadir') {
        hadir++;
      } else if (status == 'sakit') {
        sakit++;
      } else if (status == 'izin') {
        izin++;
      } else if (status == 'alpha') {
        alpha++;
      } else if (status == 'terlambat') {
        terlambat++;
      }
    }

    final dateRangeStr = "${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM yyyy').format(weekEnd)}";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Tappable to Toggle Expand
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedWeeks.remove(weekStart);
                } else {
                  _expandedWeeks.add(weekStart);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.date_range, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            dateRangeStr,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: const Color(0xFF64748B),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Summary Badges Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatBadge('Hadir', hadir, Colors.green),
                        _buildStatBadge('Sakit', sakit, Colors.orange),
                        _buildStatBadge('Izin', izin, Colors.blue),
                        _buildStatBadge('Alpha', alpha, Colors.red),
                        _buildStatBadge('Terlambat', terlambat, Colors.amber),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Child List
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                itemBuilder: (context, idx) {
                  return _buildDailyCard(records[idx]);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyCard(DateTime monthStart, List<Map<String, dynamic>> records) {
    final isExpanded = _expandedMonths.contains(monthStart);

    int hadir = 0;
    int sakit = 0;
    int izin = 0;
    int alpha = 0;

    for (var r in records) {
      final status = DbAbsensi.getStatus(r).toLowerCase();
      if (status == 'hadir' || status == 'terlambat') {
        hadir++;
      } else if (status == 'sakit') {
        sakit++;
      } else if (status == 'izin') {
        izin++;
      } else if (status == 'alpha') {
        alpha++;
      }
    }

    final monthStr = DateFormat('MMMM yyyy').format(monthStart);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Tappable to Toggle Expand
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedMonths.remove(monthStart);
                } else {
                  _expandedMonths.add(monthStart);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        monthStr,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Child List showing ONLY H S A I stats detail list (Terlambat is merged into Hadir)
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  _buildMonthlyStatRow('Hadir', hadir, Colors.green, Icons.check_circle_outline),
                  const SizedBox(height: 12),
                  _buildMonthlyStatRow('Sakit', sakit, Colors.orange, Icons.sick_outlined),
                  const SizedBox(height: 12),
                  _buildMonthlyStatRow('Izin', izin, Colors.blue, Icons.assignment_outlined),
                  const SizedBox(height: 12),
                  _buildMonthlyStatRow('Alpha', alpha, Colors.red, Icons.cancel_outlined),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyStatRow(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$count Hari",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "$label: $count",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<DateTime, List<Map<String, dynamic>>> grouped = _groupedWeeks;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Riwayat Absensi'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Sleek Toggle segment (Harian, Mingguan, Bulanan)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Harian Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTabIndex = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTabIndex == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        margin: const EdgeInsets.all(4),
                        alignment: Alignment.center,
                        child: Text(
                          'Harian',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _activeTabIndex == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Mingguan Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTabIndex = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTabIndex == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        margin: const EdgeInsets.all(4),
                        alignment: Alignment.center,
                        child: Text(
                          'Mingguan',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _activeTabIndex == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bulanan Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTabIndex = 2),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 2 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTabIndex == 2
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        margin: const EdgeInsets.all(4),
                        alignment: Alignment.center,
                        child: Text(
                          'Bulanan',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _activeTabIndex == 2 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                    : _allAbsen.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data absensi.',
                              style: TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8)),
                            ),
                          )
                        : _activeTabIndex == 0
                            // Harian List View
                            ? ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: _allAbsen.length,
                                itemBuilder: (context, index) {
                                  return _buildDailyCard(_allAbsen[index]);
                                },
                              )
                            : _activeTabIndex == 1
                                // Mingguan List View
                                ? ListView.builder(
                                    padding: const EdgeInsets.all(20),
                                    itemCount: grouped.length,
                                    itemBuilder: (context, index) {
                                      final key = grouped.keys.elementAt(index);
                                      final val = grouped[key]!;
                                      return _buildWeeklyCard(key, val);
                                    },
                                  )
                                // Bulanan List View
                                : ListView.builder(
                                    padding: const EdgeInsets.all(20),
                                    itemCount: _groupedMonths.length,
                                    itemBuilder: (context, index) {
                                      final key = _groupedMonths.keys.elementAt(index);
                                      final val = _groupedMonths[key]!;
                                      return _buildMonthlyCard(key, val);
                                    },
                                  ),
          ),
        ],
      ),
    );
  }
}
