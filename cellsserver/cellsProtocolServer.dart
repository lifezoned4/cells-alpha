library protocolServer;

import 'dart:io';
import 'dart:math';
import 'dart:convert' show UTF8;
import 'dart:convert' show JSON;

import 'package:bignum/bignum.dart';
import 'package:logging/logging.dart';
import 'package:crypto/crypto.dart';

import 'lib/cryptolib/dsa.dart';
import 'lib/cryptolib/bytes.dart';
import 'lib/cells.dart';
import 'cellsPersist.dart';

import 'cellsCore.dart';
import 'cellsAuth.dart';

final _logger = new Logger("cellsProtocolServer");

Dsa dsa = new Dsa();

class ServerCommEngine {
  static const int Width = 30;
  static const int Height = 16;
  static const int Depth = 3;
  
  Map<String, RestfulCommand> restfulCommands = new Map<String, RestfulCommand>();
  
  AuthEngine authEngine = new AuthEngine();
  
  
  World world;
  ServerCommEngine(){
    RegRestfulCommand(new RestfulWebSocketAuthUser(this));
    RegRestfulCommand(new RestfulWebSocketAuthAdmin(this));
    RegRestfulCommand(new RestfulMoveSpectator(this));
    RegRestfulCommand(new RestfulSelectInfoAbout(this));
    // authEngine.addAuth(restfulCommands[RestfulWebSocketAuth.commandNameInfo], new AllAccess());

    try {
      world = FilePersistContext.loadWorld();
    }
    catch(ex, stacktrace){
       _logger.warning("File Loading Failed");
       _logger.warning("Error was: ", ex, stacktrace);
    } 
    
    world.start();
  }
  
  RegRestfulCommand(RestfulCommand command){
    restfulCommands.putIfAbsent(command.commandName, () => command);
  }

  Map<int, User>
  
  dealWithWebSocket(String message, WebSocket conn){
    _logger.info(message);
    Map jsonMap = JSON.decode(message);
    switch(jsonMap["command"]){
      case "tokken":
        User foundUser = world.users.where((user) => user.lastSendTokken == jsonMap["data"]).first;
        if(foundUser == null)
          conn.add("{""command: ""error"", ""data"":""Tokken unknown""}");
        else {
          foundUser.socketAct = conn; 
        }
        break;
      default:
        User foundUser = world.users.where((user) => user.socketAct == conn).first;
        if(foundUser != null)
        {
          foundUser.dealWithWebSocket(message, conn);
        }
        break;
        
    }
  }
  
  String dealWithRestful(String json){
    try {
      Map<String, dynamic> msg = JSON.decode(json);
      Map<String, dynamic> command = JSON.decode(msg["msg"]);
      AuthContext context = new AuthContext(msg["username"], new BigInteger(msg["pubKey"], 16));
      if(valideSigning(msg) && restfulCommands.containsKey(command["command"]))
        return restfulCommands[command["command"]].dealWithCommand(command, context);
      else
        return "Command not Found or Signing Wrong: " + command["command"];
    } on FormatException catch(ex)
    {
      _logger.warning("JSON Command parser error!", ex);
    } on InternalCommException catch(ex){
      _logger.warning("Command Logic missmatch FATAL ERROR", ex);
    }
  }
  
  bool valideSigning(Map<String, dynamic> msg){
    BigInteger signR = new BigInteger(msg["signR"], 16);
    BigInteger signS = new BigInteger(msg["signS"], 16);
    BigInteger publicKey = new BigInteger(msg["pubKey"], 16);
    try {
      dsa.verify(base64Decode(CryptoUtils.bytesToBase64(UTF8.encode(msg["msg"]))), new DsaSignature(signR, signS), publicKey);
      return true;
    }
    on InvalidSignatureException catch(ex) {
      return false;
    }
    return false;
  }
}

class InternalCommException implements Exception{
  String cause;
  InternalCommException(this.cause);
}

abstract class RestfulCommand {
  ServerCommEngine engine;
  String commandName;
  
  RestfulCommand(this.engine);
  
  String dealWithCommand(Map<String, dynamic> jsonMap, AuthContext context){
    if(jsonMap["command"] != commandName)
      throw new InternalCommException("CommandName Fatal missmatch");
  }
}

class RestfulMoveSpectator extends RestfulCommand  {
  static String commandNameInfo = "MoveSpectator";
  
  RestfulMoveSpectator(ServerCommEngine engine) : super(engine){
    commandName = commandNameInfo;
  }
  
  String dealWithCommand(Map<String, dynamic> jsonMap, AuthContext context){
    super.dealWithCommand(jsonMap, context);
    if (jsonMap["data"]["dx"].abs() + jsonMap["data"]["dy"].abs() + jsonMap["data"]["dz"].abs() > 1)
      return "Invalid";
    if(engine.world.users.where((user) => user.username == context.username).isNotEmpty) {
      User foundUser = engine.world.users.where((user) => (user.pubKey == user.pubKey) && (user.username == context.username)).first;
      foundUser.bootSubcription.toFollow.pos.dx = jsonMap["data"]["dx"];
      foundUser.bootSubcription.toFollow.pos.dy = jsonMap["data"]["dy"];
      foundUser.bootSubcription.toFollow.pos.dz = jsonMap["data"]["dz"];
      return "Okay";
    }
    else { return "Invalid";}
  }
}

