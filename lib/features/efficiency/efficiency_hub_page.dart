import 'package:flutter/material.dart';

import '../achievement/achievement_page.dart';
import '../countdown/countdown_page.dart';
import '../habit/habit_page.dart';
import '../pomodoro/pomodoro_page.dart';

/// 效率工具聚合页：番茄专注 / 习惯 / 倒数日 / 成就勋章（均为真后端数据）。
class EfficiencyHubPage extends StatefulWidget {
  const EfficiencyHubPage({super.key});

  @override
  State<EfficiencyHubPage> createState() => _EfficiencyHubPageState();
}

class _EfficiencyHubPageState extends State<EfficiencyHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('效率工具'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '番茄专注'),
            Tab(text: '习惯打卡'),
            Tab(text: '倒数纪念日'),
            Tab(text: '成就勋章'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PomodoroPage(),
          HabitPage(),
          CountdownPage(),
          AchievementPage(),
        ],
      ),
    );
  }
}
