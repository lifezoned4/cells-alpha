library cellsProtocolServer;

import 'dart:io';
import 'dart:json';
import 'dart:utf';

import 'package:bignum/bignum.dart';
import 'package:logging/logging.dart';
import 'package:crypto/crypto.dart';
import 'lib/cryptolib/dsa.dart';
import 'lib/cryptolib/bytes.dart';

final _logger = new Logger("cellsProtocolServer");

Dsa dsa = new Dsa();

class AuthEngine {
  Map<RestfulCommand, List<AuthBasic>> commandAuths = new Map<RestfulCommand, List<AuthBasic>>();
  
  addAuth(RestfulCommand command, AuthBasic auth){
    if(commandAuths.containsKey(command))
      commandAuths[command].add(auth);
    else
      commandAuths.putIfAbsent(command, () => new List<AuthBasic>.from([auth]));
  }
}

class AuthBasic {
  String name;
}

class AllAccess extends AuthBasic  {
  AllAcces(){
    name = "*";
  }
}

class AuthUser extends AuthBasic{
  String name;
  BigInteger pubKey;
}

class ServerCommEngine {
  Map<String, RestfulCommand> restfulCommands = new Map<String, RestfulCommand>();
  
  AuthEngine authEngine = new AuthEngine();
  
  ServerCommEngine(){
    RegRestuflCommand(new RestfulWebSocketAuth(this));
    authEngine.addAuth(restfulCommands[RestfulWebSocketAuth.commandNameInfo], new AllAccess());
  }
  
  RegRestuflCommand(RestfulCommand command){
    restfulCommands.putIfAbsent(command.commandName, () => command);
  }
  
  dealWithWebSocket(String message, WebSocket conn){
    _logger.info(message);
    if(conn.readyState == WebSocket.OPEN)
      conn.add("testback");
  }
  
  String dealWithRestful(String json){
    try {
      Map<String, dynamic> msg = parse(json);
      Map<String, dynamic> command = parse(msg["msg"]);
      if(valideSigning(msg) && restfulCommands.containsKey(command["command"]))
        return restfulCommands[command["command"]].dealWithCommand(command);
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
  
  String dealWithCommand(Map<String, dynamic> jsonMap){
    if(jsonMap["command"] != commandName)
      throw new InternalCommException("CommandName Fatal missmatch");
  }
}

class RestfulWebSocketAuth extends  RestfulCommand {    
  
  static String commandNameInfo = "WebSocketAuth";
  
  RestfulWebSocketAuth(ServerCommEngine engine) : super(engine){
    commandName = commandNameInfo;
  }
  
 String dealWithCommand(Map<String, dynamic> jsonMap){
   super.dealWithCommand(jsonMap);
   return "Auth Okay";
 }
}