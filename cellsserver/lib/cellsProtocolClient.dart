library protocolClient;

import 'dart:html';
import 'dart:async';
import 'dart:convert' show UTF8;
import 'dart:convert' show JSON;
import 'package:crypto/crypto.dart';
import 'cryptolib/dsa.dart';
import 'cryptolib/bytes.dart';
import 'package:bignum/bignum.dart';

class ColorFacade {
  int r;
  int g;
  int b;
}

class WorldObjectFacade {  
  static Map<int, WorldObjectFacade> listOfFacades = new Map<int, WorldObjectFacade>();
  
  ColorFacade color = new ColorFacade()..r = 0..g = 0..b = 0;
  String type = "";
  int utctimestamp = 0;

  bool isHold = false;
  
  int id = -1;
  
  WorldObjectFacade.Empty(){
   utctimestamp = new DateTime.now().toUtc().millisecondsSinceEpoch; 
  }
  
  setData(String type, color, id){
    this.type = type;
    this.color = color;
    this.id = id;
    utctimestamp = new DateTime.now().toUtc().millisecondsSinceEpoch;
    if(listOfFacades.containsKey(id))
    {
      listOfFacades[id].utctimestamp = 0;
      listOfFacades.remove(id);
    }
      listOfFacades.putIfAbsent(id, () => this);
   }
  
  bool isTooOld(){
    return oldness() > 500;
  }
  
  int oldness(){
    return (new DateTime.now().toUtc().millisecondsSinceEpoch) - utctimestamp;
  }
}

class ClientCommEngine {  
  static const String commandNode = "/commands";
  static const String webSocketNode = "/ws";
      
  WebSocket ws;
  Function onDelayStatusChange;
  Function onErrorChange;
  Function onChangeRequestedInfo;
  Function onUpdatedCache;
  Function onSpectatorChange;
  
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
  
  initWebSocket(int tokken){
    var webSocket = new WebSocket("ws://" + serverURL + webSocketNode);
    webSocket.onOpen.listen((e) {   
      Map jsonMap = new Map();
      jsonMap.putIfAbsent("command", () => "tokken");
      jsonMap.putIfAbsent("data", () => tokken);
      webSocket.send(JSON.encode(jsonMap));
      for(int x = 0; x <  worldWidth; x++) {
        clientcache.putIfAbsent(x, () => new Map<int, Map<int, WorldObjectFacade>>());
        for(int y = 0; y < worldHeight; y++) {
          clientcache[x].putIfAbsent(y, () => new Map<int, WorldObjectFacade>());
          for(int z = 0; z < worldDepth; z++) {
            clientcache[x][y].putIfAbsent(z, () => new WorldObjectFacade.Empty());          
          }
        }
      }
      ws = webSocket;
      ws.onMessage.listen(_dealWithWebSocketMsg);      
    });    
  }
  
  
  moveSpectatorWebSocket(int dx, int dy, int dz){
    Map jsonMap = new Map();
    jsonMap.putIfAbsent("command", () => "moveSpectator");
    jsonMap.putIfAbsent("data", () => {"dx": dx, "dy": dy, "dz": dz});
    ws.send(JSON.encode(jsonMap));
  }
  
  static const String emptyChar = "-";
  static const String somethingChar = "X";
  static const String somethingInbetweenChar = "x";
  static const String somethingFarChar = "^";
  static const String somethingFarFarChar = ".";
  
  clearCache(){
    for(int x = 0; x < worldWidth; x++)
      for(int y = 0; y < worldHeight; y++)
        for(int z = 0; z < worldDepth; z++){
          clientcache[x][y][z].type = emptyChar;         
          clientcache[x][y][z].type = "#FFFFFF";      
        }
  }
  
 
  Map getView(int constX,  int constY, int offsetX, int offsetY) {
    int depth = 0;
    WorldObjectFacade found = null;
    for(int runnerDepth = 0; runnerDepth < worldDepth; runnerDepth++)
    { 
      // TODO typeSafe runVarContext 
      if(constX < 0 || constY < 0 ||
          constX >= worldWidth|| 
          constY >= worldHeight)
        return {"found": new WorldObjectFacade.Empty()..type="S", "depth": 0};
      if(runnerDepth < 0 || runnerDepth >= worldDepth)
        continue;
      WorldObjectFacade facade = clientcache[constX][constY][runnerDepth];
      if(facade != null && !facade.isTooOld())
      { 
        found = facade; 
        break;
      }
      depth++;   
    }
    return {"found": found, "depth": depth};
  }
  
