library greenCode;

import 'dart:math';
import 'package:logging/logging.dart';

Logger _logger = new Logger("greenCode");

class Direction {
  static Direction N = new Direction._(0,-1,0,0, "N");
  static Direction E = new Direction._(1,0,0,1, "E");
  static Direction S = new Direction._(0,1,0,2, "S");
  static Direction W = new Direction._(-1,0,0,3, "W");
  static Direction UP = new Direction._(0,0,-1,4, "UP");
  static Direction DOWN = new Direction._(0,0,1,5, "DOWN");
  static Direction NONE = new Direction._(0,0,0,6, "NONE");
  
  static get values => [N,E,S,W,UP,DOWN,NONE];

  bool isThis(int x, int y, int z){
    return dirX == x && dirY == y && dirZ == z;
  }
  
  static Direction getThis(int x, int y, int z){
    List<Direction> valuesList = new List.from(values);
    Iterable<Direction> it =valuesList.where((dir) => dir.isThis(x, y, z));
    if(it.length == 1)
      return it.first;
    else
      return null;
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
  
  Direction._(this.dirX, this.dirY ,this.dirZ, this.value, this.name);
}

class GreenCodeContext {    
  List<GreenCode> code = new List<GreenCode>();
  
  modulateHeads(){
    ReadHead %=  code.length;
    WriteHead %= code.length;
    FaceHead %= code.length;
  }
  
  int FaceHead = 0;
  int WriteHead = 0;
  int ReadHead = 0;
  int IP = 0;
  int copyCost = 0;
  
  
  List<int> stack = new List<int>();
  
  Direction nextMove = Direction.NONE;
  Direction injectTo = Direction.NONE;
  Direction eatOn = Direction.NONE;
  bool eat = false;
  bool inject = false;
  
  Map<String, int> registers = {"AX": 0, "BX" : 0, "CX":0};
    
  
  int getFaceHead(){
    return FaceHead % code.length;
  }
  int getAddresse(int addresse){
    if(code.length == 0)
      return 0;
    else
      return addresse % code.length;
  }
  
  selfCopy(){
    
  }
  
  static String syntaxCheckNames(String codeString){
      RegExp regExp = new RegExp("(.*?);",multiLine: true);
      regExp.allMatches(codeString).forEach((e){
        if( e.group(1).trim() == "<IP>"  || e.group(1).trim() == "<RH>" ||  e.group(1).trim() == "<WH>"  ||  e.group(1).trim() == "<FH>")
          return;
        GreenCode toAdd = GreenCode.factoriesName(e.group(1).trim());
        if(toAdd == null)
          throw new Exception("Unknown GreenCode Name: ${e.group(1)}");
      });
      return "Okay";
  }
  
  static List<GreenCode> stringToCode(String input){
    RegExp regExp = new RegExp("(.*?);",multiLine: true);
    List<GreenCode> returner = new List<GreenCode>();
    regExp.allMatches(input).forEach((e){
      if( e.group(1).trim() == "<IP>"  || e.group(1).trim() == "<RH>" ||  e.group(1).trim() == "<WH>"  ||  e.group(1).trim() == "<FH>")
        return;
      GreenCode toAdd = GreenCode.factoriesName(e.group(1).trim());
      if(toAdd == null)
        throw new Exception("Unknown GreenCode Name: ${e.group(1)}");
      returner.add(toAdd);
    });
    return returner;
  }
  
  GreenCodeContext.byNames(String codeString){
    RegExp regExp = new RegExp("(.*?);",multiLine: true);
    int i = 0;
    regExp.allMatches(codeString).forEach((e){      
      String codeToken = e.group(1).trim();
      if (codeToken == "<RH>")
      {
        ReadHead = i;
        return;
      }
      else if(codeToken == "<FH>"){
        FaceHead = i;
        return;
      }
      else if(codeToken == "<WH>")
      {
        WriteHead = i;
        return;
      }
      else if(codeToken == "<IP>")
      {
        IP = i;
        return;
      }
      GreenCode toAdd = GreenCode.factoriesName(codeToken);
      i++;
      if(toAdd != null)
        code.add(toAdd);
      else
       throw new Exception("Unknown GreenCode Name: ${e.group(1)}");
    });   
    }
  
  GreenCodeContext.byHex(String codeString){
    if(codeString.length % 2 != 0)
      throw new Exception("GreenCodeContext code not even");
    if(codeString.length == 0)
      return;
    for(int pos = 0; pos < codeString.length; pos+=2){
      String nibbleHigh = codeString[pos];
      String nibbleLow = codeString[pos+1];
      GreenCode codeElement = GreenCode.factoriesHexBytes("$nibbleHigh$nibbleLow");
      if(codeElement != null)
        code.add(codeElement);
      else
        throw new Exception("Unknown GreenCode Hex");
    }      
  }

