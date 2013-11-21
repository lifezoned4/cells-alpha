library cells;
import "dart:async";
import "dart:collection";
import "dart:math";


import '../cellsPersist.dart';
import '../cellsCore.dart';

import "greenCode.dart";

import "package:logging/logging.dart";

final _logger = new Logger("cells");

abstract class ITickable {
  tick();
}

class Color extends MassObject {
  static Color Red = new Color(254,0,0, "r");
  static Color Green = new Color(0,254,0,"g");
  static Color Blue = new Color(0,0,254, "b");
  
  Color Copy() => new Color(r, g, b, name);
  
  int r;
  int g;
  int b;  
  Color(this.r, this.g, this.b, String name){
    super.name = name;
  }
}

class Energy {  
  static const double maxEnergyInObject = 50000.0;
  double energyCount;
  Color color;
  
  Energy(this.energyCount);
  
  double incEnergyBy(double inc){
    if(energyCount + inc > maxEnergyInObject){      
      double buffEnergyCount = energyCount + inc - maxEnergyInObject;
      energyCount = maxEnergyInObject;
      return inc - buffEnergyCount;
    }
    energyCount+= inc;
    return inc;
  }
  
  double decEnergyBy(double dec){
    if(energyCount < dec){
      double buffEnergyCount = energyCount;
      energyCount = 0.0;
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
    if(x < 0 || x >= this.isIn.width)
      throw new Exception("Out of space X litteraly!");
    if(y < 0 || y >= this.isIn.height)
      throw new Exception("Out of space Y litteraly!");
    if(z < 0|| z >= this.isIn.depth)
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
  static const double startEnergy = 10000.0;
  
  // TODO should be filled by persister with same values for same world!
  static int idseed = 0;
  int id = idseed++;
  
  bool isHold = false;
    
  Position pos;
  Color _color;
  
  Color getColor() => _color;
  
  Energy energy = new Energy(startEnergy);  
  
  String type = "W";
  
  WorldObject(this._color);
}


class Cell extends WorldObject {
  GreenCodeContext greenCodeContext = null;
   
  int livingBleed = 0;
  
  Mass body;
  
  Cell(Color toSet) : super(toSet){
    
    type = "C";
    body = new Mass(toSet, pow(WorldObject.startEnergy * 3/(4*PI), 1/3));
    
    if(toSet.r == Color.Green.r && toSet.g == Color.Green.g && toSet.b == Color.Green.b)
    {
      _color = Color.Green;
      outputColor = Color.Red;
    }
    else if(toSet.r == Color.Blue.r && toSet.g == Color.Blue.g && toSet.b == Color.Blue.b)
    {
      _color = Color.Blue;
      outputColor = Color.Green;
    }
    else if(toSet.r == Color.Red.r && toSet.g == Color.Red.g && toSet.b == Color.Red.b)
    {
      _color = Color.Red;
      outputColor = Color.Blue;
    } 
  }
  
  factory Cell.withCode(Color toSet, String codeString){
    Cell constructCell = new Cell(toSet);
    if(codeString.contains(";"))
      constructCell.greenCodeContext = new GreenCodeContext.byNames(codeString);
    else if(codeString == "RANDOM")
      constructCell.greenCodeContext = new GreenCodeContext.byRandom(10);
    else
      constructCell.greenCodeContext = new GreenCodeContext.byHex(codeString);
    return constructCell;
  }
  
  Color outputColor =  Color.Red;
  double outputBuffer = 0.0;
  consumeEnergy(double dec){
    double out = energy.decEnergyBy(dec);
    outputBuffer += out;
    if(outputBuffer > 100)
    {      
      ejectOutput(null);
      outputBuffer = 0.0;
    }
  }

  void makeConsumptions(){
     // consumeEnergy(greenCodeContext.copyCost/100);
    double nextSize = pow(body.size + 1,3)*4/3*PI - pow(body.size, 3)*4/3*PI;
    if(energy.energyCount >= nextSize){
      energy.energyCount - nextSize;
      body.size++;
    }
    livingBleed++;
    if(livingBleed > 50){
      livingBleed = 0;
      consumeEnergy(body.size / 50 > 1 ? body.size / 50  : 1.0);
    }
    greenCodeContext.copyCost = 0;

  }
  
  void ejectOutput(Position toPlaceOn) {
    Random rnd = new Random();
    if(toPlaceOn == null)
    {  
      int tries = 0;
      bool placed = false;
      while(tries++ < 10 && !placed){
         int tryX =  max(0, min(pos.x + rnd.nextInt(3)-1, pos.isIn.width -1));
         int tryY = max(0, min(pos.y + rnd.nextInt(3)-1, pos.isIn.height -1));
         int tryZ = max(0, min(pos.z + rnd.nextInt(3)-1, pos.isIn.depth -1));
         Iterable it = pos.isIn.positions.where((posSearch)=> posSearch.x == tryX && posSearch.y == tryY && posSearch.z == tryZ);
         if(it.length == 0){
            toPlaceOn = new Position(pos.isIn, tryX, tryY, tryZ);
            placed = true;
         }
      }                                      
    if(tries >= 10 && !placed)
      return;
    }
    double massoutput = pow(3* outputBuffer / (4*PI),1/3);
    pos.isIn.newOutputMass(toPlaceOn ,outputColor, massoutput);
  }
  
  die(){
    ejectOutput(pos);
  }
}

class Mass extends WorldObject{

  double size;
  
  static double maxSize = pow(Energy.maxEnergyInObject*(3.0/(4.0*PI)),1/3);
  
  double toEnergy(){
    return pow(size, 3.0)*(4.0/3.0)*PI;
  }
  
  double consume(double hunger){
    double left = pow(size,3)*4/3*PI - hunger;
    if(left <= 0)
    {
      size = 0.0;
      return hunger + left;
    }
    else  {
      size = pow(left*3/(4*PI), 1/3);
      return hunger;
    }
  }
  
  double grow(double toGrow){
    double growen = pow(3/(4*PI)*((pow(size, 3)*4/3*PI) + toGrow), 1/3);
    if(growen > Mass.maxSize){
      double left = pow(growen,3)*4*PI/3 - pow(Mass.maxSize,3)*4 * PI /3;
      size = Mass.maxSize;
      return toGrow - left;
    }
    else {
      size = growen;
      return toGrow;
    }      
  }
  
  Mass(Color color, this.size) : super(color){
    type = "M";
  }
}

class MassObject {
  String name;
}

class EmptyObject extends MassObject {
  String name = "-";
}


class Boot extends WorldObject {
  String user;
  WorldObject selected;
  
  List<MassObject> band = new List<MassObject>();
  int bandPos = 3;
  
  Direction facing = Direction.E;
  
  Boot(this.user) : super(new Color(128,128,128,"gr")){
    type = "B";
    for(int i = 0; i <= 6; i++)
    band.add(new EmptyObject());
  }
  
  bandToString(){
    String returner = "";
    band.forEach((object) => returner += object.name + ";");
    return returner;
  }
  
  insertBit(Color color){
    if(band.elementAt(bandPos) is EmptyObject)
    {
      band.removeAt(3);
      band.insert(3,color);
    } 
  }
}

class World extends ITickable {
  List<User> users = new List<User>();
  int delay = 25;
  int timeToSave = 0;
  Timer timer;
  int ticksTillStart = 0; 
  HashSet<Position> positions = new HashSet<Position>();
  
  int width;
  int height;
  int depth;
  
  World(this.width, this.height, this.depth){
    /* for(int i = 0; i < 100; i++){
      Random rnd = new Random();
      Color choosenColor;
      switch(rnd.nextInt(3)){
        case 0:
          choosenColor = Color.Red;
          break;
        case 1:
          choosenColor = Color.Green;
          break;
        case 2:
          choosenColor = Color.Blue;
          break;
      }
      
      Mass object = new Mass(choosenColor, rnd.nextDouble()*5);
      Position newObjectPosition = new Position(this, rnd.nextInt(width), rnd.nextInt(height), rnd.nextInt(depth));
      newObjectPosition.putOn(object);
      positions.add(newObjectPosition);
    }
    
    for(int i = 0; i < 50; i++){
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
    */
  }
    
  newOutputMass(Position pos, Color createColor, double size)
  {
     Mass mass = new Mass(createColor, size);
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
   
    if(ticksTillStart % 100 == 0)
      FilePersistContext.wirteSave(this);
    
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
        if(mass.toEnergy() <= 0.0)
          dead.add(pos);
      } else if(pos.object is Cell){
        Cell cell = pos.object;
        if(cell.energy.energyCount == 0){
          if(cell.body.size > 0){
            double refund = pow(cell.body.size,3)*PI*4/3 - pow(cell.body.size - 1, 3)*PI*4/3;
            cell.body.size--;
            if(cell.body.size <= 0){
              cell.die();
              dead.add(pos);
            }
            else
              cell.energy.incEnergyBy(refund);                       
          }
          else {
            cell.die();
            dead.add(pos);
          }
        }
      }
      });
   
