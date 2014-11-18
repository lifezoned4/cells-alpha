library core;

import 'package:logging/logging.dart';

import "package:bignum/bignum.dart";
import "dart:io";
import 'dart:convert' show JSON;

import "lib/cells.dart";

final _logger = new Logger("cellsCore");

class User {
  Energy energy;
  bool isAdmin = false;
  WebSocket socketAct;
  BigInteger pubKey;
  String username;  
  int lastSendToken;
  int ticksLeft = 0;
  MovingAreaViewSubscription userSubcription;
  
  WorldObject selected;
    
  User(this.username, this.pubKey, this.lastSendToken);
  
  dealWithWebSocket(String message, WebSocket conn){
      print(message);
      Map jsonMap = JSON.decode(message);
      switch(jsonMap["command"]){
        case "Selection":
          int x = jsonMap["data"]["x"];
          int y = jsonMap["data"]["y"];
          selected = World.getObjectAt(x, y, subscriptions.first.world.objects, subscriptions.first.world.width);
          
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
          State state = State.Void;
          int v = int.parse(jsonMap["data"]["state"]);
          if(State.allStates.where((s) => s == v).length > 0)
            state = new State(v);
          WorldObject toPlaceOn = World.getObjectAt(userSubcription.x, userSubcription.y, userSubcription.world.objects, userSubcription.world.width);
          int dec = 0;
          if(toPlaceOn.getStateIntern() == State.Void || state == toPlaceOn.getStateIntern()) {
            userSubcription.user.energy.incEnergyBy(toPlaceOn.energy.incEnergyBy(userSubcription.user.energy.decEnergyBy(1)));
          }          
        break;                
        case "putSelection":
           
        break;
        
        case "liveSelection":
        
        break;
        case "pushSelectionEnergyToUser":          
          selected.energy.incEnergyBy(userSubcription.user.energy.incEnergyBy(selected.energy.decEnergyBy(int.parse(jsonMap["data"]["count"]))));
        break;
        
        case "demo":
          subscriptions.first.world.randomStateAdd();
        break;
      }
  }
  
  String getSendData(){
    Map jsonMap = new Map();
    jsonMap["username"] = username;
    Map jsonMapData = new Map();
    subscriptions.forEach((sub) => jsonMapData.addAll(sub.getStateAsMap()));   
    if(selected != null){
      jsonMapData["Selection"] = {};
      jsonMapData["Selection"].addAll({"x":selected.x, "y": selected.y, "state": selected.getStateIntern().toValue(), "energy": selected.getEnergyCount()});
      if(selected.cell != null){
        jsonMapData["Selection"].addAll()({"code": (selected as Cell).greenCodeContext.codeToStringNamesWithHeads(), 
                                 "registers": (selected as Cell).greenCodeContext.registersToString()});
    }
    }
    else
      jsonMapData["Selection"] = {"code": "", "registers": ""};    
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
      return;
    }
    if(socketAct != null && socketAct.readyState == WebSocket.OPEN)
     socketAct.add(getSendData());
    else 
      socketAct = null;
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
  WorldAreaViewSubscription(world, user, this.height, this.width): super(world, user);
  
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