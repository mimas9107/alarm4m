import 'package:alarm/alarm.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:smartpillbox_alarm/models/medication_model.dart';

class MedicationNotificationService {
  // 餐前餐後時段標識
  static const String BEFORE_BREAKFAST = "早餐前";
  static const String AFTER_BREAKFAST = "早餐後";
  static const String BEFORE_LUNCH = "午餐前";
  static const String AFTER_LUNCH = "午餐後";
  static const String BEFORE_DINNER = "晚餐前";
  static const String AFTER_DINNER = "晚餐後";
  
  // 用於將藥物時段轉換為識別碼
  static Map<String, String> mealTimeMappings = {
    "早餐前": "breakfastBefore",
    "早餐後": "breakfastAfter",
    "午餐前": "lunchBefore",
    "午餐後": "lunchAfter",
    "晚餐前": "dinnerBefore",
    "晚餐後": "dinnerAfter",
  };
  
  // 獲取所有用餐時段設定
  static Future<Map<String, TimeOfDay>> getMealTimesSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'breakfastBefore': _stringToTimeOfDay(prefs.getString('breakfastBefore') ?? '7:30'),
      'breakfastAfter': _stringToTimeOfDay(prefs.getString('breakfastAfter') ?? '8:30'),
      'lunchBefore': _stringToTimeOfDay(prefs.getString('lunchBefore') ?? '11:30'),
      'lunchAfter': _stringToTimeOfDay(prefs.getString('lunchAfter') ?? '12:30'),
      'dinnerBefore': _stringToTimeOfDay(prefs.getString('dinnerBefore') ?? '17:30'),
      'dinnerAfter': _stringToTimeOfDay(prefs.getString('dinnerAfter') ?? '18:30'),
    };
  }
  
  // 將時間字符串轉換為 TimeOfDay
  static TimeOfDay _stringToTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
  
  // 根據藥物描述識別應該在哪個時段提醒
  static String identifyMedicationTimeSlot(Medication medication) {
    String description = medication.medications.join(" ").toLowerCase();
    
    // 這裡需要根據你的數據格式調整判斷邏輯
    if (description.contains("早餐") && description.contains("前")) {
      return BEFORE_BREAKFAST;
    } else if (description.contains("早餐") && description.contains("後")) {
      return AFTER_BREAKFAST;
    } else if (description.contains("午餐") && description.contains("前")) {
      return BEFORE_LUNCH;
    } else if (description.contains("午餐") && description.contains("後")) {
      return AFTER_LUNCH;
    } else if (description.contains("晚餐") && description.contains("前")) {
      return BEFORE_DINNER;
    } else if (description.contains("晚餐") && description.contains("後")) {
      return AFTER_DINNER;
    }
    
    // 默認為早餐後，或者根據其他邏輯判斷
    return AFTER_BREAKFAST;
  }
  
  // 為藥物創建鬧鐘
  static Future<int> createMedicationAlarm(Medication medication) async {
    // 識別時段
    String timeSlot = identifyMedicationTimeSlot(medication);
    String settingKey = mealTimeMappings[timeSlot] ?? 'breakfastAfter';
    
    // 獲取對應時段的時間設定
    Map<String, TimeOfDay> settings = await getMealTimesSettings();
    TimeOfDay alarmTime = settings[settingKey]!;
    
    // 計算鬧鐘時間
    DateTime now = DateTime.now();
    DateTime alarmDateTime = DateTime(
      medication.date.year,
      medication.date.month,
      medication.date.day,
      alarmTime.hour,
      alarmTime.minute,
    );
    
    // 如果時間已過，不設置鬧鐘
    if (alarmDateTime.isBefore(now)) {
      return -1;
    }
    
    // 生成唯一鬧鐘ID
    int alarmId = medication.hashCode; // 或其他方式確保唯一性
    
    // 設置鬧鐘
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarmId,
        dateTime: alarmDateTime,
        assetAudioPath: 'assets/marimba.mp3',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fixed(volume: 0.9),
        notificationSettings: NotificationSettings(
          title: '服藥提醒',
          body: '現在是${timeSlot}時間，請記得服用：${medication.medications.join(", ")}',
          icon: 'notification_icon',
        ),
        
      ),
    );
    
    return alarmId;
  }
  
  // 更新所有未服用藥物的鬧鐘
  static Future<List<int>> updateMedicationAlarms(List<Medication> medications) async {
    List<int> createdAlarmIds = [];
    
    // 先獲取所有現有鬧鐘
    List<AlarmSettings> existingAlarms = await Alarm.getAlarms();
    
    // 對於每個未服用的藥物
    for (var med in medications) {
      if (!med.taken) {
        int alarmId = await createMedicationAlarm(med);
        if (alarmId > 0) {
          createdAlarmIds.add(alarmId);
        }
      }
    }
    
    return createdAlarmIds;
  }
  
  // 測試提醒觸發 - 方便快速測試指定時段的提醒
  static Future<int> testNotification(String timeSlot) async {
    Map<String, TimeOfDay> settings = await getMealTimesSettings();
    String settingKey = mealTimeMappings[timeSlot] ?? 'breakfastAfter';
    TimeOfDay alarmTime = settings[settingKey]!;
    
    // 設置一個5秒後觸發的測試鬧鐘
    DateTime testTime = DateTime.now().add(const Duration(seconds: 5));
    
    int testAlarmId = DateTime.now().millisecondsSinceEpoch % 10000;
    
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: testAlarmId,
        dateTime: testTime,
        assetAudioPath: 'assets/marimba.mp3',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fixed(volume:0.9),
        notificationSettings: NotificationSettings(
          title: '測試提醒', 
          body: '這是${timeSlot}時段的測試提醒 (原設置時間 ${alarmTime.hour}:${alarmTime.minute})',
          icon: 'notification_icon',
          ),
        
      ),
    );
    
    return testAlarmId;
  }
}