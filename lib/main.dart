import 'dart:convert';
import 'package:flutter/material.dart';
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
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ),
  ));
  runApp(const StudyApp());
}

class Subject {
  String name;
  int daily, weekly, monthly, done;
  Subject(this.name, {this.daily=1, this.weekly=5, this.monthly=20, this.done=0});
  Map<String,dynamic> toJson()=>{'name':name,'daily':daily,'weekly':weekly,'monthly':monthly,'done':done};
  factory Subject.fromJson(Map<String,dynamic> j)=>Subject(j['name'],
    daily:j['daily']??1, weekly:j['weekly']??5, monthly:j['monthly']??20, done:j['done']??0);
}

class StudyApp extends StatefulWidget {
  const StudyApp({super.key});
  @override State<StudyApp> createState()=>_StudyAppState();
}
class _StudyAppState extends State<StudyApp> {
  ThemeMode mode=ThemeMode.dark;
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false, title:'Study Command Center', themeMode:mode,
    theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:Colors.indigo),useMaterial3:true),
    darkTheme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:Colors.indigo,brightness:Brightness.dark),scaffoldBackgroundColor:const Color(0xff09111f),useMaterial3:true),
    home:HomePage(dark:mode==ThemeMode.dark,onTheme:(v)=>setState(()=>mode=v?ThemeMode.dark:ThemeMode.light)),
  );
}