   positions.removeAll(dead);
   _logger.info("positions = ${positions.length}");
  }
  
 static const int MassMerge = 75;
  
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
    HashSet<Position> surrounding = getObjectsForCube(pos.x, pos.y, pos.z, 2);
    surrounding.remove(pos);
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
                  
      while(picks.length > 0)
      {
        if(picks.length == 0)
          break;
        int pickNum = rnd.nextInt(picks.length);
        Direction dir = picks.removeAt(pickNum);      
        
        // _logger.info("Surrounding : ${surrounding.length}");
        
        
        Iterable<Position >foundings = surrounding.where((pos) => pos.x == (mass.pos.x + dir.dirX) && pos.y == (mass.pos.y + dir.dirY) && pos.z == (mass.pos.z + dir.dirZ));
        
        // _logger.info("Foundings : ${foundings.length}");
        
        if(foundings.length == 1){
          if(foundings.first.object is Mass){                        
            Mass toConsume = foundings.first.object;
            if(toConsume.getColor() == null)
              _logger.warning("Autsch");
            if(toConsume.getColor().r == mass.getColor().r && toConsume.getColor().g == mass.getColor().g && toConsume.getColor().b == mass.getColor().b)
            { 
              mass.size = pow(3/(4*PI)*(pow(mass.size,3)*4*PI/3 +  pow(toConsume.size,3)*4*PI/3), 1/3);       
              toConsume.size = 0.0;
            // _logger.info("MERGING MASS");
            }
          }
        }
      }
    }    
    else if(pos.object is Cell){
      Cell cell = pos.object;
      if(cell.greenCodeContext.eat){
        bool hasEaten = false;
        if(cell.energy.energyCount == 0)
          return;
        double hunger = cell.body.size*5;
        double startHunger = hunger;
        while(picks.length > 0 || !hasEaten)
        {
          if(picks.length == 0)
            break;
          int pickNum = rnd.nextInt(picks.length);
          Direction dir = picks.removeAt(pickNum);      
                    
          Iterable<Position >foundings = surrounding.where((pos) => pos.x == cell.pos.x + dir.dirX && pos.y == cell.pos.y + dir.dirY && pos.z == cell.pos.z + dir.dirZ);
          
          if(foundings.length == 1){
            if(foundings.first.object is Mass){
              Mass toConsume = foundings.first.object;
              if(cell.getColor().b == Color.Blue.b && toConsume.getColor().r == Color.Red.r ||
                  cell.getColor().r == Color.Red.r && toConsume.getColor().g == Color.Green.g ||
                  cell.getColor().g == Color.Green.g && toConsume.getColor().b == Color.Blue.b)
              {
                double eaten = toConsume.consume(hunger);
                double left = hunger - cell.energy.incEnergyBy(eaten);
                hunger -= eaten;            
                toConsume.grow(left);
              }
              if(hunger == 0)
                hasEaten = true;
            }
            else if (foundings.first.object is Cell){
              Cell toConsume = foundings.first.object;
              if(cell.getColor().b == Color.Blue.b && toConsume.getColor().r == Color.Red.r ||
                  cell.getColor().r == Color.Red.r && toConsume.getColor().g == Color.Green.g ||
                  cell.getColor().g == Color.Green.g && toConsume.getColor().b == Color.Blue.b)
              {
                double eaten = toConsume.body.consume(hunger);
                hunger -= eaten;
                double left = cell.energy.incEnergyBy(eaten);
                toConsume.body.grow(left);
                if(hunger == 0)
                  hasEaten = true;
              }
            }
          }
        }
        if(hunger == startHunger)
        {
         // cell.consumeEnergy((log(cell.body.toEnergy()) / log(10)));
        }
      }
    }
    
    allreadyFeed.add(pos);
 }
  
  tryMakeMoves(Position pos){
    if(pos.object.isHold)
      return;
    
    if(pos.object is Boot && pos.dx + pos.dy + pos.dz != 0){
      Boot boot = pos.object;
      if(!boot.facing.isThis(pos.dx, pos.dy, pos.dz))
      {
        boot.facing = Direction.getThis(pos.dx, pos.dy, pos.dz);
        if(boot.selected != null)
        {
          (pos.object as Boot).selected.isHold = false;
          (pos.object as Boot).selected = null;
        }
        pos.clearMove();
        return;
      }
    }
    
    positions.remove(pos);
       
    if(pos.object is Cell)
    {
      Cell cell = pos.object;
      if(0 != (cell.greenCodeContext.nextMove.dirX + cell.greenCodeContext.nextMove.dirY + cell.greenCodeContext.nextMove.dirZ).abs());
      {         
        cell.consumeEnergy(cell.body.size / 50);
      }
      pos.dx = cell.greenCodeContext.nextMove.dirX;
      pos.dy = cell.greenCodeContext.nextMove.dirY;
      pos.dz = cell.greenCodeContext.nextMove.dirZ;
    }
    
    pos.move();   
   
    if(positions.contains(pos)){
      if(pos.object is Boot){
        WorldObject toSelect = positions.where((colider) => colider.x == pos.x && colider.y == pos.y && colider.z == pos.z).first.object;
        (pos.object as Boot).selected = toSelect;
        toSelect.isHold = true;
      }
      pos.moveBack();      
    }
    positions.add(pos);
    pos.clearMove();  
  }
}