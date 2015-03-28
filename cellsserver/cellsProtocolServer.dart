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
  static const int width = 17;
  static const int height = 10;

  Map<String, RestfulCommand> restfulCommands = new Map<String, RestfulCommand>();

  AuthEngine authEngine = null;


  static World world;
  ServerCommEngine(){
    RegRestfulCommand(new RestfulWebSocketAuthUser(this));
    RegRestfulCommand(new RestfulMoveSpectation(this));
    RegRestfulCommand(new RestfulSelectInfoAbout(this));
    RegRestfulCommand(new RestfulGetWorldSize(this));

    try {
      ServerCommEngine.world = FilePersistContext.loadWorld("saves/world");
    }
    catch(ex, stacktrace){
       _logger.warning("File Loading Failed");
       _logger.warning("Error was: ", ex, stacktrace);
      return;
    }

    authEngine = new AuthEngine();

    World.persitActive = true;
    ServerCommEngine.world.start();
  }

  RegRestfulCommand(RestfulCommand command){
    restfulCommands.putIfAbsent(command.commandName, () => command);
  }

  dealWithWebSocket(String message, WebSocket conn){
    _logger.info(message);
    Map jsonMap = JSON.decode(message);
    switch(jsonMap["command"]){
      case "token":
         var it = world.users.keys.where((user) => user.lastSendToken == jsonMap["data"]);

         if(it.length > 0)
         {
          User foundUser = it.first;
          foundUser.socketAct = conn;
         }
         else {
          conn.add("{""command: ""error"", ""data"":""Tokken unknown""}");
         }
        break;
      default:
        var it = ServerCommEngine.world.users.keys.where((user) => user.socketAct == conn);
        if(it.length > 0 )
        {
          User foundUser = it.first;
          foundUser.dealWithWebSocket(message, conn);
        }
        break;
    }
  }

  String dealWithRestful(String json){
    try {
      Map<String, dynamic> msg = JSON.decode(json);
      Map<String, dynamic> command = JSON.decode(msg["msg"]);
      AuthContext context = new AuthContext(msg["username"], new BigInteger(msg["pubKey"], 16), authEngine);
      if(command.containsKey("createtoken") && command["command"] == "CreateUser")
      {
      	try {
      		BigInteger biToken = new BigInteger(command["createtoken"], 16);
      		authEngine.createUser(msg["username"],new BigInteger(msg["pubKey"], 16), biToken);
      	}
      	on Exception catch(ex){
      		_logger.warning("User Creation Exception", ex);
      		return ex.toString();
      	}
      	return "User created!";
      }
      if(!context.isValid())
      	return "Context-Pair userName, PubKey unknown!";
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
    return "FATAL ABSTRACT CALL";
  }
}

class RestfulMoveSpectation extends RestfulCommand  {
  static String commandNameInfo = "MoveSpectation";

  RestfulMoveSpectation(ServerCommEngine engine) : super(engine){
    commandName = commandNameInfo;
  }

  String dealWithCommand(Map<String, dynamic> jsonMap, AuthContext context){
    super.dealWithCommand(jsonMap, context);
    if (jsonMap["data"]["dx"].abs() + jsonMap["data"]["dy"].abs() > 1)
      return "Invalid";
    if(ServerCommEngine.world.users.keys.where((user) => user.username == context.username).isNotEmpty) {
      User foundUser = ServerCommEngine.world.users.keys.where((user) => (user.pubKey == user.pubKey) && (user.username == context.username)).first;
      foundUser.userSubcription.x += jsonMap["data"]["dx"] + ServerCommEngine.world.width % ServerCommEngine.world.width;
      foundUser.userSubcription.y += jsonMap["data"]["dy"] + ServerCommEngine.world.height % ServerCommEngine.world.height;

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
    int token = jsonMap["data"]["token"];

    var iterator =  ServerCommEngine.world.objects.where((o) => o.cell != null && o.cell.id == id);
    if(iterator.length != 1)
    {
      _logger.warning("Error on this id: $id! Count $iterator.legnth");
      return "Error on this id: $id!";
    } else {
      WorldObject object = iterator.first;
      Map returner = {"id": object.cell.id, "energy": object.getEnergyCount(),
        "x": object.x,
        "y": object.y,
      };

      returner.putIfAbsent("code", () => object.cell.greenCodeContext.codeToStringNames());

     if(ServerCommEngine.world.users.keys.where((user) => (user.lastSendToken == token) && user.userSubcription == null).isNotEmpty){
        _logger.info("Selecting object ${id}");
        ServerCommEngine.world.users.keys.where((user) => user.lastSendToken == token && user.userSubcription == null).first.selected = object;
        }

      return JSON.encode(returner);
    }
  }
}

class RestfulGetWorldSize extends  RestfulCommand {
  static String commandNameInfo = "commandGetWorldSize";

  RestfulGetWorldSize(ServerCommEngine engine) : super(engine){
      commandName = commandNameInfo;

    }
  String dealWithCommand(Map<String, dynamic> jsonMap, AuthContext context){
    super.dealWithCommand(jsonMap, context);
    return JSON.encode({"width": ServerCommEngine.world.width, "height":  ServerCommEngine.world.height});
  }
}

class RestfulWebSocketAuthUser extends  RestfulCommand {
  static String commandNameInfo = "WebSocketAuthAdmin";
  static const int ticksInTokken = 120;


  RestfulWebSocketAuthUser(ServerCommEngine engine) : super(engine){
    commandName = commandNameInfo;
  }

 String dealWithCommand(Map<String, dynamic> jsonMap, AuthContext context){
   super.dealWithCommand(jsonMap, context);
   int token = new Random().nextInt(1<<32 -1);

   User foundUser = null;
   Iterable iterFoundUser = ServerCommEngine.world.users.keys.where((u) => u.isAdmin && u.username == context.username);
   if(iterFoundUser.length > 0)
    foundUser = iterFoundUser.first;

   if(foundUser == null){
    User newUser = new User(context.username, context.pubKey, token, context);
    newUser.isAdmin = true;
    newUser.ticksLeft = ticksInTokken;
    ServerCommEngine.world.users[newUser] = 0;
    newUser.subscriptions.add(new WorldTicksSubscription(ServerCommEngine.world, newUser));
    newUser.userSubcription = null;
    newUser.subscriptions.add(new WorldAreaViewSubscription(ServerCommEngine.world, newUser,
             ServerCommEngine.width,
             ServerCommEngine.height));
   }
   else
   {
     foundUser.lastSendToken = token;
     foundUser.ticksLeft = ticksInTokken;
   }
   return token.toString();
 }
}