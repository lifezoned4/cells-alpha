import 'dart:html';
import 'dart:math';
import 'dart:convert';
import 'package:cellsserver/cellsProtocolClient.dart';

ClientCommEngine commEngine;

class Viewer {
	ClientCommEngine commEngine;

	int selectedX = 0;
	int selectedY = 0;

	Viewer(this.commEngine) {

	}


	int width = 0;
	int height = 0;
	createButtons(DivElement displayArea) {
		TableElement table = new TableElement();
		if (width != commEngine.width || height != commEngine.height) {
			width = commEngine.width;
			height = commEngine.height;
			displayArea.children.clear();
			for (int y = 0; y < commEngine.height; y++) {
				TableRowElement line = new TableRowElement();
				line.id = "FieldLine";
				for (int x = 0; x < commEngine.width; x++) {
					TableCellElement cell = new TableCellElement();
					bts.add(new ButtonElement());
					ButtonElement bt = bts[x + (y * commEngine.width)];
					bt.onClick.listen((e) => commEngine.selectInfoAbout(x, y));
					cell.children.add(bt);
					line.children.add(cell);
				}
				table.children.add(line);
			}
			displayArea.children.add(table);
		}
	}

	List<ButtonElement> bts = new List<ButtonElement>();
	updateDisplayArea(displayArea) {
		String text = "";

		createButtons(displayArea);
		for (int y = 0; y < commEngine.height; y++) {
			for (int x = 0; x < commEngine.width; x++) {
				TableCellElement cell = new TableCellElement();
				cell.id = "FieldSurrounder";
				ButtonElement bt = bts[x + (y * commEngine.width)];
				bt.id = "Field";
				if ((x + (y * commEngine.width)) < commEngine.clientcache.length) {
					WorldObjectFacade r = commEngine.clientcache[x + (y * commEngine.width)];
					if (r != null && !r.isTooOld()) {
						String selector = "";
						if (selectedX == x && selectedY == y) {
							selector = "~";
						}
						bt.text = selector + (r.energy > 0 ? (log(r.energy.toDouble() / log(/*baseEnergy*/ 500)).floor() + 1) : 0).toString();
						bt.id = "Field${r.state}${r.isCell ? "C" : ""}";
						double oldnessScalar = (1 - ((r.oldness() + 1) / 2000));
					}
				}
			}
		}

	}
}

HideConnectionBar() {
	querySelector("#loginarea").hidden = true;
	querySelector("#clientarea").hidden = false;
}

InitClient(String url, String user, String password) {
	HideConnectionBar();

	ButtonElement demo = querySelector("#demo");

	DivElement displayArea = querySelector("#displayarea");

	DivElement userActivity = querySelector("#useractivity");

	DivElement errorbar = querySelector('#errorbar');
	errorbar.text = "Logging in progress...";

	commEngine = new ClientCommEngine.fromUser(url, user, password);

	demo.onClick.listen((e) => commEngine.sendDemo());

	Viewer viewer = new Viewer(commEngine);

	commEngine.onErrorChange = (data) {
		errorbar.text = data;
	};

	commEngine.retrieveWorldSize();

	commEngine.commandWebSocketAuth((String response) {
		int parsedTokken = int.parse(response, onError: (wrongInt) => 0);
		if (parsedTokken != 0) commEngine.initWebSocket(parsedTokken);
	}, ClientCommEngine.AdminMode);

	TextAreaElement textareaGreenCode = querySelector("#greenCodeContext");
	TextAreaElement infoarea = querySelector("#infoareaText");
	TextAreaElement textareaRegisters = querySelector("#greenCodeContextRegisters");

	ButtonElement startcell = querySelector("#startcell");
	startcell.onClick.listen((e) =>
			commEngine.liveSelectedWebSocket(textareaGreenCode.value));


	bool viewingCode = false;

	commEngine.onUserActivity = (data) {
		userActivity.text = data;
	};

	commEngine.onSelectionInfo = (data) {
		if (data.length > 0) {
			 try {
			infoarea.text = "(${data["x"]},${data["y"]}): State: ${data["state"]} Energy ${data["energy"]} ${data["id"] == null ? "" : "ID: ${data["id"]}"}";
			viewer.selectedX = data["x"];
			viewer.selectedY = data["y"];
			if(data.containsKey("code")){
				textareaGreenCode.value = data["code"];
				viewingCode = true;
			}
			else
			{
				if(viewingCode){
					textareaGreenCode.value = "";
					viewingCode = false;
				}
			}
			String registers = "";
			if (data.containsKey("registers")) (JSON.decode(data["registers"]) as Map).forEach((key, value) => registers += "$key: $value\n");
			textareaRegisters.value = registers;
			 }
			 on Exception
			 {
				infoarea.text = "";
				textareaRegisters.value = "";
			 }
		}
	};


	commEngine.onUpdatedCache = () {
		viewer.updateDisplayArea(displayArea);
	};

	commEngine.onTotalEnergy = (data) {
		errorbar.text = "TotalEnergy: ${data}";
	};
}


void main() {
	InputElement url = querySelector("#url");
	InputElement user = querySelector("#user");
	InputElement password = querySelector("#password");
	InputElement createToken = querySelector("#createtoken");
	InputElement confirmepassword = querySelector("#cofirmepassword");

	DivElement errorbar = querySelector('#errorbar');

	ButtonElement create = querySelector("#create")..onClick.listen((e)
			{
				if(password.value != confirmepassword.value) errorbar.text = "Creating User failed: Password does not match confirm";
				else
				{
					commEngine = new ClientCommEngine.fromUser(url.value, user.value, password.value);
					commEngine.commandCreateUser((msg) => errorbar.text = msg, createToken.value);
				}
			}
	);

	ButtonElement connect = querySelector("#connect")..onClick.listen((e) => InitClient(url.value, user.value, password.value));
}