  GreenCodeContext.byRandom(int count){
    Random rnd = new Random();
    while(count > 0){
      code.add(GreenCode.factories[rnd.nextInt(GreenCode.factories.length -1)]);
      count--;
    }
  }
  
  int removeCodeFromTo(int from, int to){
    while(to != from && code.length != 0){
      code.removeAt(from);
      from--;
      if(from < to)
        to--;
      if(from <= 0)
        from = code.length - 1;
    }
  }
  
  String codeToStringNames(){
    return codeToStringNamesRange(0, code.length, true);
  }
  
  String codeToStringNamesRange(int from, int to, bool withHeads){
    String returner = "";
    int i = 0;
    code.forEach((element){
      if(i < from || i > to)
        return;
      if(i == ReadHead && withHeads)
        returner += "<RH>;" + "\n";
      if(i == FaceHead && withHeads)
        returner += "<FH>;" + "\n";
      if(i == WriteHead && withHeads)
        returner += "<WH>;" + "\n"; 
      if(i == IP && withHeads)
        returner += "<IP>;" + "\n";
      returner+=element.name + ";\n";
      i++;
    });
    if(i == ReadHead && withHeads)
      returner += "<RH>;" + "\n";
    if(i == FaceHead && withHeads)
      returner += "<FH>;" + "\n";
    if(i == WriteHead && withHeads)
      returner += "<WH>;" + "\n";      
    if(i == IP && withHeads)
      returner += "<IP>;" + "\n";
    return returner;
  }
  
  doGreenCode(){
    nextMove = Direction.NONE;
    injectTo = Direction.NONE;
    inject = false;
    eatOn = Direction.NONE;
    eat = false;    
    if(code.length != 0){
      IP = IP % code.length;
      code[IP].doOn(this);
      IP = getAddresse(++IP);
    }
}
}

abstract class GreenCode {
  String hexCode;
  String name;

  static List<GreenCode> factories = [new GreenCodeNopA(), 
                                      new GreenCodeNopB(),
                                      new GreenCodeNopC(), 
                                      new GreenCodeIfNot0(), 
                                      new GreenCodeMove(),
                                      new GreenCodeIfNotEqu(),
                                      new GreenCodeIfBit1(),
                                      new GreenCodeInc(),
                                      new GreenCodeCopy(),
                                      new GreenCodeInject(),
                                      new GreenCodeEat(),
                                      new GreenCodeJumpF(),
                                      new GreenCodeJumpB(),
                                      new GreenCodeSearchF(),
                                      new GreenCodeSearchB(),
                                      new GreenCodePop(),
                                      new GreenCodePush(),
                                      new GreenCodeHead(),
                                      new GreenCodeEatDir()];
  
  static GreenCode factoriesHexBytes(String hexByte){
    var returner = factories.where((e){ 
      return e.factoryByHex(hexByte) != null;
    });
    if(returner.length == 0)
    return null;
      else
    return returner.first; 
  }
  
  static GreenCode factoriesName(String name){
    var returner = factories.where((e){ 
      return e.factoryByName(name) != null;
    });
    if(returner.length == 0)
    return null;
      else
    return returner.first; 
  }
  
  GreenCode factoryByName(String name){
    if(name == this.name)   
      return this;
    else return null;
    
  }
  
  GreenCode factoryByHex(String hexByte){
    if(hexByte.length > 2)
      throw new Exception("GreenCode Construction Failed: To Long hexByte");
    if(hexCode == hexByte)   
      return this;
    else return null;
  }
  doOn(GreenCodeContext context);
}

abstract class GreenCodeNop extends GreenCode {
  String register;
  GreenCodeNop compliment();
}

class GreenCodeNopA extends GreenCodeNop{    
  GreenCodeNopA(){
      name = "nop-A";
      hexCode = "01";
      register = "AX";
  } 
  compliment(){
    return new GreenCodeNopB();
   }

  doOn(GreenCodeContext context){}
}

class GreenCodeNopB extends GreenCodeNop {    
  GreenCodeNopB(){
      name = "nop-B";
      hexCode = "02";
      register = "BX";
   } 
  compliment(){
    return new GreenCodeNopC();
  }
  
  doOn(GreenCodeContext context){}
}


class GreenCodeNopC extends GreenCodeNop {    
  GreenCodeNopC(){
      name = "nop-C";
      hexCode = "03";
      register = "CX";
      }
  compliment(){ return new GreenCodeNopA(); 
} 
  
  doOn(GreenCodeContext context){}
}

class GreenCodeIfNot0 extends GreenCode {    
  GreenCodeIfNot0(){
      name = "if-not-0";
      hexCode = "04";
  } 
    
