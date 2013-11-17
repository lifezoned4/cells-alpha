library cells;
import "dart:async";
import "dart:collection";
import "dart:math";

import '../cellsCore.dart';

import "greenCode.dart";

import "package:logging/logging.dart";

final _logger = new Logger("cells");

abstract class ITickable {
  tick();
}

class Color {
  static Color Red = new Color(254,0,0);
  static Color Green = new Color(0,254,0);
  static Color Blue = new Color(0,0,254);
  
  Color Copy() => new Color(r, g, b);
  
  int r;
  int g;
  int b;  
  Color(this.r, this.g, this.b);
}

class Energy {  
  static const int maxEnergyInObject = 255;
  int energyCount;
  Color color;
  
  Energy(this.energyCount);
  
  int incEnergyBy(int inc){
    if(energyCount + inc > maxEnergyInObject){      
      int buffEnergyCount = energyCount + inc - maxEnergyInObject;
      energyCount = maxEnergyInObject;
      return inc - buffEnergyCount;
    }
    energyCount+= inc;
    return inc;
  }
  
  int decEnergyBy(int dec){
    if(energyCount < dec){
      int buffEnergyCount = energyCount;
      energyCount = 0;
      return buffEnergyCount;
    }
    energyCount -= dec;
    return dec;
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
    if(x + dx < 0 || x + dx > isIn.width -1)
      dx = 0;
    if(y+ dy < 0 || y + dy > isIn.height -1)
      dy = 0;
    if(z + dz < 0 || z + dz > isIn.depth -1)
      dz = 0;
    x = x + dx;
    y = y + dy;
    z = z + dz;
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
  Color _color;
  
  Color getColor() => _color;
  
  Energy energy = new Energy(startEnergy);  
  
  String type = "W";
  
  WorldObject(this._color);
}


class Cell extends WorldObject {
  GreenCodeContext greenCodeContext = null;
 
  
  Cell(Color toSet) : super(toSet){
    type = "C";
    if(toSet.r == Color.Green.r && toSet.g == Color.Green.g && toSet.b == Color.Green.b)
    {
      _color = Color.Green;
      outputColor = Color.Red.Copy();
      outputColor.r = (outputColor.r ~/ Color.Red.r);
    }
    else if(toSet.r == Color.Blue.r && toSet.g == Color.Blue.g && toSet.b == Color.Blue.b)
    {
      _color = Color.Blue;
      outputColor = Color.Green.Copy();
      outputColor.g = (outputColor.g ~/ Color.Green.g);
    }
    else if(toSet.r == Color.Red.r && toSet.g == Color.Red.g && toSet.b == Color.Red.b)
    {
      _color = Color.Red;
      outputColor = Color.Blue.Copy();
      outputColor.b = (outputColor.b ~/ Color.Blue.b);
    } 
  }
  
  factory Cell.withCode(Color toSet, String codeString){
    Cell constructCell = new Cell(toSet);
    if(codeString.contains(";"))
      constructCell.greenCodeContext = new GreenCodeContext.byNames(codeString);
    else if(codeString == "RANDOM")
      constructCell.greenCodeContext = new GreenCodeContext.byRandom(200);
    else
      constructCell.greenCodeContext = new GreenCodeContext.byHex(codeString);
    return constructCell;
  }
  
  Color outputColor;
  int outputBuffer = 0;
  consumeEnergy(int inc){
    int out = energy.decEnergyBy(1);
    outputBuffer+= out;
    if(outputBuffer > energy.energyCount/10)
    {      
      ejectOutput(null);
    }
  }

  void makeConsumptions(){
     consumeEnergy((greenCodeContext.copyCost/100).ceil());
  }
  
  void ejectOutput(Position toPlaceOn) {
     Random rnd = new Random();
    Color bufColor = new Color(outputColor.r * outputBuffer, outputColor.g * outputBuffer, outputColor.b * outputBuffer);
    if(toPlaceOn == null)
      toPlaceOn = new Position(pos.isIn, min(0, max(pos.x + rnd.nextInt(2)-1, pos.isIn.width)),
                                                  min(0, max(pos.y + rnd.nextInt(2)-1, pos.isIn.height)),
                                                  min(0, max(pos.z + rnd.nextInt(2)-1, pos.isIn.depth)));
    pos.isIn.newOutputMass(toPlaceOn ,bufColor);
  }
  
  die(){
    ejectOutput(pos);
  }
}

class Mass extends WorldObject{
  Energy energyR;
  Energy energyG;
  Energy energyB;
  Mass(Color color) : super(color){
    type = "M";
    energyR = new Energy(color.r);
    energyR.color = new Color(1,0,0);
    energyG = new Energy(color.g);
    energyG..color = new Color(0,1,0);
    energyB = new Energy(color.b);
    energyB.color = new Color(0,0,1);
  }
  
