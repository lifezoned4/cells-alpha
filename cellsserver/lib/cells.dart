library cells;
import "dart:async";
import "dart:math";
import "dart:io";


import '../cellsPersist.dart';
import '../cellsCore.dart';

import "greenCode.dart";

import "package:logging/logging.dart";

final _logger = new Logger("cells");

class CellsConfiguration {
  static const int baseEnergy = Smelting * 100;
  static const int Smelting = 5;
  static const int baseConsume = 2;
  static const double damp = 7.0;
  static const int probMutation = 100; // p = 1 / probMuation
  static const int probStateMutation = 5;
}


class State {
  static State Red = new State(1, "Red");
  static State Green = new State(2, "Green");
  static State Blue = new State(3, "Blue");
  static State Void = new State(4, "Void");
  static State VoidEnd = new State(5, "VoidEnd");
  static State Unknown = new State(6, "Unkown");

  static List<State> allStates = [Red, Green, Blue, Void, VoidEnd];

  String name;

  int _value;

  State.random() {
    Random rnd = new Random();
    List<State> randomStateFrom = allStates.where((s) => s != VoidEnd && s != Void).toList();
    _value = randomStateFrom.elementAt(rnd.nextInt(randomStateFrom.length)).toValue();
  }

  String toString() {
    return _value.toString();
  }

  int toValue() => _value;

  State(this._value, this.name);
  bool operator ==(dynamic d) {
    if (d is int) return this._value == d;
    if (d is State) return this._value == d._value; else return false;
  }

  static State compliment(State to) {
    if (to == Red) return Green;
    if (to == Green) return Blue;
    if (to == Blue) return Red;
    return Void;

  }

  static State invCompliment(State to) {
    if (to == Green) return Red;
    if (to == Blue) return Green;
    if (to == Red) return Blue;
    return Void;
  }
}

class Energy {
  static const int maxEnergyInObject = CellsConfiguration.baseEnergy * 100;
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

  toString() => "{energyCount. $energyCount}";
}

class Cell {
  bool isHold = false;
  int consumed = 0;

  int id = 0;
  static int nextId = 1;

  GreenCodeContext greenCodeContext = null;

  getInternEnergyCountAt(WorldObject o) {
    return o.getEnergyCount() - consumed;
  }

  Cell.withList(List codes) {
    id = Cell.getNextCellId(this);
    greenCodeContext = new GreenCodeContext.byList(codes);
  }

  Cell.withCode(String codeString) {
    id = Cell.getNextCellId(this);
    greenCodeContext = new GreenCodeContext.byNames(codeString);
  }

  static int getNextCellId(Cell toAdd) {
    nextId++;
    assert(World.worlds.where((world) => world.listOfCells.where((c) => c.id == nextId).length == 0).length == World.worlds.length);
    return nextId;
  }

  toString() => "{id: $id, consumed: $consumed, isHold: $isHold, nextMove: ${greenCodeContext.nextMove()}";
}

class WorldObject {
  int x;
  int y;

  cellularNext(World world, WorldObject w, Function deal) {
    return deal(this, w, Neighbourhood.getNeightbourhood(w.x, w.y, world.objects, world.width, world.height).toList());
  }

  WorldObject(this.x, this.y, this.state);

  State state;
  State getStateIn() {
    if (cell == null) return state; else return State.compliment(state);
  }
  State getStateOut() {
    if (cell == null) return state; else return State.invCompliment(state);
  }

  State getStateIntern() {
    return state;
  }

  setFrom(WorldObject wo) {
    diff = wo.diff;
    setStateFrom(wo);
    setEnergyFrom(wo);
    setCellFrom(wo);
  }

  setStateFrom(WorldObject wo) => state = wo.state;
  setEnergyFrom(WorldObject wo) {
    setEnergyCount(wo.getEnergyCount());
    diff = wo.diff;
  }
  setCellFrom(WorldObject wo) => cell = wo.cell;

  Energy _energy = new Energy(0);

  int getEnergyCount() {
    return _energy != null ? _energy.energyCount : 0;
  }

