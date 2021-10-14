import 'package:example/rooms.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_test1/profile.dart';
// import 'package:firebase_test1/utils/api_fetch.dart';
// import 'package:firebase_test1/utils/authentication.dart';
// import 'package:firebase_test1/utils/global.dart';
// import 'package:firebase_test1/utils/provider_part.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_chat_core/flutter_firebase_chat_core.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:provider/src/provider.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:provider/provider.dart';

class Register extends StatefulWidget {
  const Register({Key? key}) : super(key: key);

  @override
  _RegisterState createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  @override
  Widget build(BuildContext context) {
    return context.watch<User?>() == null
        ? registerWidget()
        : const RoomsPage();
  }

  Widget registerWidget() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.only(top: 20, left: 24, right: 24),
          child: Form(
            key: _formkey,
            child: Column(
              children: [
                Wrap(
                  children: [
                    ElevatedButton(
                        onPressed: () {
                          _usernameController =
                              TextEditingController(text: 'what2004@gmail.com');
                          _signin();
                        },
                        child: const Text('what2004')),
                    ElevatedButton(
                        onPressed: () {
                          _usernameController =
                              TextEditingController(text: 'what2005@gmail.com');
                          _signin();
                        },
                        child: const Text('what2005')),
                    ElevatedButton(
                        onPressed: () {
                          _usernameController = TextEditingController(
                              text: 'what2006@yahoo.com.cn');
                          _signin();
                        },
                        child: const Text('what2006')),
                  ],
                ),
                SizedBox(
                  height: 20,
                ),
                TextFormField(
                  autocorrect: false,
                  autofillHints: _registering ? null : [AutofillHints.email],
                  autofocus: true,
                  controller: _usernameController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(8.0),
                      ),
                    ),
                    labelText: 'Email',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.cancel),
                      onPressed: () => _usernameController?.clear(),
                    ),
                  ),
                  validator: _validateEmail,
                  autovalidateMode: _autovalidate
                      ? AutovalidateMode.always
                      : AutovalidateMode.disabled,
                  keyboardType: TextInputType.emailAddress,
                  onEditingComplete: () {
                    _focusNode?.requestFocus();
                  },
                  readOnly: _registering,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next,
                  onSaved: (value) {
                    _message = null;
                  },
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: TextFormField(
                    obscureText: _obscuretext,
                    autocorrect: false,
                    autofillHints:
                        _registering ? null : [AutofillHints.password],
                    controller: _passwordController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(8.0),
                        ),
                      ),
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.remove_red_eye,
                          color: _obscuretext ? Colors.grey : Colors.blue,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscuretext = !_obscuretext;
                          });
                        },
                      ),
                    ),
                    focusNode: _focusNode,
                    keyboardType: TextInputType.emailAddress,
                    // obscureText: true,
                    onEditingComplete: _register,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.done,
                    validator: _validatePassword,
                    autovalidateMode: _autovalidate
                        ? AutovalidateMode.always
                        : AutovalidateMode.disabled,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: _registering ? null : _register,
                      child: const Text('Register'),
                    ),
                    TextButton(
                      onPressed: _registering ? null : _signin,
                      child: const Text('signin'),
                    ),
                  ],
                ),
                SizedBox(
                  height: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FocusNode? _focusNode;
  bool _registering = false;
  TextEditingController? _passwordController;
  TextEditingController? _usernameController;
  bool _autovalidate = false;
  bool _obscuretext = true;
  // String? _mobile;
  String? _message;
  final _formkey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController(text: '123123q');
    _usernameController = TextEditingController();
    // text: context.watch<SpProvider>().spp.getString('emaillastlogin'));
    _focusNode = FocusNode();
  }

  void _register() async {
    FocusScope.of(context).unfocus();

    _formkey.currentState!.save();
    if (_formkey.currentState!.validate()) {
      if (mounted) {
        setState(() {
          _registering = true;
        });
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('resgering...')));
      try {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _usernameController!.text,
          password: _passwordController!.text,
        );
        await credential.user!
            .updatePhotoURL('http://image.acomventure.com/HSAqrcode.png');
        await credential.user!
            .updateDisplayName(_usernameController!.text.split('@').first);
        await FirebaseChatCore.instance.createUserInFirestore(
          types.User(
            firstName: FirebaseAuth.instance.currentUser!.displayName,
            id: FirebaseAuth.instance.currentUser!.uid,
            imageUrl: FirebaseAuth.instance.currentUser!.photoURL,
            lastName: '',
            role: types.Role.user,
          ),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          if (mounted) {
            setState(() {
              _message = 'The password provided is too weak, please try angin！';
              _autovalidate = true;
              _registering = false;
            });
          }
          print('The password provided is too weak.');
        } else if (e.code == 'email-already-in-use') {
          if (mounted) {
            setState(() {
              _message =
                  'The account already exists for that email, please try angin！';
              _autovalidate = true;
              _registering = false;
            });
          }
          print('The account already exists for that email.');
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _message = 'Something wrong, please try angin！';
            _autovalidate = true;
            _registering = false;
          });
        }
        print(e.toString());
      }
    }
  }

  void _signin() async {
    FocusScope.of(context).unfocus();

    _formkey.currentState!.save();
    if (_formkey.currentState!.validate()) {
      if (mounted) {
        setState(() {
          _registering = true;
        });
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('login...')));
      try {
        final credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _usernameController!.text,
          password: _passwordController!.text,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          if (mounted) {
            setState(() {
              _message = 'No user found for that email, please try angin！';
              _autovalidate = true;
              _registering = false;
            });
          }
        } else if (e.code == 'wrong-password') {
          if (mounted) {
            setState(() {
              _message =
                  'Wrong password provided for that user, please try angin！';
              _autovalidate = true;
              _registering = false;
            });
          }
        }
      } catch (e) {
        print(e.toString());
        if (mounted) {
          setState(() {
            _message = 'Something wrong, please try angin！';
            _autovalidate = true;
            _registering = false;
          });
        }
      }
    }
  }

  String? _validateEmail(value) {
    var emailReg = RegExp(
        // r'^1((3[\d])|(4[75])|(5[^3|4])|(66)|(7[013678])|(8[\d])|(9[89]))\d{8}$');
        r'^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)+$');
    if (value.isEmpty) {
      return 'Please input Email!';
    } else if (!emailReg.hasMatch(value)) {
      return 'Please input correct Email !';
    }
    return _message;
  }

  String? _validatePassword(value) {
    // var passwordReg = RegExp(r'([0-9]+[a-zA-Z]+|[a-zA-Z]+[0-9]+)[0-9a-zA-Z]*');
    var passwordReg = RegExp(r'^(?![0-9]+$)(?![a-zA-Z]+$)[0-9A-Za-z]{6,16}$');
    if (value.isEmpty) {
      return 'Plese enter passwrod!';
    } else if (!passwordReg.hasMatch(value)) {
      return 'Please include alaphabet letters and numbers combianation!';
    }
    return null;
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    _passwordController?.dispose();
    _usernameController?.dispose();
    super.dispose();
  }
}
