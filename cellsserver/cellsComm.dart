library comm;
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'cellsProtocolServer.dart';

final _logger = new Logger("cellsComm");

final String _ip = "127.0.0.1";
final int _port = 8080;


ServerCommEngine _serverCommEngine;

main(){
    Logger.root.onRecord.listen(new LogPrintHandler());
   _logger.info("Starting up Cells Communication Layer");
   _logger.info("WebServer will be listening on ${_ip}:${_port}");

   runZoned((){
   _serverCommEngine = new ServerCommEngine();
   try {
   HttpServer.bind(_ip, _port)
   .then((HttpServer server) {
     try {
     server.listen((HttpRequest request) {
       if(request.uri.path == "/ws"){
        try {
         var sc = new StreamController();
         sc.stream.transform(new WebSocketTransformer())
          .listen(onWebSocketConn)
           .onError((err)  => print("Error working on HTTP server: $err"));
         sc.add(request);
         sc.done.catchError((error) => _logger.warning("Known WebSocket Error"));
        } catch(ex) {
          _logger.warning("Error on WebSocket creation", ex);
        }
       } else if (request.uri.path == "/commands" && request.method == 'POST'){
          Encoding.getByName("ASCII").decodeStream(request).then(
                                                              (t){_logger.info("Request POST: " + t);
                                                                  String reponse =_serverCommEngine.dealWithRestful(t);
                                                                  request.response.headers.set("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
                                                                  request.response.headers.set("Access-Control-Allow-Origin","*");
                                                                  request.response.add(Encoding.getByName("ASCII").encoder.convert(reponse));
                                                                  request.response.close();
                                                              });
          request.response.done.catchError((error) => _logger.warning("Known RESTFul Error"));
          }
       else if (request.uri.path == "/version"){
         request.response.write("ver.0.0.1");
         request.response.close();
       }
       else {
         try {
          _logger.warning("Uri not found: ${request.uri.path}");
          request.response.headers.set("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
          request.response.headers.set("Access-Control-Allow-Origin","*");
          request.response.close();
         } catch (ex) {
           _logger.warning("Error on response close", ex);
         }
       }
     }, onError: (err){
       _logger.warning("Listen HttpServer Stream Error!");
     });
     }
     catch(ex) {
       _logger.warning("Something went wrong inside of HttpServer binding!", ex);
     }
   }, onError: (err){
     _logger.warning("Binding HttpServer Stream Error: $err");
   });
   }
   catch(ex) {
     _logger.warning("Binding HttpServer failed!", ex);
   }
  }
  , onError: (dynamic err) {
    try {
    _logger.warning("Zoned Error: $err");
    _logger.warning(err.stackTrace.toString());
    }
    catch(ex){
      try {
      _logger.warning("Yaw Dog, Zoned Zoned Error");
      }
      catch(exkill){
        _logger.warning("SILENCE, I KILL YOU!");
      }
    }
   });
}

onWebSocketConn(WebSocket conn) {
  _logger.info("Something Connected");
  conn.listen(new CellsWebSocketConnection(conn).onWebSocketMsg);
}

class CellsWebSocketConnection {
  WebSocket conn;
  CellsWebSocketConnection(this.conn);

  onWebSocketMsg(message) {
    try {
    _serverCommEngine.dealWithWebSocket(message, conn);
    }
    on SocketException catch(ex){
      _logger.warning("Someting on the WebSocket went wrong", ex);
    }
  }
}
