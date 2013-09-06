library cellsProtocolServer;

import 'dart:io';

import 'package:logging/logging.dart';

final _logger = new Logger("cellsProtocolServer");

class ServerCommEngine {
  dealWithWebSocket(String message, WebSocket conn){
    _logger.info(message);
    if(conn.readyState == WebSocket.OPEN)
      conn.add("testback");
  }
}