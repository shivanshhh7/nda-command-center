import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color bg = Color(0xFF050505);
const Color panel = Color(0xCC171717);
const Color red = Color(0xFFFF343B);
const Color muted = Color(0xFFAAAAAA);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(const AscendApp());
}

class AscendApp extends StatelessWidget {
  const AscendApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ASCEND', debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: red, secondary: Color(0xFFB18CFF), surface: panel),
      textTheme: ThemeData.dark().textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    ),
    home: const HomeShell(),
  );
}

class TaskData {
  TaskData(this.id, this.title, {this.done = false, this.category = 'Study', this.priority = 'Medium'});
  final String id;
  final String title;
  bool done;
  final String category;
  final String priority;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done, 'category': category, 'priority': priority};
  factory TaskData.fromJson(Map<String, dynamic> j) => TaskData(
    j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
    j['title']?.toString() ?? 'Task', done: j['done'] == true,
    category: j['category']?.toString() ?? 'Study', priority: j['priority']?.toString() ?? 'Medium');
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  bool ready = false;
  String username = 'Shivansh';
  String goalName = 'NDA 1 2027';
  int goalPercent = 72;
  String goalDate = '247 Days Left';
  String goalTargets = 'Target: 450+ (GAT)  |  100+ (Maths)';
  int xp = 50;
  int streak = 1;
  int focusMinutes = 50;
  int remaining = 50 * 60;
  int focusSeconds = 0;
  bool timerRunning = false;
  Timer? ticker;
  String backgroundMode = 'default';
  String? customBackgroundPath;
  double brightness = 0;
  double blur = 0;
  double darkness = .28;
  final picker = ImagePicker();
  final List<TaskData> tasks = [];
  final List<String> notes = [];

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { ticker?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    username = p.getString('username') ?? 'Shivansh';
    goalName = p.getString('goalName') ?? 'NDA 1 2027';
    goalPercent = p.getInt('goalPercent') ?? 72;
    goalDate = p.getString('goalDate') ?? '247 Days Left';
    goalTargets = p.getString('goalTargets') ?? 'Target: 450+ (GAT)  |  100+ (Maths)';
    xp = p.getInt('xp') ?? 50;
    streak = p.getInt('streak') ?? 1;
    focusMinutes = p.getInt('focusMinutes') ?? 50;
    remaining = p.getInt('remaining') ?? focusMinutes * 60;
    focusSeconds = p.getInt('focusSeconds') ?? 0;
    backgroundMode = p.getString('backgroundMode') ?? 'default';
    customBackgroundPath = p.getString('customBackgroundPath');
    brightness = p.getDouble('brightness') ?? 0;
    blur = p.getDouble('blur') ?? 0;
    darkness = p.getDouble('darkness') ?? .28;
    try {
      final raw = jsonDecode(p.getString('tasks') ?? '[]') as List;
      tasks.addAll(raw.map((e) => TaskData.fromJson(Map<String, dynamic>.from(e))));
    } catch (_) {}
    if (tasks.isEmpty) {
      tasks.addAll([
        TaskData('sample1', 'Maths – Differentiation (30 Q)', done: true),
        TaskData('sample2', 'GAT – History (Revise)', done: true),
        TaskData('sample3', 'C Language – Loops (Practice)', done: true),
        TaskData('sample4', 'English – Comprehension'),
        TaskData('sample5', 'Running – 5 km', category: 'Personal'),
      ]);
    }
    if (mounted) setState(() => ready = true);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('username', username);
    await p.setString('goalName', goalName);
    await p.setInt('goalPercent', goalPercent);
    await p.setString('goalDate', goalDate);
    await p.setString('goalTargets', goalTargets);
    await p.setInt('xp', xp);
    await p.setInt('streak', streak);
    await p.setInt('focusMinutes', focusMinutes);
    await p.setInt('remaining', remaining);
    await p.setInt('focusSeconds', focusSeconds);
    await p.setString('tasks', jsonEncode(tasks.map((e) => e.toJson()).toList()));
    await p.setString('backgroundMode', backgroundMode);
    if (customBackgroundPath != null) await p.setString('customBackgroundPath', customBackgroundPath!);
    await p.setDouble('brightness', brightness);
    await p.setDouble('blur', blur);
    await p.setDouble('darkness', darkness);
  }

  int get doneCount => tasks.where((t) => t.done).length;
  int get level => 1 + xp ~/ 250;
  String clock(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void toggleTask(TaskData task, bool value) {
    setState(() {
      if (task.done == value) return;
      task.done = value;
      // XP is awarded only on the transition from pending to complete.
      xp = math.max(0, xp + (value ? 10 : -10));
    });
    _save();
  }

  Future<void> addTask() async {
    final c = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF202020), title: const Text('Add task'),
      content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Task name')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Add'))],
    ));
    if (result != null && result.isNotEmpty) {
      setState(() => tasks.add(TaskData(DateTime.now().microsecondsSinceEpoch.toString(), result)));
      _save();
    }
    c.dispose();
  }

  void startTimer() {
    if (timerRunning) return;
    setState(() => timerRunning = true);
    ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (remaining <= 1) {
        t.cancel();
        setState(() { remaining = 0; timerRunning = false; focusSeconds += focusMinutes * 60; xp += 15; });
        _save();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Focus session complete · +15 XP')));
      } else {
        setState(() => remaining--);
      }
    });
  }
  void pauseTimer() { ticker?.cancel(); setState(() => timerRunning = false); _save(); }
  void resetTimer() { ticker?.cancel(); setState(() { timerRunning = false; remaining = focusMinutes * 60; }); _save(); }

  Future<void> chooseGalleryBackground() async {
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) return;
    setState(() { customBackgroundPath = file.path; backgroundMode = 'custom'; });
    await _save();
  }

  void resetBackground() {
    setState(() { backgroundMode = 'default'; customBackgroundPath = null; brightness = 0; blur = 0; darkness = .28; });
    _save();
  }

  Widget _glass({required Widget child, EdgeInsets padding = const EdgeInsets.all(16), double radius = 24}) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFF454545).withOpacity(.7)),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 5))],
    ), child: child);

  Widget _background({required Widget child}) {
    Widget image;
    if (backgroundMode == 'custom' && customBackgroundPath != null && File(customBackgroundPath!).existsSync()) {
      image = Image.file(File(customBackgroundPath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (backgroundMode == 'minimal') {
      image = const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF202020), bg, Color(0xFF080808)])));
    } else if (backgroundMode == 'gradient') {
      image = const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.topRight, radius: 1.2, colors: [Color(0xFF501619), bg, bg])));
    } else {
      image = const CustomPaint(painter: MountainPainter(), child: SizedBox.expand());
    }
    return Stack(fit: StackFit.expand, children: [
      if (blur > 0) ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: blur * 8, sigmaY: blur * 8), child: image) else image,
      Container(color: Colors.black.withOpacity(darkness.clamp(0, .85))),
      if (brightness > 0) Container(color: Colors.white.withOpacity((brightness * .25).clamp(0, .25))),
      child,
    ]);
  }

  Widget _brandHeader() => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
    const AscendMark(size: 43), const SizedBox(width: 10),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ASCEND', style: TextStyle(fontFamily: 'serif', fontSize: 27, letterSpacing: 1.5, height: 1)),
      SizedBox(height: 5), Text('EARN YOUR ELEVATION.', style: TextStyle(fontSize: 10, letterSpacing: 1.4, color: Color(0xFFCCCCCC))),
    ])),
    IconButton(onPressed: () => _showInfo('Notifications', 'Notification preferences will be expanded in a later phase.'), icon: const Icon(Icons.notifications_none, size: 27)),
    IconButton(onPressed: () => _showProfile(), icon: const Icon(Icons.account_circle_outlined, size: 30)),
  ]);

  Future<void> _showInfo(String title, String message) async => showDialog<void>(context: context, builder: (c) => AlertDialog(
    backgroundColor: const Color(0xFF202020), title: Text(title), content: Text(message),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))]));

  Future<void> _showProfile() async {
    final c = TextEditingController(text: username);
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF202020), title: const Text('Profile'),
      content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Display name')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save'))]));
    if (result != null && result.isNotEmpty) { setState(() => username = result); _save(); }
    c.dispose();
  }

  Widget _shortcut(IconData icon, String label, VoidCallback action, {Color color = Colors.white}) => Expanded(child: GestureDetector(
    onTap: action, child: _glass(radius: 22, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6), child: Column(children: [
      Icon(icon, size: 34, color: color), const SizedBox(height: 10), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.2)),
    ]))));

  Widget homePage() {
    final ratio = tasks.isEmpty ? 0.0 : doneCount / tasks.length;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 118), children: [
      _brandHeader(),
      const SizedBox(height: 24),
      Text(_greeting(), style: const TextStyle(fontSize: 20, color: Color(0xFFE4E4E4))),
      Text(username, style: const TextStyle(fontFamily: 'serif', fontSize: 43, fontWeight: FontWeight.w600, height: 1.1)),
      const SizedBox(height: 10),
      const Text('“Discipline today, Selection tomorrow.”', style: TextStyle(fontSize: 15, color: Color(0xFFCCCCCC))),
      Container(width: 70, height: 4, margin: const EdgeInsets.only(top: 15, bottom: 22), decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(8))),
      Row(children: [
        _shortcut(Icons.track_changes, 'Focus\nSession', () => setState(() => tab = 2)), const SizedBox(width: 10),
        _shortcut(Icons.menu_book_outlined, 'Study\nPlan', () => setState(() => tab = 1)), const SizedBox(width: 10),
        _shortcut(Icons.check_box_outlined, 'Tasks', () => setState(() => tab = 1)), const SizedBox(width: 10),
        _shortcut(Icons.bar_chart, 'Progress', () => setState(() => tab = 3), color: const Color(0xFFB18CFF)),
      ]),
      const SizedBox(height: 18),
      _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('♧  YOUR GOAL', style: TextStyle(color: muted, letterSpacing: 1.1, fontSize: 12)),
          IconButton(onPressed: _editGoal, icon: const Icon(Icons.arrow_forward, color: Colors.white)),
        ]),
        Text(goalName, style: const TextStyle(fontFamily: 'serif', fontSize: 30, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: goalPercent / 100, minHeight: 10, color: red, backgroundColor: const Color(0xFF373737)))), const SizedBox(width: 12), Text('$goalPercent%')]),
        const SizedBox(height: 12),
        Row(children: [const Icon(Icons.calendar_month_outlined, color: muted, size: 20), const SizedBox(width: 8), Text(goalDate, style: const TextStyle(fontSize: 12)), const Spacer(), const Icon(Icons.track_changes, size: 20), const SizedBox(width: 6), Flexible(child: Text(goalTargets, style: const TextStyle(fontSize: 11, color: muted), textAlign: TextAlign.end))]),
      ])),
      const SizedBox(height: 18),
      _glass(child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Today’s Plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), Text('$doneCount / ${tasks.length} Completed', style: const TextStyle(color: muted, fontSize: 12))]),
        const SizedBox(height: 8),
        ...tasks.take(5).map((t) => _taskRow(t)),
      ])),
      const SizedBox(height: 16),
      Row(children: [
        _statCard(Icons.local_fire_department, '$streak', 'Day Streak', red), const SizedBox(width: 10),
        _statCard(Icons.access_time, '${focusSeconds ~/ 3600}h ${(focusSeconds % 3600) ~/ 60}m', 'Study Today', const Color(0xFFB18CFF)), const SizedBox(width: 10),
        _statCard(Icons.bar_chart, '${(ratio * 100).round()}%', 'Daily Target', const Color(0xFFB18CFF)),
      ]),
    ]);
  }

  String _greeting() { final h = DateTime.now().hour; return h < 12 ? 'Good Morning,' : h < 17 ? 'Good Afternoon,' : 'Good Evening,'; }
  Widget _taskRow(TaskData t) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
    Checkbox(value: t.done, activeColor: red, onChanged: (v) => toggleTask(t, v ?? false)),
    Expanded(child: Text(t.title, style: TextStyle(fontSize: 13, color: t.done ? muted : Colors.white, decoration: t.done ? TextDecoration.lineThrough : null))),
    IconButton(visualDensity: VisualDensity.compact, onPressed: () => _showInfo('Task', t.title), icon: const Icon(Icons.play_arrow_rounded, size: 20)),
  ]));
  Widget _statCard(IconData icon, String value, String label, Color color) => Expanded(child: _glass(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), radius: 20, child: Column(children: [Icon(icon, color: color, size: 25), const SizedBox(height: 6), FittedBox(child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), const SizedBox(height: 3), Text(label, style: const TextStyle(color: muted, fontSize: 10))])));

  Future<void> _editGoal() async {
    final n = TextEditingController(text: goalName), p = TextEditingController(text: '$goalPercent'), d = TextEditingController(text: goalDate), t = TextEditingController(text: goalTargets);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF202020), title: const Text('Customize goal'), content: SingleChildScrollView(child: Column(children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'Goal name')), TextField(controller: p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Progress %')), TextField(controller: d, decoration: const InputDecoration(labelText: 'Countdown text')), TextField(controller: t, decoration: const InputDecoration(labelText: 'Targets'))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))]));
    if (ok == true) { setState(() { goalName = n.text; goalPercent = (int.tryParse(p.text) ?? goalPercent).clamp(0, 100); goalDate = d.text; goalTargets = t.text; }); _save(); }
    n.dispose(); p.dispose(); d.dispose(); t.dispose();
  }

  Widget plannerPage() => ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 118), children: [
    const Text('Study Plan', style: TextStyle(fontFamily: 'serif', fontSize: 32)), const Text('Plan your next move.', style: TextStyle(color: muted)), const SizedBox(height: 18),
    FilledButton.icon(onPressed: addTask, icon: const Icon(Icons.add), label: const Text('Add Task')),
    const SizedBox(height: 12), _glass(child: Column(children: tasks.map(_taskRow).toList())),
    const SizedBox(height: 18), _glass(child: ListTile(leading: const Icon(Icons.folder_open), title: const Text('Workspace'), subtitle: const Text('Subjects, projects and personal goals'), trailing: const Icon(Icons.chevron_right), onTap: () => _showInfo('Workspace', 'Custom workspaces will be expanded in a later phase.'))),
  ]);

  Widget focusPage() => ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 118), children: [
    const Text('Focus Session', style: TextStyle(fontFamily: 'serif', fontSize: 32)), const Text('Protect your attention.', style: TextStyle(color: muted)), const SizedBox(height: 20),
    _glass(padding: const EdgeInsets.all(26), child: Column(children: [const Text('FOCUS TIMER', style: TextStyle(color: muted, letterSpacing: 2)), const SizedBox(height: 20), Text(clock(remaining), style: const TextStyle(fontSize: 58, fontWeight: FontWeight.w300, letterSpacing: 5)), Text('$focusMinutes minute session', style: const TextStyle(color: muted)), const SizedBox(height: 24), Wrap(spacing: 12, children: [FilledButton(onPressed: timerRunning ? pauseTimer : startTimer, child: Text(timerRunning ? 'Pause' : 'Start')), OutlinedButton(onPressed: resetTimer, child: const Text('Reset')), TextButton(onPressed: _customizeFocus, child: const Text('Customize'))])])),
    const SizedBox(height: 14), _glass(child: ListTile(leading: const Icon(Icons.timelapse), title: const Text('Total focus time'), subtitle: Text('${focusSeconds ~/ 3600}h ${(focusSeconds % 3600) ~/ 60}m'))),
  ]);
  Future<void> _customizeFocus() async { final c = TextEditingController(text: '$focusMinutes'); final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF202020), title: const Text('Focus duration'), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutes (1–180)')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))])); if (ok == true) { final v = int.tryParse(c.text); if (v != null && v >= 1 && v <= 180) { ticker?.cancel(); setState(() { focusMinutes = v; remaining = v * 60; timerRunning = false; }); _save(); } } c.dispose(); }

  Widget insightsPage() => ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 118), children: [
    const Text('Analytics', style: TextStyle(fontFamily: 'serif', fontSize: 32)), const Text('Measure progress, not perfection.', style: TextStyle(color: muted)), const SizedBox(height: 18),
    _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$doneCount / ${tasks.length} tasks completed', style: const TextStyle(fontSize: 19)), const SizedBox(height: 12), LinearProgressIndicator(value: tasks.isEmpty ? 0 : doneCount / tasks.length, color: red, backgroundColor: Colors.white12), const SizedBox(height: 16), Text('Level $level  ·  $xp XP'), Text('Focus time: ${focusSeconds ~/ 3600}h ${(focusSeconds % 3600) ~/ 60}m'), Text('Current streak: $streak days')]))
  ]);

  Widget settingsPage() => ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 118), children: [
    const Text('More', style: TextStyle(fontFamily: 'serif', fontSize: 32)), const Text('Make ASCEND yours.', style: TextStyle(color: muted)), const SizedBox(height: 18),
    _settingTile(Icons.person_outline, 'Profile', '$username · Level $level', _showProfile),
    _settingTile(Icons.palette_outlined, 'Appearance', 'Themes and background customization', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppearancePage(
      backgroundMode: backgroundMode, customBackgroundPath: customBackgroundPath, brightness: brightness, blur: blur, darkness: darkness,
      onChooseGallery: chooseGalleryBackground,
      onChange: (mode, b, bl, d) { setState(() { backgroundMode = mode; brightness = b; blur = bl; darkness = d; }); _save(); },
      onReset: resetBackground,
    )))),
    _settingTile(Icons.notifications_none, 'Reminders & Notifications', 'Notification preferences', () => _showInfo('Notifications', 'Reminder scheduling will be implemented in a later phase.')),
    _settingTile(Icons.backup_outlined, 'Data & Backup', 'Export your local data', _exportBackup),
    _settingTile(Icons.info_outline, 'About ASCEND', 'Earn Your Elevation.', () => _showInfo('About ASCEND', 'ASCEND · Earn Your Elevation.')),
    const SizedBox(height: 26), const Center(child: Text('By Shivanshh ❤️', style: TextStyle(color: muted, letterSpacing: 1.2, fontFamily: 'serif', fontSize: 15))),
  ]);
  Widget _settingTile(IconData icon, String title, String subtitle, VoidCallback onTap) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _glass(padding: EdgeInsets.zero, child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle, style: const TextStyle(color: muted)), trailing: const Icon(Icons.chevron_right), onTap: onTap)));
  Future<void> _exportBackup() async { final data = jsonEncode({'username': username, 'xp': xp, 'streak': streak, 'tasks': tasks.map((e) => e.toJson()).toList()}); await Clipboard.setData(ClipboardData(text: data)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup data copied to clipboard.'))); }

  @override Widget build(BuildContext context) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [homePage(), plannerPage(), focusPage(), insightsPage(), settingsPage()];
    return Scaffold(body: _background(child: SafeArea(child: pages[tab])),
      floatingActionButton: tab == 0 ? FloatingActionButton(backgroundColor: red, foregroundColor: Colors.white, onPressed: addTask, child: const Icon(Icons.add, size: 32)) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(margin: const EdgeInsets.fromLTRB(14, 0, 14, 10), decoration: BoxDecoration(color: const Color(0xE8171717), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white24)), child: NavigationBar(height: 72, backgroundColor: Colors.transparent, indicatorColor: Colors.white12, selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: red), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Plan'),
        NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Focus'),
        NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Analytics'),
        NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'More'),
      ])));
  }
}

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key, required this.backgroundMode, required this.customBackgroundPath, required this.brightness, required this.blur, required this.darkness, required this.onChooseGallery, required this.onChange, required this.onReset});
  final String backgroundMode;
  final String? customBackgroundPath;
  final double brightness, blur, darkness;
  final Future<void> Function() onChooseGallery;
  final void Function(String mode, double brightness, double blur, double darkness) onChange;
  final VoidCallback onReset;
  @override State<AppearancePage> createState() => _AppearancePageState();
}
class _AppearancePageState extends State<AppearancePage> {
  late String mode;
  late double brightness, blur, darkness;
  @override void initState() { super.initState(); mode = widget.backgroundMode; brightness = widget.brightness; blur = widget.blur; darkness = widget.darkness; }
  void update() { widget.onChange(mode, brightness, blur, darkness); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: bg, appBar: AppBar(title: const Text('Appearance')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Background Customization', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)), const SizedBox(height: 5), const Text('Choose a background or use your own photo.', style: TextStyle(color: muted)), const SizedBox(height: 18),
      _choice('ASCEND Default', 'Signature mountain theme with red moon', 'default', Icons.landscape),
      _choice('Minimal Dark', 'Clean and distraction-free', 'minimal', Icons.dark_mode_outlined),
      _choice('Dark Gradient', 'Subtle crimson gradient', 'gradient', Icons.gradient),
      GestureDetector(onTap: () async { await widget.onChooseGallery(); if (mounted) setState(() => mode = 'custom'); }, child: _choiceCard('Custom (Gallery)', 'Choose a photo from your gallery', Icons.photo_library_outlined, mode == 'custom')),
      const SizedBox(height: 18),
      _glassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Customize Background', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), const SizedBox(height: 12), _slider('Brightness', brightness, (v) { setState(() => brightness = v); update(); }), _slider('Blur', blur, (v) { setState(() => blur = v); update(); }), _slider('Darkness', darkness, (v) { setState(() => darkness = v); update(); })])),
      const SizedBox(height: 14), OutlinedButton.icon(onPressed: () { setState(() { mode = 'default'; brightness = 0; blur = 0; darkness = .28; }); widget.onReset(); }, icon: const Icon(Icons.restart_alt), label: const Text('Reset to ASCEND Default')),
      const SizedBox(height: 8), const Text('Your selection is saved on this device.', style: TextStyle(color: muted, fontSize: 12), textAlign: TextAlign.center),
    ]));
  Widget _choice(String title, String subtitle, String value, IconData icon) => GestureDetector(onTap: () { setState(() => mode = value); update(); }, child: _choiceCard(title, subtitle, icon, mode == value));
  Widget _choiceCard(String title, String subtitle, IconData icon, bool selected) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF171717), borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? red : Colors.white24, width: selected ? 1.5 : 1)), child: Row(children: [Icon(icon, color: selected ? red : Colors.white70, size: 27), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Text(subtitle, style: const TextStyle(color: muted, fontSize: 12))])), Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? red : muted)]));
  Widget _glassPanel({required Widget child}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF171717), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)), child: child);
  Widget _slider(String label, double value, ValueChanged<double> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text('${(value * 100).round()}%', style: const TextStyle(color: muted))]), Slider(value: value.clamp(0.0, 1.0).toDouble(), onChanged: onChanged, activeColor: red),]);
}