  double diff = 0.0;
  setEnergyCount(int value) {
    /*	if(_energy.energyCount != 0){
			diff += _energy.energyCount - value;
			if(_energy.energyCount - value > 0)
				_logger.info("HIGHER: $diff");
			else if(_energy.energyCount - value < 0)
				_logger.info("LOWER: $diff");
		} */
    _energy.energyCount = value;

    // if(diff != 0)
    // _logger.info("DIFF IN WO: $diff");
  }
  Cell cell = null;

  toString() => "{x: $x, y: $y, state: ${state.toString()}, energy: ${getEnergyCount()}, cell = $cell";
}

class Neighbourhood {
  WorldObject n;
  WorldObject e;
  WorldObject s;
  WorldObject w;

  List<WorldObject> toList() {
    return [n, e, s, w];
  }

  WorldObject getObjectAtDirection(Direction dir) {
    if (dir == Direction.N) return n;
    if (dir == Direction.E) return e;
    if (dir == Direction.S) return s;
    if (dir == Direction.W) return w;
    return new WorldObject(-1, -1, State.Unknown);
  }

  static Neighbourhood getNeightbourhood(int x, int y, List<WorldObject> objects, int width, int height) {
    Neighbourhood nei = new Neighbourhood();
    nei.n = World.getObjectAt(x, y - 1, objects, width, height);
    nei.e = World.getObjectAt(x + 1, y, objects, width, height);
    nei.s = World.getObjectAt(x, y + 1, objects, width, height);
    nei.w = World.getObjectAt(x - 1, y, objects, width, height);
    return nei;
  }

  static WorldObject getObjectAtDirectionFrom(Direction dir, WorldObject w, List<WorldObject> objects, int width, int height) {
    if (dir == Direction.NONE) return w;
    Neighbourhood nei = getNeightbourhood(w.x, w.y, objects, width, height);
    WorldObject o = nei.getObjectAtDirection(dir);
    if (o.state == State.Unknown) throw new Exception("BAD");
    return o;
  }
}

class World {
  int delay = 100;

  static List<World> worlds = new List<World>();

  List<Cell> listOfCells = new List<Cell>();

  static bool persitActive = false;
  static int persistAfterTicks = 100;
  Timer timer;
  int ticksSinceStart = 0;

  MeasurementEngine measurement;

  bool isDemo = false;
  int totalEnergy = 0;
  int totalWarming = 0;
  int cellEnergy = 0;
  int totalCellCount = 0;

  Map<User, int> users = new Map<User, int>();

  List<WorldObject> objects;

  int width;
  int height;

  World(this.width, this.height) {
    objects = newState(width, height, State.Void);
    measurement = new MeasurementEngine(this);
    worlds.add(this);
  }

  randomStateAdd() {
    int i = 0;
    Random rnd = new Random();
    while (i < 20) {
      int x = rnd.nextInt(width);
      int y = rnd.nextInt(height);
      List<State> selectFrom = State.allStates.where((s) => s != State.Void && s != State.VoidEnd).toList();
      State state = selectFrom.elementAt(rnd.nextInt(selectFrom.length));
      WorldObject newObject = new WorldObject(x, y, state);
      newObject.setEnergyCount(rnd.nextInt(CellsConfiguration.baseEnergy * 4));
      newObject.cell = new Cell.withCode('''  
LABEL #0;
GET #317;
LOAD @2;
STORE #27;
LABEL #327;
LOAD #700;
SUB @10;
JZERO @27;
LOAD @28;
ADD #1;
MULT #17;
STORE #8;
STORE #28;
GET #327;
LOAD @2;
STORE #1;
LABEL #317;
GET #1;
LOAD @2;
STORE #3;
GET #0;
COPY #0;
LOAD @10;
ADD #1;
MULT #2;
STORE #7;
STORE #10
GET #327;
LOAD @2;
STORE #1;
LABEL #1;
''');
      // newObject.cell.greenCodeContext = new GreenCodeContext.byRandom(30);
      objects.replaceRange(x + y * width, (x + y * width) + 1, [newObject]);
      i++;
    }
  }

  WorldObject getWorldObjectWhereCellId(int id) {
    var it = objects.where((w) => w.cell != null && w.cell.id == id);
    if (it.length > 0) return it.first; else return null;
  }

