library core;

import 'package:logging/logging.dart';

import "package:bignum/bignum.dart";
import "dart:io";
import 'dart:convert' show JSON;
import 'dart:math';

import "lib/greenCode.dart";
import "lib/cells.dart";

final _logger = new Logger("cellsCore");

class User extends ITickable {
  WebSocket socketAct;
  BigInteger pubKey;
  String username;  
  int lastSendTokken;
  int ticksLeft = 0;
  MovingAreaViewSubscription bootSubcription;
  
  User(this.username, this.pubKey, this.lastSendTokken);
  
  dealWithWebSocket(String message, WebSocket conn){
      print(message);
      Map jsonMap = JSON.decode(message);
      switch(jsonMap["command"]){
        case "moveSpectator":
          if (jsonMap["data"]["dx"].abs() + jsonMap["data"]["dy"].abs() + jsonMap["data"]["dz"].abs() > 1)
            return;
          this.bootSubcription.toFollow.pos.dx = jsonMap["data"]["dx"];
          this.bootSubcription.toFollow.pos.dy = jsonMap["data"]["dy"];
          this.bootSubcription.toFollow.pos.dz = jsonMap["data"]["dz"];
          break;
          
        case "spawnMass":
          Color color;
          switch(jsonMap["data"]["color"]){
            case "RED":
              color = Color.Red;
              break;
            case "GREEN":
              color = Color.Green;
              break;
            case "BLUE":
              color = Color.Blue;
          }
          Boot boot = this.bootSubcription.toFollow;
          if(boot.pos.isIn.positions.where((pos) => pos.x == boot.pos.x + boot.facing.dirX &&
              pos.y == boot.pos.y + boot.facing.dirY &&
              pos.z == boot.pos.z + boot.facing.dirZ).length == 0 &&
              boot.energy.energyCount > 50 && color != null){
          Position newPos;
          try {
          newPos = new Position(boot.pos.isIn, 
               boot.pos.x + boot.facing.dirX 
              ,boot.pos.y + boot.facing.dirY
              ,boot.pos.z + boot.facing.dirZ);
          } on Exception catch(ex, stacktrace) {
              _logger.warning("Added on an invalide field", ex, stacktrace);
              return;
          }
          boot.energy.decEnergyBy(50.0);
          newPos.putOn(new Mass(color, pow(50*3/(4*PI),1/3)));
          }
          break;
          
        case "liveSelected":
          if(this.bootSubcription.toFollow is Boot){
            Boot boot = this.bootSubcription.toFollow;
            if(boot.selected != null){
              if(boot.selected is Mass){
                Mass mass = boot.selected;
                String greenCode = jsonMap["data"];
                if(GreenCodeContext.syntaxCheckNames(greenCode) == "Okay")
                {
                  Cell cell = new Cell.withCode(mass.getColor(), greenCode);
                  cell.body = mass;
                  mass.pos.putOn(cell);
                  boot.selected = cell;
                  cell.isHold = true;
                }             
              }
            }
          }
          break;
        case "getEnergyFromSelected":
          if(this.bootSubcription.toFollow is Boot){
            Boot boot = this.bootSubcription.toFollow;
            if(boot.selected != null){
             double toGet = (jsonMap["data"]["count"] as int).toDouble();
             if(boot.selected is Mass){
               Mass mass = boot.selected;
               Random rnd = new Random();
               if(boot.energy.energyCount + toGet <= Energy.maxEnergyInObject)
               {
                 double consumed = mass.consume(toGet);
                 if(mass.size <= 0)
                   boot.selected = null;                   
                 boot.energy.incEnergyBy(consumed);                    
               }
              }
            }
          }
        break;
        case "sendEnergyFromBoot":
          if(this.bootSubcription.toFollow is Boot){
            Boot boot = this.bootSubcription.toFollow;
            if(boot.selected != null){
             double toSend = boot.energy.decEnergyBy((jsonMap["data"]["count"] as int).toDouble());
             double left = toSend;             
             if(boot.selected is Mass){
               Mass mass = boot.selected;
               Random rnd = new Random();
               int tryed = 0;
               double put = mass.grow(toSend);
               boot.energy.incEnergyBy(toSend - put);
             }
            }
          }
      }
  }
  
  String getSendData(){
    Map jsonMap = new Map();
    jsonMap.putIfAbsent("username", () => username);
    Map jsonMapData = new Map();
    subscriptions.forEach((sub) => jsonMapData.addAll(sub.getStateAsMap()));
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
        {"id": pos.object.id,"type": pos.object.type, "hold": pos.object.isHold ? 1 : 0, "color": 
           {"r": pos.object.getColor().r, 
            "g": pos.object.getColor().g, 
            "b": pos.object.getColor().b}});
    jsonMap.putIfAbsent(jsonMap.length.toString(), () => jsonPosition);

  }
}

class MovingAreaViewSubscription extends WorldSubscription {
  
  static const int watchAreaWidth = 7;
  static const int watchAreaHeight = 7;
  static const int watchAreaDepth = 7;
  
  WorldObject toFollow;
  
  MovingAreaViewSubscription(world, user, this.toFollow) : super(world, user);
  
  Map getStateAsMap(){
    Map jsonMap = new Map();
    Map jsonViewArea = new Map();
    world.getObjectsForRect(toFollow.pos.x - (watchAreaWidth/2).ceil(), 
                            toFollow.pos.y - (watchAreaHeight/2).ceil(),
                            toFollow.pos.z - (watchAreaDepth/2).ceil(), watchAreaWidth + 1, watchAreaHeight +1 , watchAreaDepth +1).forEach((Position pos)
        => WorldAreaViewCubicSubscription.addInfoAboutPositionInto(pos, jsonViewArea));
    jsonMap.putIfAbsent("viewArea",() => jsonViewArea);
    if(toFollow is Boot){
      Boot boot = toFollow;
      int selectedEnergy = 0;
      String greenCode = "";
      if(boot.selected != null)
        if(boot.selected is Mass)
        {
          Mass mass = boot.selected;
          selectedEnergy = mass.toEnergy().round();
        } else if (boot.selected is Cell){
          Cell cell = boot.selected;
          selectedEnergy = cell.energy.energyCount.round();
          greenCode =  cell.greenCodeContext.codeToStringNames();
        }
        jsonMap.putIfAbsent("bootInfo", () => {"greenCode": greenCode, "selectedEnergy": selectedEnergy, "energy": boot.energy.energyCount.round(), "dir": boot.facing.name, "x": toFollow.pos.x - (watchAreaWidth/2).floor(), "y": toFollow.pos.y - (watchAreaHeight/2).floor(), "z": toFollow.pos.z - (watchAreaDepth/2).floor()});
    }
    return jsonMap;
  }
}