import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MealTimeSettingsScreen extends StatefulWidget {
  const MealTimeSettingsScreen({super.key});

  @override
  State<MealTimeSettingsScreen> createState() => _MealTimeSettingsScreenState();
}

class _MealTimeSettingsScreenState extends State<MealTimeSettingsScreen> {
  // 六個時段的默認設定
  TimeOfDay _breakfastBefore = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _breakfastAfter = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _lunchBefore = const TimeOfDay(hour: 11, minute: 30);
  TimeOfDay _lunchAfter = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay _dinnerBefore = const TimeOfDay(hour: 17, minute: 30);
  TimeOfDay _dinnerAfter = const TimeOfDay(hour: 18, minute: 30);
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedTimes();
  }

  Future<void> _loadSavedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _breakfastBefore = _stringToTimeOfDay(prefs.getString('breakfastBefore') ?? '7:30');
      _breakfastAfter = _stringToTimeOfDay(prefs.getString('breakfastAfter') ?? '8:30');
      _lunchBefore = _stringToTimeOfDay(prefs.getString('lunchBefore') ?? '11:30');
      _lunchAfter = _stringToTimeOfDay(prefs.getString('lunchAfter') ?? '12:30');
      _dinnerBefore = _stringToTimeOfDay(prefs.getString('dinnerBefore') ?? '17:30');
      _dinnerAfter = _stringToTimeOfDay(prefs.getString('dinnerAfter') ?? '18:30');
      _isLoading = false;
    });
  }
  
  // 將時間字符串轉換為 TimeOfDay
  TimeOfDay _stringToTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
  // 保存設定到 SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('breakfastBefore', '${_breakfastBefore.hour}:${_breakfastBefore.minute}');
    await prefs.setString('breakfastAfter', '${_breakfastAfter.hour}:${_breakfastAfter.minute}');
    await prefs.setString('lunchBefore', '${_lunchBefore.hour}:${_lunchBefore.minute}');
    await prefs.setString('lunchAfter', '${_lunchAfter.hour}:${_lunchAfter.minute}');
    await prefs.setString('dinnerBefore', '${_dinnerBefore.hour}:${_dinnerBefore.minute}');
    await prefs.setString('dinnerAfter', '${_dinnerAfter.hour}:${_dinnerAfter.minute}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('用餐時間設定已保存')),
    );
  }
  // 顯示時間選擇器
  Future<void> _selectTime(BuildContext context, String timeLabel) async {
    TimeOfDay initialTime;
    
    // 根據標籤獲取當前時間設定
    switch (timeLabel) {
      case 'breakfastBefore':
        initialTime = _breakfastBefore;
        break;
      case 'breakfastAfter':
        initialTime = _breakfastAfter;
        break;
      case 'lunchBefore':
        initialTime = _lunchBefore;
        break;
      case 'lunchAfter':
        initialTime = _lunchAfter;
        break;
      case 'dinnerBefore':
        initialTime = _dinnerBefore;
        break;
      case 'dinnerAfter':
        initialTime = _dinnerAfter;
        break;
      default:
        initialTime = TimeOfDay.now();
    }
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() {
        switch (timeLabel) {
          case 'breakfastBefore':
            _breakfastBefore = picked;
            break;
          case 'breakfastAfter':
            _breakfastAfter = picked;
            break;
          case 'lunchBefore':
            _lunchBefore = picked;
            break;
          case 'lunchAfter':
            _lunchAfter = picked;
            break;
          case 'dinnerBefore':
            _dinnerBefore = picked;
            break;
          case 'dinnerAfter':
            _dinnerAfter = picked;
            break;
        }
      });
    }
  }
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('用餐時段設定'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '設定各餐前後服藥時間',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildMealTimeSection(
              title: '早餐時段', 
              beforeTime: _breakfastBefore, 
              afterTime: _breakfastAfter,
              beforeLabel: 'breakfastBefore',
              afterLabel: 'breakfastAfter',
            ),
            
            const Divider(height: 32),
            
            _buildMealTimeSection(
              title: '午餐時段', 
              beforeTime: _lunchBefore, 
              afterTime: _lunchAfter,
              beforeLabel: 'lunchBefore',
              afterLabel: 'lunchAfter',
            ),
            
            const Divider(height: 32),
            
            _buildMealTimeSection(
              title: '晚餐時段', 
              beforeTime: _dinnerBefore, 
              afterTime: _dinnerAfter,
              beforeLabel: 'dinnerBefore',
              afterLabel: 'dinnerAfter',
            ),
            
            const SizedBox(height: 32),
            
            Center(
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('保存設定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMealTimeSection({
    required String title,
    required TimeOfDay beforeTime,
    required TimeOfDay afterTime,
    required String beforeLabel,
    required String afterLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTimeCard(
                label: '餐前',
                time: beforeTime,
                onTap: () => _selectTime(context, beforeLabel),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimeCard(
                label: '餐後',
                time: afterTime,
                onTap: () => _selectTime(context, afterLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTimeCard({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTimeOfDay(time),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
