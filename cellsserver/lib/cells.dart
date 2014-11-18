library cells;
import "dart:async";
import "dart:math";


import '../cellsPersist.dart';
import '../cellsCore.dart';

import "greenCode.dart";

import "package:logging/logging.dart";

final _logger = new Logger("cells");

class State {
  static State Red = new State(1);
  static State Green = new State(2);
  static State Blue = new State(3);
  static State Void = new State(4);
  static State VoidEnd = new State(5);
  
  static List<State> allStates = [Red, Green, Blue, Void, VoidEnd];
 
  String name;

  int _value;
  
  
   String toString(){
     return _value.toString();
   }
  
  int toValue() => _value;
  
  State(this._value);
  bool operator==(dynamic d){
    if(d is int)
      return this._value == d;
    if(d is State)
      return this._value == d._value;
    else return false;
  }
      
   static State compliment(State to){
     if(to == Red)
       return Green;
     if(to == Green)
       return Blue;
     if(to == Blue)
       return Red;
     return Void;

   }
   
   static State invCompliment(State to){
     if(to == Green)
       return Red;
     if(to == Blue)
      return Green;
     if(to == Red)
       return Blue;
     return Void;
   }
}

class Energy {
  static int baseEnergy = 100;
  static int maxEnergyInObject = baseEnergy * 100;
  int energyCount;

  Energy(this.energyCount);
  
  // returns how much energy really incremented
  int incEnergyBy(int inc) {
    if (energyCount + inc >= maxEnergyInObject) {
      int buffEnergyCount = energyCount + inc - maxEnergyInObject;
      energyCount = maxEnergyInObject;
      return inc - buffEnergyCount;
    }
    energyCount += inc;
    return inc;
  }

  int decEnergyBy(int dec) {
    if (energyCount <= dec) {
      int buffEnergyCount = energyCount;
      energyCount = 0;
      return buffEnergyCount;
    }
    energyCount -= dec;
    return dec;
  }
} 

class Cell {
  bool isHold = false;
  int consumed;
    
  int id = 0;
  
  GreenCodeContext greenCodeContext = null; 

  Cell.withCode(this.id, String codeString) {
      greenCodeContext = new GreenCodeContext.byNames(codeString); 
  }  
}

class WorldObject {  
  int x;
  int y;
  
  WorldObject(this.x, this.y, this._state);
  
  State _state;
  State getStateIn(){
    if(cell == null)
      return _state;
    else
      return State.compliment(_state);
  }
  State getStateOut(){
    if(cell == null)
         return _state;
    else
      return State.invCompliment(_state);      
  }
  
  State getStateIntern(){
    return _state;
  }
  
  Energy energy = new Energy(0); 
  
  int getEnergyCount() {return energy != null ? energy.energyCount : 0;}
  Cell cell;
}

class Neighbourhood {
   WorldObject n;
   WorldObject e;
   WorldObject s;
   WorldObject w;
 }

class World {
  int delay = 1000;
  static int persistAfterTicks = 100;
  Timer timer;
  int ticksSinceStart = 0;

  Map<User,int> users = new Map<User,int>();
  
  List<WorldObject> objects;
  
  int width;
  int height;

  World(this.width, this.height) {
    objects = newState(width, height);
  }
  
  randomStateAdd(){
    int i = 0;
    Random rnd = new Random();
    while(i < 20){
      int x = rnd.nextInt(width);
      int y = rnd.nextInt(height);
      List<State> selectFrom = State.allStates.where((s) => s != State.VoidEnd).toList();
      State state = selectFrom.elementAt(rnd.nextInt(selectFrom.length));
      WorldObject newObject = new WorldObject(x, y, state);
      newObject.energy.energyCount = rnd.nextInt(200);
      newObject.cell = new Cell.withCode(i, "");
      newObject.cell.greenCodeContext = new GreenCodeContext.byRandom(30);
      objects.replaceRange(x + y * width,x + y * width + 1,[newObject]);
      i++;
    }
  }
  
  WorldObject getWorldObjectWhereCellId(int id){
    var it = objects.where((w) => w.cell != null && w.cell.id == id);
    if(it.length > 0)
      return it.first;
    else
      return null;
  }
  
  static List<WorldObject> newState (width, height){
    List<WorldObject> os = new List<WorldObject>();
    for(int i = 0; i < width * height; i++)
      os.add(new WorldObject(getIndexX(i, width),getIndexY(i, width), State.Void));
    return os;      
  }

  newUser(User user) {
    Random rnd = new Random();
    users.putIfAbsent(user, () => rnd.nextInt(objects.length));
  }

  start() {
    timer = new Timer(new Duration(milliseconds: delay), tick);
  }

