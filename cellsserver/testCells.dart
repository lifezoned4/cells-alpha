import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';

import 'package:unittest/unittest.dart';


import 'lib/cells.dart';
import 'lib/greenCode.dart';

var _logger = new Logger("testCells");

main() {
	startQuickLogging();
	test("WorldCreation", () {
		World world = new World(3, 3);
		expect(9, world.objects.length);
	});

	test("WorldNeighberhood", () {
		World world = new World(3, 3);
		expect(9, world.objects.length);

		int startX = 1;
		int startY = 1;

		Neighbourhood nei = Neighbourhood.getNeightbourhood(startX, startY, world.objects, 3, 3);
		expect(startX , nei.n.x);
		expect(startY -1, nei.n.y);

		expect(startX + 1, nei.e.x);
		expect(startY, nei.e.y);

		expect(startX, nei.s.x);
		expect(startY + 1, nei.s.y);

		expect(startX - 1, nei.w.x);
		expect(startY, nei.w.y);

		WorldObject o = World.getObjectAt(startX, startY, world.objects, world.width, world.height);

		List<Direction> l = [Direction.E, Direction.N, Direction.S, Direction.W];
		l.forEach((Direction ld) {
			expect(nei.getObjectAtDirection(ld).x, ld.x + startX);
			expect(nei.getObjectAtDirection(ld).y, ld.y + startY);
			});

		Map<WorldObject, Direction> mapld = {nei.n:Direction.N, nei.w: Direction.W, nei.s: Direction.S, nei.e: Direction.E};

		mapld.forEach((w,d) => expect(Neighbourhood.getObjectAtDirectionFrom(d, o, world.objects, world.width, world.height), w));


		mapld.keys.forEach((k) => mapld[k] = Direction.invertDirection(mapld[k]));

		mapld.forEach(
		 			(w,d) =>
		 					expect(Neighbourhood.getObjectAtDirectionFrom(d, w, world.objects, world.width, world.height), o)
		 			);

	});

	test("GreenCodeDirections", () {

		expect(Direction.byValue(0), Direction.NONE);
		expect(Direction.byValue(1), Direction.N);
		expect(Direction.byValue(2), Direction.E);
		expect(Direction.byValue(3), Direction.S);
		expect(Direction.byValue(4), Direction.W);

		expect(Direction.byValue(5), Direction.NONE);
		expect(Direction.byValue(6), Direction.N);
	});


	test("EnergyStay", () {
				World world = new World(3, 3);
    		expect(9, world.objects.length);

    		WorldObject o = World.getObjectAt(1, 1, world.objects, world.width, world.height);
    		expect(o.cell, null);


    		o = new WorldObject(1, 1, State.Green);
    		o.energy.energyCount = 30;

     		World.putObjectAt(1, 1, world.objects, world.width, world.height, o);

    		o = World.getObjectAt(1, 1, world.objects, world.width, world.height);

    		expect(o.energy.energyCount, 30);
    		expect(o.getStateIntern(), State.Green);

    		o = World.getObjectAt(1, 1, world.objects, world.width, world.height);
    		expect(o.energy.energyCount, 30);

    		int counter = 30;
    		while (counter > 0) {
        			world.tick();
        			o = World.getObjectAt(1, 1, world.objects, world.width, world.height);
        			expect(o.getEnergyCount(), 30);
        			counter--;
        		}
	});

	test("CellStayEnergyCounter", () {
		World world = new World(3, 3);
		expect(9, world.objects.length);

		WorldObject o = World.getObjectAt(1, 1, world.objects, world.width, world.height);
		expect(o.cell, null);

		Cell theCell = new Cell.withCode(1, "");

		o = new WorldObject(1, 1, State.Green);

		o.cell = theCell;
		int energyCount = 30;
  	o.energy.energyCount = energyCount;

		World.putObjectAt(1, 1, world.objects, world.width, world.height, o);

		while (energyCount > 0) {
			energyCount--;
			world.tick();
			o = World.getObjectAt(1, 1, world.objects, world.width, world.height);
			expect(o.cell, theCell);
			expect(o.cell.getInternEnergyCountAt(o), energyCount);
		}

		world.tick();
		o = World.getObjectAt(1, 1, world.objects, world.width, world.height);
		expect(o.getStateIntern(), State.invCompliment(State.Green));
		expect(o.getEnergyCount(), 30);
	});

	test("CellMoveUp", () {
		World world = new World(3, 3);
		expect(9, world.objects.length);

		WorldObject o = World.getObjectAt(1, 1, world.objects, world.width, world.height);

		expect(o.x, 1);
		expect(o.y, 1);

		expect(o.cell, null);

		o = new WorldObject(o.x, o.y, State.Green);

		Cell theCell = new Cell.withCode(1, "LOAD #1; STORE #8;");
		o.cell = theCell;

		o.energy.energyCount = 30;

		World.putObjectAt(o.x, o.y, world.objects, world.width, world.height, o);

		world.tick();
		_logger.info(world.toString());

		expect(theCell.greenCodeContext.registers[GreenCodeContext.RegALU], 1);
		expect(theCell.greenCodeContext.registers[GreenCodeContext.RegMove], 0);

		expect(o.cell, theCell);

		world.tick();
		_logger.info(world.toString());

		expect(theCell.greenCodeContext.nextMove(), Direction.N);

		expect(theCell.greenCodeContext.registers[GreenCodeContext.RegALU], 1);
		expect(theCell.greenCodeContext.registers[GreenCodeContext.RegMove], 1);

		o = World.getObjectAt(1, 1, world.objects, world.width, world.height);

		expect(o.cell, null);
		expect(o.getEnergyCount(), 0);

		WorldObject upO = World.getObjectAt(1, 0, world.objects, world.width, world.height);

		expect(upO.cell, theCell);
		expect(upO.getEnergyCount(), 30);

		world.tick();
		_logger.info(world.toString());

		expect(theCell.greenCodeContext.registers[GreenCodeContext.RegALU], 1);
		expect(theCell.greenCodeContext.registers[GreenCodeContext.RegMove], 0);

		upO = World.getObjectAt(1, 0, world.objects, world.width, world.height);

		expect(upO.cell, theCell);
		expect(upO.getEnergyCount(), 30);

	});
}
