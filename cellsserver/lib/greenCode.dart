library greenCode;

import 'dart:math';
import 'package:logging/logging.dart';
import 'cells.dart';
import 'dart:convert';

Logger _logger = new Logger("greenCode");

class Direction {
  static Direction N = new Direction._(0, -1, 0, 0, "N");
  static Direction E = new Direction._(1, 0, 0, 1, "E");
  static Direction S = new Direction._(0, 1, 0, 2, "S");
  static Direction W = new Direction._(-1, 0, 0, 3, "W");
  static Direction UP = new Direction._(0, 0, -1, 4, "UP");
  static Direction DOWN = new Direction._(0, 0, 1, 5, "DOWN");
  static Direction NONE = new Direction._(0, 0, 0, 6, "NONE");

  static get values => [N, E, S, W, UP, DOWN, NONE];

  bool isThis(int x, int y, int z) {
    return dirX == x && dirY == y && dirZ == z;
  }

  static Direction getThis(int x, int y, int z) {
    List<Direction> valuesList = new List.from(values);
    Iterable<Direction> it = valuesList.where((dir) => dir.isThis(x, y, z));
    if (it.length == 1) return it.first; else return null;
  }

  int value;
  int dirX;
  int dirY;
  int dirZ;
  String name;


  Direction() {
    dirX = 0;
    dirY = 0;
    dirZ = 0;
    name = "NONE";
  }

  Direction._(this.dirX, this.dirY, this.dirZ, this.value, this.name);
}


class GreenCodeContext {
  
  static const int MaxNumber = 4092;
  static const int OperationsPerCycle = 1;
  
  static const RegALU = 0;
  static const RegIP = 1;
  static const RegReadHead = 2;
  static const RegWriteHead = 3; 
  static const RegClock = 4;
  static const RegCodeLen = 5;
  static const RegEatingCount = 6;
  static const RegInject = 7;
  static const RegMove = 8;  
  
  static const RegColorOWN = 9;
  static const RegEnergyOWN = 10;
  static const RegColorDOWN = 11;
  static const RegColorN = 12;
  static const RegColorE = 13;
  static const RegColorS = 14;
  static const RegColorW = 15;
  static const RegColorUP = 16;

  static const RegEnergyDOWN = 17;
  static const RegEnergyN = 18;
  static const RegEnergyE = 19;
  static const RegEnergyS = 20;
  static const RegEnergyW = 21;
  static const RegEnergyUP = 22;
  
  List<GreenCode> code = new List<GreenCode>();

  bool assemblerError = false;

  Map<int, int> registers = new Map<int, int>();

  String registersToString(){
    Map<String, int> map = new Map<String, int>();
    registers.forEach((key, value) => map.putIfAbsent(key.toString(), () => value));
    return JSON.encode(map);
  }
  
  Direction nextMove(){
    return DirectionByRegister(registers[RegMove]);    
  }
  
  Direction injectTo(){
    return DirectionByRegister(registers[RegInject]);
  }

  Direction DirectionByRegister(reg) {    
    switch(reg % 7)
    { 
      case 1:
        return Direction.DOWN;
      case 2:
        return Direction.N;
      case 3:
        return Direction.E;
      case 4:
        return Direction.S;        
      case 6:
        return Direction.W;        
      case 7:
        return Direction.UP;      
      default:
        return Direction.NONE;
    }
  }
  
  int registersCount() {
    return 31;
  }
  
  int copyCost = 0;
  
  operation(){
    code.elementAt(registers[RegIP] % (code.length)).onContextCall(this);
    registers[RegIP] = (registers[RegIP] + 1) % code.length; 
  }
  
