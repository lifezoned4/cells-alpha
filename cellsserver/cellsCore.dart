library core;

import 'package:logging/logging.dart';

import "package:bignum/bignum.dart";
import "dart:io";
import "dart:math" show Random;
import 'dart:convert' show JSON;

import "lib/cells.dart";
import "cellsAuth.dart";
import "cellsPersist.dart";
import "cellsProtocolServer.dart";

final _logger = new Logger("cellsCore");

class User {
  AuthContext context;
  Energy energy;
  bool isAdmin = false;
  WebSocket socketAct;
  BigInteger pubKey;
  String username;
  int lastSendToken;
  int ticksLeft = 0;
  MovingAreaViewSubscription userSubcription;

  int selectedCellId = 0;
  WorldObject selected;

  User(this.username, this.pubKey, this.lastSendToken, this.context);

  dealWithWebSocket(String message, WebSocket conn){
      print(message);
      Map jsonMap = JSON.decode(message);
      switch(jsonMap["command"]){
        case "Selection":
          int x = jsonMap["data"]["x"];
          int y = jsonMap["data"]["y"];
          selected = World.getObjectAt(x, y, subscriptions.first.world.objects, subscriptions.first.world.width, subscriptions.first.world.height);
					if(selected.cell != null)
						selectedCellId = selected.cell.id;
					else
						selectedCellId = 0;
          break;
        case "SelectionId":
          int id = jsonMap["data"]["id"];
          var iterator =  subscriptions.first.world.objects.where((o) => o.cell != null && o.cell.id == id);
          if(iterator.length != 1)
          {
            _logger.warning("Error on this id: $id! Count $iterator.legnth");
          } else {
            selected = iterator.first;
          }
        break;
        case "insertEnergy":

        break;
        case "putSelection":

        break;

        case "liveSelection":
					if(selected != null){
						if(selected.getStateIntern() != State.Void)
						{
							subscriptions.first.world.measurement.putInput(jsonMap["data"], username, selected.x, selected.y);
							selected.cell = new Cell.withCode(jsonMap["data"]);
							selectedCellId = selected.cell.id;
						}
					}
        break;
        case "pushSelectionEnergyToUser":

        break;

        case "demo":
          switch(jsonMap["data"]["exmpNr"]){
                case 0:
                  subscriptions.first.world.clearWorld();
        	int i = 0;
        	while(i < 20){
	          subscriptions.first.world.randomStateAdd();
                  i++;
        	}
                break;
                case 1:
                  SwitchWorld("worldRNDExperiment");
                  break;
                case 2:
                  SwitchWorld("worldBreadExperiment");
                  break;
          }
              break;
      }
  }

  void SwitchWorld(String name){
    World.rnd = new Random(123456789);
    var users = subscriptions.first.world.users;
    var world = FilePersistContext.loadWorld("saves/${name}");
    ServerCommEngine.world = world;
    world.users = users;
    subscriptions.forEach((sub) => sub.world = world);
    world.start();
  }

  String getSendData(){
    Map jsonMap = new Map();
    jsonMap["username"] = username;
    Map jsonMapData = new Map();
    subscriptions.forEach((sub) => jsonMapData.addAll(sub.getStateAsMap()));
    if(selectedCellId != 0)
    	selected = subscriptions.first.world.getWorldObjectWhereCellId(selectedCellId);
    if(selected != null){
      jsonMapData["Selection"] = {};
      jsonMapData["Selection"].addAll({"x":selected.x, "y": selected.y, "state": selected.getStateIntern().toValue(), "energy": selected.getEnergyCount()});
      if(selected.cell != null){
        jsonMapData["Selection"].addAll({"code": selected.cell.greenCodeContext.codeToStringNamesWithHeads(),
                                 "registers": selected.cell.greenCodeContext.registersToString(),
                                 "id": selected.cell.id});
    }
    }
    else
      jsonMapData["Selection"] = {"code": "", "registers": ""};
    jsonMapData["TotalEnergy"] = {"Demo": subscriptions.first.world.isDemo, "Energy" : subscriptions.first.world.totalEnergy, "Warming": subscriptions.first.world.totalWarming};
    jsonMapData["UserActivity"] = context.engine.auths.where((a) {
    	if(a is AuthUser)
    		return ((a as AuthUser).activeContext != null);
    }).fold("", (v, a) => v + "${(a as AuthUser).name}[${(a as AuthUser).energyPocket}]; ");
    jsonMap.putIfAbsent("data", () => jsonMapData);
    return JSON.encode(jsonMap);
  }

