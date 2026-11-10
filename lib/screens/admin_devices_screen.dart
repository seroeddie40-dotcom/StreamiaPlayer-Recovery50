
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Device inventory is loaded through admin-protected RPCs.
class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  State<AdminDevicesScreen> createState() =>
      _AdminDevicesScreenState();
}

class _AdminDevicesScreenState
    extends State<AdminDevicesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;

      final admin =
          await client.rpc('is_streamia_admin');

      if (admin != true) {
        throw Exception('Adminzugriff erforderlich.');
      }

      final result =
          await client.rpc('admin_list_my_devices');

      final devices = (result as List)
          .map(
            (e) => Map<String, dynamic>.from(e as Map),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(
    Map<String, dynamic> device,
    String status,
  ) async {
    final deviceName =
        '${device['device_name'] ?? 'dieses Gerät'}';

    final actionLabel =
        status == 'blocked' ? 'sperren' : 'freigeben';

    final highlightColor =
        Theme.of(context).colorScheme.primary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Gerät $actionLabel?'),
        content: Text(
          'Möchtest du „$deviceName“ wirklich $actionLabel?',
        ),
        actions: [
          TextButton(
            autofocus: true,
            style: TextButton.styleFrom(
              overlayColor: highlightColor,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              overlayColor: highlightColor,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: Text(
              status == 'blocked'
                  ? 'Sperren'
                  : 'Freigeben',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final reason = status == 'blocked'
        ? 'Durch Admin in Streamia Player gesperrt'
        : 'Durch Admin in Streamia Player freigegeben';

    try {
      await Supabase.instance.client.rpc(
        'admin_set_device_status',
        params: {
          'p_device_id': device['device_id'],
          'p_status': status,
          'p_reason': reason,
        },
      );

      if (!mounted) return;

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor =
        Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin – Geräteverwaltung'),
        actions: [
          IconButton(
            tooltip: 'Geräteliste aktualisieren',
            focusColor:
                highlightColor.withValues(alpha: 0.16),
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(highlightColor),
    );
  }

  Widget _buildBody(Color highlightColor) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Focus(
                autofocus: true,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    overlayColor: highlightColor,
                  ),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Erneut versuchen'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_devices.isEmpty) {
      return const Center(
        child: Text(
          'Noch keine Geräte registriert.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _devices.length,
          separatorBuilder: (_, __) =>
              const Divider(),
          itemBuilder: (context, index) {
            final device = _devices[index];

            final status =
                '${device['device_status'] ?? 'unbekannt'}';

            final platform = device['platform'];

            final isTv = platform == 'android' ||
                platform == 'android_tv';

            return ListTile(
              leading: Icon(
                isTv ? Icons.tv : Icons.devices,
              ),
              title: Text(
                '${device['device_name'] ?? 'Unbenanntes Gerät'}',
              ),
              subtitle: Text(
                'User: ${device['user_id']}\n'
                '${device['platform']} · $status\n'
                'Trial bis: '
                '${device['trial_ends_at'] ?? 'kein Trial'}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                tooltip: 'Gerätestatus ändern',
                autofocus: index == 0,
                onSelected: (value) =>
                    _setStatus(device, value),
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'active',
                    child: Text('Freigeben'),
                  ),
                  PopupMenuItem<String>(
                    value: 'blocked',
                    child: Text('Sperren'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
