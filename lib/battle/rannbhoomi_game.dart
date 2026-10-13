import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../main.dart';
class RannbhoomiGame extends FlameGame{
  RannbhoomiGame({required this.level,required this.weapon});
  final int level;final WeaponTier weapon;final List<Beast> beasts=[];late Warrior player;
  Offset move=Offset.zero;int hp=120;final int maxHp=120;bool paused=false,finished=false,won=false;double elapsed=0,cooldown=0;
  void setMove(Offset v){final l=v.distance;move=l>58?v/l:v/58;if(move.distance>1)move=move/move.distance;}
  @override Color backgroundColor()=>const Color(0xFFE2D2B6);
  @override Future<void> onLoad()async{await super.onLoad();player=Warrior()..position=Vector2(1200,1200);await world.add(player);final n=(7+level~/8).clamp(7,15);
    for(var i=0;i<n;i++){final a=i*math.pi*2/n;final r=250+(i%4)*45;final b=Beast(BeastKind.values[i%5],i)..position=Vector2(1200+math.cos(a)*r,1200+math.sin(a)*r);beasts.add(b);await world.add(b);}camera.follow(player,maxSpeed:900);}
  @override void update(double dt){if(paused||finished)return;super.update(dt);elapsed+=dt;cooldown=math.max(0,cooldown-dt);hp=player.health.round();beasts.removeWhere((b)=>b.isRemoved||b.health<=0);if(player.health<=0){finished=true;won=false;}else if(beasts.isEmpty){finished=true;won=true;}if(elapsed>150){player.health-=10*dt;for(final b in beasts){b.health-=10*dt;}}}
  void attack(){if(finished||paused||cooldown>0)return;cooldown=weapon.cooldown;final hits=beasts.where((b){final d=b.position-player.position;if(d.length>weapon.range+b.radius)return false;final a=math.atan2(d.y,d.x);final da=math.atan2(math.sin(a-player.facing),math.cos(a-player.facing));return da.abs()<math.pi*.85/2;}).toList()..sort((a,b)=>(a.position-player.position).length.compareTo((b.position-player.position).length));for(final b in hits.take(weapon==WeaponTier.trident?2:1)){b.health-=weapon.damage;if(weapon.index>=4){for(final o in beasts){if(o!=b&&(o.position-b.position).length<60)o.health-=15;}}if(weapon==WeaponTier.mythic)b.health-=weapon.damage~/5;}}
}
enum BeastKind{
 griffin('Griffin',70,160,14,65,20,Color(0xFFC2410C)),drake('Drake',55,130,16,220,22,Color(0xFF166534)),skyhawk('Skyhawk',45,220,12,55,16,Color(0xFF92400E)),ironboar('Ironboar',120,110,20,60,26,Color(0xFF44403C)),venomtail('Venomtail',60,150,10,70,18,Color(0xFF4D7C0F));
 const BeastKind(this.label,this.hp,this.speed,this.damage,this.range,this.radius,this.color);
 final String label;final double hp,speed,damage,range,radius;final Color color;
}
abstract class Fighter extends PositionComponent with HasGameReference<RannbhoomiGame>{
 Fighter({required this.health,required this.maxHealth,required this.radius,required this.tint});
 double health;final double maxHealth,radius;final Color tint;double facing=-math.pi/2,flash=0,attackTimer=0;
 @override void render(Canvas c){super.render(c);c.drawOval(Rect.fromCenter(center:Offset(2,radius*.65),width:radius*2.4,height:radius*.8),Paint()..color=const Color(0x26000000));c.drawCircle(Offset.zero,radius,Paint()..color=flash>0?const Color(0xFFFFF3D6):tint);c.save();c.rotate(facing);c.drawOval(Rect.fromCenter(center:Offset(radius*.45,-radius*.1),width:radius*.72,height:radius*.45),Paint()..color=const Color(0xCC1C1917));c.restore();if(health<maxHealth){final w=radius*2.4;final r=Rect.fromLTWH(-w/2,-radius-10,w,4);c.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(3)),Paint()..color=const Color(0xFFE7E1D3));c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left,r.top,w*(health/maxHealth).clamp(0,1),4),const Radius.circular(3)),Paint()..color=Colors.red);}}
}
class Warrior extends Fighter{
 Warrior():super(health:120,maxHealth:120,radius:18,tint:const Color(0xFFB45309));
 @override void update(double dt){super.update(dt);if(game.finished)return;if(game.move.distance>.05){position+=Vector2(game.move.dx,game.move.dy)*220*dt;facing=math.atan2(game.move.dy,game.move.dx);}position.x=position.x.clamp(20,2380).toDouble();position.y=position.y.clamp(20,2380).toDouble();flash=math.max(0,flash-dt);}
}
class Beast extends Fighter{
 Beast(this.kind,this.faction):super(health:kind.hp,maxHealth:kind.hp,radius:kind.radius,tint:Color.lerp(kind.color,Color.fromARGB(255,(faction*47+80)%255,(faction*71+65)%255,(faction*29+45)%255),.22)!);
 final BeastKind kind;final int faction;double ability=0;
 @override void update(double dt){super.update(dt);if(game.finished)return;if(health<=0){removeFromParent();return;}flash=math.max(0,flash-dt);attackTimer=math.max(0,attackTimer-dt);ability-=dt;
 final targets=<Fighter>[game.player,...game.beasts.where((b)=>b!=this&&b.health>0)];targets.sort((a,b)=>(a.position-position).length.compareTo((b.position-position).length));if(targets.isEmpty)return;final t=targets.first;final d=t.position-position;final dist=d.length;if(dist>.1)facing=math.atan2(d.y,d.x);
 if(dist>kind.range*.85){var speed=kind.speed;if(kind==BeastKind.griffin&&ability<=0){speed*=2;ability=4;}position+=d.safeNorm()*speed*dt;}else if(dist<30){position-=d.safeNorm()*kind.speed*.35*dt;}else{position+=Vector2(-d.y,d.x).safeNorm()*kind.speed*.22*dt;}
 if(dist<=kind.range+t.radius&&attackTimer<=0){attackTimer=kind==BeastKind.drake?1.4:kind==BeastKind.skyhawk?.5:kind==BeastKind.ironboar?1.1:.8;t.health-=kind.damage;if(t is Beast)t.flash=.16;}
 for(final o in game.beasts){if(o==this||o.health<=0)continue;final away=position-o.position;final len=away.length;if(len>.01&&len<radius+o.radius)position+=away.safeNorm()*((radius+o.radius-len)*.5);}position.x=position.x.clamp(10,2390).toDouble();position.y=position.y.clamp(10,2390).toDouble();
 }
}
extension on Vector2{Vector2 safeNorm()=>length>.0001?(clone()..scale(1/length)):Vector2.zero();}
