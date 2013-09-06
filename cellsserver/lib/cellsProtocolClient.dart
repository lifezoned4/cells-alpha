library CellsProtocolClient;

import 'dart:html';
import 'dart:json';
import 'dart:utf';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'cryptolib/dsa.dart';
import 'cryptolib/bytes.dart';
import 'package:bignum/bignum.dart';

class ClientCommEngine {
   BigInteger privKey;
   String serverURL;
   Dsa dsa = new Dsa(); 
   
  ClientCommEngine.fromUser(this.serverURL, String user, String password){
    privKey = dsa.fromSecretUserPassword(user, password).privateKey;
  }
  
  ClientCommEngine.fromKey(this.serverURL, this.privKey){
    
  }
  
  commandFooBar(String argA, int argB, Function callback){
    String command = "FooBar";
    Map jsonMap = new Map<String, dynamic>();
    
    jsonMap.putIfAbsent("command", () => command);
    jsonMap.putIfAbsent("utc", () => new DateTime.now().toUtc().millisecondsSinceEpoch);
    jsonMap.putIfAbsent("argA", () => argA);
    jsonMap.putIfAbsent("argB", () => argB);
    
    String msg = stringify(jsonMap);
    msg = _sign(msg);
    _send(msg, callback);  
  }
  
  String _sign(String json) {
    DsaSignature signature = dsa.sign(base64Decode(CryptoUtils.bytesToBase64(encodeUtf8(json))), privKey);
    Map jsonMapWithSign = new Map<String, dynamic>();
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