class HomePage extends StatefulWidget {
  final bool dark; final ValueChanged<bool> onTheme;
  const HomePage({super.key,required this.dark,required this.onTheme});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage> {
  List<Subject> subjects=[]; bool ready=false, reminder=false, focus=false;
  TimeOfDay reminderTime=const TimeOfDay(hour:6,minute:0);
  @override void initState(){super.initState();load();}
  Future<void> load() async {
    final p=await SharedPreferences.getInstance(); final raw=p.getString('subjects');
    subjects=raw==null?[Subject('Mathematics',daily:2,weekly:10,monthly:40),Subject('English',daily:1,weekly:5,monthly:20),Subject('Physics',daily:1,weekly:5,monthly:20)]:
      (jsonDecode(raw) as List).map((e)=>Subject.fromJson(Map<String,dynamic>.from(e))).toList();
    reminder=p.getBool('reminder')??false;
    reminderTime=TimeOfDay(hour:p.getInt('hour')??6,minute:p.getInt('minute')??0);
    if(mounted)setState(()=>ready=true);
  }
  Future<void> save() async {
    final p=await SharedPreferences.getInstance();
    await p.setString('subjects',jsonEncode(subjects.map((e)=>e.toJson()).toList()));
    await p.setBool('reminder',reminder); await p.setInt('hour',reminderTime.hour); await p.setInt('minute',reminderTime.minute);
  }
  int get done=>subjects.fold(0,(a,s)=>a+s.done);
  int get goal=>subjects.fold(0,(a,s)=>a+s.monthly);
  double get ratio=>goal==0?0:(done/goal).clamp(0,1);
  Future<void> addSubject([Subject? old]) async {
    final n=TextEditingController(text:old?.name??'');
    final d=TextEditingController(text:'${old?.daily??1}');
    final w=TextEditingController(text:'${old?.weekly??5}');
    final m=TextEditingController(text:'${old?.monthly??20}');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:Text(old==null?'Add subject':'Customize subject'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:n,decoration:const InputDecoration(labelText:'Subject name')),
        TextField(controller:d,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Daily target')),
        TextField(controller:w,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Weekly target')),
        TextField(controller:m,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Monthly target')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save'))],
    ));
    if(ok==true && n.text.trim().isNotEmpty){
      setState((){if(old==null){subjects.add(Subject(n.text.trim(),daily:int.tryParse(d.text)??1,weekly:int.tryParse(w.text)??5,monthly:int.tryParse(m.text)??20));}
      else{old.name=n.text.trim();old.daily=int.tryParse(d.text)??old.daily;old.weekly=int.tryParse(w.text)??old.weekly;old.monthly=int.tryParse(m.text)??old.monthly;}});
      await save();
    }
  }
  tz.TZDateTime nextReminder(){
    final now=tz.TZDateTime.now(tz.local);
    var t=tz.TZDateTime(tz.local,now.year,now.month,now.day,reminderTime.hour,reminderTime.minute);
    if(t.isBefore(now))t=t.add(const Duration(days:1)); return t;
  }
  Future<void> setReminder() async {
    final t=await showTimePicker(context:context,initialTime:reminderTime);
    if(t==null)return;
    setState((){reminderTime=t;reminder=true;});
    await notifications.cancel(1);
    await notifications.zonedSchedule(1,'Study time','Your planned study session is ready.',
      nextReminder(),const NotificationDetails(
        android:AndroidNotificationDetails('study_daily','Daily study reminders',channelDescription:'Study schedule reminders',importance:Importance.high,priority:Priority.high),
        iOS:DarwinNotificationDetails()),
      androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:DateTimeComponents.time);
    await save();
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Daily reminder scheduled')));
  }
  Future<void> toggleReminder(bool v) async {
    if(!v){setState(()=>reminder=false);await notifications.cancel(1);await save();}
    else{await setReminder();}
  }
  @override Widget build(BuildContext context){
    if(!ready)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final cs=Theme.of(context).colorScheme;
    return Scaffold(
      appBar:AppBar(title:const Text('STUDY COMMAND CENTER',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
        actions:[IconButton(onPressed:()=>widget.onTheme(!widget.dark),icon:Icon(widget.dark?Icons.light_mode:Icons.dark_mode),tooltip:'Switch theme')]),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>addSubject(),icon:const Icon(Icons.add),label:const Text('Add subject')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:LinearGradient(colors:[cs.primary,cs.tertiary])),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('MONTHLY OVERVIEW',style:TextStyle(color:Colors.white70,letterSpacing:1)),
            const SizedBox(height:8),Text('$done / $goal',style:const TextStyle(color:Colors.white,fontSize:34,fontWeight:FontWeight.bold)),
            const Text('Targets completed',style:TextStyle(color:Colors.white70)),const SizedBox(height:12),
            ClipRRect(borderRadius:BorderRadius.circular(10),child:LinearProgressIndicator(value:ratio,minHeight:9,backgroundColor:Colors.white30,color:Colors.white)),
            const SizedBox(height:6),Text('${(ratio*100).round()}% complete',style:const TextStyle(color:Colors.white)),
          ])),
        const SizedBox(height:18),
        Row(children:[Expanded(child:_stat('Subjects','${subjects.length}',Icons.menu_book)),const SizedBox(width:8),Expanded(child:_stat('Completed','$done',Icons.check_circle)),const SizedBox(width:8),Expanded(child:_stat('Monthly goal','$goal',Icons.flag))]),
        const SizedBox(height:22),const Text('SUBJECTS & TARGETS',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:1)),
        const SizedBox(height:8),
        ...subjects.map((s)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
          Row(children:[Expanded(child:Text(s.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),
            IconButton(onPressed:()=>addSubject(s),icon:const Icon(Icons.tune)),
            IconButton(onPressed:()async{setState(()=>subjects.remove(s));await save();},icon:const Icon(Icons.delete_outline))]),
          Wrap(spacing:6,children:[_chip('Daily ${s.daily}'),_chip('Weekly ${s.weekly}'),_chip('Monthly ${s.monthly}')]),
          const SizedBox(height:12),Row(children:[Expanded(child:LinearProgressIndicator(value:s.monthly==0?0:(s.done/s.monthly).clamp(0,1),minHeight:7)),const SizedBox(width:10),Text('${s.done}/${s.monthly}')]),
          Row(mainAxisAlignment:MainAxisAlignment.end,children:[
            IconButton(onPressed:()async{if(s.done>0)setState(()=>s.done--);await save();},icon:const Icon(Icons.remove_circle_outline)),
            Text('${s.done} done',style:const TextStyle(fontWeight:FontWeight.bold)),
            IconButton(onPressed:()async{setState(()=>s.done++);await save();},icon:const Icon(Icons.add_circle_outline)),
          ]),
        ])))),
        const SizedBox(height:16),const Text('REMINDERS & FOCUS',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:1)),
        Card(child:Column(children:[
          SwitchListTile(value:reminder,onChanged:toggleReminder,title:const Text('Daily study reminder'),subtitle:Text(reminder?'Every day at ${reminderTime.format(context)}':'Off'),secondary:const Icon(Icons.notifications_active_outlined)),
          ListTile(leading:const Icon(Icons.schedule),title:const Text('Choose reminder time'),onTap:setReminder,trailing:const Icon(Icons.chevron_right)),
          ListTile(leading:Icon(focus?Icons.pause_circle:Icons.center_focus_strong),title:Text(focus?'Focus mode is on':'Start focus session'),subtitle:const Text('25-minute focus session'),trailing:FilledButton.tonal(onPressed:()=>setState(()=>focus=!focus),child:Text(focus?'Stop':'Start'))),
          const ListTile(leading:Icon(Icons.do_not_disturb_on_outlined),title:Text('DND / distraction control'),subtitle:Text('Turn on Do Not Disturb from your phone Quick Settings. The app cannot silently change system DND permissions.')),
        ])),
        const Card(child:ListTile(leading:Icon(Icons.phone_android),title:Text('Device storage'),subtitle:Text('Subjects and progress are saved on this phone. No account or cloud sync.'))),
      ]),
    );
  }
  Widget _stat(String label,String value,IconData icon)=>Card(child:Padding(padding:const EdgeInsets.all(11),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:18),const SizedBox(height:7),Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),Text(label,style:const TextStyle(fontSize:10))])));
  Widget _chip(String s)=>Chip(label:Text(s,style:const TextStyle(fontSize:11)),visualDensity:VisualDensity.compact);
}
