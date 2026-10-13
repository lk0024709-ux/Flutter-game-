import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'rannbhoomi_game.dart';
class BattleScreen extends StatefulWidget{
  const BattleScreen({super.key,required this.level,required this.mapName,required this.weapon});
  final int level;final String mapName;final WeaponTier weapon;
  @override State<BattleScreen> createState()=>_BattleScreenState();
}
class _BattleScreenState extends State<BattleScreen>{
  late final RannbhoomiGame game;
  @override void initState(){super.initState();game=RannbhoomiGame(level:widget.level,weapon:widget.weapon);}
  @override Widget build(BuildContext context)=>Scaffold(body:Stack(children:[
    GameWidget(game:game),
    SafeArea(child:Padding(padding:const EdgeInsets.all(15),child:Column(children:[
      Row(children:[_circle(Icons.home,()=>Navigator.pop(context)),const SizedBox(width:10),Expanded(child:Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:P.surface.withOpacity(.94),borderRadius:BorderRadius.circular(99)),child:Text(widget.mapName,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)))),const SizedBox(width:10),_circle(Icons.pause,()=>setState(()=>game.paused=!game.paused))]),
      const SizedBox(height:12),AnimatedBuilder(animation:game,builder:(context,_)=>Row(children:[Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(99),child:LinearProgressIndicator(minHeight:10,value:(game.hp/game.maxHp).clamp(0,1),backgroundColor:Colors.white.withOpacity(.8),color:game.hp<35?Colors.red:P.amber))),const SizedBox(width:8),Text(game.hp.clamp(0,game.maxHp).toString()+'/'+game.maxHp.toString(),style:const TextStyle(fontWeight:FontWeight.w800))])),
      const Spacer(),Row(children:[
        GestureDetector(onPanUpdate:(d)=>game.setMove(Offset(d.localPosition.dx-55,d.localPosition.dy-55)),onPanEnd:(_)=>game.setMove(Offset.zero),child:Container(width:110,height:110,decoration:BoxDecoration(color:P.surface.withOpacity(.8),shape:BoxShape.circle,border:Border.all(color:P.border,width:2)),child:const Center(child:Icon(Icons.open_with,color:P.rust,size:35)))),
        const Spacer(),GestureDetector(onTap:game.attack,child:Container(width:82,height:82,decoration:BoxDecoration(color:P.amber,borderRadius:BorderRadius.circular(25)),child:const Center(child:Text('⚔️',style:TextStyle(fontSize:30)))))
      ]),const SizedBox(height:18)
    ]))),
    if(game.paused||game.finished)Positioned.fill(child:Container(color:P.ink.withOpacity(.55),child:Center(child:Container(padding:const EdgeInsets.all(25),margin:const EdgeInsets.all(25),decoration:BoxDecoration(color:P.bg,borderRadius:BorderRadius.circular(24)),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(game.paused?'PAUSED':game.won?'ARENA CLEARED':'DEFEATED',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:12),FilledButton(onPressed:()=>game.paused?setState(()=>game.paused=false):Navigator.pop(context),style:FilledButton.styleFrom(backgroundColor:P.amber),child:Text(game.paused?'RESUME':'RETURN TO FORGE'))]))))
  ]));
  Widget _circle(IconData i,VoidCallback f)=>Material(color:P.surface,shape:const CircleBorder(),child:InkWell(onTap:f,customBorder:const CircleBorder(),child:SizedBox(width:42,height:42,child:Icon(i))));
}
