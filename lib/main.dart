import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final notifications = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  await notifications.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ));
  runApp(const AscendApp());
}

const bg = Color(0xFF050505);
const panel = Color(0xFF151515);
const silver = Color(0xFFE5E5E5);
const muted = Color(0xFF999999);

class WorkItem {
  String id, name, category;
  int daily, weekly, monthly, done;
  WorkItem({required this.id, required this.name, required this.category,
    this.daily = 1, this.weekly = 5, this.monthly = 20, this.done = 0});
  Map<String, dynamic> toJson() => {'id':id,'name':name,'category':category,
    'daily':daily,'weekly':weekly,'monthly':monthly,'done':done};
  factory WorkItem.fromJson(Map<String,dynamic> j) => WorkItem(
    id:j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
    name:j['name'] ?? 'Untitled', category:j['category'] ?? 'Personal',
    daily:j['daily'] ?? 1, weekly:j['weekly'] ?? 5,
    monthly:j['monthly'] ?? 20, done:j['done'] ?? 0);
}

class TaskItem {
  String id, title, category, priority;
  bool done;
  TaskItem({required this.id, required this.title, this.category='General',
    this.priority='Medium', this.done=false});
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,'priority':priority,'done':done};
  factory TaskItem.fromJson(Map<String,dynamic> j)=>TaskItem(
    id:j['id'],title:j['title'],category:j['category']??'General',
    priority:j['priority']??'Medium',done:j['done']??false);
}

