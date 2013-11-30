import 'dart:html';
import 'package:cellsserver/cellsProtocolClient.dart';

ClientCommEngine commEngine;

class Viewer {
  int displayOffsetX = 0;
  int displayOffsetY = 0;
  int displayOffsetZ = 0;
  int displayWidth = 0;
  int displayHeight = 0;
  int displayDepth = 0;
  
  String bootIcon = "NONE";
  
  ClientCommEngine commEngine;
  
  Viewer(this.commEngine){
    displayWidth = commEngine.clientMaxWidth();
    displayHeight = commEngine.clientMaxHeight();
    displayDepth = commEngine.clientMaxDepth();
  }
  
  updateDisplayArea (DivElement displayArea) {
  String text = "";
  displayArea.children.clear();
  TableElement table = new TableElement();
  
  for(int runnerY = displayOffsetY; runnerY < displayHeight + displayOffsetY; runnerY++){
    TableRowElement line = new TableRowElement ();
    line.id="FieldLine";
    for(int runnerX = displayOffsetX; runnerX < displayWidth + displayOffsetX; runnerX++){
      TableCellElement cell = new TableCellElement();
      cell.id = "FieldSurrounder";
      ButtonElement bt = new ButtonElement();
      bt.id = "Field";
      Map returner = commEngine.getView(runnerX, runnerY, displayOffsetX, displayOffsetY);
      WorldObjectFacade object = returner["found"];        
      if(object != null && !object.isTooOld()){
        if(object.type == "B"){
          String icon = "X";
          switch(bootIcon){
            case "UP":
              icon = "X";
            break;
            case "DOWN":
              icon = "O";
            break;
            case "W":
              icon = "<";
            break;
            case "E":
              icon =">";
            break;
            case "N":
              icon = "!";
              break;
            case "S":
              icon ="i";
              break;
         }
          bt.text = icon + returner["depth"].toString();          
        }
        else {
          bt.text = (object.isHold ? "~": "") + returner["depth"].toString();         
        }
        bt.id = "Field" + object.type;
        bt.style.color = "#000000";
        // bt.style.width = bt.style.height = "${40 - returner["depth"]*3}px";
        // bt.style.fontSize = "${18 - returner["depth"]}px";
        ColorFacade bgcolor = object.color;
        double oldnessScalar = (1-((object.oldness() + 1)/2000));
        bt.style.background = "rgb(${((bgcolor.r) * oldnessScalar).round()},${((bgcolor.g) * oldnessScalar).round()}, ${((bgcolor.b) * oldnessScalar).round()})"; 
        bt.onClick.listen((e) => commEngine.selectInfoAbout(object.id));
      }
      cell.children.add(bt);
      line.children.add(cell); 
    }
    table.children.add(line);
  }
  displayArea.children.add(table);
}
  
  
  // SHOULD BE THE SAME AS IN cellsCore.dart MovingAreaViewSubscription class
  static const int watchAreaWidth = 7;
  static const int watchAreaHeight = 7;
  static const int watchAreaDepth = 7;
  
  updateDisplayAreaInfo (DivElement displayArea){
      displayArea.children.clear();
      LabelElement labelX = new LabelElement();
      labelX.text = "X: ${(displayOffsetX + watchAreaWidth).round()} / ${commEngine.worldWidth -1}";
      
      BRElement br1 = new BRElement();
      
      LabelElement labelY = new LabelElement();
      labelY.text = "Y: ${(displayOffsetY + watchAreaHeight).round()} / ${commEngine.worldHeight -1}";
      
      BRElement br2 = new BRElement();
      
      LabelElement labelZ = new LabelElement();
      labelZ.text = "Z: ${(displayOffsetZ + watchAreaDepth).round()} / ${commEngine.worldDepth -1}";
      
      displayArea.children.add(labelX);
      displayArea.children.add(br1);
      displayArea.children.add(labelY);
      displayArea.children.add(br2);
      displayArea.children.add(labelZ);
  }
}

HideConnectionBar(){
  querySelector("#loginarea").hidden = true;
}


InitAdminClient(String url, String user, String password)
{
  HideConnectionBar();
  
  DivElement displayArea = querySelector("#displayarea");  
  DivElement admincontroll = querySelector("#admincontroll");
  
  admincontroll.hidden = false;
  
  DivElement errorbar = querySelector('#errorbar');
  errorbar.text = "Logging in progress...";
  
  commEngine = new ClientCommEngine.fromUser(url, user, password);
  
  Viewer viewer = new Viewer(commEngine);
    
  commEngine.onErrorChange = (data) {
    errorbar.text = data;
  };
  
  commEngine.commandWebSocketAuth(
      (String response){
           int parsedTokken = int.parse(response, onError: (wrongInt) => 0);
           if(parsedTokken != 0)
            commEngine.initWebSocket(parsedTokken);
      }, ClientCommEngine.AdminMode
  );
  
  commEngine.onChangeRequestedInfo = (data) {};
  
  
  querySelector("#demoMode")..onClick.listen((e) => commEngine.demoMode());
  
  TextAreaElement textarea = querySelector("#greenCodeAdmin");
  commEngine.onAdminSelectionInfo = (data) {
    // print("BEFORE WRITE");
    textarea.value = data.toString();
  };
  
  commEngine.onUpdatedCache = () {
    viewer.updateDisplayArea(displayArea);
  };
}