  getColor() => new Color(energyR.energyCount, energyG.energyCount, energyB.energyCount);
}


class Boot extends WorldObject {
  String user;
  Boot(this.user) : super(new Color(128,128,128)){
    type = "B";
  }
}

class World extends ITickable {
  List<User> users = new List<User>();
  int delay = 250;
  Timer timer;
  int ticksTillStart = 0; 
  HashSet<Position> positions = new HashSet<Position>();
  
  int width;
  int height;
  int depth;
  
  World(this.width, this.height, this.depth){
    for(int i = 0; i < 400; i++){
      Random rnd = new Random();
      Mass object = new Mass(new Color(rnd.nextInt(255), rnd.nextInt(255), rnd.nextInt(255)));
      Position newObjectPosition = new Position(this, rnd.nextInt(width), rnd.nextInt(height), rnd.nextInt(depth));
      newObjectPosition.putOn(object);
      positions.add(newObjectPosition);
    }
    
    for(int i = 0; i < 200; i++){
      Random rnd = new Random();
      Color toSet;
      switch(rnd.nextInt(3)){
        case 0:
          toSet = Color.Red;
          break;
        case 1:
          toSet = Color.Green;
          break;
        case 2:
          toSet = Color.Blue;
          break;
        default:
          toSet = Color.Red;
      }
      Cell object = new Cell.withCode(toSet, "RANDOM");
      Position newObjectPosition = new Position(this, rnd.nextInt(width), rnd.nextInt(height), rnd.nextInt(depth));
      newObjectPosition.putOn(object);
      positions.add(newObjectPosition);
    }
  }
    