class AscendApp extends StatelessWidget {
  const AscendApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'ASCEND',
    theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,
      scaffoldBackgroundColor:bg, colorScheme:const ColorScheme.dark(
        primary:silver,secondary:Color(0xFFBDBDBD),surface:panel),
      fontFamily:'Roboto', appBarTheme:const AppBarTheme(
        backgroundColor:bg,foregroundColor:silver,elevation:0,centerTitle:false),
      cardTheme:CardThemeData(color:panel,elevation:0,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),
          side:const BorderSide(color:Color(0xFF292929)))),
      inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:panel,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),
          borderSide:BorderSide.none))),
    home:const HomeShell());
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override State<HomeShell> createState()=>_HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int tab=0;
  List<WorkItem> work=[];
  List<TaskItem> tasks=[];
  Set<String> completedDays={};
  String username='ASCENDER';
  int xp=0, focusSeconds=0, bestStreak=0;
  bool ready=false;
  int focusMinutes=50;
  Timer? ticker;
  int remaining=3000;
  bool running=false;
  final noteController=TextEditingController();
  List<String> notes=[];
  List<String> habits=[];
  Set<String> habitDone={};

  @override void initState(){super.initState();load();}
  @override void dispose(){ticker?.cancel();noteController.dispose();super.dispose();}
  String get today=>DateTime.now().toIso8601String().substring(0,10);
  int get streak {
    int n=0; DateTime d=DateTime.now();
    while(completedDays.contains(d.toIso8601String().substring(0,10))){
      n++; d=d.subtract(const Duration(days:1));
    }
    return n;
  }
  int get level=>1+(xp~/250);
  int get levelXp=>xp%250;

  Future<void> load() async {
    final p=await SharedPreferences.getInstance();
    try {
      work=(jsonDecode(p.getString('work')??'[]') as List).map((e)=>WorkItem.fromJson(Map<String,dynamic>.from(e))).toList();
      tasks=(jsonDecode(p.getString('tasks')??'[]') as List).map((e)=>TaskItem.fromJson(Map<String,dynamic>.from(e))).toList();
      completedDays=Set<String>.from(jsonDecode(p.getString('days')??'[]'));
      notes=List<String>.from(jsonDecode(p.getString('notes')??'[]'));
      habits=List<String>.from(jsonDecode(p.getString('habits')??'[]'));
      habitDone=Set<String>.from(jsonDecode(p.getString('habitDone')??'[]'));
    } catch (_) {}
    username=p.getString('username')??'ASCENDER';
    xp=p.getInt('xp')??0; focusSeconds=p.getInt('focusSeconds')??0;
    focusMinutes=p.getInt('focusMinutes')??50; remaining=focusMinutes*60;
    if(mounted)setState(()=>ready=true);
  }
  Future<void> save() async {
    final p=await SharedPreferences.getInstance();
    await p.setString('work',jsonEncode(work.map((e)=>e.toJson()).toList()));
    await p.setString('tasks',jsonEncode(tasks.map((e)=>e.toJson()).toList()));
    await p.setString('days',jsonEncode(completedDays.toList()));
    await p.setString('notes',jsonEncode(notes));
    await p.setString('habits',jsonEncode(habits));
    await p.setString('habitDone',jsonEncode(habitDone.toList()));
    await p.setString('username',username); await p.setInt('xp',xp);
    await p.setInt('focusSeconds',focusSeconds); await p.setInt('focusMinutes',focusMinutes);
  }
  void award(int amount) { xp+=amount; save(); }
  void startTimer() {
    if(running)return;
    setState(()=>running=true);
    ticker=Timer.periodic(const Duration(seconds:1),(t){
      if(!mounted)return;
      if(remaining<=0){t.cancel();setState(()=>running=false);focusSeconds+=focusMinutes*60;
        award(15); notifications.show(2,'ASCEND Focus complete','Your focus session is complete.',
          const NotificationDetails(android:AndroidNotificationDetails('focus','Focus sessions',
            importance:Importance.high,priority:Priority.high))); save();
      } else {setState(()=>remaining--);}
    });
  }
  void pauseTimer(){ticker?.cancel();setState(()=>running=false);}
  void resetTimer(){ticker?.cancel();setState(() { running=false; remaining=focusMinutes*60; });}
  String clock(int s)=>'${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}';
  Future<void> addWork() async {
    final name=TextEditingController(); String category='Subject';
    final result=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,ss)=>AlertDialog(
      backgroundColor:panel,title:const Text('Create workspace item'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),
        const SizedBox(height:12),DropdownButtonFormField<String>(value:category,
          decoration:const InputDecoration(labelText:'Category'),
          items:['Subject','Work','Project','Personal Goal','Other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
          onChanged:(v)=>ss(()=>category=v??'Subject')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Create'))])));
    if(result==true && name.text.trim().isNotEmpty){setState(()=>work.add(WorkItem(
      id:DateTime.now().microsecondsSinceEpoch.toString(),name:name.text.trim(),category:category)));save();}
  }
  Future<void> addTask() async {
    final title=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      backgroundColor:panel,title:const Text('New task'),
      content:TextField(controller:title,decoration:const InputDecoration(labelText:'Task name')),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Add'))]));
    if(ok==true&&title.text.trim().isNotEmpty){setState(()=>tasks.add(TaskItem(
      id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim())));save();}
  }
  Future<void> editProfile() async {
    final c=TextEditingController(text:username);
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      backgroundColor:panel,title:const Text('Your profile'),
      content:TextField(controller:c,decoration:const InputDecoration(labelText:'Display name')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))]));
    if(ok==true&&c.text.trim().isNotEmpty){setState(()=>username=c.text.trim());save();}
  }
  Future<void> editFocus() async {
    final c=TextEditingController(text:'$focusMinutes');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      backgroundColor:panel,title:const Text('Customize focus duration'),
      content:TextField(controller:c,keyboardType:TextInputType.number,
        decoration:const InputDecoration(labelText:'Minutes (1–180)')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))]));
    final v=int.tryParse(c.text);
    if(ok==true&&v!=null&&v>=1&&v<=180){pauseTimer();setState(() { focusMinutes=v; remaining=v*60; });save();}
  }
  Widget tile(String title,String subtitle,IconData icon,{VoidCallback? onTap})=>Card(
    child:ListTile(leading:Icon(icon,color:silver),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w600)),
      subtitle:Text(subtitle,style:const TextStyle(color:muted)),trailing:const Icon(Icons.chevron_right,color:muted),onTap:onTap));
  Widget header(String title,String sub)=>Padding(padding:const EdgeInsets.only(bottom:16),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w700,letterSpacing:-.7)),
      const SizedBox(height:4),Text(sub,style:const TextStyle(color:muted))]));
  Widget card(Widget child)=>Container(padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(24),
      border:Border.all(color:const Color(0xFF292929))),child:child);
  Widget home() {
    final done=tasks.where((t)=>t.done).length;
    final ratio=tasks.isEmpty?0.0:done/tasks.length;
    return ListView(padding:const EdgeInsets.fromLTRB(18,12,18,110),children:[
      Row(children:[const Expanded(child:Text('ASCEND',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,letterSpacing:2))),
        IconButton(onPressed:editProfile,icon:const Icon(Icons.account_circle_outlined,size:28))]),
      const Text('IT’S ALWAYS YOU vs YOU.',style:TextStyle(color:muted,letterSpacing:1.1,fontSize:11)),
      const SizedBox(height:22),
      card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('TODAY’S PROGRESS',style:TextStyle(color:muted,fontSize:11,letterSpacing:1.2)),
        const SizedBox(height:10),Text('$done / ${tasks.length} tasks',style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold)),
        const SizedBox(height:12),ClipRRect(borderRadius:BorderRadius.circular(20),child:LinearProgressIndicator(
          value:ratio,minHeight:8,backgroundColor:const Color(0xFF333333),color:silver)),
        const SizedBox(height:8),Text('${(ratio*100).round()}% completed',style:const TextStyle(color:muted))
      ])),
      const SizedBox(height:14),
      Row(children:[
        Expanded(child:card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Icon(Icons.local_fire_department,color:Color(0xFFFFB74D)),const SizedBox(height:8),
          Text('$streak days',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
          const Text('Current streak',style:TextStyle(color:muted,fontSize:11))]))),
        const SizedBox(width:10),
        Expanded(child:card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Icon(Icons.military_tech,color:silver),const SizedBox(height:8),
          Text('Level $level',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
          Text('$xp XP earned',style:const TextStyle(color:muted,fontSize:11))]))),
      ]),
      const SizedBox(height:14),
      card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          const Text('FOCUS TIMER',style:TextStyle(color:muted,letterSpacing:1,fontSize:11)),
          TextButton(onPressed:editFocus,child:const Text('CUSTOMIZE'))]),
        Center(child:Text(clock(remaining),style:const TextStyle(fontSize:48,fontWeight:FontWeight.w300,letterSpacing:2))),
        Center(child:Text('$focusMinutes minute session',style:const TextStyle(color:muted))),
        const SizedBox(height:12),Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          FilledButton(onPressed:running?pauseTimer:startTimer,child:Text(running?'Pause':'Start')),
          const SizedBox(width:10),OutlinedButton(onPressed:resetTimer,child:const Text('Reset'))])
      ])),
      const SizedBox(height:14),header('Next steps','Small actions create momentum.'),
      if(tasks.where((t)=>!t.done).isEmpty) const Text('No pending tasks. Add one when you are ready.',style:TextStyle(color:muted))
      else ...tasks.where((t)=>!t.done).take(3).map((t)=>tile(t.title,t.category,Icons.circle_outlined)),
      const SizedBox(height:10),FilledButton.icon(onPressed:addTask,icon:const Icon(Icons.add),label:const Text('Quick add task')),
    ]);
  }
  Widget planner()=>ListView(padding:const EdgeInsets.fromLTRB(18,18,18,110),children:[
    header('Planner','Your work, your priorities.'),
    FilledButton.icon(onPressed:addTask,icon:const Icon(Icons.add),label:const Text('Add task')),
    const SizedBox(height:12),
    if(tasks.isEmpty) card(const Text('No tasks yet. Add your first task.',style:TextStyle(color:muted))),
    ...tasks.map((t)=>Card(child:CheckboxListTile(value:t.done,title:Text(t.title,
      style:TextStyle(decoration:t.done?TextDecoration.lineThrough:null)),
      subtitle:Text('${t.category} • ${t.priority}',style:const TextStyle(color:muted)),
      activeColor:silver,checkColor:bg,onChanged:(v){setState(()=>t.done=v??false);
        if(v==true){award(10);completedDays.add(today);bestStreak=streak;}save();},
      secondary:IconButton(icon:const Icon(Icons.delete_outline),onPressed:(){setState(()=>tasks.remove(t));save();})))),
    const SizedBox(height:18),header('Workspace','Create subjects, work, projects or personal goals.'),
    FilledButton.tonalIcon(onPressed:addWork,icon:const Icon(Icons.create_new_folder_outlined),label:const Text('Add workspace item')),
    ...work.map((w)=>Card(child:ListTile(leading:const Icon(Icons.folder_outlined),
      title:Text(w.name),subtitle:Text('${w.category} • ${w.done}/${w.monthly} monthly target'),
      trailing:PopupMenuButton<String>(onSelected:(v){if(v=='done'){setState(()=>w.done++);award(5);save();}
        if(v=='delete'){setState(()=>work.remove(w));save();}},
        itemBuilder:(_)=>[const PopupMenuItem(value:'done',child:Text('Add progress')),
          const PopupMenuItem(value:'delete',child:Text('Delete'))])))),
  ]);
  Widget focusPage()=>ListView(padding:const EdgeInsets.fromLTRB(18,18,18,110),children:[
    header('Focus Studio','Protect your attention.'),
    card(Column(children:[
      const Text('YOUR SESSION',style:TextStyle(color:muted,letterSpacing:1)),
      const SizedBox(height:18),Text(clock(remaining),style:const TextStyle(fontSize:64,fontWeight:FontWeight.w300)),
      Text('$focusMinutes minutes • customizable',style:const TextStyle(color:muted)),
      const SizedBox(height:22),Wrap(spacing:10,children:[
        FilledButton(onPressed:running?pauseTimer:startTimer,child:Text(running?'Pause':'Start focus')),
        OutlinedButton(onPressed:resetTimer,child:const Text('Reset')),
        TextButton(onPressed:editFocus,child:const Text('Customize'))])
    ])),
    const SizedBox(height:16),tile('Total focus time','${focusSeconds~/3600}h ${(focusSeconds%3600)~/60}m',Icons.timelapse),
  ]);
  Widget insights()=>ListView(padding:const EdgeInsets.fromLTRB(18,18,18,110),children:[
    header('Insights','Measure progress, not perfection.'),
    tile('Completed tasks','${tasks.where((t)=>t.done).length} tasks',Icons.task_alt),
    tile('Focus time','${focusSeconds~/3600} hours ${focusSeconds%3600~/60} minutes',Icons.timer),
    tile('Current streak','$streak consecutive days',Icons.local_fire_department),
    tile('Experience points','$xp XP • Level $level',Icons.military_tech),
    card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('LEVEL PROGRESS',style:TextStyle(color:muted,letterSpacing:1)),
      const SizedBox(height:12),Text('Level $level',style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),LinearProgressIndicator(value:levelXp/250,minHeight:8,color:silver,backgroundColor:const Color(0xFF333333)),
      const SizedBox(height:6),Text('$levelXp / 250 XP to next level',style:const TextStyle(color:muted))
    ]))
  ]);
  Widget settings()=>ListView(padding:const EdgeInsets.fromLTRB(18,18,18,110),children:[
    header('Settings','Make ASCEND yours.'),
    tile('Profile','$username • Level $level',Icons.person_outline,onTap:editProfile),
    tile('Motivational notifications','Notification preferences',Icons.notifications_none,onTap:()=>showDialog(context:context,builder:(c)=>AlertDialog(
      backgroundColor:panel,title:const Text('Notifications'),
      content:const Text('Daily reminders and motivational notifications can be configured in future updates.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))]))),
    tile('Backup & restore','Export or import your data',Icons.backup_outlined,onTap:exportData),
    tile('About ASCEND','Earn Your Elevation.',Icons.info_outline),
    const SizedBox(height:16),const Center(child:Text('IT’S ALWAYS YOU vs YOU.',style:TextStyle(color:muted,letterSpacing:1.2))),
  ]);
  Future<void> exportData() async {
    final data=jsonEncode({'username':username,'xp':xp,'focusSeconds':focusSeconds,
      'work':work.map((e)=>e.toJson()).toList(),'tasks':tasks.map((e)=>e.toJson()).toList(),
      'days':completedDays.toList(),'notes':notes,'habits':habits,'habitDone':habitDone.toList()});
    await Clipboard.setData(ClipboardData(text:data));
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Backup JSON copied to clipboard. Save it somewhere safe.')));
  }
  @override Widget build(BuildContext context){
    if(!ready)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final pages=[home(),planner(),focusPage(),insights(),settings()];
    return Scaffold(body:SafeArea(child:pages[tab]),
      bottomNavigationBar:Container(margin:const EdgeInsets.fromLTRB(14,0,14,10),
        decoration:BoxDecoration(color:const Color(0xFF171717),borderRadius:BorderRadius.circular(28),
          border:Border.all(color:const Color(0xFF303030))),
        child:NavigationBar(height:68,backgroundColor:Colors.transparent,indicatorColor:const Color(0xFF343434),
          selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
          destinations:const [
            NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
            NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Planner'),
            NavigationDestination(icon:Icon(Icons.timer_outlined),selectedIcon:Icon(Icons.timer),label:'Focus'),
            NavigationDestination(icon:Icon(Icons.insights_outlined),selectedIcon:Icon(Icons.insights),label:'Insights'),
            NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'Settings'),
          ])));
  }
}
