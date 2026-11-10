import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const subjects = {'Maths':19,'English':18,'Physics':13,'History':14,'Geography':12,'Current Affairs':6,'Biology':1,'Polity':1,'Other GAT':3};
void main()=>runApp(const NdaApp());
class NdaApp extends StatelessWidget { const NdaApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'NDA Command Center',theme:ThemeData.dark(useMaterial3:true).copyWith(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff35c78a),brightness:Brightness.dark),scaffoldBackgroundColor:const Color(0xff0b1220)),home:const Home());}
class Home extends StatefulWidget {const Home({super.key}); @override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{
 final Map<String,int> done={for(final s in subjects.keys)s:0}; int tm=0,tg=0; bool revision=false; late SharedPreferences prefs;
 @override void initState(){super.initState();load();}
 Future<void> load() async {prefs=await SharedPreferences.getInstance();for(final s in subjects.keys){done[s]=prefs.getInt(s)??0;}tm=prefs.getInt('tm')??0;tg=prefs.getInt('tg')??0;revision=prefs.getBool('rev')??false;if(mounted)setState((){});}
 Future<void> save()async{for(final s in subjects.keys){await prefs.setInt(s,done[s]!);}await prefs.setInt('tm',tm);await prefs.setInt('tg',tg);await prefs.setBool('rev',revision);}
 void change(String s,int d){setState(()=>done[s]=(done[s]!+d).clamp(0,subjects[s]!));save();}
 @override Widget build(BuildContext c){final total=done.values.fold<int>(0,(a,b)=>a+b);return Scaffold(appBar:AppBar(title:const Text('🇮🇳 NDA COMMAND CENTER')),body:ListView(padding:const EdgeInsets.all(16),children:[
 Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$total / 87 lectures',style:Theme.of(c).textTheme.headlineMedium),LinearProgressIndicator(value:total/87),Text('${(total/87*100).round()}% completed')] ))),
 const Padding(padding:EdgeInsets.only(top:16,bottom:8),child:Text('SUBJECT-WISE TRACKER',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),
 ...subjects.entries.map((e)=>Card(child:ListTile(title:Text(e.key),subtitle:LinearProgressIndicator(value:done[e.key]!/e.value),leading:Text('${done[e.key]}/${e.value}'),trailing:Wrap(children:[IconButton(onPressed:done[e.key]!>0?()=>change(e.key,-1):null,icon:const Icon(Icons.remove_circle_outline)),IconButton(onPressed:done[e.key]!<e.value?()=>change(e.key,1):null,icon:const Icon(Icons.add_circle_outline))])))),
 Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[const Text('TODAY’S TARGET',style:TextStyle(fontWeight:FontWeight.bold)),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Maths'),Text('$tm/2'),IconButton(onPressed:tm>0?(){setState(()=>tm--);save();}:null,icon:const Icon(Icons.remove)),IconButton(onPressed:tm<2?(){setState(()=>tm++);save();}:null,icon:const Icon(Icons.add))]),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('GAT'),Text('$tg/3'),IconButton(onPressed:tg>0?(){setState(()=>tg--);save();}:null,icon:const Icon(Icons.remove)),IconButton(onPressed:tg<3?(){setState(()=>tg++);save();}:null,icon:const Icon(Icons.add))]),CheckboxListTile(value:revision,onChanged:(v){setState(()=>revision=v??false);save();},title:const Text('Revision + MCQs completed'))]))),
 const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('FOCUS MODE\nUse your phone’s Digital Wellbeing > Focus mode to pause distracting apps. This app does not control system-wide app blocking.'))),
 const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('REMINDERS\nUse Android Clock for reliable alarms. App notifications can be enabled after the app is built and installed.'))),
 ]));}
}
