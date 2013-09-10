library core;

import 'package:logging/logging.dart';

import "package:bignum/bignum.dart";
import "dart:io";
import "dart:json";
import "dart:async";

final _logger = new Logger("cellsCore");

class User {
  WebSocket socketAct;
  BigInteger pubKey;
  String username;  
  int lastSendTokken;
  
  User(this.username, this.pubKey, this.lastSendTokken);
  
  String getSendData(){
    Map jsonMap = new Map();
    jsonMap.putIfAbsent("Username", () => username);
    Map jsonMapData = new Map();
    subscriptions.forEach((sub) => jsonMapData.addAll(sub.getStateAsMap()));
    jsonMap.putIfAbsent("Data", () => jsonMapData);
    return stringify(jsonMap);
  }
  
  tick(){
    socketAct.add(getSendData());
  }
  
  List<WorldSubscription> subscriptions = new List<WorldSubscription>();
}

abstract class WorldSubscription {
  World world;
  
  Map getStateAsMap();
}

class WorldDelaySubscription extends WorldSubscription {
  Map getStateAsMap(){
    Map jsonMap = new Map();
    jsonMap.putIfAbsent("Delay", () => world.delay);
    return jsonMap;
  }
}

class World {
  List<User> users;
  int delay;
  Timer timer;
  int ticksTillStart; 
  
  start(){
    timer = new Timer(new Duration(milliseconds: delay), tick);
  }
  
  tick(){
    ticksTillStart++;
    _logger.info("Tick: ${ticksTillStart}");
    timer = new Timer(new Duration(milliseconds: delay), tick);
  }
}