  doOn(GreenCodeContext context){
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
    {  if(context.registers[(context.code[context.getAddresse(context.IP + 1)] as GreenCodeNop).register] == 0)
        context.IP = context.getAddresse(context.IP + 2);
      else
        context.IP = context.getAddresse(context.IP + 2);
    }
    else if(context.registers["BX"] == 0)
      context.IP = context.getAddresse(context.IP + 1);
  }
}

class GreenCodeEat extends GreenCode {    
  GreenCodeEat(){
      name = "eat";
      hexCode = "2A";
  } 
    
  doOn(GreenCodeContext context){
    context.eat = true;
  }
}


class GreenCodeEatDir extends GreenCode {    
  GreenCodeEatDir(){
      name = "eatD";
      hexCode = "0A";
  } 
    
  doOn(GreenCodeContext context){
    int arg;
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
      arg = context.registers[(context.code[context.getAddresse(context.IP + 1)] as GreenCodeNop).register];
    else 
      arg = context.registers["BX"];
    context.eatOn = Direction.values.firstWhere((e) => e.value == arg % Direction.values.length);
    context.eat = true;
  }
}


class GreenCodeMove extends GreenCode {    
  GreenCodeMove(){
      name = "move";
      hexCode = "05";
  } 
    
  doOn(GreenCodeContext context){
    int arg;
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
      arg = context.registers[(context.code[context.getAddresse(context.IP + 1)] as GreenCodeNop).register];
    else 
      arg = context.registers["BX"];
     context.nextMove = Direction.values.firstWhere((e) => e.value == arg % Direction.values.length);
     
  }
}


class GreenCodeCopy extends GreenCode {    
  GreenCodeCopy(){
      name = "copy";
      hexCode = "C9";
  } 
    
  doOn(GreenCodeContext context){    
    context.modulateHeads();
    int momReadHead = context.ReadHead;
    int costCounter = context.FaceHead - context.ReadHead;
    if(costCounter < 0)
      costCounter = context.code.length + costCounter;
    int iCounter = 0;
    while(iCounter < costCounter)
    {         
         GreenCode toWrite;
         // Mutationsfaktor
         Random rnd = new Random();         
         if(rnd.nextInt(100) == 17)
         {
           toWrite = GreenCode.factories[rnd.nextInt(GreenCode.factories.length)];
         }
         else
           toWrite = context.code[momReadHead];
         context.code.insert(context.WriteHead, toWrite);
         context.WriteHead++;
         if(context.WriteHead < context.IP)
           context.IP++;   
         iCounter++;;
         momReadHead++;
         momReadHead %= context.code.length;
    }
    context.copyCost+=costCounter;
    context.modulateHeads();
  }
}

class GreenCodeInject extends GreenCode {    
  GreenCodeInject(){
      name = "inject";
      hexCode = "09";
  } 
    
  doOn(GreenCodeContext context){
    int arg;
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
      arg = context.registers[(context.code[context.getAddresse(context.IP + 1)] as GreenCodeNop).register];
    else 
      arg = context.registers["BX"];
    context.injectTo = Direction.values.firstWhere((e) => e.value == arg % Direction.values.length);
    context.inject = true;
  }
}


class GreenCodeIfNotEqu extends GreenCode {    
  GreenCodeIfNotEqu(){
      name = "if-n-equ";
      hexCode = "06";
  } 
    
  doOn(GreenCodeContext context){
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
    {  if(context.registers[(context.code[context.getAddresse(context.IP + 1)] as GreenCodeNop).register] 
      ==  context.registers[(context.code[context.getAddresse(context.IP + 1)] as GreenCodeNop).compliment().register])
        context.IP = context.getAddresse(context.IP + 2);
    else
      context.IP = context.getAddresse(context.IP + 1);
    }
    else if(context.registers["BX"] == context.registers["CX"])
      context.IP = context.getAddresse(context.IP + 1);
  }
}


class GreenCodeIfBit1 extends GreenCode {    
  GreenCodeIfBit1(){
      name = "if-bit-1";
      hexCode = "07";
  } 
    
  doOn(GreenCodeContext context){
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
    {  if((context.registers[(context.code[context.getAddresse(context.IP + 1)] as GreenCodeNop).register] & 1) != 1)
        context.IP = context.getAddresse(context.IP + 2);
      else
        context.IP = context.getAddresse(context.IP + 1);
    }
    else if((context.registers["BX"] & 1) != 1)
      context.IP = context.getAddresse(context.IP + 1);
  }
}

class GreenCodeJumpF extends GreenCode {    
  GreenCodeJumpF(){
      name = "jump-f";
      hexCode = "0B";
  } 
    
