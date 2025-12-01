import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeOption {
  light,
  dark,
  auto, // 朝・昼はライト、夜はダーク
}

class ThemeService extends ChangeNotifier {
  ThemeOption _themeOption = ThemeOption.light;
  
  ThemeOption get themeOption => _themeOption;
  
  ThemeMode get themeMode {
    if (_themeOption == ThemeOption.auto) {
      return _getAutoThemeMode();
    }
    return _themeOption == ThemeOption.dark ? ThemeMode.dark : ThemeMode.light;
  }
  
  bool get isDarkMode => themeMode == ThemeMode.dark;

  ThemeService() {
    _loadThemeMode();
  }

  ThemeMode _getAutoThemeMode() {
    final hour = DateTime.now().hour;
    // 6時〜18時: ライトモード、18時〜6時: ダークモード
    if (hour >= 6 && hour < 18) {
      return ThemeMode.light;
    } else {
      return ThemeMode.dark;
    }
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeValue = prefs.getString('themeOption') ?? 'light';
      
      switch (themeValue) {
        case 'dark':
          _themeOption = ThemeOption.dark;
          break;
        case 'auto':
          _themeOption = ThemeOption.auto;
          break;
        default:
          _themeOption = ThemeOption.light;
      }
      
      notifyListeners();
    } catch (e) {
      // デフォルトのライトモードを使用
    }
  }

  Future<void> toggleTheme() async {
    // ライト → ダーク → 自動 → ライト
    switch (_themeOption) {
      case ThemeOption.light:
        _themeOption = ThemeOption.dark;
        break;
      case ThemeOption.dark:
        _themeOption = ThemeOption.auto;
        break;
      case ThemeOption.auto:
        _themeOption = ThemeOption.light;
        break;
    }
    
    notifyListeners();
    await _saveThemeOption();
  }

  Future<void> setThemeOption(ThemeOption option) async {
    _themeOption = option;
    notifyListeners();
    await _saveThemeOption();
  }

  Future<void> _saveThemeOption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeValue;
      
      switch (_themeOption) {
        case ThemeOption.dark:
          themeValue = 'dark';
          break;
        case ThemeOption.auto:
          themeValue = 'auto';
          break;
        default:
          themeValue = 'light';
      }
      
      await prefs.setString('themeOption', themeValue);
    } catch (e) {
      // エラーハンドリング
    }
  }
  
  String getThemeDisplayNameKey() {
    switch (_themeOption) {
      case ThemeOption.light:
        return 'light_mode';
      case ThemeOption.dark:
        return 'dark_mode';
      case ThemeOption.auto:
        return 'auto_mode';
    }
  }
}