  static List<WorldObject> newState(width, height, State init) {
    List<WorldObject> os = new List<WorldObject>();
    for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) os.add(new WorldObject(x, y, init));
    return os;
  }

  newUser(User user) {
    Random rnd = new Random();
    users.putIfAbsent(user, () => rnd.nextInt(objects.length));
  }

  start() {
    timer = new Timer(new Duration(milliseconds: delay), tick);
  }

  setDelay(int delay) {
    if (delay > 1 && delay < 5000) {
      timer.cancel();
      this.delay = delay;
      timer = new Timer(new Duration(milliseconds: delay), tick);
    }
  }

  tick() {
    ticksSinceStart++;

    if (ticksSinceStart % persistAfterTicks == 0) if (persitActive) FilePersistContext.wirteSave(this);

    int i = 0;
    // randomStateAdd();
    List<WorldObject> future = newState(width, height, State.Unknown);

    objects.forEach((w) {
      if (w.cell != null) if (!w.cell.isHold) {
        var context = w.cell.greenCodeContext;
        context.preTick(this, w, w.x, w.y);
        context.tick();

        w.cell.consumed += (CellsConfiguration.baseConsume + log(w.cell.greenCodeContext.code.length + 1) / log(CellsConfiguration.damp)).floor();
      }
    });



    // objects => future
    // object.nei, w,
    objects.forEach((_w) {
      WorldObject w = new WorldObject(_w.x, _w.y, _w.state);
      w.setCellFrom(_w);
      w.setEnergyFrom(_w);
      w.diff = _w.diff;
      WorldObject fo = w.cellularNext(this, _w, cellularMoveCellToField).cellularNext(this, _w, cellularKillCells).cellularNext(this, _w, cellularEnergyManagment).cellularNext(this, _w, cellularCellInjection);

      if (fo.getStateIntern() == State.Void && fo.getEnergyCount() != 0) assert(fo.getEnergyCount() == 0);
      putObjectAt(fo.x, fo.y, future, width, height, fo);
    });

    objects = future;

    totalEnergy = 0;
    cellEnergy = 0;
    totalWarming = 0;

    objects.forEach((w) {
      if (w.cell != null) {
        totalWarming += w.cell.greenCodeContext.code.length;
        cellEnergy += w.getEnergyCount();
      }
      totalEnergy += w.getEnergyCount();
    });

    objects.forEach((w) {
      if (w.getEnergyCount() < 0) {
        assert(w.getEnergyCount() >= 0);
      }
    });
    totalCellCount = 0;
    listOfCells = objects.where((w) => w.cell != null).map((w) => w.cell).toList();
    totalCellCount = listOfCells.length;

    if (diffrenziator > 0) {
      _logger.info("diffy: ${diffrenziator -lastDiffy}");
      lastDiffy = diffrenziator;
    }

    users.keys.forEach((u) {
      if (u.selected != null) u.selected = getObjectAt(u.selected.x, u.selected.y, future, width, height);
    });

    users.keys.forEach((user) => user.tick());

    timer = new Timer(new Duration(milliseconds: delay), tick);

    if (totalCellCount == 0 && isDemo) {
      int i = 0;
      while (i < 10) {
        randomStateAdd();
        i++;
      }
    }
    measurement.DoMeasure();
  }

  static void putObjectAt(int x, int y, List<WorldObject> objects, int width, int height, WorldObject o) {
    if ((x < 0) || (y < 0) || (x >= width) || (y >= height)) throw new Exception("putting object outside of space (width: $width, height: $height) with (x:$x, y:$y)");
    objects.replaceRange(x + (width * y), x + (width * y) + 1, [o]);
  }

  static WorldObject getObjectAt(int x, int y, List<WorldObject> objects, int width, int height) {
    if ((x < 0) || (y < 0) || (x >= width) || (y >= height)) return new WorldObject(x, y, State.VoidEnd);
    WorldObject o = objects.elementAt((y * width) + x);
    assert(o.x == x && o.y == y);
    return o;
  }

  static List<WorldObject> getObjectsForCube(int x, int y, int radius, List<WorldObject> objects) {
    return getObjectsForRect(x - radius, y - radius, radius * 2, radius * 2, objects);
  }

  static List<WorldObject> getObjectsForRect(int x, int y, int width, int height, List<WorldObject> objects) {
    List<WorldObject> r = new List<WorldObject>();
    for (int ix = width; ix >= 0; ix--) for (int iy = height; iy >= 0; iy--) r.add(getObjectAt(x + ix, y + iy, objects, width, height));
    return r;
  }

  double lastDiffy = 0.0;
  double diffrenziator = 0.0;

  WorldObject cellularNext(WorldObject w, List<WorldObject> future, Function deal) {
    Neighbourhood nei = Neighbourhood.getNeightbourhood(w.x, w.y, objects, width, height);
    WorldObject futureObject = getObjectAt(w.x, w.y, future, width, height);
    List<WorldObject> l = [nei.n, nei.e, nei.s, nei.w];

    return deal(w, futureObject, l);

  }

  void SetFromWorldObjectTo(WorldObject fromO, WorldObject fo) {
    fo.state = fromO.state;
    fo.cell = fromO.cell;
    fo.setEnergyCount(fromO.getEnergyCount());
  }


  WorldObject cellularMoveCellToField(WorldObject fo, WorldObject past, List<WorldObject> pastNei) {

    List<WorldObject> l = pastNei.where((lw) => lw.cell != null).where((lw) => past == Neighbourhood.getObjectAtDirectionFrom(lw.cell.greenCodeContext.nextMove(), lw, objects, width, height)).toList();

    if ((fo.cell == null && fo.getEnergyCount() == 0) && l.length == 1) {
      WorldObject wo = l.first;
      fo.setFrom(wo);
    } else if (l.length > 1) {
      ;
      //
    }

    if (past.cell != null && past.cell.greenCodeContext.nextMove() != Direction.NONE) {
      var l = pastNei.where((lw) => lw == Neighbourhood.getObjectAtDirectionFrom(past.cell.greenCodeContext.nextMove(), past, objects, width, height)).toList();
      l = l.where((lw) => lw.cell == null && lw.getEnergyCount() == 0).toList();
      if (l.length == 1) {
        fo.cell = null;
        fo.setEnergyCount(0);
        fo.state = State.Void;
      }
    }
    return fo;
  }

  cellularKillCells(WorldObject fo, WorldObject past, List<WorldObject> pastNei) {

    if (fo.cell != null && fo.cell.consumed > past.getEnergyCount()) if (fo.cell.greenCodeContext.nextMove() == Direction.NONE) {
      fo.state = fo.getStateOut();
      fo.cell = null;
    }
    return fo;
  }

  cellularCellInjection(WorldObject fo, WorldObject past, List<WorldObject> pastNei) {
    Random rnd = new Random();
    var it = pastNei.where((lw) => lw.cell != null).toList().where((lw) => lw.cell.greenCodeContext.nextInject() != Direction.NONE).toList().where((lw) => Neighbourhood.getObjectAtDirectionFrom(lw.cell.greenCodeContext.nextInject(), lw, objects, width, height) == past).toList();
    var l = it.toList();
    if (l.length == 1) {
      if (fo.cell != null && fo.cell.greenCodeContext.nextMove() == Direction.NONE) {
        fo.cell.greenCodeContext.insertCode(l.first.cell.greenCodeContext.codeRangeBetweenHeads());
        l.first.cell.greenCodeContext.removeCodeRangeBetweenHeads();
      } else if (fo.cell == null && past.state == State.Void) {
        fo.cell = new Cell.withCode("");
        if (rnd.nextInt(CellsConfiguration.probStateMutation) == 1) fo.state = new State.random();
        l.forEach((lw) {
          fo.cell.greenCodeContext.insertCode(lw.cell.greenCodeContext.codeRangeBetweenHeads());
          lw.cell.greenCodeContext.removeCodeRangeBetweenHeads();
        });
      }
      if (fo.cell == null && fo.getEnergyCount() > 0 && fo.getStateIntern() == l.first.state) {
        fo.cell = new Cell.withCode("");
        l.forEach((lw) {
          fo.cell.greenCodeContext.insertCode(lw.cell.greenCodeContext.codeRangeBetweenHeads());
          lw.cell.greenCodeContext.removeCodeRangeBetweenHeads();
        });
      }
    }
    return fo;
  }


  cellularEnergyManagment(WorldObject fo, WorldObject past, List<WorldObject> pastNei) {
    fo.setEnergyCount(fo.getEnergyCount() - pastNei.fold(0, (i, lw) {
      if (lw.getEnergyCount() > past.getEnergyCount() && lw.getStateIn() == past.getStateOut()) {
        if (lw.getEnergyCount() < CellsConfiguration.Smelting) return i + lw.getEnergyCount();
        return i + CellsConfiguration.Smelting;
      }
      return i;
    }));

    fo.setEnergyCount(fo.getEnergyCount() + pastNei.fold(0, (i, lw) {
      if (lw.getEnergyCount() < past.getEnergyCount() && lw.getStateOut() == past.getStateIn() && past.getEnergyCount() > CellsConfiguration.Smelting) {
        if ((lw.getEnergyCount() - CellsConfiguration.Smelting) <= 0) return i + lw.getEnergyCount();
        return i + CellsConfiguration.Smelting;
      }
      return i;
    }));

    if (fo.state == State.Void && fo.getEnergyCount() != 0) fo.setStateFrom(past);

    // TODO: fix this LEAK!
    if (fo.getEnergyCount() <= 0) {
      fo.setEnergyCount(0);
      fo.state = State.Void;
    }

    if (past.cell != null && past.cell.greenCodeContext.nextInject() != Direction.NONE) {
      var l = pastNei.where((lw) => lw == Neighbourhood.getObjectAtDirectionFrom(past.cell.greenCodeContext.nextInject(), past, objects, width, height)).toList();
      if (l.length > 0) {
        WorldObject to = l.first;
        if (to.state == State.Void) {
          fo.setEnergyCount(fo.getEnergyCount() - (fo.getEnergyCount() / 2).floor());
        }
      }
    }

    List<WorldObject> move = pastNei.where((lw) => lw.cell != null).where((lw) => past == Neighbourhood.getObjectAtDirectionFrom(lw.cell.greenCodeContext.nextMove(), lw, objects, width, height)).toList();
    if (past.cell == null && past.state == State.Void && move.length == 0) {
      List<WorldObject> inject = pastNei.where((lw) => lw.cell != null).where((lw) => past == Neighbourhood.getObjectAtDirectionFrom(lw.cell.greenCodeContext.nextInject(), lw, objects, width, height)).toList();
      if (inject.length > 0) {
        fo.setStateFrom(inject.first);
        fo.setEnergyCount(fo.getEnergyCount() + inject.fold(0, (i, lw) => (lw.getEnergyCount() / 2).ceil()));
      }
    }

    return fo;
  }


  toString() {
    return "[$ticksSinceStart] " + objects.map((w) => w.cell == null ? 0 : 1).join(";");
  }
}

