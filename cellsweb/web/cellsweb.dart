import 'dart:html';
import 'package:cellsserver/cellsProtocolClient.dart';

ClientCommEngine commEngine;

class Viewer {  
  int _choosenNumber = 0;
 
  int displayOffsetX = 0;
  int displayOffsetY = 0;
  int displayOffsetZ = 0;
  int displayWidth = 11;
  int displayHeight = 11;
  int displayDepth = 5;
  
  get viewNumber => _choosenNumber;
  set viewNumber(int value) {
    print(value);
    _choosenNumber = value % views.length;
  }
  List<Map> views = [xy_1, zy_2, xz_3, xz_4, zy_5, xy_6];
    
  static int getHeight(Viewer viewer) => viewer.displayHeight;
  static int getWidth(Viewer viewer) => viewer.displayWidth;
  static int getDepth(Viewer viewer) => viewer.displayDepth;
  
  static int getOffsetX(Viewer viewer) => viewer.displayOffsetX;
  static int getOffsetY(Viewer viewer) => viewer.displayOffsetY;
  static int getOffsetZ(Viewer viewer) => viewer.displayOffsetZ;
  
  static Map xy_1 = {"Name": "XY_1", 
              "iMaxVarA": getHeight,
              "iMaxVarB": getWidth,
              "VarAOffset": getOffsetX,
              "VarBOffset": getOffsetY,
              "iMaxRunner": getDepth,
              "runnerFunc": ClientCommEngine.runVarXY_1,
              "left": "ZY_5",
              "right": "ZY_2",
              "up": "XZ_3",
              "down": "XZ_4"
              };
  
  static Map xy_6 = {"Name": "XY_6", 
              "iMaxVarA": getHeight,
              "iMaxVarB": getWidth,
              "VarAOffset": getOffsetY,
              "VarBOffset": getOffsetX,
              "iMaxRunner": getDepth,
              "runnerFunc": ClientCommEngine.runVarXY_6,
              "left": "ZY_2",
              "right": "ZY_5",
              "up": "XZ_4",
              "down": "XZ_3"
              };
  
  static Map zy_2 = {"Name": "ZY_2", 
              "iMaxVarA": getHeight,
              "iMaxVarB": getDepth,
              "VarAOffset": getOffsetY,
              "VarBOffset": getOffsetZ,
              "iMaxRunner": getWidth,
              "runnerFunc": ClientCommEngine.runVarZY_2,
              "left": "XY_1",
              "right": "XY_6",
              "up": "XZ_3",
              "down": "XZ_4"
              };
  
  static Map zy_5 = {"Name": "ZY_5", 
              "iMaxVarA": getHeight,
              "iMaxVarB": getDepth,
              "VarAOffset": getOffsetY,
              "VarBOffset": getOffsetZ,
              "iMaxRunner": getWidth,
              "runnerFunc": ClientCommEngine.runVarZY_5,
              "left": "XY_6",
              "right": "XY_1",
              "up": "XZ_3",
              "down": "XZ_4"
              };
  
  static Map xz_4 = {"Name": "XZ_4", 
              "iMaxVarA": getWidth,
              "iMaxVarB": getDepth,
              "VarAOffset": getOffsetX,
              "VarBOffset": getOffsetZ,
              "iMaxRunner": getHeight,
              "runnerFunc": ClientCommEngine.runVarZX_4,
              "left": "ZY_5",
              "right": "ZY_2",
              "up": "XY_1",
              "down": "XY_6"
              };
  
  
  static Map xz_3 = {"Name": "XZ_3", 
              "iMaxVarA": getDepth,
              "iMaxVarB": getWidth,
              "VarAOffset": getOffsetZ,
              "VarBOffset": getOffsetX,
              "iMaxRunner": getHeight,
              "runnerFunc": ClientCommEngine.runVarXZ_3,
              "left": "ZY_2",
              "right": "ZY_5",
              "up": "XY_6",
              "down": "XY_1"
              };
  
  
  updateDisplayArea (DivElement diplayArea, ClientCommEngine commEngine) {
    String text = "";
    diplayArea.children.clear();
    for(int constArun = views[_choosenNumber]["VarAOffset"](this); constArun < views[_choosenNumber]["VarAOffset"](this) + views[_choosenNumber]["iMaxVarA"](this); constArun++){
      diplayArea.children.add(new BRElement()); 
      for(int constBrun = views[_choosenNumber]["VarBOffset"](this); constBrun < views[_choosenNumber]["VarBOffset"](this) + views[_choosenNumber]["iMaxVarB"](this); constBrun++){
        ButtonElement div = new ButtonElement();
        div.text = "--";
        div.id = "Field";
        Map returner = commEngine.getView(
            constArun, constBrun,
            views[_choosenNumber]["runnerFunc"], views[_choosenNumber]["iMaxRunner"](this));
        WorldObjectFacade object = returner["found"];        
        if(object != null && !object.isTooOld()){
          div.text = (returner["depth"] < 10 ? "0" : "") + returner["depth"].toString();          
          div.style.color = "#000000";
          ColorFacade bgcolor = object.color;
          double oldnessScalar = (1/((object.oldness() + 1)/1000));
          div.style.background = "rgb(${(bgcolor.r * oldnessScalar).round()},${(bgcolor.g * oldnessScalar).round()}, ${(bgcolor.b * oldnessScalar).round()})"; 
        }
        diplayArea.children.add(div); 
      }
    }
  }
  
