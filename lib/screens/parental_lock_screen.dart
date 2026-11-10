import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage/prefs_service.dart';

class ParentalLockScreen extends StatefulWidget {
  const ParentalLockScreen({super.key});

  @override
  State<ParentalLockScreen> createState() => _ParentalLockScreenState();
}

class _ParentalLockScreenState extends State<ParentalLockScreen> {
  String _entered = '';
  bool _verified = false;
  PrefsService? _prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((sp) {
      if (!mounted) return;
      setState(() => _prefs = PrefsService(sp));
    });
  }

  void _onDigit(String d) {
    if (_entered.length >= 4) return;
    setState(() => _entered += d);
    if (_entered.length == 4) _submit();
  }

  void _submit() {
    final existing = _prefs!.parentalPin;
    if (existing == null) {
      _prefs!.setParentalPin(_entered);
      setState(() { _verified = true; _entered = ''; });
    } else if (existing == _entered) {
      setState(() { _verified = true; _entered = ''; });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falsche PIN')),
      );
      setState(() => _entered = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kindersperre')),
      body: Center(
        child: _prefs == null
            ? const CircularProgressIndicator()
            : FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: _verified ? _buildFolderList() : _buildPinPad(),
              ),
      ),
    );
  }

  Widget _buildPinPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_prefs!.parentalPin == null ? 'PIN festlegen' : 'PIN eingeben',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) => Container(
            margin: const EdgeInsets.all(8),
            width: 48, height: 64,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(i < _entered.length ? '●' : '', style: const TextStyle(fontSize: 28))),
          )),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 240,
          child: Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              ...List.generate(9, (i) => Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  autofocus: i == 0,
                  borderRadius: BorderRadius.circular(8),
                  focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.28),
                  onTap: () => _onDigit('${i + 1}'),
                  child: Container(
                  width: 64, height: 64, alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 24)),
                  ),
                ),
              )),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                  onTap: () => setState(() => _entered = ''),
                  child: Container(
                  width: 64, height: 64, alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.clear),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                  onTap: () => _onDigit('0'),
                  child: Container(
                  width: 64, height: 64, alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                  child: const Text('0', style: TextStyle(fontSize: 24)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFolderList() {
    final folders = _prefs!.lockedFolders;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gesperrte Ordner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: folders.isEmpty
                ? const Center(child: Text('Keine gesperrten Ordner'))
                : ListView.builder(
                    itemCount: folders.length,
                    itemBuilder: (context, i) {
                      final f = folders[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          autofocus: i == 0,
                          focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.24),
                          onTap: () async {
                            final newList = List<String>.from(folders)..remove(f);
                            await _prefs!.setLockedFolders(newList);
                            setState(() {});
                          },
                          child: ListTile(
                          leading: const Icon(Icons.lock),
                          title: Text(f),
                          trailing: const Icon(Icons.lock_open),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
