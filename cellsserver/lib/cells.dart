library cells;
import "dart:async";
import "dart:collection";
import "dart:math";

import "greenCode.dart";

import "package:logging/logging.dart";

final _logger = new Logger("cells");

abstract class ITickable {
  tick();
}

class Color {
  int r;
  int g;
  int b;  
  Color(this.r, this.g, this.b);
}

class Energy {
  int energyCount;
  
  Energy(this.energyCount);
  
  int incEnergyBy(int inc){
    energyCount+= inc;
    return energyCount;
  }
  
  int decEnergyBy(int dec){
    if(energyCount < dec){
      energyCount = 0;
      return dec;
    }
    energyCount -= dec;
    return energyCount;
  }
}

class Position {
  World isIn;
    
  int x;
  int y;
  int z;
  
  int dx = 0;
  int dy = 0;
  int dz = 0;
  
  WorldObject object;
  Position(this.isIn, this.x, this.y, this.z) {
    if(x < -this.isIn.width || x > this.isIn.width)
      throw new Exception("Out of space X litteraly!");
    if(y < -this.isIn.height || y > this.isIn.height)
      throw new Exception("Out of space Y litteraly!");
    if(z < -this.isIn.depth || z > this.isIn.depth)
      throw new Exception("Out of space Z litteraly!");
    isIn.positions.add(this);
  }
  
  
  clearMove(){
    dx = dy = dz = 0;
  }
  
  moveBack(){
   dx*= -1;
   dy*= -1;
   dz*= -1;
   move();
  }
  
  move(){
    x = min(max(x + dx, 0), isIn.width - 1);
    y = min(max(y + dy, 0), isIn.height - 1);
    z = min(max(z + dz, 0), isIn.depth - 1);
  }
  
  // TODO: Think about this hashCode!
  int get hashCode  =>  x*983 + y*991 + z* 997;
  
  operator ==(Position other){
      return other.x == x && other.y == y && other.z == z;
  }
  
  putOn(WorldObject object){
    this.object = object;
    object.pos = this;
  }
}

class WorldObject {
  static const int startEnergy = 100;
  
  // TODO should be filled by persister with same values for same world!
  static int idseed = 0;
  int id = idseed++;
    
  Position pos;
  Color color;
  Energy energy = new Energy(startEnergy);  
  
  String type = "W";
  
  WorldObject(this.color);
}

class Cell extends WorldObject {
  static Color green = new Color(0,254,0);
  static Color blue = new Color(0,0,254);
  static Color red = new Color(254,0,0);
  
  GreenCodeContext greenCodeContext = null;
  
  Cell(int colorIndex) : super(new Color(0,0,0)){
    type = "C";
    if(colorIndex == 0)
      color = green;
    else if(colorIndex == 1)
      color = blue;
    else if(colorIndex == 2)
      color = red;
  }
  
  factory Cell.withCode(int colorIndex, String codeString){
    Cell constructCell = new Cell(colorIndex);
    if(codeString.contains(";"))
      constructCell.greenCodeContext = new GreenCodeContext.byNames(codeString);
    else if(codeString == "RANDOM")
      constructCell.greenCodeContext = new GreenCodeContext.byRandom(200);
    else
      constructCell.greenCodeContext = new GreenCodeContext.byHex(codeString);
    return constructCell;
  }
}

class Boot extends WorldObject {
  String user;
  Boot(this.user) : super(new Color(128,128,128)){
    type = "B";
  }
}

class World extends ITickable {
  List<ITickable> users = new List<ITickable>();
  int delay = 250;
  Timer timer;
  int ticksTillStart = 0; 
  HashSet<Position> positions = new HashSet<Position>();
  
  int width;
  int height;
  int depth;
  
  World(this.width, this.height, this.depth){
    for(int i = 0; i < 2000; i++){
      Random rnd = new Random();
      WorldObject object = new WorldObject(new Color(rnd.nextInt(255), rnd.nextInt(255), rnd.nextInt(255)));
      Position newObjectPosition = new Position(this, rnd.nextInt(width), rnd.nextInt(height), rnd.nextInt(depth));
      newObjectPosition.putOn(object);
      positions.add(newObjectPosition);
    }
    
    for(int i = 0; i < 200; i++){
      Random rnd = new Random();
      Cell object = new Cell.withCode(rnd.nextInt(3), "RANDOM");
      Position newObjectPosition = new Position(this, rnd.nextInt(width), rnd.nextInt(height), rnd.nextInt(depth));
      newObjectPosition.putOn(object);
      positions.add(newObjectPosition);
    }
  }
    
  Boot findBoot(String user){
    var iterable = positions.where((pos) => pos.object is Boot).where((pos) => (pos.object as Boot).user == user);
    
    if(iterable.length != 1)
      return null;
    else
      return iterable.first.object;
  }
  
  Boot newBoot(String user){
    Random rnd = new Random();
    Boot boot = new Boot(user);
    Position newBootPosition = new Position(this, rnd.nextInt(width), rnd.nextInt(height), rnd.nextInt(depth));
    newBootPosition.putOn(boot);
    return boot;
  }
  
  start(){
    timer = new Timer(new Duration(milliseconds: delay), tick);
  }
  
  tick(){
    ticksTillStart++;
    // _logger.info("Tick: ${ticksTillStart}");
   
    makeGreenCodeCalc();
    makeMoves();
    
    users.forEach((user) => user.tick());
    
    timer = new Timer(new Duration(milliseconds: delay), tick);
  }
  
  HashSet<Position> getObjectsForCube(int x, int y, int z, int radius){
    HashSet debugger = positions.where((position) => x - radius < position.x && position.x < x + radius &&
                                                     y - radius < position.y && position.y < y + radius &&
                                                     z - radius < position.z && position.z < z + radius).toSet();
    return debugger;
  }
  
  
  HashSet<Position> getObjectsForRect(int x, int y, int z, int width, int height, int depth){
    return  positions.where((position) => x < position.x && position.x < x + width &&
        y < position.y && position.y < y + height &&
        z < position.z && position.z < z + depth).toSet();
  }    
  
  
  makeGreenCodeCalc(){
   positions.forEach((pos){ if (pos.object is Cell)
                              (pos.object as Cell).greenCodeContext.doGreenCode();    
                        });
  }
  
  makeMoves(){ 
   Random rnd = new Random();
   Set<Position> dealWith = positions.toSet();
   /*dealWith.forEach((e){
     if(e.object is Cell)
     switch(rnd.nextInt(3)){
       case 0:
         e.dx = rnd.nextInt(3)-1;         
         break;
       case 1:
         e.dy = rnd.nextInt(3)-1;         
         break;
       case 2:
         e.dz = rnd.nextInt(3)-1;         
         break;       
     }
    }); */
   dealWith.forEach((pos) => tryMakeMove(pos));
  }
  
  
  tryMakeMove(Position pos){
    positions.remove(pos);
   
    pos.move();   
   
    if(positions.contains(pos)){
      pos.moveBack();
    }
    positions.add(pos);
    pos.clearMove();  
  }
}