import 'package:gsheets/gsheets.dart';
import 'package:background_fetch/background_fetch.dart';
import '../models/medication_model.dart';
import '../credential.dart';

class GoogleSheetsService {
  final String spreadsheetId;
  final String sheetName;
  late Worksheet _sheet;

  // static const _credentials = r'''
  // {
  //   "type": "service_account",
  //   "project_id": "your_project_id",
  //   "private_key_id": "your_private_key_id",
  //   "private_key": "-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n",
  //   "client_email": "your_client_email",
  //   "client_id": "your_client_id",
  //   "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  //   "token_uri": "https://oauth2.googleapis.com/token",
  //   "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  //   "client_x509_cert_url": "your_client_cert_url"
  // }
  // ''';

  GoogleSheetsService({
    required this.spreadsheetId,
    required this.sheetName,
  });

  Future<bool> initialize() async {
    try {
      final gsheets = GSheets(credentials);
      final ss = await gsheets.spreadsheet(spreadsheetId);
      _sheet = ss.worksheetByTitle(sheetName)!;
      return true;
    } catch (e) {
      print('Error initializing Google Sheets: $e');
      return false;
    }
  }

  Future<List<Medication>> getMedicationData() async {
    final rows = await _sheet.values.allRows();
    if (rows == null || rows.isEmpty) return [];

    return rows
        .skip(1) // Skip header row
        .map((row) => Medication.fromSheetRow(row))
        .toList();
  }

  Future<bool> updateMedicationStatus(int compartmentNumber, bool taken) async {
  try {
    // 獲取所有數據
    final rows = await _sheet.values.allRows();
    if (rows == null || rows.isEmpty) return false;
    
    // 尋找匹配的行
    int rowIndex = -1;
    for (int i = 1; i < rows.length; i++) {
      // 假設第一列是 compartment
      if (rows[i][0] == compartmentNumber.toString()) {
        rowIndex = i + 1; // +1 因為 gsheets 行索引從 1 開始
        break;
      }
    }
    
    if (rowIndex == -1) return false;
    
    // 更新已服用狀態 (假設 taken 列是第 13 列，即 M 列)
    await _sheet.values.insertValue(
      taken ? 'Yes' : 'No',
      column: 13, // 列 M - 假設這是 "Taken" 列
      row: rowIndex,
    );
    
    return true;
  } catch (e) {
    print('Error updating medication status: $e');
    return false;
  }
}

  
  
  // 背景提取功能
  void configureBackgroundFetch() {
    BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
        startOnBoot: true,
      ),
      _onBackgroundFetch,
      _onBackgroundFetchTimeout,
    );
  }

  Future<void> _onBackgroundFetch(String taskId) async {
    try {
      final medications = await getMedicationData();

      for (var medication in medications) {
        if (!medication.taken) {
          print('[提醒] 未服用藥物: ${medication.medications.join(', ')}');
          // TODO: 這裡可以加入通知功能
        }
      }
    } catch (e) {
      print('[BackgroundFetch] Error: $e');
    }
    BackgroundFetch.finish(taskId);
  }

  void _onBackgroundFetchTimeout(String taskId) {
    print('[BackgroundFetch] TIMEOUT: $taskId');
    BackgroundFetch.finish(taskId);
  }
  
  void dispose() {
    BackgroundFetch.stop();
  }
}
