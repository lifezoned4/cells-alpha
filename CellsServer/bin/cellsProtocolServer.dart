library cellsProtocolServer;
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';

final _logger = new Logger("cellsProtocolServer");

class ServerCommEngine {
  dealWith(String message){
    _logger.info(message);
  }
}