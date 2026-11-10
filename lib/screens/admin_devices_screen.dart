import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inventory is loaded only through an admin-guarded RPC; clients cannot query all devices.
class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key});
  @override
  State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final admin = await client.rpc('is_streamia_admin');
      if (admin != true) throw Exception('Adminzugriff erforderlich.');
      final result = await client.rpc('admin_list_my_devices');
      _devices = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setStatus(Map<String, dynamic> device, String status) async {
    final deviceName = '${device['device_name'] ?? 'dieses Gerät'}';
    final actionLabel = status == 'blocked' ? 'sperren' : 'freigeben';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Gerät $actionLabel?'),
        content: Text('Möchtest du „$deviceName“ wirklich $actionLabel?'),
        actions: [
          TextButton(
            autofocus: true,
            style: TextButton.styleFrom(focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16)),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.20)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(status == 'blocked' ? 'Sperren' : 'Freigeben'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final reason = status == 'blocked' ? 'Durch Admin in Streamia Player gesperrt' : 'Durch Admin in Streamia Player freigegeben';
    try {
      await Supabase.instance.client.rpc('admin_set_device_status', params: {
        'p_device_id': device['device_id'], 'p_status': status, 'p_reason': reason,
      });
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin – Geräteverwaltung'), actions: [
      IconButton(
        tooltip: 'Geräteliste aktualisieren',
        focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
        onPressed: _load,
        icon: const Icon(Icons.refresh),
      ),
    ]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(autofocus: true, style: FilledButton.styleFrom(focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.18)), onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Erneut versuchen'))])))
      : _devices.isEmpty ? const Center(child: Text('Noch keine Geräte registriert.'))
      : RefreshIndicator(onRefresh: _load, child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: _devices.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final d = _devices[index];
            final status = '${d['device_status'] ?? 'unbekannt'}';
            return ListTile(
              leading: Icon(d['platform'] == 'android' || d['platform'] == 'android_tv' ? Icons.tv : Icons.devices),
              title: Text('${d['device_name'] ?? 'Unbenanntes Gerät'}'),
              subtitle: Text('User: ${d['user_id']}\n${d['platform']} · $status\nTrial bis: ${d['trial_ends_at'] ?? 'kein Trial'}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                tooltip: 'Gerätestatus ändern',
                autofocus: index == 0,
                onSelected: (value) => _setStatus(d, value),
                itemBuilder: (_) => const [
                PopupMenuItem(value: 'active', child: Text('Freigeben')),
                PopupMenuItem(value: 'blocked', child: Text('Sperren')),
              ]),
            );
          },
        ))),
  );
}
