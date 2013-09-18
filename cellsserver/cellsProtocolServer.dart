library protocolServer;

import 'dart:io';
import 'dart:json';
import 'dart:utf';
import 'dart:math';

import 'package:bignum/bignum.dart';
import 'package:logging/logging.dart';
import 'package:crypto/crypto.dart';

import 'lib/cryptolib/dsa.dart';
import 'lib/cryptolib/bytes.dart';
import 'lib/cells.dart';

import 'cellsCore.dart';
import 'cellsAuth.dart';

final _logger = new Logger("cellsProtocolServer");

Dsa dsa = new Dsa();

class ServerCommEngine {
  Map<String, RestfulCommand> restfulCommands = new Map<String, RestfulCommand>();
  
  AuthEngine authEngine = new AuthEngine();
  
  World world = new World(20,20,20);
  
  ServerCommEngine(){
    RegRestuflCommand(new RestfulWebSocketAuth(this));
    // authEngine.addAuth(restfulCommands[RestfulWebSocketAuth.commandNameInfo], new AllAccess());
    world.start();
  }
  
  RegRestuflCommand(RestfulCommand command){
    restfulCommands.putIfAbsent(command.commandName, () => command);
  }

  Map<int, User>
  
  dealWithWebSocket(String message, WebSocket conn){
    _logger.info(message);
    Map jsonMap = parse(message);
    switch(jsonMap["command"]){
      case "tokken":
        User foundUser = world.users.where((user) => user.lastSendTokken == jsonMap["data"]).first;
        if(foundUser == null)
          conn.add("{""command: ""error"", ""data"":""Tokken unknown""}");
        else
          foundUser.socketAct = conn;
        break;
    }
  }
  
  String dealWithRestful(String json){
    try {
      Map<String, dynamic> msg = parse(json);
      Map<String, dynamic> command = parse(msg["msg"]);
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
      dsa.verify(base64Decode(CryptoUtils.bytesToBase64(encodeUtf8(msg["msg"]))), new DsaSignature(signR, signS), publicKey);
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

class RestfulWebSocketAuth extends  RestfulCommand {      
  static String commandNameInfo = "WebSocketAuth";
  static const int ticksInTokken = 120;
  
  
  RestfulWebSocketAuth(ServerCommEngine engine) : super(engine){
    commandName = commandNameInfo;
  }
  
 String dealWithCommand(Map<String, dynamic> jsonMap, AuthContext context){
   
   super.dealWithCommand(jsonMap, context);
   int tokken = new Random().nextInt(1<<32 -1);
   if(engine.world.users.where((user) => user.username == context.username).isNotEmpty) {
    User foundUser = engine.world.users.where((user) => (user.pubKey == user.pubKey) && (user.username == context.username)).first;
    foundUser.lastSendTokken = tokken;
    foundUser.ticksLeft = ticksInTokken;
   }
   else{
    User newUser = new User(context.username, context.pubKey, tokken);
    newUser.ticksLeft = ticksInTokken;
    engine.world.users.add(newUser);
    newUser.subscriptions.add(new WorldTicksSubscription(engine.world, newUser));
    newUser.subscriptions.add(new WorldAreaViewCubicSubscription(engine.world, newUser,10,10,10,15));
    }
   return tokken.toString();
 }
}