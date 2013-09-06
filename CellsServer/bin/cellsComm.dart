library cellsComm;
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';

import 'dart:io';
import 'dart:async';

import 'cellsProtocolServer.dart';

final _logger = new Logger("cellsComm");

final String _ip = "127.0.0.1";
final int _port = 8080;

final _serverCommEngine = new ServerCommEngine();

main(){
    Logger.root.onRecord.listen(new PrintHandler()); 
   _logger.info("Starting up Cells Communication Layer");
   _logger.info("WebServer will be listening on ${_ip}:${_port}");
   
   HttpServer.bind(_ip, _port)
   .then((HttpServer server) {
     server.listen((HttpRequest request) {
       if(request.uri.path == "/ws"){         
       var sc = new StreamController();
       sc.stream.transform(new WebSocketTransformer())
        .listen(onWebSocketConn)
         .onError((error)  => print("Error working on HTTP server: $error"));
       sc.add(request);
       } else if (request.uri.path == "/version"){
         request.response.write("ver.0.0.1");
         request.response.close();
       }
       else {
        _logger.warning("Uri not found: ${request.uri.path}");
       request.response.close();
       }
     });
   });
}

onWebSocketConn(WebSocket conn) {        
  _logger.info("Something Connected");
  conn.listen(onWebSocketMsg);
}

onWebSocketMsg(message) { 
  _serverCommEngine.dealWith(message);
}