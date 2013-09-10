library auth;


import 'cellsProtocolServer.dart';
import 'package:bignum/bignum.dart';

class AuthContext {
  String username;
  BigInteger pubKey;
  
  AuthContext(this.username, this.pubKey);
}


class AuthEngine {
  Map<RestfulCommand, List<AuthBasic>> commandAuths = new Map<RestfulCommand, List<AuthBasic>>();
  
  addAuth(RestfulCommand command, AuthBasic auth){
    if(commandAuths.containsKey(command))
      commandAuths[command].add(auth);
    else
      commandAuths.putIfAbsent(command, () => new List<AuthBasic>.from([auth]));
  }
}

class AuthBasic {
  String name;
}

class AllAccess extends AuthBasic  {
  AllAcces(){
    name = "*";
  }
}

class AuthUser extends AuthBasic{
  String name;
  BigInteger pubKey;
}