class MeasurementEngine {

  String pathTo = 'saves/measurements/';
  DateTime lastFileDt;
  World modell;
  File fileTo;
  IOSink _sink;

  static int TicksPerFile = 60 * 10 * 2; /* 10 ticks/s * 60s  * 2 */
  int ticksHandled = 0;

  List<Measurement> measurements;

  static String dtToStamp(DateTime dt) => "${dt.year.toString().padLeft(4, "0")}${dt.month.toString().padLeft(2, "0")}${dt.day.toString().padLeft(2, "0")}${dt.hour.toString().padLeft(2, "0")}${dt.minute.toString().toString().padLeft(2, "0")}${dt.second.toString().padLeft(2, "0")}";

  MeasurementEngine(this.modell) {

  	measurements = new List<Measurement>();

  	addVariantMeasurementsForSelector(MeasurementSelector.EnergyCount, [MeasurmentRelevator.isGreen, MeasurmentRelevator.isBlue, MeasurmentRelevator.isRed], [MeasurmentRelevator.isCell, MeasurmentRelevator.isPureEnergy]);
  	addVariantMeasurementsForSelector(MeasurementSelector.UniqueCount, [MeasurmentRelevator.isGreen, MeasurmentRelevator.isBlue, MeasurmentRelevator.isRed], [MeasurmentRelevator.isCell, MeasurmentRelevator.isPureEnergy]);
  	addVariantMeasurementsForSelector(MeasurementSelector.RegOPs, [MeasurmentRelevator.isGreen, MeasurmentRelevator.isBlue, MeasurmentRelevator.isRed], [MeasurmentRelevator.isCell]);



  	createMeasurementFile();
  }

