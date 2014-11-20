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
	static int baseEnergy = 10;
	static int maxEnergyInObject = baseEnergy * 10;
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

	toString() =>  "{energyCount. $energyCount}";
}

class Cell {
	bool isHold = false;
	int consumed = 0;

	int id = 0;

	GreenCodeContext greenCodeContext = null;

	getInternEnergyCountAt(WorldObject o){
		return o.getEnergyCount() - consumed;
	}

	Cell.withCode(this.id, String codeString) {
		greenCodeContext = new GreenCodeContext.byNames(codeString);
	}

	toString() => "{id: $id, consumed: $consumed, isHold: $isHold, nextMove: ${greenCodeContext.nextMove()}";
}

class WorldObject {
	int x;
	int y;

	WorldObject(this.x, this.y, this._state);

	State _state;
	State getStateIn() {
		if (cell == null) return _state; else return State.compliment(_state);
	}
	State getStateOut() {
		if (cell == null) return _state; else return State.invCompliment(_state);
	}

	State getStateIntern() {
		return _state;
	}

	Energy energy = new Energy(0);

	int getEnergyCount() {
		return energy != null ? energy.energyCount : 0;
	}
	Cell cell = null;

	toString() => "{x: $x, y: $y, state: ${_state.toString()}, energy: ${getEnergyCount()}, cell = $cell";
}

class Neighbourhood {
	WorldObject n;
	WorldObject e;
	WorldObject s;
	WorldObject w;

	WorldObject getObjectAtDirection(Direction dir){
		if(dir == Direction.N)
			return n;
		if(dir == Direction.E)
			return e;
		if(dir == Direction.S)
			return s;
		if(dir == Direction.W)
			return w;
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

	static WorldObject getObjectAtDirectionFrom(Direction dir, WorldObject w, List<WorldObject> objects, int width, int height)
	{
		if(dir == Direction.NONE)
			return w;
		Neighbourhood nei = getNeightbourhood(w.x,w.y, objects, width, height);
		WorldObject o =  nei.getObjectAtDirection(dir);
		if(o._state == State.Unknown)
			throw new Exception("BAD");
		return o;
	}
}

class World {
	int delay = 200;


	static bool persitActive = false;
	static int persistAfterTicks = 100;
	Timer timer;
	int ticksSinceStart = 0;

	int totalEnergy = 0;

	Map<User, int> users = new Map<User, int>();

	List<WorldObject> objects;

	int width;
	int height;

	World(this.width, this.height) {
		objects = newState(width, height, State.Void);
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
			newObject.energy.energyCount = rnd.nextInt(200);
			newObject.cell = new Cell.withCode(i, "");
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
		for (int y = 0; y < height; y++)
			for(int x = 0; x < width; x++)
			os.add(new WorldObject(x, y,init));
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

		if (ticksSinceStart % persistAfterTicks == 0)
			if(persitActive)
				FilePersistContext.wirteSave(this);

		int i = 0;
		// randomStateAdd();
		List<WorldObject> future = newState(width, height, State.Unknown);

		totalEnergy = 0;
		objects.forEach((w) {
			if (w.cell != null) if (!w.cell.isHold) {
				var context = w.cell.greenCodeContext;
				context.preTick(this, w, w.x, w.y);
				context.tick();

				w.cell.consumed+=(1 + (log(w.cell.greenCodeContext.code.length + 1)/log(10)).floor());
			}
			totalEnergy += w.getEnergyCount();

		});

		objects.forEach((w){
			cellularNextOn(w, future);
			i++;
		});

		objects = future;


		users.keys.forEach((u)  {
			if(u.selected != null)
				u.selected = getObjectAt(u.selected.x, u.selected.y, future, width, height);
		});

		users.keys.forEach((user) => user.tick());

		timer = new Timer(new Duration(milliseconds: delay), tick);
	}

	static void putObjectAt(int x, int y, List<WorldObject> objects, int width, int height, WorldObject o) {
		if ((x < 0) || (y < 0) || (x >= width) || (y >= height))
    			throw new Exception("putting object outside of space (width: $width, height: $height) with (x:$x, y:$y)");
		objects.replaceRange(x +(width*y), x +(width*y) + 1, [o]);
	}

	static WorldObject getObjectAt(int x, int y, List<WorldObject> objects, int width, int height) {
		if ((x < 0) || (y < 0) || (x >= width) || (y >= height))
			return new WorldObject(x, y, State.VoidEnd);
		WorldObject o =  objects.elementAt((y * width) + x);
		assert(o.x == x && o.y == y);
		return o;
	}

	static List<WorldObject> getObjectsForCube(int x, int y, int radius, List<WorldObject> objects) {
		return getObjectsForRect(x - radius, y - radius, radius * 2, radius * 2, objects);
	}

	static List<WorldObject> getObjectsForRect(int x, int y, int width, int height, List<WorldObject> objects) {
		List<WorldObject> r = new List<WorldObject>();
		for (int ix = width; ix >= 0; ix--) for (int iy = height; iy >= 0; iy--)  r.add(getObjectAt(x + ix, y + iy, objects, width, height));
		return r;
	}

