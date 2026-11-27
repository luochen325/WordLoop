import 'package:material_ui/material_ui.dart';

import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _serverController;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: appState.serverUrl);
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: '内容服务'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '后端地址',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _serverController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: 'http://192.168.1.10:8000',
                        filled: true,
                        fillColor: const Color(0xFFF7F7FC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saveServer,
                            child: const Text('保存'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _testing ? null : _testServer,
                            child: _testing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('测试连接'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '手机和电脑需要在同一 Wi-Fi 下。电脑运行后端后，在命令行执行 ipconfig 查看 IPv4 地址。',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: '学习计划'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '每日新词',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${appState.dailyNewGoal} 个',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.seed,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: appState.dailyNewGoal.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      label: '${appState.dailyNewGoal}',
                      onChanged: (value) => appState.setDailyNewGoal(value.round()),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '学习时自动生成配图',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      subtitle: const Text(
                        '打开后进入每个新词会自动生成场景图，每张约 0.25 元',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      value: appState.autoImageOnStudy,
                      onChanged: appState.setAutoImageOnStudy,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '首轮间隔打散',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      subtitle: const Text(
                        '新词第一次复习按难度分散到 1~3 天后，避免全部堆在明天；关闭则完全按官方首次 1 天策略',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      value: appState.staggerFirstInterval,
                      onChanged: appState.setStaggerFirstInterval,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: '复习提醒'),
              AppCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '每日提醒',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      subtitle: const Text(
                        '只在当天有待复习单词时，于设定时间提醒',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      value: appState.reminderEnabled,
                      onChanged: (value) => appState.setReminder(
                        appState.reminderHour,
                        appState.reminderMinute,
                        value,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '提醒时间',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      trailing: Text(
                        '${appState.reminderHour.toString().padLeft(2, '0')}:'
                        '${appState.reminderMinute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.seed,
                        ),
                      ),
                      onTap: _pickTime,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '发送测试通知',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      trailing: const Icon(Icons.notifications_active_outlined,
                          color: AppColors.seed),
                      onTap: () async {
                        await appState.notifications.showTest();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已发送测试通知（部分系统需授权通知权限）'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: '发音'),
              AppCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '自动发音',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  subtitle: const Text(
                    '点击单词或例句时使用系统 TTS 朗读',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  value: appState.ttsEnabled,
                  onChanged: appState.setTtsEnabled,
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: '演示工具'),
              AppCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bolt_rounded,
                          color: AppColors.amber),
                      title: const Text(
                        '把所有已学单词设为待复习',
                        style: TextStyle(fontSize: 14, color: AppColors.ink),
                      ),
                      subtitle: const Text(
                        '答辩演示时快速生成复习队列',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      onTap: () async {
                        await appState.makeAllDue();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '已将 ${appState.dueCount} 个单词设为待复习',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restart_alt_rounded,
                          color: AppColors.rose),
                      title: const Text(
                        '重置学习进度',
                        style: TextStyle(fontSize: 14, color: AppColors.ink),
                      ),
                      subtitle: const Text(
                        '清空所有记忆状态与复习记录',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      onTap: _confirmReset,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: '关于'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WordLoop',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '版本 1.1.0 · 基于 NGSL 2809 词',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '记忆算法：DHP / DSR 模型 + SSP-MMC 随机最短路径调度（KDD 2022）。\n'
                      '内容生成：通义千问生成单词讲解，通义万相生成配图。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveServer() async {
    await appState.setServerUrl(_serverController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('后端地址已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _testServer() async {
    await appState.setServerUrl(_serverController.text);
    setState(() => _testing = true);
    try {
      final data = await appState.testConnection();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '连接成功 · 大模型：${data['llm']} · 图片：${data['image']}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('连接失败：$error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: appState.reminderHour,
        minute: appState.reminderMinute,
      ),
    );
    if (picked == null) return;
    await appState.setReminder(
      picked.hour,
      picked.minute,
      appState.reminderEnabled,
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置学习进度？'),
        content: const Text('这会清空所有单词的记忆状态和复习记录，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.resetProgress();
    }
  }
}
