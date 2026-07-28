import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:apk/dashboard/a_admin/widget/custom_button.dart';
import 'package:apk/dashboard/a_admin/database/db_kelas.dart';
import 'package:apk/dashboard/a_admin/function/f_kelas/content_kelas.dart';
import 'package:apk/dashboard/a_admin/database/db_namasekolah.dart';
import 'package:apk/error_handler/connection.dart';

class DaftarKelas extends StatefulWidget {
  const DaftarKelas({super.key});

  @override
  State<DaftarKelas> createState() => _DaftarKelasState();
}

class _DaftarKelasState extends State<DaftarKelas> {
  List<Map<String, dynamic>> allData = [];
  bool isLoading = true;
  String? searchQuery;
  String namaSekolah = "Nama Sekolah";
  bool isSearchActive = false;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    if (!await ConnectionHandler.checkConnection()) {
      if (mounted) {
        setState(() => isLoading = false);
        ConnectionHandler.showNoConnectionDialog(
          context: context,
          onRetry: () {
            setState(() => isLoading = true);
            fetchData();
          },
        );
      }
      return;
    }

    try {
      final res = await ClassService.getClasses();
      final sekolah = await NamaSekolahService.getNamaSekolah() ?? "Nama Sekolah";

      if (!mounted) return;

      setState(() {
        allData = res ?? [];
        namaSekolah = sekolah;
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) print(e);

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  String _safe(dynamic value) {
    if (value == null || value.toString().isEmpty) return "-";
    return value.toString();
  }

  String _waliName(Map<String, dynamic> item) {
    final guruData = item['guru'];

    if (guruData is List && guruData.isNotEmpty) {
      final waliGuru = guruData.firstWhere(
        (g) => g is Map && g['wali'] == true,
        orElse: () => null,
      );

      if (waliGuru != null) {
        return waliGuru['name']?.toString() ?? "-";
      }

      return guruData.first['name']?.toString() ?? "-";
    }

    return "-";
  }

  List<Map<String, dynamic>> get _filteredData {
    final query = (searchQuery ?? "").toLowerCase();

    if (query.isEmpty) return allData;

    return allData.where((item) {
      final name = _safe(item['name_class']).toLowerCase();
      final wali = _waliName(item).toLowerCase();
      final tahun = _safe(item['tahun']).toLowerCase();

      return name.contains(query) ||
          wali.contains(query) ||
          tahun.contains(query);
    }).toList();
  }

  int _muridCount(Map<String, dynamic> item) {
    final muridData = item['murid'];
    if (muridData is List) return muridData.length;
    return 0;
  }

  Color _levelColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF2563EB);
      case 2:
        return const Color(0xFF059669);
      case 3:
        return const Color(0xFF7C3AED);
      case 4:
        return const Color(0xFFDC2626);
      case 5:
        return const Color(0xFFEA580C);
      case 6:
        return const Color(0xFF0891B2);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _softLevelColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFFDBEAFE);
      case 2:
        return const Color(0xFFD1FAE5);
      case 3:
        return const Color(0xFFEDE9FE);
      case 4:
        return const Color(0xFFFEE2E2);
      case 5:
        return const Color(0xFFFFEDD5);
      case 6:
        return const Color(0xFFCFFAFE);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Widget _levelBadge(int level) {
    final color = _levelColor(level);
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _softLevelColor(level),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, color: color, size: 18),
          const SizedBox(height: 2),
          Text(
            level == 7 ? "LAIN" : "KLS $level",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _classCard(Map<String, dynamic> item) {
    final level = int.tryParse(item['id_class']?.toString() ?? "") ?? 7;
    final nameClass = _safe(item['name_class']);
    final wali = _waliName(item);
    final tahun = _safe(item['tahun']);
    final muridCount = _muridCount(item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SizedBox(
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomCard(
              title: "",
              showIcon: false,
              height: 100,
              backgroundColor: Colors.white,
              borderColor: const Color(0xFFE8EEF6),
              borderWidth: 1,
              borderRadius: 14,
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContentKelas(classData: item),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _levelBadge(level),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nameClass,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Wali: $wali",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.groups_2_outlined, size: 14),
                            const SizedBox(width: 4),
                            Text("$muridCount murid",
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 10),
                            const Icon(Icons.calendar_month_outlined, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                tahun,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCBD5E1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataCount = allData.length;
    final visibleData = _filteredData;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2563EB),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Container(
            height: 45,
            width: double.infinity,
            color: const Color(0xFF2563EB),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Daftar Kelas",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$dataCount kelas terdaftar",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    setState(() => isLoading = true);
                    fetchData();
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // SEARCH BAR
          Container(
            height: 70,
            color: const Color(0xFF2563EB),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: isSearchActive
                    ? TextField(
                        autofocus: true,
                        onChanged: (value) {
                          setState(() => searchQuery = value);
                        },
                        decoration: InputDecoration(
                          hintText: "Cari kelas atau wali kelas...",
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFCCCCCC),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          prefixIcon: IconButton(
                            icon: const Icon(Icons.arrow_back, size: 18),
                            onPressed: () {
                              setState(() {
                                isSearchActive = false;
                                searchQuery = null;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Transform.translate(
                            offset: const Offset(-12, 0),
                            child: IconButton(
                              icon: const Icon(Icons.search, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  isSearchActive = true;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: Text(
                              namaSekolah,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontFamily: "Inter",
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 0),

          // LIST
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: fetchData,
                    child: visibleData.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.5,
                                child: const Center(child: Text("Belum ada kelas")),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 10, bottom: 20),
                            itemCount: visibleData.length,
                            itemBuilder: (context, index) {
                              return _classCard(visibleData[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}