  void addVariantMeasurementsForSelector(MeasurementSelector p, List<MeasurmentRelevator> colors,  List<MeasurmentRelevator> types) {
    measurements.addAll(
        		colors
               .fold([], (List<Measurement>l, r)
               {
                  l.addAll(types
                  .fold([], (List<Measurement> ll, rr) {
                    ll.add(new Measurement([r, rr], p));
                    return ll;
                  }));
                  return l;
               }));
  }

  void createMeasurementFile() {
  	lastFileDt = new DateTime.now();
    var d = new Directory(pathTo);
    if(!d.existsSync())
    	d.createSync(recursive: true);
    fileTo = new File(pathTo + 'measurement');
        if (fileTo.existsSync()) {
          fileTo.renameSync(pathTo +'measurement-failure-${dtToStamp(new DateTime.now())}');
        }
      	fileTo.createSync();
        if(_sink != null){

        }
        _sink = fileTo.openWrite(mode: FileMode.APPEND);
        _sink.writeln("Tick, ${measurements.fold("", (s, m) => "$s ${m.getName()},")}");
  }

  void DoMeasure() {
    measurements.forEach((m) => m.reset());

    modell.objects.forEach((o) => measurements.forEach((m) => m.pushObject(o)));

    _sink.writeln("${modell.ticksSinceStart}, ${measurements.fold("", (s, m) =>  "$s ${m.getValue()},")}");

    ticksHandled++;
    if(ticksHandled > TicksPerFile)
    {
    	ticksHandled = 0;
    	Future.wait([_sink.close().whenComplete(() {
      	fileTo.renameSync(pathTo + "measurement-${dtToStamp(lastFileDt)}-${dtToStamp(new DateTime.now())}.csv");
      	createMeasurementFile();
    	})]
    	);
    }
   }
}

