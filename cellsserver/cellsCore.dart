library core;

import 'package:logging/logging.dart';

import "package:bignum/bignum.dart";
import "dart:io";
import "dart:json";

import "lib/cells.dart";

final _logger = new Logger("cellsCore");

class User extends ITickable {
  WebSocket socketAct;
  BigInteger pubKey;
  String username;  
  int lastSendTokken;
  int ticksLeft = 0;
  
  
  User(this.username, this.pubKey, this.lastSendTokken);
  
  String getSendData(){
    Map jsonMap = new Map();
    jsonMap.putIfAbsent("username", () => username);
    Map jsonMapData = new Map();
    subscriptions.forEach((sub) => jsonMapData.addAll(sub.getStateAsMap()));
    jsonMap.putIfAbsent("data", () => jsonMapData);
    return stringify(jsonMap);
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

class WorldAreaViewCubicSubscription extends WorldSubscription {
  int x;
  int y;
  int z;
  int radius;
  
  WorldAreaViewCubicSubscription(world, user, this.x, this.y, this.z, this.radius): super(world, user);
  
  Map getStateAsMap(){
    Map jsonMap = new Map();
    Map jsonViewArea = new Map();
    world.getObjectsForCube(x, y, z, radius).forEach((Position pos) => addInfoAboutPositionInto(pos, jsonViewArea));
    jsonMap.putIfAbsent("viewArea", () => jsonViewArea);
    return jsonMap;
  } 
  
  static addInfoAboutPositionInto(Position pos, Map jsonMap){
    Map jsonPosition = new Map();
    jsonPosition.putIfAbsent("x", () =>  pos.x);
    jsonPosition.putIfAbsent("y", () =>  pos.y);
    jsonPosition.putIfAbsent("z", () =>  pos.z);{}
    jsonPosition.putIfAbsent("object", () => 
        {"id": pos.object.id, "color": {"r": pos.object.color.r, "g": pos.object.color.g, "b": pos.object.color.b}});
    _logger.info("Some Radius Calc with result:" + stringify(jsonPosition));
    jsonMap.putIfAbsent(jsonMap.length.toString(), () => jsonPosition);

  }
}

class MovingAreaViewSubscription extends WorldSubscription {
  
  WorldObject toFollow;
  
  MovingAreaViewSubscription(world, user, this.toFollow) : super(world, user);
  
  Map getStateAsMap(){
    Map jsonMap = new Map();
    Map jsonViewArea = new Map();
    world.getObjectsForCube(toFollow.pos.x, toFollow.pos.y, toFollow.pos.z, 5).forEach((Position pos)
        => WorldAreaViewCubicSubscription.addInfoAboutPositionInto(pos, jsonViewArea));
    jsonMap.putIfAbsent("viewArea",() => jsonViewArea);
    return jsonMap;
  }
}