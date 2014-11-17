import 'lib/greenCode.dart';
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';

var _logger = new Logger("greenCodeTester");

main(){
  startQuickLogging();
	var context = new GreenCodeContext.byNames("LOAD #5; ADD #3; STORE #17;");
  for(int i = 0; i < context.code.length; i++)
    context.operation();
	assert(context.registers[17] == 8);

	context = new GreenCodeContext.byNames("ADD #5; STORE #17;");
    for(int i = 0; i < context.code.length*3; i++)
      context.operation();
  assert(context.registers[17] == 15); 
    
  context = new GreenCodeContext.byRandom(10);
  for(int i = 0; i < 10*3; i++)
    context.operation();
  // assert(context.code.length == 10);
  // _logger.info(context.codeToStringNames());

  _logger.info("FINE!");
}