class Measurement {
  int _value = 0;

  void reset() {
    _value = 0;
  }

  List<MeasurmentRelevator> rels;
  MeasurementSelector sel;

  Measurement(this.rels, this.sel);

  void pushObject(WorldObject o) {
  		_value += getMeasureValue(o);
  }

  int getMeasureValue(WorldObject o) {
      if (rels.fold(true, (b, r) => b && r.isRelevant(o))) return sel.select(o);
      return 0;
    }

  getName() => "${rels.fold("", (s, r) => "$s${r.name}")}${sel.name}";


  int getValue() {
    return _value;
  }
}

class MeasurmentRelevator
{
  static MeasurmentRelevator isGreen = new HelperMeasurementRelavatorState(State.Green);
  static MeasurmentRelevator isBlue = new HelperMeasurementRelavatorState(State.Blue);
  static MeasurmentRelevator isRed = new HelperMeasurementRelavatorState(State.Red);

  static MeasurmentRelevator isCell = new MeasurmentRelevator()..isRelevant = ((WorldObject o) => o.cell != null)..name =  "Cell";
  static MeasurmentRelevator isPureEnergy = new MeasurmentRelevator()..isRelevant = ((WorldObject o) => o.cell == null && o._energy != null)..name = "Energy";

  Function isRelevant;
  String name;
}

class HelperMeasurementRelavatorState extends MeasurmentRelevator
{
	HelperMeasurementRelavatorState (State color){
    name = "${color.name}";
    isRelevant = (WorldObject o) => o.getStateIntern() == color;
  }
}

class MeasurementSelector
{
  static MeasurementSelector EnergyCount = new MeasurementSelector()
  ..select = ((WorldObject o) => o.getEnergyCount())
  ..name = "TotalEnergyCount";

  static MeasurementSelector UniqueCount = new MeasurementSelector()
  ..select = ((WorldObject o) => 1)
  ..name = "UniqueCount";

  static MeasurementSelector RegOPs = new MeasurementSelector()
  ..select = ((WorldObject o) => o.cell.greenCodeContext.code.length)
  ..name = "RegOPs";

  Function select;
  String name;
}