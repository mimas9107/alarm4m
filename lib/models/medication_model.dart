bool mydebug = false;

class Medication {
  final int compartment;
  final int count;
  final List<String> medications;
  final DateTime timestamp;
  final DateTime date;
  final bool taken;
  static const Map<String, String> medication_name = {
    "Madopar": "美道普錠",
    "Norvasc": "脈優",
    "Diovan": "得安穩",
    "Isobide": "易適倍錠",
    "Diphenidol": "敵芬尼朵",
    "Tulip": "妥寧"
  };

  Medication({
    required this.compartment,
    required this.count,
    required this.medications,
    required this.timestamp,
    required this.date,
    required this.taken,
  });
  // 獲取藥物中文名
  String getLocalizedMedicationName(String name) {
    return medication_name[name] ?? name;
  }

  // 獲取所有藥物的本地名稱列表
  List<String> getLocalizedMedicationNames() {
    return medications.map((med) => getLocalizedMedicationName(med)).toList();
  }

  static DateTime? parseGoogleSheetsDate(String value) {
    try {
      final numValue = double.tryParse(value);
      if (numValue != null) {
        // Google Sheets 的日期基準點是 1899-12-30
        final epoch = DateTime.utc(1899, 12, 30);
        return epoch.add(Duration(milliseconds: (numValue * 86400000).toInt()));
      }
    } catch (e) {
      print('[parseGoogleSheetsDate] Error: $e, value: $value');
    }
    return null;
  }

  factory Medication.fromSheetRow(List<dynamic> row) {
    // Expected columns: compartment, count, medication, medication1, medication2...
    // timestamp, date, taken

    List<String> meds = [];
    // Start from the 'medication' column (index 2) and go through all medication columns
    for (int i = 2; i < 9; i++) {
      if (i < row.length && row[i] != null && row[i].toString().isNotEmpty) {
        meds.add(row[i].toString());
        print(row[i].toString());
      }
    }
    // print('====[medication_model.dart/Medication fromSheetRow]====');
    // print(parseGoogleSheetsDate(row[10].toString()));
    // print(parseGoogleSheetsDate(row[11].toString()));
    // print(row[12].toString().toLowerCase());
    // print('=======================================================');
    return Medication(
      compartment: int.parse(row[0].toString()),
      count: int.parse(row[1].toString()),
      medications: meds,
      // timestamp: DateTime.parse(row[10].toString()),
      // date: DateTime.parse(row[11].toString()),
      timestamp: parseGoogleSheetsDate(row[10].toString())!,
      date: parseGoogleSheetsDate(row[11].toString())!,
      taken: row[12].toString().toLowerCase() == 'yes' ? true : false,
    );
  }

  @override
  String toString() {
    return 'Compartment: $compartment, Count: $count, Medications: $medications, Timestamp: $timestamp, Date: $date, Taken: $taken';
  }
}
