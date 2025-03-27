import 'dart:async';
import 'package:flutter/material.dart';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';

import 'package:smartpillbox_alarm/models/medication_model.dart';
import 'package:smartpillbox_alarm/screens/edit_alarm.dart';
import 'package:smartpillbox_alarm/screens/meal_time_settings_screen.dart';
import 'package:smartpillbox_alarm/screens/ring.dart';

import 'package:smartpillbox_alarm/services/google_sheets_service.dart';
import 'package:smartpillbox_alarm/services/medication_alarm_service.dart';
import 'package:smartpillbox_alarm/services/medication_notification_service.dart';
import 'package:smartpillbox_alarm/services/permission.dart';
import 'package:smartpillbox_alarm/widgets/tile.dart';

import 'package:logging/logging.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:url_launcher/url_launcher.dart';

import '../credential.dart';

const version = '5.0.3';

class MedicationAlarmHomeScreen extends StatefulWidget {
  const MedicationAlarmHomeScreen({super.key});

  @override
  State<MedicationAlarmHomeScreen> createState() =>
      _MedicationAlarmHomeScreenState();
}

class _MedicationAlarmHomeScreenState extends State<MedicationAlarmHomeScreen> {
  Timer? _permissionCheckTimer;
  bool _permissionsChecked = false;

  static final _log = Logger('MedicationAlarmHomeScreen');
  List<AlarmSettings> alarms = [];
  List<Medication> medications = [];
  bool isLoading = true;

  // Google Sheets service
  late GoogleSheetsService _googleSheetsService;
  late MedicationAlarmService _medicationAlarmService;

  static StreamSubscription<AlarmSet>? ringSubscription;
  static StreamSubscription<AlarmSet>? updateSubscription;
  Timer? _refreshTimer;