  newOutputMass(Position pos, Color createColor)
  {
     Mass mass = new Mass(createColor);
     pos.putOn(mass);
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
    makeMovesAndEatsAndKill();
    
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
    
  makeMovesAndEatsAndKill(){ 
   Set<Position> dealWith = positions.toSet();
  
   dealWith.forEach((pos) => tryMakeMoves(pos));

   dealWith.forEach((pos){ if(pos.object is Cell) 
                              {
                                  Cell cell = pos.object;
                                  cell.makeConsumptions();
                              } 
   });
   
   Set<Position> allreadyFeed = new Set<Position>();
   dealWith.forEach((pos) => tryEatFor(pos, allreadyFeed));

   List<Position> dead = new List<Position>();
   
   dealWith.forEach((pos){
      if(pos.object is Mass){
        Mass mass = pos.object;
        if(mass.energyB.energyCount == 0 && mass.energyG.energyCount == 0 && mass.energyR.energyCount == 0)
          dead.add(pos);
      } else if(pos.object is Cell){
        Cell cell = pos.object;
        if(cell.energy.energyCount == 0){
          cell.die();
          dead.add(pos);
        }
      }
      });
   
   positions.removeAll(dead);
   _logger.info("positions = ${positions.length}");
  }
  
   static const int MassConsume = 75;
  
  tryIfInject(Position pos){
    if(!(pos.object is Cell))
      return;
    Cell cell = pos.object;
    if(!cell.greenCodeContext.inject)
      return;
    if(cell.greenCodeContext.injectTo != Direction.NONE)
    {
      
    }
  }
   
  tryEatFor(Position pos, Set<Position> allreadyFeed){
    HashSet<Position> surrounding = getObjectsForRect(pos.x - 1, pos.y -1, pos.z -1, 3, 3, 3);
    surrounding.removeAll(allreadyFeed);

    List<Direction> picks = new List<Direction>();
    for(int dx = -1; dx <= 1; dx++)
      for(int dy = -1; dy <= 1; dy++)
        for(int dz = -1; dz <= 1; dz++){
          Direction dir = new Direction();
          dir.dirX = dx;
          dir.dirY = dy;
          dir.dirZ = dz;
          if(dir.dirX == 0  && dir.dirY == 0 && dir.dirZ == 0)
            continue;
          picks.add(dir);
        }
    
    Random rnd = new Random();
    
    if(pos.object is Mass){
      Mass mass = pos.object;
                  
      bool eaten = false;
      while(picks.length > 0 || !eaten)
      {
        if(picks.length == 0)
          break;
        int pickNum = rnd.nextInt(picks.length);
        Direction dir = picks.removeAt(pickNum);      
          
      
        Iterable<Position >foundings = surrounding.where((pos) => pos.x == mass.pos.x + dir.dirX && pos.y == mass.pos.y + dir.dirY && pos.z == mass.pos.y + dir.dirZ);
        
        if(foundings.length == 1){
          if(foundings.first.object is Mass){
            List<Energy> order = new List<Energy>();
            order.add(mass.energyR);
            order.add(mass.energyG);
            order.add(mass.energyB);
            order.sort((a, b) => b.energyCount - a.energyCount);
            
            Mass toConsume = foundings.first.object;
            Energy firstEnergy = order.removeAt(0);
            int firstleft = MassConsume - firstEnergy.incEnergyBy(firstEnergy.color.r == 1 ? toConsume.energyR.decEnergyBy(MassConsume) 
                                  : firstEnergy.color.g == 1 ? toConsume.energyG.decEnergyBy(MassConsume) 
                                  : toConsume.energyB.decEnergyBy(MassConsume));
            Energy secoundEnergy = order.removeAt(0);
            int secoundleft = firstleft - secoundEnergy.incEnergyBy(secoundEnergy.color.r == 1 ? toConsume.energyR.decEnergyBy(firstleft) 
                : secoundEnergy.color.g == 1 ? toConsume.energyG.decEnergyBy(firstleft) 
                : toConsume.energyB.decEnergyBy(firstleft));
            Energy thirdEnergy = order.removeAt(0);
            int thirdleft =  secoundleft - thirdEnergy.incEnergyBy(thirdEnergy.color.r == 1 ? toConsume.energyR.decEnergyBy(secoundleft) 
                : thirdEnergy.color.g == 1 ? toConsume.energyG.decEnergyBy(secoundleft) 
                : toConsume.energyB.decEnergyBy(secoundleft));          
            eaten = thirdleft == 0;
          }
        }
      }
    }
    
    else if(pos.object is Cell){
      Cell cell = pos.object;
      if(cell.greenCodeContext.eat){
        bool eaten = false;
        if(cell.energy.energyCount == 0)
          return;
        int hunger = 2*log(cell.energy.energyCount).ceil();
        int startHunger = hunger;
        while(picks.length > 0 || !eaten)
        {
          if(picks.length == 0)
            break;
          int pickNum = rnd.nextInt(picks.length);
          Direction dir = picks.removeAt(pickNum);      
          
          
          Iterable<Position >foundings = surrounding.where((pos) => pos.x == cell.pos.x + dir.dirX && pos.y == cell.pos.y + dir.dirY && pos.z == cell.pos.y + dir.dirZ);
          
          if(foundings.length == 1){
            if(foundings.first.object is Mass){
              Mass toConsume = foundings.first.object;
              int eaten = 0;
              
              if(cell.getColor().b == 254)
               eaten = toConsume.energyR.decEnergyBy(hunger);
              else if(cell.getColor().g == 254)
               eaten = toConsume.energyB.decEnergyBy(hunger);
              else
               eaten = toConsume.energyG.decEnergyBy(hunger);
              
              hunger -= eaten;
              int left = cell.energy.incEnergyBy(eaten);
              
              if(cell.getColor().b == 254)
               eaten = toConsume.energyR.incEnergyBy(left);
              else if(cell.getColor().g == 254)
               eaten = toConsume.energyB.incEnergyBy(left);
              else
               eaten = toConsume.energyG.incEnergyBy(left);
            }
            else if (foundings.first.object is Cell){
              Cell toConsume = foundings.first.object;
              if(cell.getColor().b == 254 && toConsume.getColor().r == 254 ||
                 cell.getColor().r == 254 && toConsume.getColor().g == 254 ||
                 cell.getColor().g == 254 && toConsume.getColor().b == 254)
              {
                int eaten = toConsume.energy.decEnergyBy(hunger);
                hunger -= eaten;
                int left = cell.energy.incEnergyBy(eaten);
                toConsume.energy.incEnergyBy(left);
              }
            }
          }
        }
        if(hunger == startHunger)
        {
         cell.consumeEnergy((log(cell.energy.energyCount) / log(10)).ceil());
        }
      }
    }
    
    allreadyFeed.add(pos);
 }
  
  tryMakeMoves(Position pos){
    positions.remove(pos);
    
    if(pos.object is Cell)
    {
      Cell cell = pos.object;
      if(0 != (cell.greenCodeContext.nextMove.dirX + cell.greenCodeContext.nextMove.dirY + cell.greenCodeContext.nextMove.dirZ).abs());
      {         
        cell.consumeEnergy(1);
      }
      pos.dx = cell.greenCodeContext.nextMove.dirX;
      pos.dy = cell.greenCodeContext.nextMove.dirY;
      pos.dz = cell.greenCodeContext.nextMove.dirZ;
    }
    
    if(pos.object is Mass)
    {
      Random rnd = new Random();
      Mass energy = pos.object;
      pos.dx = rnd.nextInt(3) - 1;
      pos.dy = rnd.nextInt(3) - 1;
      pos.dz = rnd.nextInt(3) - 1;
    }
    
    pos.move();   
   
    if(positions.contains(pos)){
      pos.moveBack();
    }
    positions.add(pos);
    pos.clearMove();  
  }
}