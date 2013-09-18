import 'dart:html';
import 'package:cellsserver/cellsProtocolClient.dart';

ClientCommEngine commEngine;

class Viewer {  
  int _choosenNumber = 0;
  
  get viewNumber => _choosenNumber;
  set viewNumber(int value) {
    print(value);
    _choosenNumber = value % views.length;
  }
  List<Map> views = [xy_1, zy_2, xz_3, xz_4, zy_5, xy_6];
    
  static int getHeight(ClientCommEngine commEngine) => commEngine.worldHeight;
  static int getWidth(ClientCommEngine commEngine) => commEngine.worldHeight;
  static int getDepth(ClientCommEngine commEngine) => commEngine.worldDepth;
  
  static Map xy_1 = {"Name": "XY_1", 
              "iMaxVarA": getHeight, 
              "iMaxVarB": getWidth,
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
              "iMaxRunner": getDepth,
              "runnerFunc": ClientCommEngine.runVarXY_6,
              "left": "ZY_2",
              "right": "ZY_5",
              "up": "XZ_4",
              "down": "XZ_3"
              };
  
  static Map zy_2 = {"Name": "ZY_2", 
              "iMaxVarA": getDepth,
              "iMaxVarB": getHeight,
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
    for(int constArun = 0; constArun < views[_choosenNumber]["iMaxVarA"](commEngine); constArun++){
      diplayArea.children.add(new BRElement()); 
      for(int constBrun = 0; constBrun < views[_choosenNumber]["iMaxVarB"](commEngine); constBrun++){
        ButtonElement div = new ButtonElement();
        div.text = "--";
        div.id = "XYField";
        Map returner = commEngine.getView(
            constArun, constBrun,
            views[_choosenNumber]["runnerFunc"], views[_choosenNumber]["iMaxRunner"](commEngine));
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
}

void main() {
  
  Viewer viewer = new Viewer();
  
  DivElement displayarea = query("#displayarea");
   
  SelectElement viewSelector = query("#viewChoose"); 
  viewer.views.forEach((view) => viewSelector.children.add(new OptionElement()..text = view["Name"]..value = viewSelector.options.length.toString()));
  
  viewSelector.onChange.listen((e) => viewer.viewNumber = int.parse(viewSelector.selectedOptions.first.value));
  

  
  
  
  Function navViews = (String name){viewer.viewNumber = viewer.views.indexOf(
      viewer.views.firstWhere((e) => e["Name"] == viewer.views[viewer.viewNumber][name]));
  viewSelector.selectedIndex = viewer.viewNumber;
  };
  
  ButtonElement left = query("#left");
  left.onClick.listen((e){
    navViews("left");
  });
  
  
  ButtonElement up = query("#up");
  up.onClick.listen((e){
    navViews("up");
  });
  
  ButtonElement right = query("#right");
  right.onClick.listen((e){
    navViews("right");
  });
  
 
  ButtonElement down = query("#down");
  down.onClick.listen((e){
    navViews("down");
  });
  
  
  
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
    viewer.updateDisplayArea(displayarea, commEngine);
  };
}