  Map<int, Map<int, Map<int, WorldObjectFacade>>> clientcache = new Map<int, Map<int, Map<int, WorldObjectFacade>>>();
  int worldWidth = 30;
  int worldHeight = 16;
  int worldDepth = 3;
  
  int clientMaxWidth() => worldWidth;
  int clientMaxHeight() => worldHeight;
  int clientMaxDepth() => worldDepth;
  
  _dealWithWebSocketMsg(MessageEvent msg){
    try {
      Map jsonMap = JSON.decode(msg.data);
      if(jsonMap["username"] != username)
        return;
      jsonMap.remove("username");
      jsonMap["data"].forEach((command, value){
        switch(command)
        {
          case "ticksLeft":
            if(onDelayStatusChange != null)
              onDelayStatusChange(value);
            if(value == 0){
              commandWebSocketAuth((tokken){
                onErrorChange("New tokken: $tokken");
                initWebSocket(int.parse(tokken)); 
              }, mode);
            }
          break;            
          case "viewArea":
            // clearCache();
            Map jsonMap  = value;         
            jsonMap.forEach((k,v) {
              Map vmap = v;
              WorldObjectFacade toWorkOn =  clientcache[vmap["x"]][vmap["y"]][vmap["z"]];
              ColorFacade color = new ColorFacade();
              color.r = vmap["object"]["color"]["r"];
              color.g = vmap["object"]["color"]["g"];
              color.b = vmap["object"]["color"]["b"];
              toWorkOn.setData(vmap["object"]["type"], color, vmap["object"]["id"]);             
              toWorkOn.utctimestamp = new DateTime.now().toUtc().millisecondsSinceEpoch;
              toWorkOn.isHold = vmap["object"]["hold"] == 1 ? true : false;
            });
            onUpdatedCache();
            break;            
          case "bootInfo":
            Map jsonMap = value;
            onSpectatorChange(jsonMap);
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
  
  commandMoveSpectator(int dx, int dy, int dz, callback){
    String command = "MoveSpectator";
    Map jsonMap = new Map();
    
    jsonMap.putIfAbsent("command", () => command);
    jsonMap.putIfAbsent("utc", () => new DateTime.now().toUtc().millisecondsSinceEpoch);
    jsonMap.putIfAbsent("data",() => {"dx": dx, "dy": dy, "dz": dz});
    String msg = JSON.encode(jsonMap);
    
    msg = _sign(msg);
    _send(msg, callback); 
  }
  
  selectInfoAbout(int id){
    print(id);
    commandSelectInfoAbout(id, (value) => onChangeRequestedInfo(value));
  }
  
  commandSelectInfoAbout(int id, Function callback){
    try {
      String command = "SelectInfoAbout";
      Map jsonMap = new Map();
      jsonMap.putIfAbsent("command", () => command);
      jsonMap.putIfAbsent("utc", () => new DateTime.now().toUtc().millisecondsSinceEpoch);
      jsonMap.putIfAbsent("data", () => {"id": id});
      String msg = JSON.encode(jsonMap);
      
      msg = _sign(msg);
      _send(msg, callback);
    } catch(ex) {
      onErrorChange("Getting Info for $id failed");
    }    
  }
  
  static const String AdminMode = "Admin";
  static const String UserMode = "User";
  
  String mode;
  
  commandWebSocketAuth(Function callback, String mode){
    try {
      String command = "WebSocketAuth" + mode;
      this.mode = mode;
      Map jsonMap = new Map();
      
      jsonMap.putIfAbsent("command", () => command);
      jsonMap.putIfAbsent("utc", () => new DateTime.now().toUtc().millisecondsSinceEpoch);
      String msg = JSON.encode(jsonMap);
      
      msg = _sign(msg);
      _send(msg, callback);
    } catch(ex) {
      onErrorChange("Connection failed");
    }
  }
  
  String _sign(String json) {
    DsaSignature signature = dsa.sign(base64Decode(CryptoUtils.bytesToBase64(UTF8.encode(json))), keyPair.privateKey);
    Map jsonMapWithSign = new Map<String, dynamic>();
    jsonMapWithSign.putIfAbsent("username", () => username);
    jsonMapWithSign.putIfAbsent("pubKey", () => keyPair.publicKey.toString(16));    
    jsonMapWithSign.putIfAbsent("msg", () => json);
    jsonMapWithSign.putIfAbsent("signR", () => signature.r.toString(16));
    jsonMapWithSign.putIfAbsent("signS", () => signature.s.toString(16));
    return JSON.encode(jsonMapWithSign);
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