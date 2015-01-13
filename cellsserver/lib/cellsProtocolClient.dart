library protocolClient;

import 'dart:html';
import 'dart:convert' show UTF8;
import 'dart:convert' show JSON;
import 'package:crypto/crypto.dart';
import 'cryptolib/dsa.dart';
import 'cryptolib/bytes.dart';


class WorldObjectFacade {
  static Map<int, WorldObjectFacade> listOfFacades = new Map<int, WorldObjectFacade>();

  int state = 0;
  int utctimestamp = 0;

  bool isHold = false;
  bool isCell = false;

  int id = 0;
  int energy = 0;

  WorldObjectFacade.Empty() {
    utctimestamp = new DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  setData(state, id) {
    this.state = state;
    this.id = id;
    utctimestamp = new DateTime.now().toUtc().millisecondsSinceEpoch;
    if (listOfFacades.containsKey(id)) {
      listOfFacades[id].utctimestamp = 0;
      listOfFacades.remove(id);
    }
    listOfFacades.putIfAbsent(id, () => this);
  }

  bool isTooOld() {
    return oldness() > 2000;
  }

  int oldness() {
    return (new DateTime.now().toUtc().millisecondsSinceEpoch) - utctimestamp;
  }
}

class ClientCommEngine {
  static const String commandNode = "/commands";
  static const String webSocketNode = "/ws";

  WebSocket ws;
  Function onDelayStatusChange;
  Function onErrorChange;
  Function onUpdatedCache;
  Function onSelectionInfo;
  Function onTotalEnergy;
  Function onUserActivity;

  DsaKeyPair keyPair;
  String serverURL;
  String username;
  Dsa dsa = new Dsa();
  int token;


  ClientCommEngine.fromUser(this.serverURL, this.username, String password) {
    keyPair = dsa.fromSecretUserPassword(username, password);
    initCache(width, height);
    _doTokeneExchange();
  }

  ClientCommEngine.fromKeyPair(this.serverURL, DsaKeyPair this.keyPair) {
    throw new Exception("Not implemented!");
  }

  initWebSocket(int token) {
  	if(ws != null)
  		ws.close();
  	ws = new WebSocket("ws://" + serverURL + webSocketNode);

    ws.onOpen.listen((e) {
      Map jsonMap = new Map();
      jsonMap.putIfAbsent("command", () => "token");
      jsonMap.putIfAbsent("data", () => token);
      ws.send(JSON.encode(jsonMap));
      ws.onMessage.listen(_dealWithWebSocketMsg);
    });

    ws.onClose.listen((e) {
    	_doTokeneExchange();
    });

    ws.onError.listen((e) {
    	_doTokeneExchange();
    });
  }

  void _doTokeneExchange() {
    this.commandWebSocketAuth((String response) {
          		int parsedTokken = int.parse(response, onError: (wrongInt) => 0);
          		if (parsedTokken != 0) this.initWebSocket(parsedTokken);
          		else {
          		   print(response);
          		  _doTokeneExchange();          		
          		}
          	}, ClientCommEngine.AdminMode);
  }

  int width = 10;
  int height = 30;
  initCache(int width, int height){
    this.width = width;
    this.height = height;
    int i = 0;
    clientcache.clear();
    while(i < width * height)
    {
      clientcache.add(new WorldObjectFacade.Empty());
      i++;
    }
  }

  retrieveWorldSize(){
    commandGetWorldSize((result) =>
        initCache(JSON.decode(result)["width"],JSON.decode(result)["height"]));
  }

  retrieveInfoForObject(int x, int y) {
    Map jsonMap = new Map();
    jsonMap.putIfAbsent("command", () => "Selection");
    jsonMap.putIfAbsent("data", () => {
      "x": x, "y": y
    });
    ws.send(JSON.encode(jsonMap));
  }

  spawnMassWebSocket(int state) {
    Map jsonMap = new Map();
    jsonMap.putIfAbsent("command", () => "insertEnergy");
    jsonMap.putIfAbsent("data", () => {
      "state": state
    });
    ws.send(JSON.encode(jsonMap));
  }

  liveSelectedWebSocket(String greenCode) {
    Map jsonMap = new Map();
    jsonMap.putIfAbsent("command", () => "liveSelection");
    jsonMap.putIfAbsent("data", () => greenCode);
    ws.send(JSON.encode(jsonMap));
  }

  getEnergyFromSelectedWebSocket(int count) {
    Map jsonMap = new Map();
    jsonMap.putIfAbsent("command", () => "pushSelectionEnergyToUser");
    jsonMap.putIfAbsent("data", () => {
      "count": count
    });
    ws.send(JSON.encode(jsonMap));
  }