InitUserClient(String url, String user, String password){
  HideConnectionBar();

  DivElement displayArea = querySelector("#displayarea");

  DivElement errorbar = querySelector('#errorbar');
  errorbar.text = "Logging in progress...";
  
  DivElement movebar = querySelector("#movebar");
  DivElement infoarea = querySelector("#infoarea");
  
  DivElement bootcontroll1 = querySelector("#bootcontroll");
  DivElement bootcontrollSpwan = querySelector("#bootcontrollSpwan");
  
  bootcontroll1.hidden = false;
  bootcontrollSpwan.hidden = false;
      
  movebar.hidden = false;  
 
  commEngine = new ClientCommEngine.fromUser(url, user, password);
  
  Viewer viewer = new Viewer(commEngine);
  
  (querySelector("#buttonLeft") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(-1, 0 , 0));

  (querySelector("#buttonRight") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(1, 0 , 0));

  (querySelector("#buttonDown") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(0, 1 , 0));

  (querySelector("#buttonUp") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(0, -1 , 0));
  
  (querySelector("#buttonRise") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(0, 0 , 1));
  
  (querySelector("#buttonSink") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(0, 0 , -1));
    
  commEngine.onErrorChange = (data) {
    errorbar.text = data;
  };
  
  commEngine.commandWebSocketAuth(
      (String response){
           int parsedTokken = int.parse(response, onError: (wrongInt) => 0);
           if(parsedTokken != 0)
            commEngine.initWebSocket(parsedTokken);
      }, ClientCommEngine.UserMode
      );
  
  viewer.displayWidth = viewer.displayWidth = Viewer.watchAreaWidth;
  viewer.displayHeight = viewer.displayHeight = Viewer.watchAreaHeight; 
  viewer.displayDepth = viewer.displayDepth = Viewer.watchAreaDepth;
  
  
  commEngine.onDelayStatusChange = (data) {
       
  };
  
  commEngine.onUpdatedCache = () {
    viewer.updateDisplayArea(displayArea);
    viewer.updateDisplayAreaInfo(infoarea);
  };
  
  querySelector("#buttonREDspawn")..onClick.listen((e) => commEngine.spawnMassWebSocket("RED"));
  querySelector("#buttonGREENspawn")..onClick.listen((e) => commEngine.spawnMassWebSocket("GREEN"));
  querySelector("#buttonBLUEspawn")..onClick.listen((e) => commEngine.spawnMassWebSocket("BLUE"));
  
  ButtonElement bootEnergy = querySelector("#bootEnergyMedium")..onClick.listen((e) => commEngine.sendEnergyFromBootWebSocket(3));
  querySelector("#bootEnergyLarge")..onClick.listen((e) => commEngine.sendEnergyFromBootWebSocket(10));
  querySelector("#bootEnergySmall")..onClick.listen((e) => commEngine.sendEnergyFromBootWebSocket(1));
    
  ButtonElement selectedEnergy = querySelector("#selectedEnergyMedium")..onClick.listen((e) => commEngine.getEnergyFromSelectedWebSocket(3));
  querySelector("#selectedEnergyLarge")..onClick.listen((e) => commEngine.getEnergyFromSelectedWebSocket(10));
  querySelector("#selectedEnergySmall")..onClick.listen((e) => commEngine.getEnergyFromSelectedWebSocket(1));
  
  TextAreaElement greenCode = querySelector("#greenCode");
  
  
  bool dirty = false;
  querySelector("#live")..onClick.listen((e) {
    dirty = false;
    commEngine.liveSelectedWebSocket(greenCode.value);
  });
  (querySelector("#greenCode") as TextAreaElement).onInput.listen((e) => dirty = true);
  
  
  commEngine.onSpectatorChange = (data) {
    viewer.displayOffsetX = data["x"];
    viewer.displayOffsetY = data["y"];
    viewer.displayOffsetZ = data["z"];
    viewer.bootIcon = data["dir"];
    
    selectedEnergy.text = data["selectedEnergy"].toString();
    bootEnergy.text = data["energy"].toString();

    if(!dirty)
      greenCode.value = data["greenCode"];
    
    commEngine.onUpdatedCache();
  };

}

void main() {  
    InputElement url = querySelector("#url");
    InputElement user = querySelector("#user");
    InputElement password = querySelector("#password");
        
    ButtonElement connectAdmin = querySelector("#connectadmin")..onClick.listen((e) => InitAdminClient(url.value, user.value, password.value));
    ButtonElement connectUser = querySelector("#connectuser")..onClick.listen((e) => InitUserClient(url.value, user.value, password.value));
}