library persist;

import 'dart:io';
import 'package:logging/logging.dart';
import 'lib/cells.dart';
import 'cellsProtocolServer.dart';
import 'dart:convert' show JSON;

Logger _logger = new Logger("FilePersistContext");

class FilePersistContext {
  static const String commandAuthsPath = "auth/commands/";
  static const String knownUsers = "users/";

  String path;

  static World loadWorld(){

  	_logger.info("START LOADING....");
    World newWorld = new World(ServerCommEngine.width, ServerCommEngine.height);
    File persistedWorld = new File("saves/world");

    if(!persistedWorld.existsSync())
      persistedWorld.createSync();

    int i = 0;
    persistedWorld.readAsLinesSync().forEach((line) {
    	// _logger.info("decoding: $line");
      Map jsonMap = JSON.decode(line);
      WorldObject o = new WorldObject(jsonMap["x"], jsonMap["y"], new State(jsonMap["state"]));
      if(jsonMap.containsKey("greenCode"))
      {
      	if(jsonMap["greenCode"] is List)
      		o.cell = new Cell.withList(jsonMap["greenCode"]);
      }
      o.setEnergyCount(jsonMap["energy"]);
      assert(i == o.y*ServerCommEngine.width + o.x);
      World.putObjectAt(o.x, o.y, newWorld.objects, newWorld.width, newWorld.height, o);
      i++;
    	_logger.info("LOADING:($i/${ServerCommEngine.width*ServerCommEngine.height})");

    });
  	_logger.info("LOADING FINISHED!");
    return newWorld;
  }

  static void wirteSave(World world){
    File persistedWorld = new File("saves/world");
    String totalFile = "";
    world.objects.forEach((o){
       Map<String, dynamic> jsonMap = {"x": o.x, "y": o.y,
                      "energy": o.getEnergyCount(),
                      "state": o.getStateIntern().toValue(),
                      "greenCode": o.cell != null ? o.cell.greenCodeContext.code.map((cc) => cc.toString()).toList() : ""};
       totalFile += JSON.encode(jsonMap) + '\n';
    });
    persistedWorld.writeAsStringSync(totalFile);
  }

}