  doOn(GreenCodeContext context){
    List<GreenCodeNop> nops = new  List<GreenCodeNop>();
    int i = 1;
    while(context.code[context.getAddresse(context.IP + i)] is GreenCodeNop){
      nops.add(context.code[context.getAddresse(context.IP + i)]);
      i++;
    }    
    if(nops.length == 0)
    {
      context.IP = context.getAddresse(context.IP + context.registers["BX"]);
    }
    else
    {      
      int z = context.getAddresse(context.IP + nops.length + 1);
      int startPoint = context.IP;
      int matched = 0;
      while(true){
        if(context.code[context.getAddresse(z)] is GreenCodeNop)
        {
          if(context.code[context.getAddresse(z)].hexCode == nops[matched].compliment().hexCode)
            matched++;
        }
        else
          matched = 0;
        if(matched == nops.length)
        {
          context.IP = z;
          break;
         }
        z = context.getAddresse(++z);
        if(z == startPoint)
          break;        
      }
    }
  }
}

class GreenCodeJumpB extends GreenCode {    
  GreenCodeJumpB(){
      name = "jump-b";
      hexCode = "0C";
  } 
    
  doOn(GreenCodeContext context){
    List<GreenCodeNop> nops = new  List<GreenCodeNop>();
    int i = 1;
    while(context.code[context.getAddresse(context.IP + i)] is GreenCodeNop){
      nops.add(context.code[context.getAddresse(context.IP + i)]);
      i++;
    }    
    if(nops.length == 0)
    {
      context.IP = context.getAddresse(context.IP - context.registers["BX"]);
    }
    else
    {
      nops = nops.reversed.toList();
      int z = context.IP;
      int startPoint = context.IP;
      int matched = 0;
      while(true){
        if(context.code[context.getAddresse(z)] is GreenCodeNop)
        {
          if(context.code[context.getAddresse(z)].hexCode == nops[matched].compliment().hexCode)
            matched++;
        }
        else
          matched = 0;
        if(matched == nops.length)
        {
          context.IP = z + matched -1;
          break;
         }
        z = context.getAddresse(--z);
        if(z == startPoint)
          break;        
      }
    }
  }
}

class GreenCodeSearchF extends GreenCode {    
  GreenCodeSearchF(){
      name = "search-f";
      hexCode = "0D";
  } 
  
  doOn(GreenCodeContext context){
    int buffIP = context.IP;
      new GreenCodeJumpF().doOn(context);
    context.registers["BX"] = context.IP - buffIP;
    context.IP = buffIP;
  }
}

class GreenCodeSearchB extends GreenCode {    
  GreenCodeSearchB(){
      name = "search-b";
      hexCode = "0E";
  } 
    
  doOn(GreenCodeContext context){
    int buffIP = context.IP;
      new GreenCodeJumpB().doOn(context);
    context.registers["BX"] = context.IP - buffIP;
    context.IP = buffIP;
  }
}

class GreenCodePush extends GreenCode {    
  GreenCodePush(){
      name = "push";
      hexCode = "0F";
  } 
    
  doOn(GreenCodeContext context){
    int arg;
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
      context.stack.add(context.registers[(context.code[context.getAddresse(context.IP + 1)] as GreenCodeNop).register]);
    else 
      context.stack.add(context.registers["BX"]);
  }
}

class GreenCodePop extends GreenCode {    
  GreenCodePop(){
      name = "pop";
      hexCode = "11";
  } 
    
  doOn(GreenCodeContext context){
    int arg;
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
      if(context.stack.length > 0)
        context.registers[(context.code[context.getAddresse(context.IP + 1)] as GreenCodeNop).register] = context.stack.removeLast();
    else 
    {
      if(context.stack.length > 0)
        context.registers["BX"] =context.stack.removeLast();
    }
   }
}

class GreenCodeInc extends GreenCode {
  GreenCodeInc(){
      name = "inc";
      hexCode = "10";
  }
  doOn(GreenCodeContext context){
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
      context.registers[(context.code[context.getAddresse(context.IP + 1)] as GreenCodeNop).register ]++;
    else 
      context.registers["BX"]++;
  }
}

  class GreenCodeHead extends GreenCode {
    GreenCodeHead(){
      name= "head";
      hexCode = "13";
    }

    doOn(GreenCodeContext context){
      if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop){
        if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNopA)
        {
          context.FaceHead = context.getAddresse(context.FaceHead+ context.registers["BX"]) % context.code.length;
        }  
        else if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNopB)
          context.WriteHead = context.getAddresse(context.WriteHead+ context.registers["BX"]) % context.code.length;
        else if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNopC)
          context.ReadHead = context.getAddresse(context.ReadHead+ context.registers["BX"]) % context.code.length;
        }
      else
      {
        context.FaceHead = context.getAddresse(context.FaceHead+ context.registers["BX"]);
      }      
    }
  }
  