  preTick(World world, Position me, int x, int y, int z){
    registers[RegClock]+=1;
    registers[RegEatingCount] = 0;
    registers[RegInject] = 0;
    registers[RegMove] = 0; 
    registers[RegColorOWN] = ColorIndexAtPos(me);
    registers[RegEnergyOWN] = me.object.energy.energyCount.floor();

    var poses = world.getObjectsForCube(x, y, z, 2);
    poses.forEach((pos) {
       Direction dir = Direction.getThis(me.x - pos.x, me.y - pos.y, me.z - pos.z);
       if(dir == Direction.DOWN ){
         registers[RegEnergyDOWN] = EnergyAtPos(pos);
         registers[RegColorDOWN] = ColorIndexAtPos(pos);
       }
       if(dir == Direction.N ){
                registers[RegEnergyN] = EnergyAtPos(pos);
                registers[RegColorN] = ColorIndexAtPos(pos);
       }
       if(dir == Direction.E ){
                registers[RegEnergyE] = EnergyAtPos(pos);
                registers[RegColorE] = ColorIndexAtPos(pos);
       }
       if(dir == Direction.S ){
                       registers[RegEnergyS] = EnergyAtPos(pos);
                       registers[RegColorS] = ColorIndexAtPos(pos);
       }
       if(dir == Direction.W ){
                       registers[RegEnergyW] = EnergyAtPos(pos);
                       registers[RegColorW] = ColorIndexAtPos(pos);
       }
       if(dir == Direction.UP){
                       registers[RegEnergyUP] = EnergyAtPos(pos);
                       registers[RegColorUP] = ColorIndexAtPos(pos);
       }
      }
    );
  }
  
  int EnergyAtPos(Position pos){
    return pos.object.energy.energyCount.floor();
  }
  
  int ColorIndexAtPos(Position pos){
    return pos.object.getColor().ThisIs(Color.Green) ? 1 : pos.object.getColor().ThisIs(Color.Blue) ? 2 : pos.object.getColor().ThisIs(Color.Red) ? 3 : 0;
  }
  
  tick(){
    if (!assemblerError) {
      int i = OperationsPerCycle;
      while(i > 0){
            operation();
            i--;  
      }
    }
  }

  String codeToStringNames() {
    return code.map((e) => e.toString() + "\n").join();
  }
  
  String codeToStringNamesWithHeads(){
    int pos = 0; 
    return code.map((e) {
      String r = (pos == registers[RegIP] ? "<IP>\n" : "") 
    + (pos == registers[RegReadHead] ? "<RH>\n" : "") 
    + (pos == registers[RegWriteHead] ? "<WH>\n" : "") 
    + e.toString() + "\n"; 
      pos++;
      return r;}).join();
  }
  
  List<GreenCode> _codeRange(int from, int to) {
  if(code.length == 0) return  [] as List<GreenCode>;
    int _from = min(from % code.length, to % code.length);
    int _to = max(from % code.length, to % code.length);
    if(_to > 0)
      return code.getRange(_from, _to).toList();
  else
     return [] as List<GreenCode>;
  }

  _removeCodeRange(int from, int to){
    if(code.length == 0) return;
    int _from = min(from % code.length, to % code.length);
    int _to = max(from % code.length, to % code.length);   
    if(_to > 0)
      code.removeRange(_from, _to);
    else
      return;
  }
  
  int eat(){
    return registers[RegEatingCount];
  }

  List<GreenCode> codeRangeBetweenHeads(){
    return _codeRange(registers[RegReadHead], registers[RegWriteHead]);
  }
  
  removeCodeRangeBetweenHeads(){
    _removeCodeRange(registers[RegReadHead], registers[RegWriteHead]);
  }
  
  GreenCodeContext.byNames(String codeString) {
    createEmptyRegisters();
    if (!codeString.trim().endsWith(";")) assemblerError = true;
    if (codeString.trim()== "") return;
    RegExp regExp = new RegExp("(.+?) ([@#*]?)([0-9]+?);", multiLine: true);
    regExp.allMatches(codeString).forEach((e) {
      String name = e.group(1).trim();
      String flag = e.group(2).trim();
      int operand = int.parse(e.group(3).trim());
      try {
        code.add(GreenCode.byName(name, flag, operand));
      } on GreenCodeInvalidOperation catch (ex) {
        _logger.warning("Assemlber Error on ${e.group(0)}: ${ex}, ${ex.cause}");
        assemblerError = true;
      }
    });
    if (assemblerError) _logger.warning("Could not start Cell becouse of Errors!: $codeString");
  }

  void createEmptyRegisters() {
    for (int i = 0; i < registersCount(); i++) registers[i] = 0;
  }
  
  GreenCodeContext.byRandom(int count) {
    Random rnd = new Random();
    while (count > 0) {
      code.add(GreenCode.getRandomCode(rnd.nextInt(128)));
      count--;
    }
    createEmptyRegisters();
  }
}

class GreenCodeInvalidOperation implements Exception {
  String cause;
  GreenCodeInvalidOperation(this.cause);
}

abstract class GreenCode {
  String operandFlag;
  int operand;
  