  void _initializePermissions() async {
    await Future.delayed(Duration(milliseconds: 300)); //給個小小延遲，讓 UI繼續載入
    bool hasPermission = await AlarmPermissions.checkNotificationPermission();
    if (!hasPermission) {
      _showPermissionDeniedDialog();
    }
    // await AlarmPermissions.checkNotificationPermission();

    if (Alarm.android) {
      await AlarmPermissions.checkAndroidScheduleExactAlarmPermission();
    }
    setState(() {
      _permissionsChecked = true;
    });
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notification Permission is not opened yet.'),
        content: Text('請前往設定開啟通知權限以確保提醒功能正常運作.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("確定"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _initializePermissions(); // 修正會被權限請求設定阻塞造成程式不正常的狀況
    _startPermissionCheckTimer();
    _initializeServices();

    unawaited(loadAlarms());
    ringSubscription ??= Alarm.ringing.listen(ringingAlarmsChanged);
    updateSubscription ??= Alarm.scheduled.listen((_) {
      unawaited(loadAlarms());
    });

    // Set up periodic refresh for medications
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _loadMedications();
    });
  }

  void _startPermissionCheckTimer() {
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer =
        Timer.periodic(Duration(seconds: 10), (timer) async {
      bool hasPermission = await AlarmPermissions.checkNotificationPermission();
      if (!hasPermission) {
        _showPermissionDeniedDialog();
      }
    });
  }

  Future<void> _initializeServices() async {
    _googleSheetsService = GoogleSheetsService(
      spreadsheetId: spreadsheetId,
      sheetName: 'Sheet1',
    );

    _medicationAlarmService = MedicationAlarmService(
      sheetsService: _googleSheetsService,
    );

    await _googleSheetsService.initialize();
    await _medicationAlarmService.initialize();

    // Load initial medications
    await _loadMedications();
  }

  Future<void> _loadMedications() async {
    setState(() {
      isLoading = true;
    });

    try {
      final meds = await _googleSheetsService.getMedicationData();
      setState(() {
        medications = meds;
        isLoading = false;
      });
      _log.info('Loaded ${medications.length} medications');
    } catch (e) {
      _log.severe('Failed to load medications: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadAlarms() async {
    final updatedAlarms = await Alarm.getAlarms();
    updatedAlarms.sort((a, b) => a.dateTime.isBefore(b.dateTime) ? 0 : 1);
    setState(() {
      alarms = updatedAlarms;
    });
  }

  Future<void> ringingAlarmsChanged(AlarmSet alarms) async {
    if (alarms.alarms.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            ExampleAlarmRingScreen(alarmSettings: alarms.alarms.first),
      ),
    );
    unawaited(loadAlarms());
  }

  Future<void> navigateToAlarmScreen(AlarmSettings? settings) async {
    final res = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: ExampleAlarmEditScreen(alarmSettings: settings),
        );
      },
    );

    if (res != null && res == true) unawaited(loadAlarms());
  }

  @override
  void dispose() {
    ringSubscription?.cancel();
    updateSubscription?.cancel();
    _refreshTimer?.cancel();
    _googleSheetsService.dispose();
    _medicationAlarmService.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('⏰用藥提醒'),
          bottom: const TabBar(
            tabs: [
              // Tab(text: '🔔提醒\n'), //Alarms
              Tab(child: Text('🔔提醒\n', style: TextStyle(fontSize: 24))),
              // Tab(text: '💊藥品\n'), //Medications
              Tab(child: Text('💊藥品\n', style: TextStyle(fontSize: 24))),
              // Tab(text: '🛠️設定\n'), //Settings
              Tab(child: Text('🛠️設定\n', style: TextStyle(fontSize: 24))),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildAlarmsTab(),
              _buildMedicationsTab(),
              _buildSettingsTab(),
            ],
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FloatingActionButton(
                onPressed: _loadMedications,
                backgroundColor: Colors.green,
                heroTag: 'refresh',
                child: const Icon(Icons.refresh),
              ),
              const FloatingActionButton(
                onPressed: Alarm.stopAll,
                backgroundColor: Colors.red,
                heroTag: 'stopAll',
                child: Text(
                  'STOP ALL',
                  textScaler: TextScaler.linear(0.9),
                  textAlign: TextAlign.center,
                ),
              ),
              FloatingActionButton(
                onPressed: () => navigateToAlarmScreen(null),
                heroTag: 'addAlarm',
                child: const Icon(Icons.alarm_add_rounded, size: 33),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildAlarmsTab() {
    return alarms.isNotEmpty
        ? ListView.separated(
            itemCount: alarms.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return ExampleAlarmTile(
                key: Key(alarms[index].id.toString()),
                title: TimeOfDay(
                  hour: alarms[index].dateTime.hour,
                  minute: alarms[index].dateTime.minute,
                ).format(context),
                onPressed: () => navigateToAlarmScreen(alarms[index]),
                onDismissed: () {
                  Alarm.stop(alarms[index].id).then((_) => loadAlarms());
                },
              );
            },
          )
        : Center(
            child: Text(
              'No alarms set',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
  }

  Widget _buildMedicationsTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (medications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '無藥丸資料',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadMedications,
              child: const Text('更新'),
            ),
          ],
        ),
      );
    }
    // Group medications by date
    final Map<String, List<Medication>> groupedMeds = {};
    for (var med in medications) {
      final dateString = '${med.date.year}-${med.date.month}-${med.date.day}';
      groupedMeds[dateString] = [...(groupedMeds[dateString] ?? []), med];
    }

    return ListView.builder(
      itemCount: groupedMeds.length,
      itemBuilder: (context, index) {
        final dateString = groupedMeds.keys.elementAt(index);
        final dateItems = groupedMeds[dateString]!;

        return ExpansionTile(
          title: Text('日期: $dateString'),
          children: dateItems.map((med) => _buildMedicationTile(med)).toList(),
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
                child: ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('用餐時段設定'),
              subtitle: const Text('設定各餐前後服藥提醒時間'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MealTimeSettingsScreen(),
                  ),
                );
              },
            )),
            const SizedBox(height: 8),
            const Text('點擊以下按鈕測試對應時段提醒(5秒後觸發)'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton('早餐前'),
                _buildTestButton('早餐後'),
                _buildTestButton('午餐前'),
                _buildTestButton('午餐後'),
                _buildTestButton('晚餐前'),
                _buildTestButton('晚餐後'),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncMedicationsToAlarms,
              icon: const Icon(Icons.sync),
              label: const Text('同步所有未服用藥物通知'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            )
          ],
        ));
  }

  Widget _buildTestButton(String timeSlot) {
    return ElevatedButton(
      onPressed: () async {
        int alarmId =
            await MedicationNotificationService.testNotification(timeSlot);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已設置${timeSlot}測試提醒，5秒後觸發')),
        );
      },
      child: Text(timeSlot),
    );
  }

  Future<void> _syncMedicationsToAlarms() async {
    setState(() {
      isLoading = true;
    });
    try {
      List<int> createdAlarms =
          await MedicationNotificationService.updateMedicationAlarms(
              medications);
      await loadAlarms();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已同步 ${createdAlarms.length}個藥物提醒'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失敗: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildMedicationTile(Medication medication) {
    //生成藥名顯示字串: 中文(英文)
    List<String> formattedNames = medication.medications.map((med) {
      String localName = medication.getLocalizedMedicationName(med);
      return localName == med ? med : "$localName ($med)";
    }).toList();

    return ListTile(
      title: Text('Compartment: ${medication.compartment}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('藥名: ${formattedNames.join(", ")}'),
          Text('數量: ${medication.count}'),
          Text('是否服用: ${medication.taken ? "是" : "否"}'),
          Text('Timestamp: ${medication.timestamp}'),
        ],
      ),
      trailing: medication.taken
          ? const Icon(Icons.check_circle, color: Colors.green, size: 48)
          : const Icon(Icons.warning, color: Colors.orange, size: 48),
    );
  }
}
