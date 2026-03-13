import 'package:flutter/material.dart';
import '../config/theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('早安, 媽媽', style: TextStyle(fontSize: 14, color: AppTheme.subTextColor, fontWeight: FontWeight.normal)),
            const Text('育兒小幫手', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: AppTheme.surfaceColor,
              child: Icon(Icons.notifications_outlined, color: AppTheme.textColor),
            ),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBabyStatusCard(),
            const SizedBox(height: 24),
            const Text('快速紀錄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildQuickActionsGrid(context),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('近期活動', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () {}, child: const Text('查看全部', style: TextStyle(color: AppTheme.subTextColor))),
              ],
            ),
            _buildRecentActivityList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBabyStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.child_care, color: AppTheme.primaryColor, size: 30),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('寶寶 (小寶)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('3 個月 12 天', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('睡覺中', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      {'icon': Icons.local_dining, 'label': '餵奶', 'color': const Color(0xFFFF9AA2)},
      {'icon': Icons.baby_changing_station, 'label': '換尿布', 'color': const Color(0xFFFFB7B2)},
      {'icon': Icons.bed, 'label': '睡眠', 'color': const Color(0xFFFFDAC1)},
      {'icon': Icons.water_drop, 'label': '擠奶', 'color': const Color(0xFFE2F0CB)},
      {'icon': Icons.monitor_weight, 'label': '生長', 'color': const Color(0xFFB5EAD7)},
      {'icon': Icons.medical_services, 'label': '醫療', 'color': const Color(0xFFC7CEEA)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final item = actions[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('點擊了 ${item['label']}')));
            },
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item['icon'] as IconData, color: (item['color'] as Color), size: 28),
                ),
                const SizedBox(height: 8),
                Text(item['label'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivityList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_dining, color: AppTheme.subTextColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('親餵母乳', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('左側 15 分鐘', style: TextStyle(fontSize: 12, color: AppTheme.subTextColor)),
                ],
              ),
              const Spacer(),
              const Text('10:30', style: TextStyle(fontSize: 12, color: AppTheme.subTextColor)),
            ],
          ),
        );
      },
    );
  }
}