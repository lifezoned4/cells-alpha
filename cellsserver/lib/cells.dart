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

class Color {
  static Color Red = new Color(254,0,0, "r");
  static Color Green = new Color(0,254,0,"g");
  static Color Blue = new Color(0,0,254, "b");
  
  Color Copy() => new Color(r, g, b, name);
  
  String name;
  
  int r;
  int g;
  int b;  
  Color(this.r, this.g, this.b, String name){
    this.name = name;
  }
  
  bool ThisIs(Color color){
    return color.r == r && color.g == g && color.b == b;
  }
}

class Energy {  
  static double maxEnergyInObject = pow(2,32).toDouble();
  double energyCount;
  Color color;
  
  Energy(this.energyCount);
  
  
  // returns how much energy really incremented
  double incEnergyBy(double inc){
    if(energyCount + inc >= maxEnergyInObject){      
      double buffEnergyCount = energyCount + inc - maxEnergyInObject;
      energyCount = maxEnergyInObject;
      return inc - buffEnergyCount;
    }
    energyCount+= inc;
    return inc;
  }
  
  double decEnergyBy(double dec){
    if(energyCount <= dec){
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
  static const double startEnergy = 100.0;
  
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
    
  Cell(Color toSet) : super(toSet){
    
    type = "C"; 
    
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
    consumeEnergy(greenCodeContext.copyCost.toDouble() / 100);   
    livingBleed++;
    if(livingBleed > 50){
      livingBleed = 0;
      consumeEnergy(pow(energy.energyCount,1/8));
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
    double massoutput = outputBuffer;
    pos.isIn.newOutputMass(toPlaceOn ,outputColor, massoutput);
  }
  
  die(){
    ejectOutput(pos);
  }
}

class Mass extends WorldObject{
  Mass(Color color) : super(color){
    type = "M";
  }
}

class Boot extends WorldObject {
  String user;
  WorldObject selected;
  
  Direction facing = Direction.E;
  
  Boot(this.user) : super(new Color(128,128,128,"gr")){
    type = "B";
  }
}

class World extends ITickable {
  List<User> users = new List<User>();
  int delay = 100;
  int timeToSave = 0;
  Timer timer;
  int ticksTillStart = 0; 
  HashSet<Position> positions = new HashSet<Position>();
  
  int width;
  int height;
  int depth;
  
  World(this.width, this.height, this.depth){
    /* for(int i = 0; i < 200; i++){
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
      
      Mass object = new Mass(choosenColor);
      object.energy.energyCount = rnd.nextDouble()*WorldObject.startEnergy;
      Position newObjectPosition = new Position(this, rnd.nextInt(width), rnd.nextInt(height), rnd.nextInt(depth));
      newObjectPosition.putOn(object);
      positions.add(newObjectPosition);
    } */
    
    /*for(int i = 0; i < 100; i++){
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
      object.energy.energyCount =  rnd.nextDouble()*WorldObject.startEnergy*1000;
      positions.add(newObjectPosition); 
    }*/
  }
    
  newOutputMass(Position pos, Color createColor, double size)
  {
     Mass mass = new Mass(createColor);
     mass.energy.energyCount = size;
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
   positions.forEach((pos){ if (pos.object is Cell && !pos.object.isHold)
                              (pos.object as Cell).greenCodeContext.doGreenCode();    
                        });
  }
    
  makeMovesAndEatsAndKill(){
   Set<Position> dealWith = positions.toSet();
  
   dealWith.forEach((pos) => tryMakeMoves(pos));

   dealWith.forEach((pos){ if(pos.object is Cell && !pos.object.isHold) 
                              {
                                  Cell cell = pos.object;
                                  cell.makeConsumptions();
                                  tryIfInject(pos);
                              } 
   });
   
   Set<Position> allreadyFeed = new Set<Position>();
   dealWith.forEach((pos) => tryEatFor(pos, allreadyFeed));

   List<Position> dead = new List<Position>();
   
   dealWith.forEach((pos){
      if(pos.object is Mass){
        Mass mass = pos.object;
        if(mass.energy.energyCount <= 0.0)
          dead.add(pos);
      } else if(pos.object is Cell){
        Cell cell = pos.object;
        if(cell.energy.energyCount <= 0){
              cell.die();
              dead.add(pos);
          }
        }
      });
   
   positions.removeAll(dead);
   double totalEnergyGreen = 0.0;
   double totalEnergyRed = 0.0;
   double totalEnergyBlue = 0.0;
   positions.forEach((pos)  {
    if(pos.object.getColor().ThisIs(Color.Green))
      totalEnergyGreen+=pos.object.energy.energyCount;
    else if(pos.object.getColor().ThisIs(Color.Red))
      totalEnergyRed+=pos.object.energy.energyCount;
    else if (pos.object.getColor().ThisIs(Color.Blue))
      totalEnergyBlue+=pos.object.energy.energyCount;     
   });
   
    // _logger.info("positions = ${positions.length} red = ${totalEnergyRed} green = ${totalEnergyGreen} blue = ${totalEnergyBlue}");
    // _logger.info("total = ${totalEnergyGreen + totalEnergyBlue + totalEnergyRed}");
  }
  
  demoMode(){
    for(int i = 0; i < 100; i++){
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
      object.energy.energyCount =  rnd.nextDouble()*WorldObject.startEnergy*1000;
      positions.add(newObjectPosition); 
    }
  }
  
 static const int MassMerge = 75;
  
  tryIfInject(Position pos){
    if(!(pos.object is Cell) || pos.object.isHold)
      return;
    Cell cell = pos.object;
    if(!cell.greenCodeContext.inject)
      return;
    if(!cell.greenCodeContext.injectTo.isThis(0, 0, 0))
    {
      Position found = null;
      Iterable founder = positions.where((posSearch) => posSearch.x == pos.x + cell.greenCodeContext.injectTo.dirX &&
                                                        posSearch.y == pos.y + cell.greenCodeContext.injectTo.dirY &&
                                                        posSearch.z == pos.z + cell.greenCodeContext.injectTo.dirZ);
      if(founder.length == 1){
        found = founder.first;
      }
      
      if(found != null){
       if(found.object is Mass){
         Mass mass = found.object;
         Cell newCell = new Cell.withCode(mass.getColor(), 
             cell.greenCodeContext.codeToStringNamesRange(cell.greenCodeContext.ReadHead, 
                                                          cell.greenCodeContext.FaceHead, false));
         cell.greenCodeContext.removeCodeFromTo(cell.greenCodeContext.ReadHead,  cell.greenCodeContext.FaceHead);
         cell.greenCodeContext.modulateHeads();
         newCell.energy.energyCount = mass.energy.energyCount;
         _logger.info("MASS IS NOW CELL");
         mass.pos.putOn(newCell);
       } else if (found.object is Cell){
         Cell toInjectIn = found.object;
         toInjectIn.greenCodeContext.code.insertAll(toInjectIn.greenCodeContext.WriteHead, 
             GreenCodeContext.stringToCode(
                 cell.greenCodeContext.codeToStringNamesRange(cell.greenCodeContext.ReadHead, 
                                                              cell.greenCodeContext.FaceHead, false)));
         cell.greenCodeContext.removeCodeFromTo(cell.greenCodeContext.ReadHead,  cell.greenCodeContext.FaceHead);
         cell.greenCodeContext.modulateHeads(); 
       }
      }
      else {
        if(cell.energy.energyCount < WorldObject.startEnergy)
          return;
        String extractedCode =   cell.greenCodeContext.codeToStringNamesRange(cell.greenCodeContext.ReadHead, 
            cell.greenCodeContext.FaceHead, false);
        _logger.info(extractedCode);
        Cell newCell = new Cell.withCode(cell.getColor(), extractedCode);
        Position newPos;
        try {
          newPos = new Position(this, 
              cell.pos.x + cell.greenCodeContext.injectTo.dirX,
              cell.pos.y + cell.greenCodeContext.injectTo.dirY, 
              cell.pos.z + cell.greenCodeContext.injectTo.dirZ);
          } on Exception catch (e){}
        if(newPos != null){
          cell.greenCodeContext.removeCodeFromTo(cell.greenCodeContext.ReadHead,  cell.greenCodeContext.FaceHead);
          cell.greenCodeContext.modulateHeads();
          newPos.putOn(newCell);
          _logger.info("NEW CELL IS BORN");
          cell.energy.decEnergyBy(WorldObject.startEnergy);
        }
      }
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
              mass.energy.energyCount+= toConsume.energy.energyCount;
              toConsume.energy.energyCount = 0.0;
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
        double hunger = pow(cell.energy.energyCount, 1/8)* WorldObject.startEnergy;
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
              if(cell.getColor().ThisIs(Color.Blue) && toConsume.getColor().ThisIs(Color.Red) ||
                  cell.getColor().ThisIs(Color.Red) && toConsume.getColor().ThisIs(Color.Green) ||
                  cell.getColor().ThisIs(Color.Green) && toConsume.getColor().ThisIs(Color.Blue))
              {
                double eaten = toConsume.energy.decEnergyBy(hunger);
                double left = hunger - cell.energy.incEnergyBy(eaten);
                hunger -= eaten;            
                toConsume.energy.incEnergyBy(left);
              }
              if(hunger == 0)
                hasEaten = true;
            }
            else if (foundings.first.object is Cell){
              Cell toConsume = foundings.first.object;
              if(cell.getColor().ThisIs(Color.Blue) && toConsume.getColor().ThisIs(Color.Red) ||
                  cell.getColor().ThisIs(Color.Red) && toConsume.getColor().ThisIs(Color.Green) ||
                  cell.getColor().ThisIs(Color.Green) && toConsume.getColor().ThisIs(Color.Blue))
              {
                double eaten = toConsume.energy.decEnergyBy(hunger);
                hunger -= eaten;
                double left = cell.energy.incEnergyBy(eaten);
                toConsume.energy.incEnergyBy(left);
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
        cell.consumeEnergy(1.0);
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