import 'dart:html';
import 'package:cellsserver/cellsProtocolClient.dart';

ClientCommEngine commEngine;

void main() {
  
  commEngine = new ClientCommEngine.fromUser("http://127.0.0.1:8080/commands", "test", "test");
  
  commEngine.commmandWebSocketAuth((String response) => print(response));
  
  var webSocket = new WebSocket("ws://127.0.0.1:8080/ws");
  webSocket.onOpen.listen((e) {   
    webSocket.send("test");
  });
  webSocket.onMessage.listen((MessageEvent e) {
    print(e.data);
  });
}

void reverseText(MouseEvent event) {
  
}
