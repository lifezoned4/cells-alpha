import 'dart:html';
import 'package:cellsserver/cellsProtocolClient.dart';

ClientCommEngine commEngine;

class Viewer {  
  int _choosenNumber = 0;
 
  int displayOffsetX = 0;
  int displayOffsetY = 0;
  int displayOffsetZ = 0;
  int displayWidth = 30;
  int displayHeight = 16;
  int displayDepth = 3;
  
  get viewNumber => _choosenNumber;
  set viewNumber(int value) {
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
              "VarAOffset": getOffsetY,
              "VarBOffset": getOffsetX,
              "VarAConstrain": ClientCommEngine.getHeight,
              "VarBConstrain": ClientCommEngine.getWidth,
              "VarIRunnerOffset": getOffsetZ,
              "RunnerVarConstrain": ClientCommEngine.getDepth,
              "iMaxRunner": getDepth,
              "runnerFunc": ClientCommEngine.runVarXY_1,
              "left": "ZY_5",
              "right": "ZY_2",
              "up": "XZ_3",
              "down": "XZ_4"
              };
  
  static Map zy_2 = {"Name": "ZY_2", 
                     "iMaxVarA": getHeight,
                     "iMaxVarB": getDepth,
                     "VarAOffset": getOffsetY,
                     "VarBOffset": getOffsetZ,
                     "VarAConstrain": ClientCommEngine.getHeight,
                     "VarBConstrain": ClientCommEngine.getDepth,
                     "VarIRunnerOffset": getOffsetX,
                     "RunnerVarConstrain": ClientCommEngine.getWidth,
                     "iMaxRunner": getWidth,
                     "runnerFunc": ClientCommEngine.runVarZY_2,
                     "left": "XY_1",
                     "right": "XY_6",
                     "up": "XZ_3",
                     "down": "XZ_4"
  };
  
  static Map xz_3 = {"Name": "XZ_3", 
                     "iMaxVarA": getDepth,
                     "iMaxVarB": getWidth,
                     "VarAOffset": getOffsetZ,
                     "VarBOffset": getOffsetX,
                     "VarAConstrain": ClientCommEngine.getDepth,
                     "VarBConstrain": ClientCommEngine.getWidth,
                     "VarIRunnerOffset": getOffsetY,
                     "RunnerVarConstrain": ClientCommEngine.getHeight,
                     "iMaxRunner": getHeight,
                     "runnerFunc": ClientCommEngine.runVarXZ_3,
                     "left": "ZY_2",
                     "right": "ZY_5",
                     "up": "XY_6",
                     "down": "XY_1"
  };
  
  static Map xz_4 = {"Name": "XZ_4", 
                     "iMaxVarA": getWidth,
                     "iMaxVarB": getDepth,
                     "VarAOffset": getOffsetX,
                     "VarBOffset": getOffsetZ, 
                     "VarAConstrain": ClientCommEngine.getWidth,
                     "VarBConstrain": ClientCommEngine.getDepth,
                     "VarIRunnerOffset": getOffsetY,
                     "RunnerVarConstrain": ClientCommEngine.getHeight,
                     "iMaxRunner": getHeight,
                     "runnerFunc": ClientCommEngine.runVarZX_4,
                     "left": "ZY_5",
                     "right": "ZY_2",
                     "up": "XY_1",
                     "down": "XY_6"
  };

  static Map zy_5 = {"Name": "ZY_5", 
                     "iMaxVarA": getHeight,
                     "iMaxVarB": getDepth,
                     "VarAOffset": getOffsetY,
                     "VarBOffset": getOffsetZ,
                     "VarAConstrain": ClientCommEngine.getHeight,
                     "VarBConstrain": ClientCommEngine.getDepth,
                     "VarIRunnerOffset": getOffsetX,
                     "RunnerVarConstrain": ClientCommEngine.getWidth,
                     "iMaxRunner": getWidth,
                     "runnerFunc": ClientCommEngine.runVarZY_5,
                     "left": "XY_6",
                     "right": "XY_1",
                     "up": "XZ_3",
                     "down": "XZ_4"
  };

  
  static Map xy_6 = {"Name": "XY_6", 
              "iMaxVarA": getHeight,
              "iMaxVarB": getWidth,
              "VarAOffset": getOffsetY,
              "VarBOffset": getOffsetX,
              "VarAConstrain": ClientCommEngine.getHeight,
              "VarBConstrain": ClientCommEngine.getWidth,
              "VarIRunnerOffset": getOffsetZ,
              "RunnerVarConstrain": ClientCommEngine.getDepth,
              "iMaxRunner": getDepth,
              "runnerFunc": ClientCommEngine.runVarXY_6,
              "left": "ZY_2",
              "right": "ZY_5",
              "up": "XZ_4",
              "down": "XZ_3"
              };