  setDelay(int delay){
    if(delay > 1 && delay < 5000){
      timer.cancel();
      this.delay = delay;
      timer = new Timer(new Duration(milliseconds: delay), tick);
    }
  }
  
  tick() {
    ticksSinceStart++;

    if (ticksSinceStart % persistAfterTicks == 0) FilePersistContext.wirteSave(this);

    int i = 0;
    randomStateAdd();
    List<WorldObject> future = newState(width, height);
    objects.forEach((w) => preCellularNextEnergy(w, future));
    
    objects.forEach((w){
      if(w.cell != null)
          if(!w.cell.isHold){
        var context = w.cell.greenCodeContext;
        context.preTick(this, w, getIndexX(i, width), getIndexY(i, width));
        context.tick();
      }
      
      cellularNextOn(w, future);
      i++;
    });    
    
    objects = future;

    users.keys.forEach((user) => user.tick());

    timer = new Timer(new Duration(milliseconds: delay), tick);
  }

  static int getIndexX(i, width){
    return i % width;
  }
  
  static int getIndexY(i, width){
    return (i / width).floor();
  }
  
  static WorldObject getObjectAt(int x, int y, List<WorldObject> objects, int width){
    if((y*width + x) < 0 || (y*width + x) >= objects.length)
      return new WorldObject(x, y, State.VoidEnd);
    return objects.elementAt(y*width + x);
  }
  
  static List<WorldObject> getObjectsForCube(int x, int y, int radius, List<WorldObject> objects) {
    return getObjectsForRect(x - radius, y - radius, radius*2, radius*2, objects);
  }

  static List<WorldObject> getObjectsForRect(int x, int y, int width, int height, List<WorldObject> objects) {
    List<WorldObject> r = new List<WorldObject>();
    for(int iy = height; iy >= 0; iy--)
        for(int ix = width; ix >= 0; ix--)
          r.add(getObjectAt(x + ix, y + iy, objects, width));
    return r;
  }
    
  Neighbourhood getNeightbourhood(int x, int y){
      Neighbourhood nei = new Neighbourhood();
       nei.n = getObjectAt(x, y - 1, objects, width);
       nei.e = getObjectAt(x + 1, y, objects, width);
       nei.s = getObjectAt(x, y + 1, objects, width);
       nei.w = getObjectAt(x - 1, y, objects, width);
     return nei;
  }
  
  preCellularNextEnergy(WorldObject w, List<WorldObject> future){
    WorldObject futureObject = getObjectAt(w.x, w.y, future, width);      
    futureObject.energy = w.energy;  
  }
  
  cellularNextOn(WorldObject w, List<WorldObject> future){
    int x = w.x;
    int y = w.y;
    Neighbourhood nei = getNeightbourhood(x, y);
   
    WorldObject futureObject = getObjectAt(x, y, future, width);
    futureObject.energy = w.energy;
    
    if(w.cell != null && !w.cell.isHold)
    {
      if(futureObject.cell == null && futureObject.energy == null){
        Direction dir = w.cell.greenCodeContext.nextMove();
        
        WorldObject futureTo = getObjectAt(x + dir.x, y + dir.y, future, width);
                
        if(futureTo.cell != null || futureTo.getStateIntern() == State.VoidEnd)
         futureObject.cell = w.cell; 
        else{
         futureTo.cell = w.cell;
         futureTo._state = w._state;
         futureTo.energy = w.energy;
        }
        
        if(futureObject.cell != null){
          List<WorldObject> l = [nei.n, nei.e, nei.s, nei.w];
          
          l = l.where((lw) => lw.cell != null);
          l = l.where((lw) {dir = lw.cell.greenCodeContext.nextMove();
                            return (x == (dir.x + lw.x)) && (y == (dir.y + lw.y));
                           });
          
          int lowest = l.fold(Energy.maxEnergyInObject,(i, w) => w.getEnergyCount() == 0 ? i : min(i,w.getEnergyCount()));
          Iterable it = l.where((lw) => lw.getEnergyCount() == lowest);
          if(it.length > 0){
            futureObject.cell = it.first.cell;
            futureObject._state = it.first._state;
            futureObject.energy = it.first.energy;
          }
        }
      }
  
      if(w.cell != null && w.getEnergyCount() == w.cell.consumed){
        futureObject._state = w.getStateOut();
        futureObject.cell = null;
        futureObject.energy = w.energy;
      }
      
      // TODO: INJECT
      
      List<WorldObject> l = [nei.n, nei.e, nei.s, nei.w];              
      futureObject.energy.energyCount = l.fold(w.getEnergyCount(), (i, lw) => lw.getEnergyCount()< w.getEnergyCount() && lw.getStateOut() == w.getStateIn() ? i + lw.getEnergyCount() : i);
    
      future.replaceRange(x + width * y , x + width * y + 1, [futureObject]);
    }
  }
}