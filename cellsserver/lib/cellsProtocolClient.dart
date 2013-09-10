library protocolClient;

import 'dart:html';
import 'dart:json';
import 'dart:utf';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'cryptolib/dsa.dart';
import 'cryptolib/bytes.dart';
import 'package:bignum/bignum.dart';

class ClientCommEngine {
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
  
  commmandWebSocketAuth(Function callback){
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
    request.open("POST", serverURL, async: false);
    
    request.send(msg); // perform the async POST
  }  
}