  updateDisplayArea (DivElement displayArea, ClientCommEngine commEngine) {
    String text = "";
    displayArea.children.clear();
    TableElement table = new TableElement();
    
    for(int constArun = views[_choosenNumber]["VarAOffset"](this); constArun < views[_choosenNumber]["VarAOffset"](this) + views[_choosenNumber]["iMaxVarA"](this) ; constArun++){
      TableRowElement line = new TableRowElement ();
      line.id="FieldLine";
      for(int constBrun = views[_choosenNumber]["VarBOffset"](this); constBrun < views[_choosenNumber]["VarBOffset"](this) + views[_choosenNumber]["iMaxVarB"](this); constBrun++){
        TableCellElement cell = new TableCellElement();
        cell.id = "FieldSurrounder";
        ButtonElement bt = new ButtonElement();
        bt.id = "Field";
        Map returner = commEngine.getView(
            constArun, views[_choosenNumber]["VarAConstrain"] , constBrun, views[_choosenNumber]["VarBConstrain"],
            views[_choosenNumber]["runnerFunc"], 
            views[_choosenNumber]["VarIRunnerOffset"](this), 
            views[_choosenNumber]["iMaxRunner"](this),
            views[_choosenNumber]["RunnerVarConstrain"]);
        WorldObjectFacade object = returner["found"];        
        if(object != null && !object.isTooOld()){
          bt.text = returner["depth"].toString();         
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
  
  updateDisplayAreaInfo (DivElement displayArea, ClientCommEngine engine){
    displayArea.children.clear();
    LabelElement labelX = new LabelElement();
    labelX.text = "X: ${(displayOffsetX + 5).round()} / ${engine.worldWidth -1}";
    
    BRElement br1 = new BRElement();
    
    LabelElement labelY = new LabelElement();
    labelY.text = "Y: ${(displayOffsetY + 5).round()} / ${engine.worldHeight -1}";
    
    BRElement br2 = new BRElement();
    
    LabelElement labelZ = new LabelElement();
    labelZ.text = "Z: ${(displayOffsetZ + 2).round()} / ${engine.worldDepth -1}";
    
    displayArea.children.add(labelX);
    displayArea.children.add(br1);
    displayArea.children.add(labelY);
    displayArea.children.add(br2);
    displayArea.children.add(labelZ);
  }
}

void main() {
  
    InputElement url = query("#url");
    InputElement user = query("#user");
    InputElement password = query("#password");
        
    ButtonElement connect = query("#connect")..onClick.listen((e) => InitClient(url.value, user.value, password.value));
}

InitClient(String url, String user, String password){
  
  ButtonElement connect = query("#connect");
  InputElement urlElm = query("#url");
  InputElement userElm = query("#user");
  InputElement passwordElm = query("#password");
  
  DivElement infoarea = query("#infoarea");
  infoarea.text = "Nothing selected.";
  
  connect.disabled = true;
  urlElm.disabled = true;
  userElm.disabled = true;
  passwordElm.disabled = true;
  
  DivElement errorbar = query('#errorbar');
  
  Viewer viewer = new Viewer();
  
  Viewer viewerXY_1 = new Viewer()..viewNumber = 0;
// Viewer viewerZY_2 = new Viewer()..viewNumber = 1;
// Viewer viewerZX_3 = new Viewer()..viewNumber = 2;
    
 //  DivElement displayareaUp = query("#displayAreaUp");
 // DivElement displayareaCenter = query("#displayAreaCenter");
  DivElement displayareaRight = query("#displayAreaRight");
  DivElement displayareaInfo = query("#displayAreaInfo");
  
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
  
  commEngine = new ClientCommEngine.fromUser(url, user, password);
  
  commEngine.onErrorChange = (data) {
    errorbar.text = data;
  };
  
  commEngine.commandWebSocketAuth(
      (String response){
           int parsedTokken = int.parse(response, onError: (wrongInt) => 0);
           if(parsedTokken != 0)
            commEngine.initWwebSocket(parsedTokken);
      }
      );
  
  commEngine.onDelayStatusChange = (data) {
       
  };
  
 
  commEngine.onChangeRequestedInfo = (data){
    infoarea.text = data;
  };
  
  commEngine.onUpdatedChache = () {
    viewerXY_1.updateDisplayAreaInfo(displayareaInfo, commEngine);
    viewerXY_1.updateDisplayArea(displayareaRight, commEngine);
   // viewerZY_2.updateDisplayArea(displayareaCenter, commEngine);
   // viewerZX_3.updateDisplayArea(displayareaUp, commEngine);
  };
  
  commEngine.onSpectatorChange = (data) {
    viewerXY_1.displayOffsetX = data["x"];
 //   viewerZY_2.displayOffsetX = data["x"];
 //   viewerZX_3.displayOffsetX = data["x"];
    
    viewerXY_1.displayOffsetY = data["y"];
 //   viewerZY_2.displayOffsetY = data["y"];
 //  viewerZX_3.displayOffsetY = data["y"];
    
    viewerXY_1.displayOffsetZ = data["z"];
 //   viewerZY_2.displayOffsetZ = data["z"];
 //   viewerZX_3.displayOffsetZ = data["z"];
    commEngine.onUpdatedChache();
  };
  }
