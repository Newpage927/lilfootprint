// lib/main.dart
import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/home_screen.dart';
import 'screens/records_screen.dart';
import 'screens/record_history_screen.dart';
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
        Locale('en'),
        Locale('zh'),
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

  final List<Widget> _pages = [
    const HomeScreen(),   // 1. 個人化推薦
    const RecordsScreen(),// 2. 育兒紀錄 + 照片
    const RecordHistoryScreen(), // 2.5 紀錄歷史
    const PlacesMapView(),    // 3. 地圖
    const AiChatScreen(), // 4. AI Chat
  ];

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = screenWidth / 5;
    return Container(
      decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('image/background.png'),
        fit: BoxFit.cover,
        repeat: ImageRepeat.repeat,
      ),
    ),
    child:Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (itemWidth * _currentIndex) + (itemWidth / 2) - 30, 
            top: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xff4F000B),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: const Color(0xff4F000B),
            indicatorColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: Color(0x80DBC8B6)),
                selectedIcon: Icon(Icons.home, color: Color(0xffDBC8B6)),
                label: '推薦',
              ),
              NavigationDestination(
                icon: Icon(Icons.photo_camera_back_outlined, color: Color(0x80DBC8B6)),
                selectedIcon: Icon(Icons.photo_camera_back, color: Color(0xffDBC8B6)),
                label: '紀錄',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart_outline, color: Color(0x80DBC8B6)),
                selectedIcon: Icon(Icons.pie_chart, color: Color(0xffDBC8B6)),
                label: '分析',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined, color: Color(0x80DBC8B6)),
                selectedIcon: Icon(Icons.map, color: Color(0xffDBC8B6)),
                label: '地圖',
              ),
              NavigationDestination(
                icon: Icon(Icons.smart_toy_outlined, color: Color(0x80DBC8B6)),
                selectedIcon: Icon(Icons.smart_toy, color: Color(0xffDBC8B6)),
                label: 'AI 助手',
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}