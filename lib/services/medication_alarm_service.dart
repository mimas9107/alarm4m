import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_sheets_service.dart';
import '../models/medication_model.dart';

// enum MealTime { morning, noon, evening }
enum MealTime {
  breakfastBefore,
  breakfastAfter,
  lunchBefore,
  lunchAfter,
  dinnerBefore,
  dinnerAfter
}

class MedicationAlarmService {
  static final _log = Logger('MedicationAlarmService');

  final GoogleSheetsService _sheetsService;
  Timer? _checkTimer;
  List<Medication> _medications = [];

  // // Configuration for meal times
  // final TimeOfDay _morningTime;
  // final TimeOfDay _noonTime;
  // final TimeOfDay _eveningTime;
  Map<MealTime, TimeOfDay> _mealTimes = {}; // 6時段版本
  final Duration _reminderWindow;

  MedicationAlarmService({
    required GoogleSheetsService sheetsService,
    // TimeOfDay morningTime = const TimeOfDay(hour: 8, minute: 0),
    // TimeOfDay noonTime = const TimeOfDay(hour: 12, minute: 0),
    // TimeOfDay eveningTime = const TimeOfDay(hour: 18, minute: 0),
    Duration reminderWindow = const Duration(minutes: 30),
  })  : _sheetsService = sheetsService,
        //  _morningTime = morningTime,
        //  _noonTime = noonTime,
        //  _eveningTime = eveningTime,
        _reminderWindow = reminderWindow;

  Future<void> initialize() async {
    try {
      await _loadMealTimeSettings();
      final initialized = await _sheetsService.initialize();
      if (!initialized) {
        _log.severe('Failed to initialize Google Sheets service');
        return;
      }

      // 修改檢查間隔為每分鐘檢查一次
      _checkTimer?.cancel();
      _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
        await _checkNextMedicationTime();
      });

      // 初始檢查
      await _checkNextMedicationTime();

