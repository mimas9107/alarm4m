import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartpillbox_alarm/screens/medication_home.dart';
import 'package:smartpillbox_alarm/utils/logging.dart';
import 'package:smartpillbox_alarm/services/google_sheets_service.dart';
import 'package:smartpillbox_alarm/services/medication_alarm_service.dart';
import 'credential.dart';

// This is your Google Sheets ID and sheet name
// const String SPREADSHEET_ID = spreadsheetId;
// const String SHEET_NAME = 'Sheet1';

// Configure meal times and reminder window
// const TimeOfDay MORNING_TIME = TimeOfDay(hour: 8, minute: 0);
// const TimeOfDay NOON_TIME = TimeOfDay(hour: 12, minute: 0);
// const TimeOfDay EVENING_TIME = TimeOfDay(hour: 18, minute: 0);
const Duration REMINDER_WINDOW = Duration(minutes: 30);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  setupLogging(showDebugLogs: true);
  

  await Alarm.init();

  // Initialize Google Sheets service
  final googleSheetsService = GoogleSheetsService(
    spreadsheetId: spreadsheetId,
    sheetName: 'Sheet1',
  );

  // Initialize medication alarm service
  final medicationAlarmService = MedicationAlarmService(
    sheetsService: googleSheetsService,
    // morningTime: MORNING_TIME,
    // noonTime: NOON_TIME,
    // eveningTime: EVENING_TIME,
    reminderWindow: REMINDER_WINDOW,
  );

  // Initialize services
  await medicationAlarmService.initialize();

  runApp(
    MaterialApp(
      theme: ThemeData(useMaterial3: false),
      home: const MedicationAlarmHomeScreen(),
    ),
  );
}