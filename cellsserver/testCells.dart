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
		expect(startX, nei.n.x);
		expect(startY - 1, nei.n.y);

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

		Map<WorldObject, Direction> mapld = {
			nei.n: Direction.N,
			nei.w: Direction.W,
			nei.s: Direction.S,
			nei.e: Direction.E
		};

		mapld.forEach((w, d) => expect(Neighbourhood.getObjectAtDirectionFrom(d, o, world.objects, world.width, world.height), w));


		mapld.keys.forEach((k) => mapld[k] = Direction.invertDirection(mapld[k]));

		mapld.forEach((w, d) => expect(Neighbourhood.getObjectAtDirectionFrom(d, w, world.objects, world.width, world.height), o));

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

		Cell theCell = new Cell.withCode("");

		o = new WorldObject(1, 1, State.Green);

		o.cell = theCell;
		int energyCount = 30;
		o.energy.energyCount = energyCount;

		World.putObjectAt(1, 1, world.objects, world.width, world.height, o);

		while (energyCount > 0) {
			energyCount -= CellsConfiguration.baseConsume;
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

		Cell theCell = new Cell.withCode("LOAD #1; STORE #8;");
		o.cell = theCell;

		o.energy.energyCount = 30;

		World.putObjectAt(o.x, o.y, world.objects, world.width, world.height, o);

		world.tick();

		expect(theCell.greenCodeContext.registers[GreenCodeContext.RegALU], 1);
		expect(theCell.greenCodeContext.registers[GreenCodeContext.RegMove], 0);

		expect(o.cell, theCell);

		world.tick();

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

		expect(theCell.greenCodeContext.registers[GreenCodeContext.RegALU], 1);
		expect(theCell.greenCodeContext.registers[GreenCodeContext.RegMove], 0);

		upO = World.getObjectAt(1, 0, world.objects, world.width, world.height);

		expect(upO.cell, theCell);
		expect(upO.getEnergyCount(), 30);
	});

	test("CelLMoveIntoEnergy", () {
		World world = new World(1, 5);
		expect(5, world.objects.length);


		WorldObject o = new WorldObject(0, 4, State.Green);
		o.energy.energyCount = 100;
		o.cell = new Cell.withCode("LOAD #1; STORE #8;");

		World.putObjectAt(o.x, o.y, world.objects, world.width, world.height, o);

		WorldObject energy = new WorldObject(0, 2, State.Green);
		energy.energy.energyCount = 1771;

		World.putObjectAt(energy.x, energy.y, world.objects, world.width, world.height, energy);

		int i = 0;
		while (i < 20) {
			i++;
			world.tick();
			expect(world.totalCellCount, 1);
		}
	});

	test("CellInjectIntoVoid", () {
		World world = new World(3, 3);
		expect(9, world.objects.length);

		WorldObject o = new WorldObject(1, 1, State.Green);
		o.energy.energyCount = 100;
		o.cell = new Cell.withCode("LOAD #3; STORE #3; LOAD #1; STORE #7;");

		World.putObjectAt(o.x, o.y, world.objects, world.width, world.height, o);

		world.tick();

		int i = 0;
		while (i < 3) {
			i++;
			expect(world.totalCellCount, 1);
			world.tick();
		}

		WorldObject upO = World.getObjectAt(1, 0, world.objects, world.width, world.height);
		expect(upO.cell != null, true);
		expect(upO.getEnergyCount(), 50);
		expect(world.totalCellCount, 2);
		expect(upO.cell.greenCodeContext.code.length, 4);
		expect(o.cell.greenCodeContext.code.length, 0);
	});

	test("CellInjectIntoEnergy", () {
		World world = new World(3, 3);
		expect(9, world.objects.length);


		WorldObject energy = new WorldObject(1, 0, State.Green);
		energy.energy.energyCount = 200;

		World.putObjectAt(energy.x, energy.y, world.objects, world.width, world.height, energy);

		energy = World.getObjectAt(1, 0, world.objects, world.width, world.height);

		expect(energy.getStateIntern(), State.Green);

		WorldObject o = new WorldObject(1, 1, State.Green);
		o.energy.energyCount = 100;
		o.cell = new Cell.withCode("LOAD #3; STORE #3; LOAD #1; STORE #7; ADD #1; ADD #2;");

		World.putObjectAt(o.x, o.y, world.objects, world.width, world.height, o);

		world.tick();

		int i = 0;
		while (i < 3) {
			i++;
			expect(world.totalCellCount, 1);
			world.tick();
		}

		o = World.getObjectAt(1, 1, world.objects, world.width, world.height);

		expect(o.getEnergyCount(), 100);
		expect(o.cell != null, true);
		expect(o.cell.greenCodeContext.code.length, 2);

		WorldObject upO = World.getObjectAt(1, 0, world.objects, world.width, world.height);
		expect(upO.cell != null, true);
		expect(upO.getEnergyCount(), 200);
		expect(upO.cell.greenCodeContext.code.length, 4);
		expect(o.cell.greenCodeContext.code.length, 2);
	});


	test("CellInjectIntoCell", () {
		World world = new World(3, 3);
		expect(9, world.objects.length);

		WorldObject cellO = new WorldObject(1, 0, State.Green);
		cellO.energy.energyCount = 150;
		cellO.cell = new Cell.withCode("ADD #1; ADD #2; ADD #3;");

		World.putObjectAt(cellO.x, cellO.y, world.objects, world.width, world.height, cellO);

		cellO = World.getObjectAt(1, 0, world.objects, world.width, world.height);

		expect(cellO.getStateIntern(), State.Green);

		WorldObject o = new WorldObject(1, 1, State.Green);
		o.energy.energyCount = 100;
		o.cell = new Cell.withCode("LOAD #3; STORE #3; LOAD #1; STORE #7; ADD #1; ADD #2;");

		World.putObjectAt(o.x, o.y, world.objects, world.width, world.height, o);

		world.tick();

		int i = 0;
		while (i < 3) {
			i++;
			expect(world.totalCellCount, 2);
			world.tick();
		}

		o = World.getObjectAt(1, 1, world.objects, world.width, world.height);
		expect(o.cell.greenCodeContext.code.length, 2);
		WorldObject upO = World.getObjectAt(1, 0, world.objects, world.width, world.height);
		expect(upO.cell.greenCodeContext.code.length, 7);
	});

	test("ErrorsInAssembler", () {
		World world = new World(3, 3);
  	expect(9, world.objects.length);

  	WorldObject cellO = new WorldObject(1, 0, State.Green);
  		cellO.energy.energyCount = 150;
  		cellO.cell = new Cell.withCode("LOAD #1; STOR3E #2; LOAD #1; ADD #2; STORE #8;");

  		expect(cellO.cell.greenCodeContext.code.length, 0);

  		World.putObjectAt(cellO.x, cellO.y, world.objects, world.width, world.height, cellO);

  		world.tick();
  		expect(cellO.cell.greenCodeContext.registers[GreenCodeContext.RegEnergyOWN], 150);
  		expect(cellO.cell.greenCodeContext.registers[GreenCodeContext.RegIP], 0);
	});


	test("TotalEnergyConstant", (){
		World world = new World(500, 500);
		int i = 0;
		while(i < 500)
		{world.randomStateAdd();
			i++;
		}

		world.tick();

		int totalEnergy = world.totalEnergy;

		i = 0;
		while(i < 500)
		{
			world.tick();
			expect(totalEnergy, world.totalEnergy);
			_logger.info("Step: $i");
			i++;
		}

	});
}
