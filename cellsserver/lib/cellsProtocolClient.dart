library protocolClient;

import 'dart:html';
import 'dart:json';
import 'dart:utf';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'cryptolib/dsa.dart';
import 'cryptolib/bytes.dart';
import 'package:bignum/bignum.dart';



class WorldObjectFacade {
  String color;
  String type;
  
  WorldObjectFacade(this.type, this.color);
}


class ClientCommEngine {  
  static const String commandNode = "/commands";
  static const String webSocketNode = "/ws";
      
  WebSocket ws;
  Function onDelayStatusChange;
  Function onErrorChange;
  Function onUpdatedChache;
  
  DsaKeyPair keyPair;
  String serverURL;
  String username;
  Dsa dsa = new Dsa(); 
   
  ClientCommEngine.fromUser(this.serverURL, this.username, String password){
    keyPair = dsa.fromSecretUserPassword(username, password); 
  }
  
  ClientCommEngine.fromKeyPair(this.serverURL, DsaKeyPair this.keyPair){
    throw new Exception("Not implemented!");
  }
  
  initWwebSocket(int tokken){
    var webSocket = new WebSocket("ws://" + serverURL + webSocketNode);
    webSocket.onOpen.listen((e) {   
      Map jsonMap = new Map();
      jsonMap.putIfAbsent("command", () => "tokken");
      jsonMap.putIfAbsent("data", () => tokken);
      webSocket.send(stringify(jsonMap));
      for(int x = 0; x <  subscribedWidth; x++) {
        clientcache.putIfAbsent(x, () => new Map<int, Map<int, WorldObjectFacade>>());
        for(int y = 0; y < subscribedHeight; y++) {
          clientcache[x].putIfAbsent(y, () => new Map<int, WorldObjectFacade>());
          for(int z = 0; z < subscribedDepth; z++) {
            clientcache[x][y].putIfAbsent(z, () => new WorldObjectFacade("", "#000000"));          
          }
        }
      }
      ws = webSocket;
      ws.onMessage.listen(_dealWithWebSocketMsg);      
    });    
  }
  
  static const String  emptyChar = "-";
  static const String somethingChar = "X";
  static const String somethingInbetweenChar = "x";
  static const String somethingFarChar = "^";
  static const String somethingFarFarChar = ".";
  
  clearCache(){
    for(int x = 0; x < subscribedWidth; x++)
      for(int y = 0; y < subscribedHeight; y++)
        for(int z = 0; z < subscribedDepth; z++){
          clientcache[x][y][z].type = emptyChar;         
          clientcache[x][y][z].type = "#FFFFFF";      
        }
  }
  
  WorldObjectFacade getZYView(int z, int y) {
    int depthX = 0;
    WorldObjectFacade found = null;
    for(int x = subscribedWidth - 1; x >= 0; x--)
    { 
      if(clientcache[x][y][z].type == somethingChar){
        found = clientcache[x][y][z]; 
        break;
      }
      depthX++;   
    }
    if(depthX == 0)
        return new WorldObjectFacade(somethingChar, found.color);
    else if(depthX >= subscribedWidth)
        return new WorldObjectFacade(emptyChar, "#000000");
    else if (depthX == 2)
      return  new WorldObjectFacade(somethingInbetweenChar, found.color);
    else if (depthX == 3)
      return new WorldObjectFacade(somethingFarChar, found.color);
    else if (depthX == 4);
        return new WorldObjectFacade(somethingFarFarChar, found.color);
  }
  
  WorldObjectFacade getXYView(int x, int y) {
    int depth = 0;
    WorldObjectFacade found = null;
    for(int z = 0; z < subscribedDepth; z++)
    { 
      if(clientcache[x][y][z].type == somethingChar){
        found = clientcache[x][y][z]; 
        break;
      }
      depth++;   
    }
    if(depth == 0)
        return new WorldObjectFacade(somethingChar, found.color);
    else if(depth >= subscribedDepth)
        return new WorldObjectFacade(emptyChar, "#000000");
    else if (depth == 2)
      return  new WorldObjectFacade(somethingInbetweenChar, found.color);
    else if (depth == 3)
      return new WorldObjectFacade(somethingFarChar, found.color);
    else if (depth == 4);
        return new WorldObjectFacade(somethingFarFarChar, found.color);
  }
  
  Map<int, Map<int, Map<int, WorldObjectFacade>>> clientcache = new Map<int, Map<int, Map<int, WorldObjectFacade>>>();
  int startpositionX = 0;
  int startpositionY = 0;
  int startpositionZ = 0;
  int subscribedWidth = 20;
  int subscribedHeight = 20;
  int subscribedDepth = 20;
  
  _dealWithWebSocketMsg(MessageEvent msg){
    try {
      Map jsonMap = parse(msg.data);
      if(jsonMap["username"] != username)
        return;
      jsonMap.remove("username");
      jsonMap["data"].forEach((command, value){
        switch(command)
        {
          case "ticksLeft":
            onDelayStatusChange(value);
            if(value == 0){
              commandWebSocketAuth((tokken) =>  initWwebSocket(int.parse(tokken)));
            }
          break;            
          case "viewArea":
            clearCache();
            Map jsonMap  = parse(value);
            print(value);
            jsonMap.forEach((k,v) {
              Map vmap = parse(v);
              clientcache[vmap["x"] - startpositionX][vmap["y"] - startpositionY][vmap["z"] - startpositionZ].type = somethingChar;
              clientcache[vmap["x"] - startpositionX][vmap["y"] - startpositionY][vmap["z"] - startpositionZ].color = "#00FF00";
              });
            onUpdatedChache();
            break;
          case "error":
            onErrorChange(value);
            break;
        }
      });
    } catch(ex) {
      print(ex);
    }
  }
  
  commandWebSocketAuth(Function callback){
    String command = "WebSocketAuth";
    Map jsonMap = new Map<String, dynamic>();
    
    jsonMap.putIfAbsent("command", () => command);
    jsonMap.putIfAbsent("utc", () => new DateTime.now().toUtc().millisecondsSinceEpoch);
    String msg = stringify(jsonMap);
    
    msg = _sign(msg);
    _send(msg, callback);  
  }
  
  String _sign(String json) {
    DsaSignature signature = dsa.sign(base64Decode(CryptoUtils.bytesToBase64(encodeUtf8(json))), keyPair.privateKey);
    Map jsonMapWithSign = new Map<String, dynamic>();
    jsonMapWithSign.putIfAbsent("username", () => username);
    jsonMapWithSign.putIfAbsent("pubKey", () => keyPair.publicKey.toString(16));    
    jsonMapWithSign.putIfAbsent("msg", () => json);
    jsonMapWithSign.putIfAbsent("signR", () => signature.r.toString(16));
    jsonMapWithSign.putIfAbsent("signS", () => signature.s.toString(16));
    return stringify(jsonMapWithSign);
  }
  
  Future<String> _send(String msg, Function callback) {
    HttpRequest request = new HttpRequest(); // create a new XHR
    
    // add an event handler that is called when the request finishes
    request.onReadyStateChange.listen((_) {
      if (request.readyState == HttpRequest.DONE &&
          (request.status == 200 || request.status == 0)) {
        // data saved OK.
        callback(request.responseText); // output the response from the server
      }
    });

    // POST the data to the server
    request.open("POST", "http://" + serverURL + commandNode, async: false);
    
    request.send(msg); // perform the async POST
  }  
}