class AscendMark extends StatelessWidget {
  const AscendMark({super.key, this.size = 42});
  final double size;
  @override Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _MarkPainter());
}
class _MarkPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = s.width * .075..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(s.width*.08, s.height*.78)..lineTo(s.width*.47, s.height*.10)..lineTo(s.width*.91, s.height*.78)..lineTo(s.width*.68, s.height*.70)..lineTo(s.width*.51, s.height*.49)..lineTo(s.width*.32, s.height*.70)..close();
    canvas.drawPath(path, p);
    final inner = Path()..moveTo(s.width*.35, s.height*.69)..lineTo(s.width*.52, s.height*.58)..lineTo(s.width*.69, s.height*.69);
    canvas.drawPath(inner, p..strokeWidth = s.width*.055);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MountainPainter extends CustomPainter {
  const MountainPainter();
  @override void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF101116), Color(0xFF070708), Color(0xFF020202)]).createShader(rect));
    final moon = Offset(size.width*.79, size.height*.19);
    canvas.drawCircle(moon, size.width*.105, Paint()..color = const Color(0xFFE5232B));
    canvas.drawCircle(moon.translate(-size.width*.018, -size.width*.015), size.width*.092, Paint()..color = const Color(0x22FFB0B0));
    final cloudPaint = Paint()..color = const Color(0xFF55565D).withOpacity(.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    for (int i=0; i<6; i++) { canvas.drawOval(Rect.fromCenter(center: Offset(size.width*(.47+i*.075), size.height*(.20+i*.025)), width: size.width*.27, height: size.height*.045), cloudPaint); }
    final mountain = Path()..moveTo(0,size.height*.47)..lineTo(size.width*.20,size.height*.37)..lineTo(size.width*.31,size.height*.42)..lineTo(size.width*.52,size.height*.20)..lineTo(size.width*.60,size.height*.31)..lineTo(size.width*.77,size.height*.12)..lineTo(size.width*.88,size.height*.31)..lineTo(size.width,size.height*.39)..lineTo(size.width,size.height*.68)..lineTo(0,size.height*.68)..close();
    canvas.drawPath(mountain, Paint()..shader = const LinearGradient(begin: Alignment.topLeft,end: Alignment.bottomRight,colors:[Color(0xFF8E929A),Color(0xFF24262D),Color(0xFF08090B)]).createShader(rect));
    final snow = Path()..moveTo(size.width*.52,size.height*.20)..lineTo(size.width*.49,size.height*.29)..lineTo(size.width*.55,size.height*.265)..lineTo(size.width*.58,size.height*.34)..lineTo(size.width*.61,size.height*.30)..lineTo(size.width*.77,size.height*.12)..lineTo(size.width*.70,size.height*.30)..lineTo(size.width*.66,size.height*.27)..lineTo(size.width*.62,size.height*.39)..lineTo(size.width*.59,size.height*.31)..lineTo(size.width*.55,size.height*.34)..close();
    canvas.drawPath(snow, Paint()..color = const Color(0xFFE1E2E5));
    final ridge = Path()..moveTo(0,size.height*.50)..lineTo(size.width*.22,size.height*.41)..lineTo(size.width*.36,size.height*.49)..lineTo(size.width*.53,size.height*.34)..lineTo(size.width*.70,size.height*.46)..lineTo(size.width*.88,size.height*.34)..lineTo(size.width,size.height*.42)..lineTo(size.width,size.height*.75)..lineTo(0,size.height*.75)..close();
    canvas.drawPath(ridge, Paint()..color = const Color(0xFF090A0D));
    canvas.drawRect(Rect.fromLTWH(0,size.height*.60,size.width,size.height*.40), Paint()..shader = LinearGradient(begin: Alignment.topCenter,end: Alignment.bottomCenter,colors:[Colors.black.withOpacity(.05),Colors.black]).createShader(rect));
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
