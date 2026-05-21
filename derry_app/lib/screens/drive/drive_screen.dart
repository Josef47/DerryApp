import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/drive_link_model.dart';
import '../../providers/settings_provider.dart';

class DriveScreen extends ConsumerStatefulWidget {
  const DriveScreen({super.key});

  @override
  ConsumerState<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends ConsumerState<DriveScreen> {
  bool _isHM = false;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _userId = prefs.getString(AppConstants.prefUserId) ?? '';
      _isHM = prefs.getBool(AppConstants.prefIsHousemaster) ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final linksAsync = ref.watch(driveLinksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drive Dosyaları'),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        actions: [
          if (_isHM)
            IconButton(
              icon: const Icon(Icons.add_link_rounded),
              tooltip: 'Link Ekle',
              onPressed: () => _showAddLinkDialog(context),
            ),
        ],
      ),
      body: linksAsync.when(
        data: (links) {
          if (links.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textSecondary),
                const SizedBox(height: 12),
                const Text('Henüz Drive bağlantısı eklenmedi.',
                    style: TextStyle(color: AppTheme.textSecondary)),
                if (_isHM) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddLinkDialog(context),
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('Link Ekle'),
                  ),
                ],
              ]),
            );
          }

          final folders = links.where((l) => l.type == 'folder').toList();
          final files = links.where((l) => l.type == 'file').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (folders.isNotEmpty) ...[
                const _SectionHeader('Klasörler'),
                ...folders.map((l) => _LinkTile(link: l, isHM: _isHM, userId: _userId)),
              ],
              if (files.isNotEmpty) ...[
                const _SectionHeader('Dosyalar'),
                ...files.map((l) => _LinkTile(link: l, isHM: _isHM, userId: _userId)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  void _showAddLinkDialog(BuildContext context) {
    final labelCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String type = 'file';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Drive Bağlantısı Ekle'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Etiket / Başlık'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Google Drive URL',
                hintText: 'https://drive.google.com/...',
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Tip: '),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Dosya'),
                selected: type == 'file',
                onSelected: (_) => setS(() => type = 'file'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Klasör'),
                selected: type == 'folder',
                onSelected: (_) => setS(() => type = 'folder'),
              ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (labelCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) return;
                final link = DriveLinkModel(
                  id: '',
                  label: labelCtrl.text.trim(),
                  url: urlCtrl.text.trim(),
                  type: type,
                  addedBy: _userId,
                );
                await ref.read(driveServiceProvider).addLink(link);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              fontSize: 13)),
    );
  }
}

class _LinkTile extends ConsumerWidget {
  final DriveLinkModel link;
  final bool isHM;
  final String userId;

  const _LinkTile({required this.link, required this.isHM, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = link.type == 'folder'
        ? Icons.folder_rounded
        : Icons.insert_drive_file_rounded;
    final color = link.type == 'folder' ? Colors.amber : Colors.blue;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(link.label, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(link.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            onPressed: () => _openLink(link.url),
          ),
          if (isHM)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
              onPressed: () async {
                await ref.read(driveServiceProvider).deleteLink(link.id);
              },
            ),
        ]),
        onTap: () => _openLink(link.url),
      ),
    );
  }

  void _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
