library auth;

import 'cellsProtocolServer.dart';
import 'package:bignum/bignum.dart';
import 'dart:io';
import 'dart:convert';

class AuthContext {
  String username;
  BigInteger pubKey;
	bool isActive;
	AuthEngine engine;

  AuthContext(this.username, this.pubKey, this.engine);

  bool isValid(){
  	return engine.auths.where((u) => u.name == username).where((u) => u.isMyPubKey(pubKey)).length == 1;
  }

  doActive(){
  	isActive = true;
  	(engine.auths.where((u) => u.name == username && u is AuthUser). first as AuthUser).activeContext = this;
  }

  deActive(){
  	(engine.auths.where((u) => u.name == username && u is AuthUser). first as AuthUser).lastLogin = new DateTime.now();
    	engine.writeUsers();
    isActive = false;
   (engine.auths.where((u) => u.name == username && u is AuthUser). first as AuthUser).activeContext = null;
  }
}

class AuthEngine {
	static const int STARTENERGY = 1000;
  Map<RestfulCommand, List<AuthBasic>> commandAuths = new Map<RestfulCommand, List<AuthBasic>>();

  List<AuthBasic> auths = new List<AuthBasic>();
	List<BigInteger> createTokens = new List<BigInteger>();

	AuthEngine(){
		readTokenList();
		readUsers();
	}

	readUsers(){
		File usersFile = new File("saves/users");
		 if(usersFile.existsSync())
 		 {
 			 usersFile.openRead();
 			 usersFile.readAsLinesSync().forEach((line) =>  readUser(line));
 		 }
	}

	writeUsers(){
		File usersFile = new File("saves/users");
     		if(usersFile.existsSync())
     		{
     			usersFile.deleteSync();
     		}
   			usersFile.createSync();
				var totalString = "";
  			auths.where((a) => a is AuthUser).forEach((user) => totalString += user.toString() + "\n");
  			usersFile.writeAsStringSync(totalString);
	}

	readTokenList(){
		 File tokenFile = new File("saves/createTokens");
		 if(tokenFile.existsSync())
		 {
			 tokenFile.openRead();
			 tokenFile.readAsLinesSync().forEach((line) {
				 if(line != "") createTokens.add(new BigInteger(line, 16));
			 });
		 }
	}

	writeTokenList(){
			File tokenFile = new File("saves/createTokens");
   		if(tokenFile.existsSync())
   		{
   			tokenFile.deleteSync();
				tokenFile.createSync();
				var totalString = "";
				createTokens.forEach((t) => totalString += t.toRadix(16) + "\n");
				tokenFile.writeAsStringSync(totalString);
   		}
	}

	readUser(String jsonLine){
		auths.add(new AuthUser.fromJSON(jsonLine));
	}

  createUser(String username, BigInteger pubKey, BigInteger token){
  	readTokenList();
  	if(!createTokens.contains(token))
  		throw new Exception("Invalid Create Token");
  	if(auths.where((a) => a.name == username).length > 0)
  		throw new Exception("Username allready in Collection");
  	else {
  		if(pubKey != null){

	  		auths.add(new AuthUser.newUser(username, pubKey));
	  		createTokens.removeWhere((t) =>  t == token);
	  		writeUsers();
	  		writeTokenList();
  		}
  		else
  			throw new Exception("Username has no PubKey set");
  	}
  }
}

abstract class AuthBasic {
  String name;

  AuthBasic();

  AuthBasic.withName(this.name);

  bool isMyPubKey(BigInteger pubKey);
}

class AllAccess extends AuthBasic  {
  AllAcces(){
    name = "*";
  }

  bool isMyPubKey(BigInteger pubKey) => false;
}

class AuthUser extends AuthBasic{

	AuthContext activeContext;

	bool isMyPubKey(BigInteger pubKey) => pubKey.equals(this.pubKey);

	AuthUser.newUser(String name, this.pubKey): super.withName(name){
		lastLogin = new DateTime.fromMillisecondsSinceEpoch(0);
		energyPocket = AuthEngine.STARTENERGY;
	}

	AuthUser.fromJSON(String jsonString){
		Map json = JSON.decode(jsonString);
		name = json["username"];
		pubKey = new BigInteger(json["pubkey"], 16);
		energyPocket = json["energypocket"];
		lastLogin = DateTime.parse(json["lastlogin"]);
	}

	String toString(){
		Map json = new Map();
		json["username"] = name;
		json["pubkey"] = pubKey.toRadix(16);
		json["energypocket"] = energyPocket;
		json["lastlogin"] = lastLogin.toString();
		return JSON.encode(json);
	}

  BigInteger pubKey;
  int energyPocket;
  DateTime lastLogin;
}