  updateDisplayAreaInfo (DivElement displayArea, ClientCommEngine engine){
    displayArea.children.clear();
    LabelElement labelX = new LabelElement();
    labelX.text = "X: ${(displayOffsetX + 5).round()} / ${engine.worldWidth}";
    
    BRElement br1 = new BRElement();
    
    LabelElement labelY = new LabelElement();
    labelY.text = "Y: ${(displayOffsetY + 5).round()} / ${engine.worldHeight}";
    
    BRElement br2 = new BRElement();
    
    LabelElement labelZ = new LabelElement();
    labelZ.text = "Z: ${(displayOffsetZ + 2).round()} / ${engine.worldDepth}";
    
    displayArea.children.add(labelX);
    displayArea.children.add(br1);
    displayArea.children.add(labelY);
    displayArea.children.add(br2);
    displayArea.children.add(labelZ);
  }
}

void main() {
  
  Viewer viewer = new Viewer();
  
  Viewer viewerXY_1 = new Viewer()..viewNumber = 0;
  Viewer viewerZY_2 = new Viewer()..viewNumber = 1;
  Viewer viewerZX_3 = new Viewer()..viewNumber = 2;
  
  
  DivElement displayareaUp = query("#displayAreaUp");
  DivElement displayareaCenter = query("#displayAreaCenter");
  DivElement displayareaRight = query("#displayAreaRight");
  DivElement displayareaInfo = query("#displayAreaInfo");
  
  ParagraphElement count = query("#count");
  
  window.onKeyDown.listen((e){
   
    if(e.keyCode == KeyCode.A)
      commEngine.moveSpectatorWebSocket(-1, 0 , 0);
    if(e.keyCode == KeyCode.D)
      commEngine.moveSpectatorWebSocket(1, 0 , 0);
    if(e.keyCode == KeyCode.S)
      commEngine.moveSpectatorWebSocket(0, 1 , 0);
    if(e.keyCode == KeyCode.W)
      commEngine.moveSpectatorWebSocket(0, -1 , 0);
    if(e.keyCode == KeyCode.Q)
      commEngine.moveSpectatorWebSocket(0, 0 , -1);
    if(e.keyCode == KeyCode.E)
      commEngine.moveSpectatorWebSocket(0, 0 , 1);
  });
  
  commEngine = new ClientCommEngine.fromUser("192.168.17.118:8080", "test", "test");
  
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
   
  };
  
  
  commEngine.onUpdatedChache = () {
    viewerXY_1.updateDisplayAreaInfo(displayareaInfo, commEngine);
    viewerXY_1.updateDisplayArea(displayareaCenter, commEngine);
    viewerZY_2.updateDisplayArea(displayareaRight, commEngine);
    viewerZX_3.updateDisplayArea(displayareaUp, commEngine);
  };
  
  commEngine.onSpectatorChange = (data) {
    viewerXY_1.displayOffsetX = data["x"];
    viewerZY_2.displayOffsetX = data["x"];
    viewerZX_3.displayOffsetX = data["x"];
    
    viewerXY_1.displayOffsetY = data["y"];
    viewerZY_2.displayOffsetY = data["y"];
    viewerZX_3.displayOffsetY = data["y"];
    
    viewerXY_1.displayOffsetZ = data["z"];
    viewerZY_2.displayOffsetZ = data["z"];
    viewerZX_3.displayOffsetZ = data["z"];
    commEngine.onUpdatedChache();
  };
  
  
}
