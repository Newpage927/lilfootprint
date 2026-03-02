import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFFE9E9E9); 
  static const secondaryColor = Color(0xFF2D2D2D); 
  static const surfaceColor = Color(0xFFFFF0F3); 
  static const backgroundColor = Color(0xFFFAFAFA); 
  static const textColor = Color(0xFF4A4A4A); 
  static const subTextColor = Color(0xFF9E9E9E); 

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
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
    );
  }
}