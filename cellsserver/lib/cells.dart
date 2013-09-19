library cells;
import "dart:async";
import "dart:collection";
import "dart:math";

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
    x = min(max(x - dx, 0), isIn.width - 1);
    y = min(max(y - dy, 0), isIn.height - 1);
    z = min(max(z - dz, 0), isIn.depth - 1);
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
  
  WorldObject(this.color);
}

class World extends ITickable {
  List<ITickable> users = new List<ITickable>();
  int delay = 100;
  Timer timer;
  int ticksTillStart = 0; 
  HashSet<Position> positions = new HashSet<Position>();
  
  int width;
  int height;
  int depth;
  
  Position firstObjectPos;
  Position spectatorPos;
  World(this.width, this.height, this.depth){
   firstObjectPos = new Position(this, 2, 2, 2);
   spectatorPos = new Position(this, 5, 5, 2);
   firstObjectPos.putOn(new WorldObject(new Color(0,255,0)));
   spectatorPos.putOn(new WorldObject(new Color(255,0,0)));
  }
  
  start(){
    timer = new Timer(new Duration(milliseconds: delay), tick);
  }
  
  tick(){
    ticksTillStart++;
    // _logger.info("Tick: ${ticksTillStart}");
    
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
  
  makeMoves(){  
    makeSpecialMoves();
    Set<Position> dealWith = positions.toSet();
   dealWith.forEach((pos) => tryMakeMove(pos));
  }
  
  makeSpecialMoves(){
    var rnd = new Random();
    
    int move = rnd.nextInt(6)-3;
    firstObjectPos.clearMove();
    switch(move.abs()){
      case 1: 
        firstObjectPos.dx = move.isNegative ? -1 : 1;
        break;
      case 2:
        firstObjectPos.dy = move.isNegative ? -1 : 1;
        break;
      case 3:
        firstObjectPos.dz = move.isNegative ? -1 : 1;
        break;
    }
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