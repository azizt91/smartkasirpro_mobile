import 'package:flutter/material.dart';
import 'package:mobile_app/core/services/notification_service.dart';
import 'package:mobile_app/core/theme/app_colors.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notifService = NotificationService();

  // Current selections per category
  String _orderSound = kDefaultSounds[kCategoryOrder]!;
  String _shiftSound = kDefaultSounds[kCategoryShift]!;
  String _auditSound = kDefaultSounds[kCategoryAudit]!;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final order = await _notifService.getSoundForCategory(kCategoryOrder);
    final shift = await _notifService.getSoundForCategory(kCategoryShift);
    final audit = await _notifService.getSoundForCategory(kCategoryAudit);
    setState(() {
      _orderSound = order;
      _shiftSound = shift;
      _auditSound = audit;
      _isLoading = false;
    });
  }

  Future<void> _setSound(String category, String soundKey) async {
    await _notifService.setSoundForCategory(category, soundKey);
    setState(() {
      switch (category) {
        case kCategoryOrder:
          _orderSound = soundKey;
          break;
        case kCategoryShift:
          _shiftSound = soundKey;
          break;
        case kCategoryAudit:
          _auditSound = soundKey;
          break;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nada berhasil diubah'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _previewSound(String soundKey) {
    _notifService.previewSound(soundKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Nada Notifikasi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark)),
        backgroundColor: AppColors.surfaceLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade50, Colors.orange.shade50],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade700, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Atur nada notifikasi yang berbeda untuk setiap jenis pemberitahuan.',
                            style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Pesanan Masuk
                  _buildCategorySection(
                    icon: Icons.shopping_bag,
                    iconColor: Colors.green,
                    title: 'Pesanan Masuk',
                    subtitle: 'Notifikasi saat ada pesanan baru dari pelanggan',
                    category: kCategoryOrder,
                    currentSound: _orderSound,
                  ),
                  const SizedBox(height: 16),

                  // Section 2: Shift Ditutup
                  _buildCategorySection(
                    icon: Icons.access_time_filled,
                    iconColor: Colors.blue,
                    title: 'Shift Ditutup',
                    subtitle: 'Notifikasi saat kasir menutup shift',
                    category: kCategoryShift,
                    currentSound: _shiftSound,
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Peringatan Audit
                  _buildCategorySection(
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.red,
                    title: 'Peringatan Audit',
                    subtitle: 'Notifikasi peringatan aktivitas mencurigakan',
                    category: kCategoryAudit,
                    currentSound: _auditSound,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategorySection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String category,
    required String currentSound,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sound Options
          ...availableSounds.map((sound) {
            final isSelected = currentSound == sound.key;
            return InkWell(
              onTap: () => _setSound(category, sound.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? iconColor.withOpacity(0.05) : null,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Row(
                  children: [
                    // Radio indicator
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? iconColor : Colors.grey.shade400,
                          width: isSelected ? 2 : 1.5,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: iconColor,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),

                    // Sound icon
                    Icon(
                      sound.key == 'silent' ? Icons.volume_off : Icons.music_note,
                      color: isSelected ? iconColor : Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 10),

                    // Label & description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sound.label,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                              color: isSelected ? iconColor : AppColors.textDark,
                            ),
                          ),
                          Text(
                            sound.description,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),

                    // Preview button
                    if (sound.key != 'silent')
                      IconButton(
                        onPressed: () => _previewSound(sound.key),
                        icon: Icon(Icons.volume_up, color: Colors.grey.shade400, size: 22),
                        tooltip: 'Preview',
                        splashRadius: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