  static List<String> possibleFlags = ["*", "#", "@"];

  String getName();

  String toString(){
    return getName()  + " " + operandFlag + operand.toString() + ";"; 
  }
  
  int valueOnContext(GreenCodeContext context) {
    switch (operandFlag) {
      case "#":
        return operand;
      case "@":
        return context.registers[operand % context.registersCount()];
      case "*":
        return context.registers[context.registers[operand % context.registersCount()] % context.registersCount()];
      default:
        throw new GreenCodeInvalidOperation("Invalid Operand on Operation call: SOULD NEVER HAPPEN!");
    }
  }

  onContextCall(GreenCodeContext context){
    onContextDo(context);
    context.registers[GreenCodeContext.RegALU] %= GreenCodeContext.MaxNumber;
  }
  
  onContextDo(GreenCodeContext context);

  GreenCode.byValues(String operandFlag, int operand) {
    setValues(operandFlag, operand);
  }

  setValues(String operandFlag, int operand) {
    if (!possibleFlags.contains(operandFlag)) throw new GreenCodeInvalidOperation("Illiagel Operand Flag");
    this.operandFlag = operandFlag;
    this.operand = operand;
  }

  static GreenCode getRandomCode(int operand){
    int codesLength = 10;
    var rnd = new Random();
    String operandFlag = possibleFlags.elementAt(rnd.nextInt(possibleFlags.length));
    switch(rnd.nextInt(codesLength))
    {
      case 0:
        return new GreenCodeLoad(operandFlag, operand);
      case 1:
        return new GreenCodeStore(operandFlag, operand);
      case 2:
        return new GreenCodeAdd(operandFlag, operand);
      case 3:
        return new GreenCodeSub(operandFlag, operand);
      case 4:
        return new GreenCodeDiv(operandFlag, operand);
      case 5:
        return new GreenCodeMult(operandFlag, operand);
      case 6:        
        return new GreenCodeGet(operandFlag, operand);
      case 7:
        return new GreenCodeJzero(operandFlag, operand);
      case 8:
        return new GreenCodeCopy(operandFlag, operand);
      case 9:
        return new GreenCodeLabel(operandFlag, operand);
    }
    throw new GreenCodeInvalidOperation("Random Error: SHOULD NEVER HAPPEN!");
  }
  
  static GreenCode byName(String name, String operandFlag, int operand) {
    GreenCode r = null;
    if (GreenCodeLoad.me.getName() == name) r = new GreenCodeLoad(operandFlag, operand);
    if (GreenCodeStore.me.getName() == name) r = new GreenCodeStore(operandFlag, operand);
    if (GreenCodeAdd.me.getName() == name) r = new GreenCodeAdd(operandFlag, operand);
    if (GreenCodeSub.me.getName() == name) r = new GreenCodeSub(operandFlag, operand);
    if (GreenCodeDiv.me.getName() == name) r = new GreenCodeDiv(operandFlag, operand);
    if (GreenCodeMult.me.getName() == name) r = new GreenCodeMult(operandFlag, operand);
    if (GreenCodeGet.me.getName() == name) r = new GreenCodeGet(operandFlag, operand);
    if (GreenCodeJzero.me.getName() == name) r = new GreenCodeJzero(operandFlag, operand);
    if (GreenCodeCopy.me.getName() == name) r = new GreenCodeCopy(operandFlag, operand);   
    if (GreenCodeLabel.me.getName() == name) r = new GreenCodeLabel(operandFlag, operand);   
    if (r == null) throw new GreenCodeInvalidOperation("Illiagel OperandName");
    return r;
  }
}

class GreenCodeLoad extends GreenCode {
  static GreenCodeLoad me = new GreenCodeLoad("#", 0);

  GreenCodeLoad(String operandFlag, int operand) : super.byValues(operandFlag, operand);

  String getName() {
    return "LOAD";
  }

  onContextDo(GreenCodeContext context) {
    context.registers[GreenCodeContext.RegALU] = valueOnContext(context);
  }
}

class GreenCodeStore extends GreenCode {
  static GreenCodeStore me = new GreenCodeStore("#", 0);

  GreenCodeStore(String operandFlag, int operand) : super.byValues(operandFlag, operand);

  String getName() {
    return "STORE";
  }
  
  onContextDo(GreenCodeContext context) {
    context.registers[(valueOnContext(context) % context.registersCount())] = context.registers[GreenCodeContext.RegALU];
  }
}