  sendDemo(){
    Map jsonMap = new Map();
        jsonMap.putIfAbsent("command", () => "demo");
        jsonMap.putIfAbsent("data", () => {
        });
        ws.send(JSON.encode(jsonMap));
  }

  List<WorldObjectFacade> clientcache = new List<WorldObjectFacade>();

  _dealWithWebSocketMsg(MessageEvent msg) {
    try {
      Map jsonMap = JSON.decode(msg.data);
      if (jsonMap["username"] != username) return;
      jsonMap.remove("username");
      jsonMap["data"].forEach((command, value) {
        switch (command) {
          case "ticksLeft":
            if (onDelayStatusChange != null) onDelayStatusChange(value);
            if (value <= 0) {
           		ws.close();
            }
            break;
          case "Selection":
            // print("Getting selection data");
            onSelectionInfo(value);
            break;
          case "viewArea":
            // clearCache();
            Map jsonMap = value;
            jsonMap.forEach((k, v) {
                if(clientcache.length > (v["x"] + v["y"]*width)){
                  WorldObjectFacade toWorkOn = clientcache[v["x"] + (v["y"]*width)];
                  toWorkOn.id = v["object"]["state"];
                  toWorkOn.state = v["object"]["state"];
                  toWorkOn.utctimestamp = new DateTime.now().toUtc().millisecondsSinceEpoch;
                  toWorkOn.isHold = v["object"]["hold"] == 1 ? true : false;
                  toWorkOn.isCell = v["object"]["cell"] == 1;
                  toWorkOn.energy = v["object"]["energy"];
            }
            });
            onUpdatedCache();
            break;

          case "TotalEnergy":
          	onTotalEnergy(value);
          	break;
          case "error":
            onErrorChange(value);
            break;
          case "UserActivity":
          	onUserActivity(value);
          	break;
        }
      });
    } catch (ex) {
      print(ex);
    }
  }


  selectInfoAbout(int x, int y) {
    retrieveInfoForObject(x, y);
  }

  commandGetWorldSize(Function callback){
    try {
       String command = "commandGetWorldSize";
        Map jsonMap = new Map();
        jsonMap.putIfAbsent("command", () => command);
        jsonMap.putIfAbsent("utc", () => new DateTime.now().toUtc().millisecondsSinceEpoch);
        jsonMap.putIfAbsent("data", () => {
          "token": token
        });
      String msg = JSON.encode(jsonMap);

      msg = _sign(msg);
      _send(msg, callback);
      } catch (ex) {
        onErrorChange("Getting World Size failed");
      }
  }

  commandSelectInfoAbout(int id, Function callback) {
    try {
      String command = "SelectInfoAbout";
      Map jsonMap = new Map();
      jsonMap.putIfAbsent("command", () => command);
      jsonMap.putIfAbsent("utc", () => new DateTime.now().toUtc().millisecondsSinceEpoch);
      jsonMap.putIfAbsent("data", () => {
        "id": id,
        "token": token
      });
      String msg = JSON.encode(jsonMap);

      msg = _sign(msg);
      _send(msg, callback);
    } catch (ex) {
      onErrorChange("Getting Info for $id failed");
    }
  }

  static const String AdminMode = "Admin";
  static const String UserMode = "User";

  String mode;

  commandCreateUser(Function callback, String createToken){
  	try {
  	String command = "CreateUser";
  	 Map jsonMap = new Map();

  	 jsonMap.putIfAbsent("command", () => command);
     jsonMap.putIfAbsent("utc", () => new DateTime.now().toUtc().millisecondsSinceEpoch);
     jsonMap.putIfAbsent("createtoken", () => createToken);
     String msg = JSON.encode(jsonMap);
		 msg = _sign(msg);
	   _send(msg, callback);
      } catch (ex) {
        onErrorChange("Creation failed");
      }
  }

  commandWebSocketAuth(Function callback, String mode) {
    try {
      String command = "WebSocketAuth" + mode;
      this.mode = mode;
      Map jsonMap = new Map();

      jsonMap.putIfAbsent("command", () => command);
      jsonMap.putIfAbsent("utc", () => new DateTime.now().toUtc().millisecondsSinceEpoch);
      String msg = JSON.encode(jsonMap);

      msg = _sign(msg);
      _send(msg, callback);
    } catch (ex) {
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

  void _send(String msg, Function callback) {
    HttpRequest request = new HttpRequest(); // create a new XHR

    // add an event handler that is called when the request finishes
    request.onReadyStateChange.listen((_) {
      if (request.readyState == HttpRequest.DONE && (request.status == 200 || request.status == 0)) {
        // data saved OK.
        callback(request.responseText); // output the response from the server
      }
    });

    // POST the data to the server
    request.open("POST", "http://" + serverURL + commandNode, async: false);

    request.send(msg); // perform the async POST
  }
}
