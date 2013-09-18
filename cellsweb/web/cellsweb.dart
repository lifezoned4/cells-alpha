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
    displayareaXY.text = data.toString();
  };
  
  commEngine.onUpdatedChache = () {
    String text = "";
    displayareaXY.children.clear();
    for(int y = 0; y < commEngine.worldHeight; y++){
      displayareaXY.children.add(new BRElement()); 
      for(int x = 0; x < commEngine.worldWidth - 1; x++){
        ButtonElement div = new ButtonElement();
        div.text = "--";
        div.id = "XYField";
        Map returner = commEngine.getXYView(x, y);
        WorldObjectFacade object = returner["found"];        
        if(object != null && !object.isTooOld()){
          div.text = (returner["depth"] < 10 ? "0" : "") + returner["depth"].toString();          
          div.style.color = "#000000";
          ColorFacade bgcolor = object.color;
          double oldnessScalar = (1/((object.oldness() + 1)/1000));
          div.style.background = "rgb(${(bgcolor.r * oldnessScalar).round()},${(bgcolor.g * oldnessScalar).round()}, ${(bgcolor.b * oldnessScalar).round()})"; 
        }
        displayareaXY.children.add(div); 
      }     
    }
    displayareaZY.children.clear();
    for(int y = 0; y < commEngine.worldHeight; y++){
      displayareaZY.children.add(new BRElement()); 
      for(int z = commEngine.worldDepth - 1; z >= 0; z--){
        ButtonElement div = new ButtonElement();
        div.text = "--";
        div.id = "YZField";
        Map returner = commEngine.getZYView(z, y);
        WorldObjectFacade object = returner["found"];  
        if(object != null && !object.isTooOld()){
          div.text = (returner["depth"] < 10 ? "0" : "") + returner["depth"].toString();
          div.style.color = "#000000";
          ColorFacade bgcolor = object.color;
          double oldnessScalar = (1/((object.oldness() + 1)*1/100));
          div.style.background = "rgb(${(bgcolor.r * oldnessScalar).round()},${(bgcolor.g * oldnessScalar).round()}, ${(bgcolor.b * oldnessScalar).round()})"; 
        }
        displayareaZY.children.add(div); 
      }     
    }
  };
}