class GreenCodeAdd extends GreenCode {
  static GreenCodeAdd me = new GreenCodeAdd("#", 0);

  GreenCodeAdd(String operandFlag, int operand) : super.byValues(operandFlag, operand);

  String getName() {
    return "ADD";
  }

  onContextDo(GreenCodeContext context) {
    context.registers[GreenCodeContext.RegALU] += valueOnContext(context);
  }
}

class GreenCodeSub extends GreenCode {
  static GreenCodeSub me = new GreenCodeSub("#", 0);

  GreenCodeSub(String operandFlag, int operand) : super.byValues(operandFlag, operand);

  String getName() {
    return "SUB";
  }

  onContextDo(GreenCodeContext context) {
    context.registers[GreenCodeContext.RegALU] -= valueOnContext(context);
    context.registers[GreenCodeContext.RegALU] = max(context.registers[GreenCodeContext.RegALU], 0);
  }
}

class GreenCodeDiv extends GreenCode {
  static GreenCodeDiv me = new GreenCodeDiv("#", 0);

  GreenCodeDiv(String operandFlag, int operand) : super.byValues(operandFlag, operand);

  String getName() {
    return "DIV";
  }

  onContextDo(GreenCodeContext context) {
    if(valueOnContext(context) != 0)
    context.registers[GreenCodeContext.RegALU] =  (context.registers[GreenCodeContext.RegALU] / valueOnContext(context)).floor(); 
  }
}

class GreenCodeMult extends GreenCode {
  static GreenCodeMult me = new GreenCodeMult("#", 0);

  GreenCodeMult(String operandFlag, int operand) : super.byValues(operandFlag, operand);

  String getName() {
    return "MULT";
  }

  onContextDo(GreenCodeContext context) {
    if(valueOnContext(context) != 0)
    context.registers[GreenCodeContext.RegALU] = context.registers[GreenCodeContext.RegALU] * valueOnContext(context); 
  }
}

class GreenCodeGet extends GreenCode {
  static GreenCodeGet me = new GreenCodeGet ("#", 0);

  GreenCodeGet(String operandFlag, int operand) : super.byValues(operandFlag, operand);

  String getName() {
    return "GET";
  }

  onContextDo(GreenCodeContext context) {
    int start = context.registers[GreenCodeContext.RegIP] % context.code.length;
    int i = start;
    do{
      GreenCode code = context.code[i];
      if(code is GreenCodeLabel)
      {
        if(code.valueOnContext(context) == valueOnContext(context))
        {   
          break;
        }
      }
      i++;
      i%=context.code.length;
    }
    while(i != start);
    context.registers[GreenCodeContext.RegReadHead] = i; 
  }
}

class GreenCodeLabel extends GreenCode {
  static GreenCodeLabel me = new GreenCodeLabel ("#", 0);

  GreenCodeLabel(String operandFlag, int operand) : super.byValues(operandFlag, operand);

  String getName() {
    return "LABEL";
  }

  onContextDo(GreenCodeContext context) {    
  }
}

class GreenCodeJzero extends GreenCode {
  static GreenCodeJzero me = new GreenCodeJzero ("#", 0);

  GreenCodeJzero(String operandFlag, int operand) : super.byValues(operandFlag, operand);

  String getName() {
    return "JZERO";
  }

  onContextDo(GreenCodeContext context) {
    if(context.registers[GreenCodeContext.RegALU] == 0)
      context.registers[GreenCodeContext.RegIP] = context.registers[GreenCodeContext.RegIP] + valueOnContext(context) % context.code.length; 
  }
}

class GreenCodeCopy extends GreenCode {
  static GreenCodeCopy me = new GreenCodeCopy ("#", 0);

  GreenCodeCopy(String operandFlag, int operand) : super.byValues(operandFlag, operand);

  String getName() {
    return "COPY";
  }

  onContextDo(GreenCodeContext context) {
    List<GreenCode> list = context.codeRangeBetweenHeads();
    if(list.length == 0)
      return;
    var rnd = new Random();
    if(rnd.nextInt(10000)<1){
      int pos = rnd.nextInt(list.length);
      list.replaceRange(pos, pos, [GreenCode.getRandomCode(rnd.nextInt(GreenCodeContext.MaxNumber))]);
    }
    context.code.insertAll(valueOnContext(context) % context.code.length, list);
    context.copyCost = list.length;
  }
}