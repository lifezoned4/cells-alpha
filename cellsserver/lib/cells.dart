library cells;
import "dart:async";
import "dart:math";


import '../cellsPersist.dart';
import '../cellsCore.dart';

import "greenCode.dart";

import "package:logging/logging.dart";

final _logger = new Logger("cells");

class CellsConfiguration {
	static const int baseEnergy = Smelting * 100;
	static const int Smelting = 5;
	static const int baseConsume = 2;
	static const int probMutation = 10000; // p = 1 / probMuation
}


class State {

	static State Red = new State(1);
	static State Green = new State(2);
	static State Blue = new State(3);
	static State Void = new State(4);
	static State VoidEnd = new State(5);
	static State Unknown = new State(6);

	static List<State> allStates = [Red, Green, Blue, Void, VoidEnd];

	String name;

	int _value;

	String toString() {
		return _value.toString();
	}

	int toValue() => _value;

	State(this._value);
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
		setStateFrom(wo);
		setEnergyFrom(wo);
		setCellFrom(wo);
	}

	setStateFrom(WorldObject wo) => state = wo.state;
	setEnergyFrom(WorldObject wo) => setEnergyCount(wo.getEnergyCount());
	setCellFrom(WorldObject wo) => cell = wo.cell;

	Energy _energy = new Energy(0);

	int getEnergyCount() {
		return _energy != null ? _energy.energyCount : 0;
	}

	double diff = 0.0;
	setEnergyCount(int value){
		diff += (_energy.energyCount - value);
		_energy.energyCount = value;
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
		return [n,e,s,w];
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
	int delay = 20;

	static List<World> worlds = new List<World>();

	List<Cell> listOfCells = new List<Cell>();

	static bool persitActive = false;
	static int persistAfterTicks = 100;
	Timer timer;
	int ticksSinceStart = 0;

	int totalEnergy = 0;
	int totalCellCount = 0;

	Map<User, int> users = new Map<User, int>();

	List<WorldObject> objects;

	int width;
	int height;

	World(this.width, this.height) {
		objects = newState(width, height, State.Void);
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
			newObject.setEnergyCount(rnd.nextInt(CellsConfiguration.baseEnergy));
			newObject.cell = new Cell.withCode("");
			newObject.cell.greenCodeContext = new GreenCodeContext.byRandom(30);
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

				w.cell.consumed += (CellsConfiguration.baseConsume + (log(w.cell.greenCodeContext.code.length + CellsConfiguration.baseConsume) / log(10)).floor());
			}

		});



		// objects => future
		// object.nei, w,
		objects.forEach((_w) {
			WorldObject w = new WorldObject(_w.x, _w.y, _w.state);
			w.setCellFrom(_w);
			w.setEnergyFrom(_w);
			WorldObject fo = w.cellularNext(this, _w, cellularMoveCellToField)
					.cellularNext(this, _w, cellularKillCells)
										.cellularNext(this, _w, cellularEnergyManagment)
					.cellularNext(this, _w, cellularCellInjection);

			putObjectAt(fo.x, fo.y, future, width, height, fo);
		});

		objects = future;

		totalEnergy = 0;
		objects.forEach((w) {
			totalEnergy += w.getEnergyCount();
		});



		objects.forEach(
				(w){
				if(w.state == State.Void)
						assert(w.getEnergyCount() == 0);});

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
		} else if(fo.cell != null && fo.cell.greenCodeContext.nextMove() != Direction.NONE)
		{
			var l = pastNei.where((lw) => lw == Neighbourhood.getObjectAtDirectionFrom(past.cell.greenCodeContext.nextMove(), past, objects, width, height)).toList();
			l = l.where((lw) => lw.cell == null && lw.getEnergyCount() == 0).toList();
			if(l.length == 1){
				fo.cell = null;
				fo..setEnergyCount(0);
				fo.state = State.Void;
			}
		}
		return fo;
	}

	cellularKillCells(WorldObject fo, WorldObject past, List<WorldObject> pastNei) {
		if (fo.cell != null && fo.cell.consumed > past.getEnergyCount())
			if(fo.cell.greenCodeContext.nextMove() == Direction.NONE){
				fo.state = fo.getStateOut();
				fo..cell = null;
				fo.setEnergyCount(fo.getEnergyCount());
		}

		return fo;
	}

	cellularCellInjection(WorldObject fo, WorldObject past, List<WorldObject> pastNei) {
		var it = pastNei.where((lw) => lw.cell != null).toList().where((lw) => lw.cell.greenCodeContext.nextInject() != Direction.NONE).toList().where((lw) => Neighbourhood.getObjectAtDirectionFrom(lw.cell.greenCodeContext.nextInject(), lw, objects, width, height) == past).toList();
		var l = it.toList();
		if (l.length == 1) {
			if(fo.cell != null && fo.cell.greenCodeContext.nextMove() == Direction.NONE){
				fo.state = fo.state == State.Void && fo.cell == null ? l.first.state : fo.state;
				fo.setEnergyCount(fo.cell == null ? (l.first.getEnergyCount() / 2).floor() : fo.getEnergyCount());
				fo.cell.greenCodeContext.insertCode(l.first.cell.greenCodeContext.codeRangeBetweenHeads());
				l.first.cell.greenCodeContext.removeCodeRangeBetweenHeads();
		}  else if(fo.cell == null && fo.state == State.Void){
					fo.cell = new Cell.withCode("");
					fo.setStateFrom(l.first);
					if(fo.getEnergyCount() != 0)
						fo.setEnergyCount(fo.getEnergyCount() + l.first.getEnergyCount());
					else
						fo.setEnergyFrom(l.first);
					l.forEach((lw){
          							fo.cell.greenCodeContext.insertCode(lw.cell.greenCodeContext.codeRangeBetweenHeads());
                      								lw.cell.greenCodeContext.removeCodeRangeBetweenHeads();
                      						});
			} if(fo.cell == null && fo.getEnergyCount() > 0){
				fo.cell = new Cell.withCode("");
				l.forEach((lw){
					fo.cell.greenCodeContext.insertCode(lw.cell.greenCodeContext.codeRangeBetweenHeads());
          lw.cell.greenCodeContext.removeCodeRangeBetweenHeads();
                              		});
			}
		}
		return fo;
	}


	cellularEnergyManagment(WorldObject fo, WorldObject past, List<WorldObject> pastNei) {
		int sum = 0;
		sum += pastNei.fold(0, (i, lw) => lw.getEnergyCount() < fo.getEnergyCount() && lw.getStateOut() == past.getStateIn() ? (lw.getEnergyCount() < CellsConfiguration.Smelting ? i + lw.getEnergyCount() : i + CellsConfiguration.Smelting) : i);
		sum += pastNei.fold(0, (i, lw) => lw.getEnergyCount() > fo.getEnergyCount() && lw.getStateIn() == past.getStateOut() ? (0 >= (i - CellsConfiguration.Smelting) ? 0 : i - CellsConfiguration.Smelting) : i);

		if(fo.cell != null){
			var l = pastNei.where((lw) => lw == Neighbourhood.getObjectAtDirectionFrom(fo.cell.greenCodeContext.nextInject(), past, objects, width, height)).toList();
			if (l.length > 0) {
				if (l.first.getEnergyCount() == 0) {
					sum -= pastNei.where((lw) => lw.state != fo.state && lw.state == State.Void && lw.cell == null).where((lw) => lw == Neighbourhood.getObjectAtDirectionFrom(fo.cell.greenCodeContext.nextInject(), fo, objects, width, height)).fold(0, (i, lw) => (past.getEnergyCount() / 2).floor());
				}
			}
		} else if(past.cell == null && past.state == State.Void){
			var l = pastNei.where((lw) => lw.cell != null).where((lw) => past == Neighbourhood.getObjectAtDirectionFrom(lw.cell.greenCodeContext.nextInject(), lw, objects, width, height)).toList();
			if (l.length > 0) {
      		if (fo.getEnergyCount() == 0) {
      					sum -= l.fold(0, (i, lw) => (lw.getEnergyCount() / 2).floor());
      		}
			}
		}

		if(sum != 0)
			fo.setEnergyCount(fo.getEnergyCount() + sum);

		return fo;
	}


	toString() {
		return "[$ticksSinceStart] " + objects.map((w) => w.cell == null ? 0 : 1).join(";");
	}
}
