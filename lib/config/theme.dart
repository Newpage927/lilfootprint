import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFFFF8C00); 
  static const secondaryColor = Color(0xFF2D2D2D); 
  static const surfaceColor = Color(0xFFFFF0F3); 
  static const backgroundColor = Color(0xFFFAFAFA); 
  static const textColor = Color(0xFF4F000B); 
  static const subTextColor = Color(0xFF9E9E9E); 

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        background: backgroundColor,
        surface: Colors.white,
        onSurface: textColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        centerTitle: false, 
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0, 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), 
          side: BorderSide(color: Colors.grey.shade100), 
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Colors.transparent, // 隱藏選中時的背景底色
        // 如果您想連點擊時的「水波紋」反饋也一併拿掉，可以設定：
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        // 設定未選中時的文字樣式
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: Color(0xffDBC8B6), fontWeight: FontWeight.bold);
          }
          return const TextStyle(color:Color(0x80DBC8B6)); // 未選中時稍淡一點
        }),
        // 設定圖示顏色
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xffDBC8B6));
          }
          return const IconThemeData(color: Color(0x80DBC8B6));
        }),
      ),
    );
  }
}