class RestfulSelectInfoAbout extends RestfulCommand {
  static String commandNameInfo = "SelectInfoAbout";

  RestfulSelectInfoAbout(ServerCommEngine engine) : super(engine){
    commandName = commandNameInfo;
  }
  
  String dealWithCommand(Map<String, dynamic> jsonMap, AuthContext context){    
    super.dealWithCommand(jsonMap, context);
    int id = jsonMap["data"]["id"];
    int tokken = jsonMap["data"]["tokken"];
    
    var iterator =  engine.world.positions.where((e) => e.object.id == id);
    if(iterator.length != 1)
    {
      _logger.warning("Error on this id: $id! Count $iterator.legnth");
      return "Error on this id: $id!";
    } else {
      WorldObject object = iterator.first.object;
      Map returner = {"id": object.id, "energy": object.energy.energyCount, 
        "x": object.pos.x, 
        "y": object.pos.y,
        "z": object.pos.z};
      if(object is Cell){
        Cell cell = object;
        returner.putIfAbsent("code", () => cell.greenCodeContext.codeToStringNames());
      }
      if(engine.world.users.where((user) => (user.lastSendTokken == tokken) && user.bootSubcription == null).isNotEmpty){
        _logger.info("Selecting object ${id}");
        if(object is Cell){
          if(engine.world.users.where((user) => user.lastSendTokken == tokken && user.bootSubcription == null).length > 1)
            _logger.info("BAD THINGS HAPPENED");
          _logger.info("IS CELL");
          engine.world.users.where((user) => user.lastSendTokken == tokken && user.bootSubcription == null).first.selected = object;      
        }
      }
      return JSON.encode(returner);
      }
  }
}

class RestfulWebSocketAuthUser extends  RestfulCommand {      
  static String commandNameInfo = "WebSocketAuthUser";
  static const int ticksInTokken = 120;
    
  RestfulWebSocketAuthUser(ServerCommEngine engine) : super(engine){
    commandName = commandNameInfo;
  }
  
 String dealWithCommand(Map<String, dynamic> jsonMap, AuthContext context){
   super.dealWithCommand(jsonMap, context);
   int tokken = new Random().nextInt(1<<32 -1);
   if(engine.world.users.where((user) => user.username == context.username).isNotEmpty && engine.world.users.where((user) => user.username == context.username).first.bootSubcription != null) {
    User foundUser = engine.world.users.where((user) => (user.pubKey == user.pubKey) && (user.username == context.username)).first;
    foundUser.lastSendTokken = tokken;
    foundUser.ticksLeft = ticksInTokken;
   }
   else{
    User newUser = new User(context.username, context.pubKey, tokken);
    newUser.ticksLeft = ticksInTokken;
    engine.world.users.add(newUser);
    newUser.subscriptions.add(new WorldTicksSubscription(engine.world, newUser));
    Boot boot = engine.world.findBoot(context.username);
    if(boot == null)
    {
      boot = engine.world.newBoot(context.username);
    }
    newUser.bootSubcription = new MovingAreaViewSubscription(engine.world, newUser, boot);    
    newUser.subscriptions.add(newUser.bootSubcription);
    }
   return tokken.toString();
 }
}

class RestfulWebSocketAuthAdmin extends  RestfulCommand {      
  static String commandNameInfo = "WebSocketAuthAdmin";
  static const int ticksInTokken = 120;
  
  
  RestfulWebSocketAuthAdmin(ServerCommEngine engine) : super(engine){
    commandName = commandNameInfo;
  }
  
 String dealWithCommand(Map<String, dynamic> jsonMap, AuthContext context){   
   super.dealWithCommand(jsonMap, context);
   int tokken = new Random().nextInt(1<<32 -1);
    User newAdminUser = new User(context.username, context.pubKey, tokken);
    newAdminUser.ticksLeft = ticksInTokken;
    engine.world.users.add(newAdminUser);
    newAdminUser.subscriptions.add(new WorldTicksSubscription(engine.world, newAdminUser));
    newAdminUser.bootSubcription = null;
    newAdminUser.subscriptions.add(new WorldAreaViewCubicSubscription
        (engine.world, newAdminUser, 
            (ServerCommEngine.Width/2).ceil(), 
            (ServerCommEngine.Height/2).ceil(), 
            (ServerCommEngine.Depth/2).ceil(), (max(max(ServerCommEngine.Width.toDouble(), 
                                                       ServerCommEngine.Height.toDouble()), 
                                                       ServerCommEngine.Depth.toDouble())~/2 + 1)));
   return tokken.toString();
 }
}