  tick(){

  	ticksLeft--;
    if(ticksLeft < 0)
    {
      if(socketAct != null && socketAct.readyState == WebSocket.OPEN)
      socketAct.close();
      socketAct = null;
    	context.deActive();
      return;
    }

    if(socketAct != null && socketAct.readyState == WebSocket.OPEN){
    	context.doActive();
    	socketAct.add(getSendData());
    }
    else {
    	context.deActive();
    	socketAct = null;
    }
  }

  List<WorldSubscription> subscriptions = new List<WorldSubscription>();
}

abstract class WorldSubscription {
  World world;
  User user;

  WorldSubscription(this.world, this.user);

  Map getStateAsMap();
}

class WorldTicksSubscription extends WorldSubscription {
  WorldTicksSubscription(world, user): super(world, user);

  Map getStateAsMap(){
    Map jsonMap = new Map();
    jsonMap.putIfAbsent("ticksLeft", () => user.ticksLeft);
    return jsonMap;
  }
}

class WorldAreaViewSubscription extends WorldSubscription {
  int width = 0;
  int height = 0;
  WorldAreaViewSubscription(world, user, this.width, this.height): super(world, user);

  Map getStateAsMap(){
    Map jsonMap = new Map();
    Map jsonViewArea = new Map();
    World.getObjectsForRect(0, 0, width, height, world.objects).forEach((o) => addInfoAboutPositionInto(o, jsonViewArea));
    jsonMap.putIfAbsent("viewArea", () => jsonViewArea);
    return jsonMap;
  }

  static addInfoAboutPositionInto(WorldObject o, Map jsonMap){
    Map jsonPosition = new Map();
    jsonPosition.putIfAbsent("x", () =>  o.x);
    jsonPosition.putIfAbsent("y", () =>  o.y);
    jsonPosition.putIfAbsent("object", () =>
        {
         "id": o.cell != null ? o.cell.id : 0,
         "energy": o.getEnergyCount(),
         "state": o.getStateIntern().toValue(),
         "hold": o.cell != null ? (o.cell.isHold ? 1 : 0) : 0,
         "cell": o.cell != null ? 1 : 0
        });
    jsonMap.putIfAbsent(jsonMap.length.toString(), () => jsonPosition);
  }
}

class MovingAreaViewSubscription extends WorldSubscription {
  static const int watchAreaWidth = 7;
  static const int watchAreaHeight = 7;

  getX() => world.getWorldObjectWhereCellId(idToFollow) != null ? world.getWorldObjectWhereCellId(idToFollow).x : x;
  getY() => world.getWorldObjectWhereCellId(idToFollow) != null ? world.getWorldObjectWhereCellId(idToFollow).y : y;

  int idToFollow = 0;

  int x;
  int y;


  MovingAreaViewSubscription(world, user, this.idToFollow) : super(world, user);

  Map getStateAsMap(){
    Map jsonMap = new Map();
    Map jsonViewArea = new Map();
    World.getObjectsForRect(getX() - (watchAreaWidth/2).ceil(),
                            getY() - (watchAreaHeight/2).ceil(),
                            watchAreaWidth + 1, watchAreaHeight +1,
                            world.objects).forEach((WorldObject o)
        => WorldAreaViewSubscription.addInfoAboutPositionInto(o, jsonViewArea));
    jsonMap.putIfAbsent("viewArea",() => jsonViewArea);
    return jsonMap;
  }
}