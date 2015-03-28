library comm;

import 'package:logging/logging.dart';
import 'package:logging_handlers/server_logging_handlers.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';
import 'package:http_server/http_server.dart' show VirtualDirectory;

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'cellsProtocolServer.dart';

final _logger = new Logger("cellsComm");

final String _ip = "127.0.0.1";
final int _portWS = 8086;
final int _portHTTP = 8087;

VirtualDirectory virDir;

ServerCommEngine _serverCommEngine;

startServerHTTP() async {
  HttpServer server = await HttpServer.bind(_ip, _portHTTP);
  _logger.info("HTTP WebServer Listening on ${_ip}:${_portHTTP}");
  await for (HttpRequest request in server) {
         virDir.serveRequest(request);
  }
}

main() {
  Logger.root.level = Level.INFO;
  var loggerStream = Logger.root.onRecord.asBroadcastStream();
  loggerStream.listen(new SyncFileLoggingHandler("saves/logging"));
  loggerStream.listen(new LogPrintHandler());

  _logger.info("Starting up Cells Communication Layer");

  File script = new File(Platform.script.toFilePath());

  
  virDir = new VirtualDirectory(script.parent.path + "/../cellsweb/build/web")
    ..allowDirectoryListing = true;

  startServerHTTP();

  _logger.info("WebSocket will be listening on ${_ip}:${_portWS}");

  runZoned(() {
    _serverCommEngine = new ServerCommEngine();

    try {
      HttpServer.bind(_ip, _portWS).then((HttpServer server) {
        try {
          server.listen((HttpRequest request) {
            if (request.uri.path == "/ws") {
              try {
                var sc = new StreamController();
                sc.stream
                    .transform(new WebSocketTransformer())
                    .listen(onWebSocketConn)
                    .onError(
                        (err) => _logger.warning("Error working on HTTP server: $err"));
                sc.add(request);
                sc.done.catchError(
                    (error) => _logger.warning("Known WebSocket Error"));
              } catch (ex) {
                _logger.warning("Error on WebSocket creation", ex);
              }
            } else if (request.uri.path == "/commands" &&
                request.method == 'POST') {
              Encoding.getByName("ASCII").decodeStream(request).then((t) {
                _logger.fine("Request POST: " + t);
                String reponse = _serverCommEngine.dealWithRestful(t);
                request.response.headers.set("Access-Control-Allow-Headers",
                    "Origin, X-Requested-With, Content-Type, Accept");
                request.response.headers.set(
                    "Access-Control-Allow-Origin", "*");
                request.response
                    .add(Encoding.getByName("ASCII").encoder.convert(reponse));
                request.response.close();
              });
              request.response.done.catchError(
                  (error) => _logger.warning("Known RESTFul Error"));
            } else if (request.uri.path == "/version") {
              request.response.write("ver.0.0.1");
              request.response.close();
            } else {
              try {
                _logger.warning("Uri WebSocket on Port ${_portWS} not found: ${request.uri.path}");
                request.response.headers.set("Access-Control-Allow-Headers",
                    "Origin, X-Requested-With, Content-Type, Accept");
                request.response.headers.set(
                    "Access-Control-Allow-Origin", "*");
                request.response.close();
              } catch (ex) {
                _logger.warning("Error WebSocket on Port ${_portWS} on response close", ex);
              }
            }
          }, onError: (err) {
            _logger.warning("Listen HttpServer WebSocket on Port ${_portWS} Stream Error!");
          });
        } catch (ex) {
          _logger.warning(
              "Something went wrong inside of HttpServer WebSocket on Port ${_portWS} binding!", ex);
        }
      }, onError: (err) {
        _logger.warning("Binding HttpServer for WebSocket on Port ${_portWS} Stream Error: $err");
      });
    } catch (ex) {
      _logger.warning("Binding HttpServer for WebSocket on Port ${_portWS} failed!", ex);
    }
  }, onError: (dynamic err) {
    try {
      _logger.shout("Zoned Error: $err");
    } catch (ex) {
      _logger.shout("Yaw Dog, Zoned Zoned Error");
    }
  });
}

onWebSocketConn(WebSocket conn) {
  conn.listen(new CellsWebSocketConnection(conn).onWebSocketMsg);
}

class CellsWebSocketConnection {
  WebSocket conn;
  CellsWebSocketConnection(this.conn);

  onWebSocketMsg(message) {
    try {
      _serverCommEngine.dealWithWebSocket(message, conn);
    } on SocketException catch (ex) {
      _logger.warning("Someting on the WebSocket went wrong", ex);
    }
  }
}
