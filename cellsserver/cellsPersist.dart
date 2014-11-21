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
    World newWorld = new World(ServerCommEngine.width, ServerCommEngine.height);
    File persistedWorld = new File("saves/world");
    persistedWorld.openRead();
    int i = 0;
    persistedWorld.readAsLinesSync().forEach((line) {
      Map jsonMap = JSON.decode(line);
      WorldObject o = new WorldObject(jsonMap["x"], jsonMap["y"], new State(jsonMap["state"]));
      if(jsonMap.containsKey("greenCode"))
        o.cell = new Cell.withCode(jsonMap["greenCode"]);
      o.energy.energyCount = jsonMap["energy"];
      assert(i == o.y*ServerCommEngine.width + o.x);
      i++;
    });
    return newWorld;
  }

  static void wirteSave(World world){
    File persistedWorld = new File("saves/world");
    persistedWorld.openWrite();
    String totalFile = "";
    world.objects.forEach((o){
       Map<String, dynamic> jsonMap = {"x": o.x, "y": o.y,
                      "energy": o.energy.energyCount,
                      "state": o.getStateIntern().toValue(),
                      "greenCode": o.cell != null ? o.cell.greenCodeContext.codeToStringNames() : ""};
       totalFile += JSON.encode(jsonMap) + '\n';
    });
    persistedWorld.writeAsStringSync(totalFile);
  }

}