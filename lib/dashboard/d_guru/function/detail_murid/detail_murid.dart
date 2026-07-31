import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailMuridPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const DetailMuridPage({
    super.key,
    required this.data,
  });

  @override
  State<DetailMuridPage> createState() => _DetailMuridPageState();
}

class _DetailMuridPageState extends State<DetailMuridPage> {
  bool _isLoading = true;
  Map<String, dynamic> _fullData = {};

  @override
  void initState() {
    super.initState();
    _fullData = Map.from(widget.data);
    _fetchFullData();
  }

  Future<void> _fetchFullData() async {
    try {
      final idTabel = widget.data['id_tabel']?.toString();
      if (idTabel == null) return;

      final response = await Supabase.instance.client
          .from('murid')
          .select('*, class_name(name_class)')
          .eq('id_tabel', idTabel)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _fullData = Map<String, dynamic>.from(response);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTanggalLahir(dynamic value) {
    if (value == null) return '-';
    try {
      final date = DateTime.parse(value.toString());
      return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nama = _fullData['nama']?.toString() ?? '-';
    final nis = _fullData['nis']?.toString() ?? '-';
    final gender = _fullData['gender']?.toString() ?? '-';
    final tanggalLahir = _formatTanggalLahir(_fullData['tanggal_lahir']);
    final alamat = _fullData['alamat']?.toString() ?? '-';
    final orangTua = _fullData['orang_tua']?.toString() ?? '-';
    final noTele = _fullData['no_tele']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ─── App Bar / Header ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            backgroundColor: const Color(0xFF2563EB),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Detail Siswa',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 48),
                          Text(
                            nama,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _badgeWidget('NIS: $nis'),
                        ],
                      ),
              ),
            ),
          ),

          // ─── Content ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _isLoading
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Identitas Siswa'),
                        const SizedBox(height: 8),
                        _infoCard([
                          _infoRow(Icons.wc_rounded, 'Jenis Kelamin', gender),
                          _divider(),
                          _infoRow(Icons.cake_rounded, 'Tanggal Lahir', tanggalLahir),
                          _divider(),
                          _infoRow(Icons.location_on_rounded, 'Alamat', alamat),
                        ]),
                        const SizedBox(height: 20),
                        _sectionTitle('Kontak Orang Tua'),
                        const SizedBox(height: 8),
                        _infoCard([
                          _infoRow(Icons.person_rounded, 'Nama Orang Tua', orangTua),
                          _divider(),
                          _infoRow(Icons.phone_rounded, 'No. Telepon', noTele),
                        ]),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _badgeWidget(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 66, color: Color(0xFFF1F5F9));
}
