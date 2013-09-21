library greenCode;

import 'dart:math';

class Direction {
  static const N = const Direction._(0,-1,0,0);
  static const E = const Direction._(1,0,0,1);
  static const S = const Direction._(0,1,0,2);
  static const W = const Direction._(-1,0,0,3);
  static const UP = const Direction._(0,0,-1,4);
  static const DOWN = const Direction._(0,0,1,5);
  static const NONE = const Direction._(0,0,0,6);
  static const SELF = const Direction._(0,0,0,7);
  
  static get values => [N,E,S,W,UP,DOWN,NONE,SELF];

  final int value;
  final int dirX;
  final int dirY;
  final int dirZ;

  const Direction._(this.dirX, this.dirY ,this.dirZ, this.value);
}

class GreenCodeContext {    
  List<GreenCode> code = new List<GreenCode>();
  
  int FaceHead = 0;
  int WriteHead = 0;
  int ReadHead = 0;
  int IP = 0;
  
  List<int> stack = new List<int>();
  
  Direction nextMove = Direction.NONE;
  Direction copyTo = Direction.NONE;
  Direction eatOn = Direction.NONE;
  
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
        GreenCode toAdd = GreenCode.factoriesName(e.group(1).trim());
        if(toAdd == null)
          throw new Exception("Unknown GreenCode Name: ${e.group(1)}");
      });
      return "Okay";
  }
  
  GreenCodeContext.byNames(String codeString){
    RegExp regExp = new RegExp("(.*?);",multiLine: true);
    regExp.allMatches(codeString).forEach((e){
      GreenCode toAdd = GreenCode.factoriesName(e.group(1).trim());
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
  
  String toStringNames(){
    String returner = "";
    code.forEach((element) => returner+=element.name + ";");
    return returner;
  }
  
  doGreenCode(){
    nextMove = Direction.NONE;
    copyTo = Direction.NONE;
    eatOn = Direction.NONE;    
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
                                      new GreenCodeEat(),
                                      new GreenCodeJumpF(),
                                      new GreenCodeJumpB(),
                                      new GreenCodeSearchF(),
                                      new GreenCodeSearchB(),
                                      new GreenCodePop(),
                                      new GreenCodePush(),
                                      new GreenCodeHead()];
  
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
  factoryDo(String hexNibble);
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
    {  if(context.registers[context.code[context.getAddresse(context.IP + 1)].register] == 0)
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
      hexCode = "0A";
  } 
    
  doOn(GreenCodeContext context){
    int arg;
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
      arg = context.registers[context.code[context.getAddresse(context.IP + 1)].register];
    else 
      arg = context.registers["BX"];
    context.eatOn = Direction.values.firstWhere((e) => e.value == arg % Direction.values.length);
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
      arg = context.registers[context.code[context.getAddresse(context.IP + 1)].register];
    else 
      arg = context.registers["BX"];
     context.nextMove = Direction.values.firstWhere((e) => e.value == arg % Direction.values.length);
     
  }
}

class GreenCodeCopy extends GreenCode {    
  GreenCodeCopy(){
      name = "copy";
      hexCode = "09";
  } 
    
  doOn(GreenCodeContext context){
    int arg;
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
      arg = context.registers[context.code[context.getAddresse(context.IP + 1)].register];
    else 
      arg = context.registers["BX"];
    context.copyTo = Direction.values.firstWhere((e) => e.value == arg % Direction.values.length);
  }
}


class GreenCodeIfNotEqu extends GreenCode {    
  GreenCodeIfNotEqu(){
      name = "if-n-equ";
      hexCode = "06";
  } 
    
  doOn(GreenCodeContext context){
    if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNop)
    {  if(context.registers[context.code[context.getAddresse(context.IP + 1)].register] 
      ==  context.registers[context.code[context.getAddresse(context.IP + 1)].compliment().register])
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
    {  if((context.registers[context.code[context.getAddresse(context.IP + 1)].register] & 1) != 1)
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
      context.stack.add(context.registers[context.code[context.getAddresse(context.IP + 1)].register]);
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
        context.registers[context.code[context.getAddresse(context.IP + 1)].register] = context.stack.removeLast();
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
      context.registers[context.code[context.getAddresse(context.IP + 1)].register]++;
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
          context.FaceHead = context.getAddresse(context.FaceHead+ context.registers["BX"]);
        }  
        else if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNopB)
          context.WriteHead = context.getAddresse(context.WriteHead+ context.registers["BX"]);
        else if(context.code[context.getAddresse(context.IP + 1)] is GreenCodeNopC)
          context.ReadHead = context.getAddresse(context.ReadHead+ context.registers["BX"]);
        }
      else
      {
        context.FaceHead = context.getAddresse(context.FaceHead+ context.registers["BX"]);
      }      
    }
  }
  