	cellularNextOn(WorldObject w, List<WorldObject> future) {
		int x = w.x;
		int y = w.y;
		Neighbourhood nei = Neighbourhood.getNeightbourhood(x, y, objects, width, height);

		WorldObject futureObject = getObjectAt(x, y, future, width, height);

		if (w.cell != null) {
				Direction dir = w.cell.greenCodeContext.nextMove();

				if(dir != Direction.NONE){
					List<WorldObject> l = [nei.n, nei.e, nei.s, nei.w];
					l = l.where((lw) => lw == Neighbourhood.getObjectAtDirectionFrom(dir, w, objects, width, height)).toList();
					l = l.where((lw) => lw.cell == null && lw._state == State.Void).toList();

					if(l.length > 0){
						futureObject.cell = null;
						futureObject.energy.energyCount = 0;
						futureObject._state = State.Void;
					}
				}
		}

		if(w.cell == null && w.getEnergyCount() <= 0){
			List<WorldObject> l = [nei.n, nei.e, nei.s, nei.w];

			l = l.where((lw) => lw.cell != null).toList();

			l = l.where((lw) => lw.cell.greenCodeContext.nextMove() != Direction.NONE).toList();

			l = l.where((lw){
						return Neighbourhood.getObjectAtDirectionFrom(lw.cell.greenCodeContext.nextMove(), lw, objects, width, height) == w;
					}
			).toList();

			if (l.length == 1) {
					futureObject.cell = l.first.cell;
					futureObject._state = l.first._state;
					futureObject.energy.energyCount = l.first.energy.energyCount;
				}
		}

		if (w.cell != null) {
	  		if(w.cell.greenCodeContext.nextMove() == Direction.NONE){
		  		if(w.cell.consumed > w.getEnergyCount()){
						futureObject._state = w.getStateOut();
		  			futureObject.cell = null;
		  		}
		  		else
		  		{
		  			futureObject._state = w._state;
		  			futureObject.cell = w.cell;
					}
		  		futureObject.energy.energyCount = w.getEnergyCount();
				}

		}

		{
  			List<WorldObject> l = [nei.n, nei.e, nei.s, nei.w];
				l = l.where((lw) => lw.cell != null).toList();
				l = l.where((lw) => lw.cell.greenCodeContext.nextInject() != Direction.NONE).toList();

				if(l.length > 0){
					if(w.cell != null){
						l.forEach((lw){
								futureObject.cell.greenCodeContext.insertCode(lw.cell.greenCodeContext.codeRangeBetweenHeads());
								lw.cell.greenCodeContext.removeCodeRangeBetweenHeads();
						});
					} else if(w.cell == null && w.getEnergyCount() <= 0)
					{
						futureObject.cell = new Cell.withCode(10, "");
						l.forEach((lw){
							futureObject.cell.greenCodeContext.insertCode(lw.cell.greenCodeContext.codeRangeBetweenHeads());
            								lw.cell.greenCodeContext.removeCodeRangeBetweenHeads();
            						});
					}
					else
					{
						futureObject.energy.energyCount = w.getEnergyCount();
						futureObject.cell = new Cell.withCode(10, "");
            						l.forEach((lw){
            							futureObject.cell.greenCodeContext.insertCode(lw.cell.greenCodeContext.codeRangeBetweenHeads());
                        								lw.cell.greenCodeContext.removeCodeRangeBetweenHeads();
                        						});
					}
				}
		}


		if(futureObject._state == State.Unknown)
		{
			futureObject._state = w._state;
			futureObject.energy.energyCount = w.energy.energyCount;
		}

		{
			List<WorldObject> l = [nei.n, nei.e, nei.s, nei.w];

			futureObject.energy.energyCount = l.fold(futureObject.getEnergyCount(), (i, lw) => lw.getEnergyCount() < w.getEnergyCount() && lw.getStateOut() == w.getStateIn() ? i + 1 : i);
			futureObject.energy.energyCount = l.fold(futureObject.getEnergyCount(), (i, lw) => lw.getEnergyCount() > w.getEnergyCount() && lw.getStateIn() == w.getStateOut() ? i - 1 : i);

			futureObject.energy.energyCount = l.fold(futureObject.getEnergyCount(),  (i, lw){
				if(w.cell == 0 && w.getEnergyCount() <= 0 && lw.cell!= 0)
					if(lw.cell.greenCodeContext.nextInject() != Direction.NONE)
						return i + (lw.getEnergyCount()/2).floor();
				return i;
			});
		}

		if(futureObject.energy.energyCount <= 0){
			futureObject._state = State.Void;
    	}

		if(futureObject._state == State.Void)
			futureObject.energy.energyCount = 0;
	}

	toString(){
		return "[$ticksSinceStart] " +  objects.map((w) => w._state.toString()).join(";");
	}
}
