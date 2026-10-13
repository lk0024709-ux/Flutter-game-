enum ChimeraType { gryphonPrime, basilisk, ravager, wyvern, deathroll, rannsChimera, omegaChimera }

class ChimeraDefinition {
  const ChimeraDefinition({required this.type,required this.name,required this.icon,required this.hp,required this.difficulty,required this.arena,required this.attacks,required this.defenses});
  final ChimeraType type;
  final String name,icon,arena;
  final int hp;
  final double difficulty;
  final List<String> attacks,defenses;
  bool get unlockedByBronzeClear => type==ChimeraType.gryphonPrime;
  static const List<ChimeraDefinition> all = [
    ChimeraDefinition(type:ChimeraType.gryphonPrime,name:'Gryphon Prime',icon:'🦁🦅',hp:800,difficulty:3.5,arena:'Mountain Peak',attacks:['Dive Strike','Shockwave'],defenses:['Dodge Instinct','Iron Hide']),
    ChimeraDefinition(type:ChimeraType.basilisk,name:'Basilisk',icon:'🐉🐍',hp:900,difficulty:4,arena:'Ancient Swamp',attacks:['Poison Breath','Petrify'],defenses:['Energy Shield','Damage Reflect']),
    ChimeraDefinition(type:ChimeraType.ravager,name:'Ravager',icon:'🐗🦁',hp:1200,difficulty:4.5,arena:'Broken Fortress',attacks:['Charge','Roar'],defenses:['Iron Hide','Regeneration']),
    ChimeraDefinition(type:ChimeraType.wyvern,name:'Wyvern',icon:'🦅🐉',hp:700,difficulty:4,arena:'Cliff Edge',attacks:['Fireballs','Dive Strike'],defenses:['Phase Shift','Dodge Instinct']),
    ChimeraDefinition(type:ChimeraType.deathroll,name:'Deathroll',icon:'🐍🐗',hp:1000,difficulty:4.5,arena:'Desert Dunes',attacks:['Venom Aura','Roll Attack'],defenses:['Iron Hide','Damage Reflect']),
    ChimeraDefinition(type:ChimeraType.rannsChimera,name:"Rann's Chimera",icon:'🦁🐗🦅',hp:1800,difficulty:6,arena:'Ruined Throne',attacks:['Full Arsenal','Lightning Strike','Tail Swipe'],defenses:['Phase Shift','Summon Minions','Regeneration']),
    ChimeraDefinition(type:ChimeraType.omegaChimera,name:'Omega Chimera',icon:'🐲',hp:3000,difficulty:8,arena:'Void Dimension',attacks:['Reality Shift','Shockwave','Fireballs','Charge'],defenses:['All Defenses','Phase Shift','Energy Shield']),
  ];
  static ChimeraDefinition byType(ChimeraType type)=>all.firstWhere((c)=>c.type==type);
}
