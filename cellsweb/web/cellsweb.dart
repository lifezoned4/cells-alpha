import 'dart:html';
import 'package:cellsserver/cellsProtocolClient.dart';

ClientCommEngine commEngine;

class Viewer {
  int _choosenNumber = 0;
 
  int displayOffsetX = 0;
  int displayOffsetY = 0;
  int displayOffsetZ = 0;
  int displayWidth = 0;
  int displayHeight = 0;
  int displayDepth = 0;
  
  ClientCommEngine commEngine;
  
  Viewer(this.commEngine){
    displayWidth = commEngine.clientMaxWidth();
    displayHeight = commEngine.clientMaxHeight();
    displayDepth = commEngine.clientMaxDepth();
  }
  
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

  updateDisplayArea (DivElement displayArea) {
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
  
  
  // SHOULD BE THE SAME AS IN cellsCore.dart MovingAreaViewSubscription class
  static const int watchAreaWidth = 6;
  static const int watchAreaHeight = 6;
  static const int watchAreaDepth = 6;
  
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
 query("#loginarea").hidden = true;
}


InitAdminClient(String url, String user, String password)
{
  HideConnectionBar();
  
  DivElement displayArea = query("#displayarea");
 
  DivElement errorbar = query('#errorbar');
  errorbar.text = "Logging in progress...";
  
  commEngine = new ClientCommEngine.fromUser(url, user, password);
  
  Viewer viewer = new Viewer(commEngine)..viewNumber = 0;
    
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
  
  commEngine.onUpdatedChache = () {
    viewer.updateDisplayArea(displayArea);
  };
}

InitUserClient(String url, String user, String password){
  HideConnectionBar();

  DivElement displayArea = query("#displayarea");

  DivElement errorbar = query('#errorbar');
  errorbar.text = "Logging in progress...";
  
  DivElement movebar = query("#movebar");
  DivElement infoarea = query("#infoarea");
  
  movebar.hidden = false;
  
  commEngine = new ClientCommEngine.fromUser(url, user, password);
  
  Viewer viewer = new Viewer(commEngine)..viewNumber = 0;
  
  (query("#buttonLeft") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(-1, 0 , 0));

  (query("#buttonRight") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(1, 0 , 0));

  (query("#buttonUp") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(0, 1 , 0));

  (query("#buttonDown") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(0, -1 , 0));
  
  (query("#buttonRise") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(0, 0 , 1));
  
  (query("#buttonSink") as ButtonElement).onClick.listen((a)=>commEngine.moveSpectatorWebSocket(0, 0 , -1));
    
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
  
  commEngine.onUpdatedChache = () {
    viewer.updateDisplayArea(displayArea);
    viewer.updateDisplayAreaInfo(infoarea);
  };
  
  commEngine.onSpectatorChange = (data) {
    viewer.displayOffsetX = data["x"];
    viewer.displayOffsetY = data["y"];
    viewer.displayOffsetZ = data["z"];
    commEngine.onUpdatedChache();
  };

}

void main() {  
    InputElement url = query("#url");
    InputElement user = query("#user");
    InputElement password = query("#password");
        
    ButtonElement connectAdmin = query("#connectadmin")..onClick.listen((e) => InitAdminClient(url.value, user.value, password.value));
    ButtonElement connectUser = query("#connectuser")..onClick.listen((e) => InitUserClient(url.value, user.value, password.value));
}