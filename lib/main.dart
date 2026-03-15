// lib/main.dart
import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/home_screen.dart';
import 'screens/records_screen.dart';
import 'screens/map_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const ParentingApp());
}

class ParentingApp extends StatelessWidget {
  const ParentingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainScaffold(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // 英文
        Locale('zh'), // 中文
      ],
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  // 這裡定義新的 4 個頁面
  final List<Widget> _pages = [
    const HomeScreen(),   // 1. 個人化推薦
    const RecordsScreen(),// 2. 育兒紀錄 + 照片
    const PlacesMapView(),    // 3. 地圖
    const AiChatScreen(), // 4. AI Chat
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '推薦',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_camera_back_outlined), // 紀錄改用這個圖示更像相簿/紀錄
            selectedIcon: Icon(Icons.photo_camera_back),
            label: '紀錄',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '地圖',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined), // AI 用機器人或星星圖示
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI 助手',
          ),
        ],
      ),
    );
  }
}