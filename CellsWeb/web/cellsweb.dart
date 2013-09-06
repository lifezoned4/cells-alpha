import 'dart:html';

void main() {
  var webSocket = new WebSocket("ws://127.0.0.1:8080/ws");
  webSocket.onOpen.listen((e) {   
    webSocket.send("test");
  });
}

void reverseText(MouseEvent event) {
  
}
