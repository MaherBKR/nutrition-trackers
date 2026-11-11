import 'package:flutter/material.dart';
import '../database/database.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<Map<String, dynamic>>> _reminders;

  @override
  void initState() {
    super.initState();
    NotificationService.init();
    _load();
  }

  void _load() {
    _reminders = AppDatabase.instance.database
        .then((db) => db.query('reminders', orderBy: 'id'));
  }

  Future<void> _applyReminder(Map<String, dynamic> r, bool enabled) async {
    final db = await AppDatabase.instance.database;
    await db.update('reminders', {'is_enabled': enabled ? 1 : 0},
        where: 'id = ?', whereArgs: [r['id']]);

    final days = (r['days_active'] as String)
        .split(',').map(int.parse).toList();

    if (!enabled) {
      await NotificationService.cancelReminder(r['id'], days);
    } else if (r['schedule_type'] == 'Fixed Time') {
      final parts = (r['time_or_interval'] as String).split(':');
      await NotificationService.scheduleFixed(
          r['id'], r['title'], int.parse(parts[0]), int.parse(parts[1]), days);
    } else {
      // Interval reminder (hydration): stored as minutes
      await NotificationService.scheduleHydration(
          9, 22, int.parse(r['time_or_interval']));
    }
    setState(_load);
  }

  Future<void> _addReminderDialog() async {
    final db = await AppDatabase.instance.database;
    String type = 'Supplement';
    String scheduleType = 'Fixed Time';
    final titleCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '19:30');
    final days = {1, 2, 3, 4, 5, 6, 7};
    TimeOfDay picked = const TimeOfDay(hour: 19, minute: 30);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const ['Water', 'Meal', 'Supplement']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Title (e.g. Creatine 5g + Collagen 10g)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField(
                  value: scheduleType,
                  decoration: const InputDecoration(labelText: 'Schedule'),
                  items: const ['Fixed Time', 'Interval']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      scheduleType = v!;
                      valueCtrl.text =
                          v == 'Fixed Time' ? '19:30' : '90';
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (scheduleType == 'Fixed Time')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text('Time: ${picked.format(ctx)}'),
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: picked);
                      if (t != null) {
                        setDialogState(() {
                          picked = t;
                          valueCtrl.text =
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  )
                else
                  TextField(
                    controller: valueCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Interval (minutes, e.g. 90)'),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(
                            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1]),
                        selected: days.contains(d),
                        onSelected: (sel) => setDialogState(() =>
                            sel ? days.add(d) : days.remove(d)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved == true && titleCtrl.text.isNotEmpty) {
      final id = await db.insert('reminders', {
        'type': type,
        'title': titleCtrl.text.trim(),
        'schedule_type': scheduleType,
        'time_or_interval': valueCtrl.text,
        'days_active': (days.toList()..sort()).join(','),
        'is_enabled': 1,
      });
      setState(_load);
      final row = (await db.query('reminders',
          where: 'id = ?', whereArgs: [id])).first;
      await _applyReminder(row, true);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _importDialog() async {
    final pathCtrl = TextEditingController();
    final ok = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: TextField(
          controller: pathCtrl,
          decoration: const InputDecoration(
              labelText: 'Full path to nutrition_backup_YYYY_MM_DD.json'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: const Text('Merge'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'overwrite'),
            child: const Text('Overwrite All'),
          ),
        ],
      ),
    );
    if (ok == null) return;
    try {
      final n = await BackupService.restoreJson(pathCtrl.text,
          overwrite: ok == 'overwrite');
      _snack('Restored $n rows (${ok == 'overwrite' ? 'overwrite' : 'merge'} mode)');
    } catch (e) {
      _snack('Restore failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('Reminders',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _reminders,
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No reminders yet.'),
                );
              }
              return Column(
                children: [
                  for (final r in items)
                    SwitchListTile(
                      secondary: Icon(r['type'] == 'Water'
                          ? Icons.water_drop
                          : r['type'] == 'Meal'
                              ? Icons.restaurant
                              : Icons.medication),
                      title: Text(r['title']),
                      subtitle: Text(
                        '${r['schedule_type']}: ${r['time_or_interval']} • days ${r['days_active']}',
                      ),
                      value: r['is_enabled'] == 1,
                      onChanged: (v) => _applyReminder(r, v),
                    ),
                ],
              );
            },
          ),
          Center(
            child: OutlinedButton.icon(
              onPressed: _addReminderDialog,
              icon: const Icon(Icons.add_alarm),
              label: const Text('Add Reminder'),
            ),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Backup & Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export backup (JSON)'),
            onTap: () async =>
                _snack('Saved to: ${await BackupService.exportJson()}'),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore from backup'),
            onTap: _importDialog,
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('Export CSV (weight + logs)'),
            onTap: () async {
              final paths = await BackupService.exportCsv();
              _snack('Saved: ${paths.join(' | ')}');
            },
          ),
        ],
      ),
    );
  }
}
