import 'dart:html';
import 'package:cellsserver/cellsProtocolClient.dart';

ClientCommEngine commEngine;

class Viewer {
  ClientCommEngine commEngine;

  int selectedX = 0;
  int selectedY = 0;
  
  Viewer(this.commEngine) {
    commEngine.width;
    commEngine.height;
  }

  updateDisplayArea(DivElement displayArea) {
    String text = "";
    displayArea.children.clear();
    TableElement table = new TableElement();

    for (int y = 0; y < commEngine.height; y++) {
      TableRowElement line = new TableRowElement();
      line.id = "FieldLine";
      for (int x = 0; x < commEngine.width; x++) {
        TableCellElement cell = new TableCellElement();
        cell.id = "FieldSurrounder";
        ButtonElement bt = new ButtonElement();
        bt.id = "Field";
        if((x + (y * commEngine.width)) < commEngine.clientcache.length){
         WorldObjectFacade r = commEngine.clientcache[x + (y * commEngine.width)];
         if (r != null && !r.isTooOld()) {
            bt.text = (r.isHold ? "~" : "") + r.state.toString();
            bt.id = "Field${r.state}${r.isCell ? "" : "C"}";
            double oldnessScalar = (1 - ((r.oldness() + 1) / 2000));
            bt.style.background = "rgb(${((254) * oldnessScalar).round()},${((254) * oldnessScalar).round()},${((254)*oldnessScalar).round()})";         
            if(selectedX == x && selectedY == y)
            {
              bt.style.background = "#FFFF00";
            }
            bt.style.color = "#000000";
            bt.onClick.listen(
                (e) => 
                    commEngine.selectInfoAbout(x, y)
            );
          }
        }
        cell.children.add(bt);
        line.children.add(cell);
      }
      table.children.add(line);
    }
    displayArea.children.add(table);
  }
}

HideConnectionBar() {
  querySelector("#loginarea").hidden = true;
}

InitClient(String url, String user, String password) {
  HideConnectionBar();

  ButtonElement demo = querySelector("#demo");
  
  DivElement displayArea = querySelector("#displayarea");

  DivElement errorbar = querySelector('#errorbar');
  errorbar.text = "Logging in progress...";

  commEngine = new ClientCommEngine.fromUser(url, user, password);

  demo.onClick.listen((e) =>commEngine.sendDemo());
    
  Viewer viewer = new Viewer(commEngine);

  commEngine.onErrorChange = (data) {
    errorbar.text = data;
  };

  commEngine.retrieveWorldSize();
  
  commEngine.commandWebSocketAuth((String response) {
    int parsedTokken = int.parse(response, onError: (wrongInt) => 0);
    if (parsedTokken != 0) commEngine.initWebSocket(parsedTokken);
  }, ClientCommEngine.AdminMode);

  TextAreaElement textarea = querySelector("#greenCodeContext");
  TextAreaElement infoarea = querySelector("#infoareaText");
  TextAreaElement textareaRegisters = querySelector("#greenCodeContextRegisters");
  
  commEngine.onSelectionInfo = (data) {
      infoarea.text = "(${data["x"]},${data["y"]}): State: ${data["state"]} Energy ${data["energy"]}";
      viewer.selectedX = data["x"];
      viewer.selectedY = data["y"];
  };

  commEngine.onUpdatedCache = () {
    viewer.updateDisplayArea(displayArea);
  };
}


void main() {
  InputElement url = querySelector("#url");
  InputElement user = querySelector("#user");
  InputElement password = querySelector("#password");

  ButtonElement connect = querySelector("#connect")..onClick.listen((e) => InitClient(url.value, user.value, password.value));
  }