      _log.info('Medication alarm service initialized successfully');
    } catch (e) {
      _log.severe('Failed to initialize medication alarm service: $e');
    }
  }

  Future<void> _loadMealTimeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _mealTimes = {
      MealTime.breakfastBefore:
          _stringToTimeOfDay(prefs.getString('breakfastBefore') ?? '7:30'),
      MealTime.breakfastAfter:
          _stringToTimeOfDay(prefs.getString('breakfastAfter') ?? '8:30'),
      MealTime.lunchBefore:
          _stringToTimeOfDay(prefs.getString('lunchBefore') ?? '11:30'),
      MealTime.lunchAfter:
          _stringToTimeOfDay(prefs.getString('lunchAfter') ?? '12:30'),
      MealTime.dinnerBefore:
          _stringToTimeOfDay(prefs.getString('dinnerBefore') ?? '17:30'),
      MealTime.dinnerAfter:
          _stringToTimeOfDay(prefs.getString('dinnerAfter') ?? '18:30'),
    };
    _log.info('Meal time settings loaded');
  }

  TimeOfDay _stringToTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  MealTime _getMealTimeForMedication(Medication medication) {
    String description = medication.medications.join(' ').toLowerCase();
    if (description.contains('早餐') && description.contains('前')) {
      return MealTime.breakfastBefore;
    } else if (description.contains("早餐") && description.contains("後")) {
      return MealTime.breakfastAfter;
    } else if (description.contains("午餐") && description.contains("前")) {
      return MealTime.lunchBefore;
    } else if (description.contains("午餐") && description.contains("後")) {
      return MealTime.lunchAfter;
    } else if (description.contains("晚餐") && description.contains("前")) {
      return MealTime.dinnerBefore;
    } else if (description.contains("晚餐") && description.contains("後")) {
      return MealTime.dinnerAfter;
    }
    // default to breakfast after
    return MealTime.breakfastAfter;
  }

  Future<void> _loadMedicationData() async {
    try {
      _medications = await _sheetsService.getMedicationData();
      _log.info('Loaded ${_medications.length} medication records');
    } catch (e) {
      _log.warning('Failed to load medication data: $e');
    }
  }

  Future<void> _checkNextMedicationTime() async {
    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;

      // 檢查所有用餐時段
      for (var mealTime in MealTime.values) {
        final scheduledTime = _mealTimes[mealTime]!;
        final scheduledMinutes = scheduledTime.hour * 60 + scheduledTime.minute;

        // 計算距離下一個服藥時間還有多久
        int minutesUntilNextDose = scheduledMinutes - currentMinutes;

        // 如果時間已過，計算到明天的時間
        if (minutesUntilNextDose < 0) {
          minutesUntilNextDose += 24 * 60;
        }

        // 只在接近服藥時間的時候（前15分鐘內）才進行詳細檢查
        if (minutesUntilNextDose <= 15) {
          await _checkMedicationSchedule(mealTime);
          _log.info(
              '檢查 ${_getMealTimeDisplayName(mealTime)} 的用藥時間，距離服藥時間還有 $minutesUntilNextDose 分鐘');
        }
      }
    } catch (e) {
      _log.warning('檢查下一個用藥時間時發生錯誤: $e');
    }
  }

  Future<void> _checkMedicationSchedule(MealTime mealTime) async {
    try {
      // 重新載入最新的用藥資料
      await _loadMedicationData();

      final now = DateTime.now();
      final scheduledTime = _mealTimes[mealTime]!;

      // 檢查是否在提醒時間範圍內
      if (_isWithinReminderWindow(now, scheduledTime)) {
        final todayMedications = _getTodayMedications(now, mealTime);

        if (todayMedications.isEmpty) {
          _log.info('今天 ${_getMealTimeDisplayName(mealTime)} 沒有需要服用的藥物');
          return;
        }

        // 檢查是否有未服用的藥物
        final unTakenMeds =
            todayMedications.where((med) => !med.taken).toList();
        if (unTakenMeds.isNotEmpty) {
          _setAlarmForMealTime(mealTime);
        }
      }
    } catch (e) {
      _log.warning('檢查用藥排程時發生錯誤: $e');
    }
  }

  bool _isWithinReminderWindow(DateTime now, TimeOfDay scheduledTime) {
    final currentMinutes = now.hour * 60 + now.minute;
    final scheduledMinutes = scheduledTime.hour * 60 + scheduledTime.minute;
    final difference = (currentMinutes - scheduledMinutes).abs();
    return difference <= _reminderWindow.inMinutes;
  }

  List<Medication> _getTodayMedications(DateTime now, MealTime mealTime) {
    return _medications
        .where((med) =>
            med.date.year == now.year &&
            med.date.month == now.month &&
            med.date.day == now.day &&
            _getMealTimeForMedication(med) == mealTime)
        .toList();
  }

  void _setAlarmForMealTime(MealTime mealTime) async {
    try {
      // Check if we already have an alarm for this meal time
      final prefs = await SharedPreferences.getInstance();
      final alarmIdKey = 'alarm_id_${mealTime.toString().split('.').last}';
      final existingAlarmId = prefs.getInt(alarmIdKey);

      if (existingAlarmId != null) {
        // Check if this alarm is still active
        final alarms = await Alarm.getAlarms();
        final alarmExists = alarms.any((alarm) => alarm.id == existingAlarmId);

        if (alarmExists) {
          _log.info('Alarm already exists for $mealTime');
          return;
        }
      }

      // Create a new alarm
      final alarmId = DateTime.now().millisecondsSinceEpoch % 10000;
      // final mealTimeString = mealTime.toString().split('.').last;
      final mealTimeString = _getMealTimeDisplayName(mealTime);

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime:
            DateTime.now().add(const Duration(seconds: 5)), // Trigger soon
        loopAudio: true,
        vibrate: true,
        assetAudioPath: 'assets/marimba.mp3',
        volumeSettings: VolumeSettings.fixed(volume: 0.8),
        warningNotificationOnKill: Platform.isIOS,
        notificationSettings: NotificationSettings(
          // title: 'Medication Reminder',
          title: ' 服 藥 提 醒 ! ',
          // body: 'Time to take your $mealTimeString medication!',
          body: ' 時間到了! 你要吃$mealTimeString的藥喔',
          icon: 'notification_icon',
        ),
      );

      final success = await Alarm.set(alarmSettings: alarmSettings);
      if (success) {
        _log.info('Set alarm for $mealTime medication');
        await prefs.setInt(alarmIdKey, alarmId);
      } else {
        _log.warning('Failed to set alarm for $mealTime medication');
      }
    } catch (e) {
      _log.severe('Error setting alarm: $e');
    }
  }

  //Convert MealTime enum to display name
  String _getMealTimeDisplayName(MealTime mealTime) {
    switch (mealTime) {
      case MealTime.breakfastBefore:
        return '早餐前';
      case MealTime.breakfastAfter:
        return "早餐後";
      case MealTime.lunchBefore:
        return "午餐前";
      case MealTime.lunchAfter:
        return "午餐後";
      case MealTime.dinnerBefore:
        return "晚餐前";
      case MealTime.dinnerAfter:
        return "晚餐後";
      default:
        return "用藥";
    }
  }

  Future<void> dispose() async {
    _checkTimer?.cancel();
  }
}
