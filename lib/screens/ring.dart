import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:smartpillbox_alarm/models/medication_model.dart';
import 'package:smartpillbox_alarm/services/google_sheets_service.dart';
import '../credential.dart';

class ExampleAlarmRingScreen extends StatefulWidget {
  const ExampleAlarmRingScreen({required this.alarmSettings, super.key});
  final AlarmSettings alarmSettings;
  @override
  State<ExampleAlarmRingScreen> createState() => _ExampleAlarmRingScreenState();
}

class _ExampleAlarmRingScreenState extends State<ExampleAlarmRingScreen> {
  static final _log = Logger('ExampleAlarmRingScreenState');
  StreamSubscription<AlarmSet>? _ringingSubscription;

  List<Medication> _pendingMedications = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  late GoogleSheetsService _sheetsService;

  @override
  void initState() {
    super.initState();
    _ringingSubscription = Alarm.ringing.listen((alarms) {
      if (alarms.containsId(widget.alarmSettings.id)) return;
      _log.info('Alarm ${widget.alarmSettings.id} stopped ringing.');
      _ringingSubscription?.cancel();
      if (mounted) Navigator.pop(context);
    });

    _initializeGoogleSheets();
  }

  Future<void> _initializeGoogleSheets() async {
    _sheetsService = GoogleSheetsService(
      spreadsheetId: spreadsheetId,
      sheetName: 'Sheet1',
    );

    await _sheetsService.initialize();
    await _loadPendingMedications();
  }

  Future<void> _loadPendingMedications() async {
    try {
      final medications = await _sheetsService.getMedicationData();
      final now = DateTime.now();
      final todayMeds = medications.where((med) {
        return med.date.year == now.year &&
            med.date.month == now.month &&
            med.date.day == now.day &&
            !med.taken;
      }).toList();

      setState(() {
        _pendingMedications = todayMeds;
        _isLoading = false;
      });
    } catch (e) {
      _log.severe('Error loading medications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllMedicationsAsTaken() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      for (var medication in _pendingMedications) {
        await _sheetsService.updateMedicationStatus(
            medication.compartment, true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已標記所有藥物為已服用！')),
        );
      }

      _log.info('已標記所有藥物為已服用');
    } catch (e) {
      _log.severe('更新藥物狀態時發生錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失敗: $e')),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  void dispose() {
    _ringingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String timeSlot = '';
    if (widget.alarmSettings.notificationSettings?.body != null) {
      String body = widget.alarmSettings.notificationSettings!.body;
      // 解析通知內容，獲取時段信息
      if (body.contains('早餐前')) {
        timeSlot = '早餐前';
      } else if (body.contains('早餐後')) {
        timeSlot = '早餐後';
      } else if (body.contains('午餐前')) {
        timeSlot = '午餐前';
      } else if (body.contains('午餐後')) {
        timeSlot = '午餐後';
      } else if (body.contains('晚餐前')) {
        timeSlot = '晚餐前';
      } else if (body.contains('晚餐後')) {
        timeSlot = '晚餐後';
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 96),
                  const Text(
                    '🔔 服藥提醒 🔔',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '現在是 $timeSlot 服藥時間',
                    style: TextStyle(fontSize: 22, color: Colors.blue[700]),
                  ),
                ],
              ),
              _isLoading
                  ? CircularProgressIndicator()
                  : Expanded(
                      child: _pendingMedications.isEmpty
                          ? Center(
                              child: Text(
                                '今天沒有待服用的藥物',
                                style: TextStyle(fontSize: 18),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _pendingMedications.length,
                              itemBuilder: (context, index) {
                                final med = _pendingMedications[index];
                                return _buildMedicationCard(med);
                              },
                            ),
                    ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUpdating
                        ? null
                        : () async {
                            await Alarm.set(
                              alarmSettings: widget.alarmSettings.copyWith(
                                dateTime: DateTime.now()
                                    .add(const Duration(minutes: 5)),
                              ),
                            );
                            Navigator.pop(context);
                          },
                    icon: const Icon(Icons.snooze),
                    label: const Text('5分鐘後再提醒'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isUpdating
                        ? null
                        : () async {
                            await _markAllMedicationsAsTaken();
                            await Alarm.stop(widget.alarmSettings.id);
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                    icon: const Icon(Icons.check_circle),
                    label: _isUpdating ? Text('更新中...') : Text('已服用並關閉'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationCard(Medication medication) {
    // 獲取本地化藥物名稱
    List<String> formattedNames = medication.medications.map((med) {
      String localName = medication.getLocalizedMedicationName(med);
      return localName == med ? med : "$localName ($med)";
    }).toList();

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '藥盒格號: ${medication.compartment}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '數量: ${medication.count}',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            Divider(),
            Text(
              '藥品:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...formattedNames.map((name) => Padding(
                  padding: EdgeInsets.only(left: 10, top: 4),
                  child: Text('• $name', style: TextStyle(fontSize: 18)),
                )),
            SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed:
                    _isUpdating ? null : () => _markAllMedicationsAsTaken(),
                icon: Icon(Icons.check_circle),
                label: _isUpdating ? Text('更新中...') : Text('已服用並關閉'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: Size(200, 44),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
