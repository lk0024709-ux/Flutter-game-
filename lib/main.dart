import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'battle/battle_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const BladeBrawlApp());
}
class P {
  static const bg=Color(0xFFF5F1EA), surface=Color(0xFFFFFFFF), sand=Color(0xFFEDE7DB);
  static const border=Color(0xFFE7E1D3), amber=Color(0xFFD97706), rust=Color(0xFF7C2D12);
  static const ink=Color(0xFF1C1917), muted=Color(0xFF78716C);
}
class BladeBrawlApp extends StatelessWidget {
  const BladeBrawlApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'Blade Brawl: Rannbhoomi',debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:P.bg,colorScheme:ColorScheme.fromSeed(seedColor:P.amber),textTheme:GoogleFonts.interTextTheme()),
    home:const ForgeHome());
}
enum WeaponTier {
  dagger('Dagger','🗡️',15,55,.35),sword('Sword','⚔️',22,70,.45),axe('Axe','🪓',35,75,.55),
  trident('Trident','🔱',50,95,.60),storm('Storm Blade','⚡',75,110,.70),mythic('Mythic Blade','💎',120,130,.80);
  const WeaponTier(this.label,this.emoji,this.damage,this.range,this.cooldown);
  final String label,emoji;final int damage;final double range,cooldown;
}
class ForgeHome extends StatefulWidget {
  const ForgeHome({super.key});
  @override State<ForgeHome> createState()=>_ForgeHomeState();
}
class _ForgeHomeState extends State<ForgeHome> {
  List<int?> slots=List<int?>.filled(9,null);int coins=250,merges=0,tab=0;bool loading=true;
  DateTime last=DateTime.now();DateTime? manual;Timer? timer;
  double get interval=>(5-(merges~/10)*.3).clamp(1.5,5.0);
  WeaponTier get weapon {final v=slots.whereType<int>();return WeaponTier.values[v.isEmpty?0:v.reduce((a,b)=>a>b?a:b)];}
  @override void initState(){super.initState();_load();timer=Timer.periodic(const Duration(milliseconds:500),(_)=>_tick());}
  @override void dispose(){timer?.cancel();super.dispose();}
  Future<void> _load() async {
    final p=await SharedPreferences.getInstance();final raw=p.getString('bb_save');
    if(raw!=null){try{final d=jsonDecode(raw) as Map<String,dynamic>;slots=(d['slots'] as List).map<int?>((e)=>e==null?null:e as int).toList();coins=d['coins'] as int? ??250;merges=d['merges'] as int? ??0;
      final saved=DateTime.tryParse(d['last'] as String? ??'');if(saved!=null){final n=(DateTime.now().difference(saved).inSeconds/interval).floor().clamp(0,9);for(var i=0;i<n;i++){final e=slots.indexOf(null);if(e<0)break;slots[e]=0;}}
    }catch(_){slots=List<int?>.filled(9,null);}}
    if(slots.every((e)=>e==null))slots[4]=0;last=DateTime.now();if(mounted)setState(()=>loading=false);_save();
  }
  Future<void> _save() async {final p=await SharedPreferences.getInstance();await p.setString('bb_save',jsonEncode({'slots':slots,'coins':coins,'merges':merges,'last':last.toIso8601String()}));}
  void _tick(){if(!mounted||loading||!slots.contains(null))return;if(DateTime.now().difference(last).inMilliseconds>=interval*1000){setState(()=>slots[slots.indexOf(null)]=0);last=DateTime.now();HapticFeedback.selectionClick();_save();}else{setState((){});}}
  void _msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),behavior:SnackBarBehavior.floating));
  void _forge(){if(!slots.contains(null)){_msg('Forge grid is full. Merge a weapon first.');return;}if(manual!=null&&DateTime.now().difference(manual!)<const Duration(seconds:10)){_msg('Forge Now is recharging.');return;}manual=DateTime.now();setState(()=>slots[slots.indexOf(null)]=0);last=DateTime.now();HapticFeedback.mediumImpact();_save();}
  void _drop(int a,int b){if(a==b||slots[a]==null)return;setState((){final x=slots[a]!,y=slots[b];if(y==null){slots[b]=x;slots[a]=null;}else if(x==y&&x<5){slots[b]=x+1;slots[a]=null;merges++;coins+=5;HapticFeedback.heavyImpact();}else if(x!=y){slots[a]=y;slots[b]=x;}else{_msg('Mythic Blade is the highest tier.');}});_save();}
  @override Widget build(BuildContext context){if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));return Scaffold(
    body:SafeArea(child:IndexedStack(index:tab,children:[_forgePage(),CampaignPage(weapon:weapon),StorePage(coins:coins,onBuy:(c){if(coins<c){_msg('Not enough coins.');return;}setState(()=>coins-=c);_save();})])),
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),backgroundColor:P.surface,indicatorColor:P.sand,destinations:const[
      NavigationDestination(icon:Icon(Icons.local_fire_department_outlined),label:'Forge'),NavigationDestination(icon:Icon(Icons.shield_outlined),label:'Campaign'),NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'Store')]));
  }
  Widget _forgePage()=>ListView(padding:const EdgeInsets.all(22),children:[
    Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('R A N N B H O O M I',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:P.rust)),Text('The Forge Yard',style:GoogleFonts.manrope(fontSize:28,fontWeight:FontWeight.w800))])),Text('🪙 '+coins.toString(),style:const TextStyle(fontWeight:FontWeight.w800))]),
    const SizedBox(height:22),
    Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF3F392F),Color(0xFF26241F)]),borderRadius:BorderRadius.circular(24)),child:Row(children:[
      const Text('🔥',style:TextStyle(fontSize:38)),const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Ancient Furnace',style:GoogleFonts.manrope(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)),
        Text(slots.contains(null)?'Auto-forging · '+interval.toStringAsFixed(1)+'s':'FULL · Merge weapons to make room',style:const TextStyle(color:Color(0xFFD6CFC2),fontSize:12)),
        const SizedBox(height:10),ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(minHeight:5,value:slots.contains(null)?(DateTime.now().difference(last).inMilliseconds/(interval*1000)).clamp(0,1):1,backgroundColor:Colors.white12,color:P.amber))
      ]))])),
    const SizedBox(height:24),Row(children:[Expanded(child:Text('Weapon grid',style:GoogleFonts.manrope(fontSize:20,fontWeight:FontWeight.w800))),Text(merges.toString()+' merges',style:const TextStyle(color:P.muted,fontSize:12))]),
    const SizedBox(height:5),const Text('Drag matching weapons together to evolve them.',style:TextStyle(color:P.muted,fontSize:13)),const SizedBox(height:14),
    GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:9,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:1.05),
      itemBuilder:(context,i)=>DragTarget<int>(onAcceptWithDetails:(d)=>_drop(d.data,i),builder:(context,c,r){final t=slots[i];return Container(decoration:BoxDecoration(color:c.isNotEmpty?const Color(0xFFFFE7B8):P.surface,border:Border.all(color:c.isNotEmpty?P.amber:P.border),borderRadius:BorderRadius.circular(18)),child:t==null?const Icon(Icons.add,color:Color(0xFFD6CFC2)):Draggable<int>(data:i,feedback:Material(color:Colors.transparent,child:_tile(t)),childWhenDragging:const Icon(Icons.more_horiz),child:_tile(t)));})),
    const SizedBox(height:20),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_forge,icon:const Icon(Icons.add),label:const Text('Forge Now'),style:OutlinedButton.styleFrom(padding:const EdgeInsets.all(15)))),const SizedBox(width:12),Expanded(child:FilledButton.icon(onPressed:()=>setState(()=>tab=1),icon:const Icon(Icons.sports_martial_arts),label:const Text('Enter Arena'),style:FilledButton.styleFrom(backgroundColor:P.amber,foregroundColor:Colors.white,padding:const EdgeInsets.all(15))))]),
    const SizedBox(height:24),const Text('YOUR ACTIVE WEAPON',style:TextStyle(fontSize:10,letterSpacing:1.5,fontWeight:FontWeight.w800,color:P.muted)),const SizedBox(height:10),
    Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:P.surface,border:Border.all(color:P.border),borderRadius:BorderRadius.circular(18)),child:Row(children:[Text(weapon.emoji,style:const TextStyle(fontSize:30)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(weapon.label,style:GoogleFonts.manrope(fontWeight:FontWeight.w800)),Text(weapon.damage.toString()+' damage · '+weapon.range.toInt().toString()+' range',style:const TextStyle(color:P.muted,fontSize:12))])),const Icon(Icons.check_circle,color:Color(0xFF15803D))]))
  ]);
  Widget _tile(int t)=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(WeaponTier.values[t].emoji,style:const TextStyle(fontSize:29)),Text(WeaponTier.values[t].label,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700)),Text('T'+(t+1).toString(),style:const TextStyle(fontSize:9,color:P.muted))]));
}
class CampaignPage extends StatelessWidget{
  const CampaignPage({super.key,required this.weapon});final WeaponTier weapon;
  static const ranks=['Bronze','Silver','Gold','Platinum','Diamond','Masters','Grand Masters'];
  static const maps=['The Dust Pit','Frost Hollow','Ember Forge','Jade Temple','Crystal Cavern','Storm Citadel','Throne of Rann'];
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[
    Text('Choose your battle',style:GoogleFonts.manrope(fontSize:26,fontWeight:FontWeight.w800)),const Text('350 levels · 7 ranks · Rannbhoomi',style:TextStyle(color:P.muted)),const SizedBox(height:20),
    ...List.generate(7,(r)=>Container(margin:const EdgeInsets.only(bottom:14),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:P.surface,border:Border.all(color:P.border),borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Text(['🥉','🥈','🥇','💠','💎','🏆','👑'][r],style:const TextStyle(fontSize:24)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(ranks[r],style:GoogleFonts.manrope(fontSize:17,fontWeight:FontWeight.w800)),Text(maps[r],style:const TextStyle(color:P.muted,fontSize:12))])),if(r>0)const Icon(Icons.lock_outline,color:P.muted)]),
      const SizedBox(height:13),Wrap(spacing:6,runSpacing:6,children:List.generate(50,(i){final n=r*50+i+1;final open=n<=3;return InkWell(onTap:open?()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BattleScreen(level:n,mapName:maps[r],weapon:weapon))):()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Clear earlier levels to unlock this battle.'))),child:Container(width:39,height:39,decoration:BoxDecoration(color:open?P.sand:P.bg,border:Border.all(color:n==1?P.amber:P.border,width:n==1?2:1),borderRadius:BorderRadius.circular(9)),child:Center(child:open?Text(n.toString(),style:const TextStyle(fontWeight:FontWeight.w700,fontSize:11)):const Icon(Icons.lock,size:13,color:Color(0xFFB9B0A0))))})),
    ])))
  ]);
}
class StorePage extends StatelessWidget{
  const StorePage({super.key,required this.coins,required this.onBuy});final int coins;final ValueChanged<int> onBuy;
  static const items=[('🥉','Normal Armor','Basic protection',100),('🥈','Advanced Armor','+5 HP regen/sec',350),('🥇','Legend Armor','Reflect 10% damage',900),('💎','Epic Armor','Revive once per battle',2200),('❤️','Revive Potion','+1 auto-revive',200),('⚔️','Damage Elixir','+25% damage',150),('🧲','Chest Magnet','2× chest spawns',100),('🛡️','Iron Skin','+20% defense',180)];
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[Text('The Armory',style:GoogleFonts.manrope(fontSize:27,fontWeight:FontWeight.w800)),Text('🪙 '+coins.toString(),style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:18),...items.map((x)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:P.surface,border:Border.all(color:P.border),borderRadius:BorderRadius.circular(17)),child:Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:P.sand,borderRadius:BorderRadius.circular(14)),child:Center(child:Text(x.$1,style:const TextStyle(fontSize:24)))),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.$2,style:GoogleFonts.manrope(fontWeight:FontWeight.w800)),Text(x.$3,style:const TextStyle(color:P.muted,fontSize:11)),Text('🪙 '+x.$4.toString(),style:const TextStyle(color:P.amber,fontWeight:FontWeight.w800,fontSize:12))])),FilledButton(onPressed:()=>onBuy(x.$4),style:FilledButton.styleFrom(backgroundColor:P.ink,foregroundColor:Colors.white),child:const Text('BUY'))])))]);
}
