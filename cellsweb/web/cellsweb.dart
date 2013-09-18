import 'dart:html';
import 'package:cellsserver/cellsProtocolClient.dart';

ClientCommEngine commEngine;

void main() {
  
  DivElement displayareaXY = query("#displayareaXY");

  DivElement displayareaZY = query("#displayareaYZ");
  
  ParagraphElement count = query("#count");
  
  commEngine = new ClientCommEngine.fromUser("127.0.0.1:8080", "test", "test");
  
  commEngine.commandWebSocketAuth(
      (String response){
           int parsedTokken = int.parse(response, onError: (wrongInt) => 0);
           if(parsedTokken != 0)
            commEngine.initWwebSocket(parsedTokken);
      }
      );
  
  commEngine.onDelayStatusChange = (data) {
    count.text = data.toString();     
  };
  
  commEngine.onErrorChange = (data) {
    displayarea.text = data.toString();
  };
  
  commEngine.onUpdatedChache = () {
    String text = "";
    displayareaXY.children.clear();
    for(int y = 0; y < commEngine.subscribedHeight; y++){
      displayareaXY.children.add(new BRElement()); 
      for(int x = 0; x < commEngine.subscribedWidth; x++){
        ButtonElement div = new ButtonElement();
        div.id = "XYField";
        div.text = commEngine.getXYView(x, y).type;
        div.style.color = "#000000";
        div.style.background = commEngine.getXYView(x, y).color;
        displayareaXY.children.add(div); 
      }     
    }
    displayareaZY.children.clear();
    for(int y = 0; y < commEngine.subscribedHeight; y++){
      displayareaZY.children.add(new BRElement()); 
      for(int z = commEngine.subscribedDepth - 1; z >= 0; z--){
        ButtonElement div = new ButtonElement();
        div.id = "YZField";
        div.text = commEngine.getZYView(z, y).type;
        div.style.color = "#000000";
        div.style.background = commEngine.getZYView(z, y).color;
        displayareaZY.children.add(div); 
      }     
    }
  };
}
