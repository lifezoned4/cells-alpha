library persist;

import 'dart:io';
import 'lib/cells.dart';
import 'cellsProtocolServer.dart';
import 'dart:convert' show JSON;

class FilePersistContext {
  static const String commandAuthsPath = "auth/commands/";
  static const String knownUsers = "users/";
    
  String path;
  
  static World loadWorld(){
    World newWorld = new World(ServerCommEngine.Width, ServerCommEngine.Height, ServerCommEngine.Depth);
    File persistedWorld = new File("saves/world");
    persistedWorld.openRead();
    persistedWorld.readAsLinesSync().forEach((line) {
      Map jsonMap = JSON.decode(line);
      Position newPos = new Position(newWorld, jsonMap["x"], jsonMap["y"], jsonMap["z"]);
      WorldObject toPlace;
      switch(jsonMap["type"]){
        case "M":
          toPlace = new Mass(new Color(jsonMap["worldObject"]["color"]["r"],
                                       jsonMap["worldObject"]["color"]["g"], 
                                       jsonMap["worldObject"]["color"]["b"], jsonMap["worldObject"]["color"]["name"]), jsonMap["mass"]["size"]);
          break;
        case "C":
          toPlace = new Cell.withCode(new Color(jsonMap["worldObject"]["color"]["r"],
                                       jsonMap["worldObject"]["color"]["g"], 
                                       jsonMap["worldObject"]["color"]["b"], jsonMap["worldObject"]["color"]["name"]), jsonMap["cell"]["code"]);
          (toPlace as Cell).body.size = jsonMap["cell"]["body"];
          (toPlace as Cell).outputBuffer = jsonMap["cell"]["outputBuffer"];
          (toPlace as Cell).livingBleed = jsonMap["cell"]["livingBleed"];          
          break;
        case "B":
          toPlace = new Boot(jsonMap["boot"]["user"]); 
          break;
      }
      toPlace.energy.energyCount = jsonMap["worldObject"]["energy"];
      newPos.putOn(toPlace);
    });
    return newWorld;
  }
  
  static void wirteSave(World world){
    File persistedWorld = new File("saves/world");
    persistedWorld.openWrite(); 
    String totalFile = "";
    world.positions.forEach((pos){
      
       Map jsonMap = {"x": pos.x, "y": pos.y, "z": pos.z, 
                      "worldObject": {"energy": pos.object.energy.energyCount, 
                                      "color": {"r": pos.object.getColor().r, 
                                           "g": pos.object.getColor().g,
                                           "b": pos.object.getColor().b,
                                           "name": pos.object.getColor().name}}};
       if(pos.object is Cell){
         Cell cell = pos.object;
         jsonMap.putIfAbsent("type", () => "C");
         jsonMap.putIfAbsent("cell", () => {"body": cell.body.size, 
                                            "code": cell.greenCodeContext.codeToStringNames(),
                                            "outputBuffer": cell.outputBuffer,
                                            "livingBleed": cell.livingBleed});
       }
       if(pos.object is Mass){
         Mass mass = pos.object;
         jsonMap.putIfAbsent("type", () => "M");
         jsonMap.putIfAbsent("mass", () => {"size": mass.size});
       }
       if(pos.object is Boot){
         Boot boot = pos.object;
         jsonMap.putIfAbsent("type", () => "B");
         jsonMap.putIfAbsent("boot", () => {"user": boot.user});
       }       
       totalFile += JSON.encode(jsonMap) + '\n';
    });
    persistedWorld.writeAsStringSync(totalFile);
  }

}