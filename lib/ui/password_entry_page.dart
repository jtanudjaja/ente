import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:password_strength/password_strength.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/account_configured_event.dart';
import 'package:photos/events/subscription_purchased_event.dart';
import 'package:photos/services/user_service.dart';
import 'package:photos/ui/common/dynamicFAB.dart';
import 'package:photos/ui/payment/subscription.dart';
import 'package:photos/ui/recovery_key_page.dart';
import 'package:photos/ui/web_page.dart';
import 'package:photos/utils/dialog_util.dart';
import 'package:photos/utils/navigation_util.dart';
import 'package:photos/utils/toast_util.dart';

enum PasswordEntryMode {
  set,
  update,
  reset,
}

class PasswordEntryPage extends StatefulWidget {
  final PasswordEntryMode mode;

  PasswordEntryPage({this.mode = PasswordEntryMode.set, Key key})
      : super(key: key);

  @override
  _PasswordEntryPageState createState() => _PasswordEntryPageState();
}

class _PasswordEntryPageState extends State<PasswordEntryPage> {
  static const kMildPasswordStrengthThreshold = 0.4;
  static const kStrongPasswordStrengthThreshold = 0.7;

  final _logger = Logger((_PasswordEntryPageState).toString());
  final _passwordController1 = TextEditingController(),
      _passwordController2 = TextEditingController();
  final Color _validFieldValueColor = Color.fromRGBO(45, 194, 98, 0.2);
  String _volatilePassword;
  String _password;
  String _passwordInInputBox = '';
  double _passwordStrength = 0.0;
  bool _password1Visible = false;
  bool _password2Visible = false;
  final _password1FocusNode = FocusNode();
  final _password2FocusNode = FocusNode();
  bool _password1InFocus = false;
  bool _password2InFocus = false;

  bool _passwordsMatch = false;
  bool _isPasswordValid = false;

  @override
  void initState() {
    super.initState();
    _volatilePassword = Configuration.instance.getVolatilePassword();
    if (_volatilePassword != null) {
      Future.delayed(
          Duration.zero, () => _showRecoveryCodeDialog(_volatilePassword));
    }
    _password1FocusNode.addListener(() {
      setState(() {
        _password1InFocus = _password1FocusNode.hasFocus;
      });
    });
    _password2FocusNode.addListener(() {
      setState(() {
        _password2InFocus = _password2FocusNode.hasFocus;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKeypadOpen = MediaQuery.of(context).viewInsets.bottom > 125;

    FloatingActionButtonLocation fabLocation() {
      if (isKeypadOpen) {
        return null;
      } else {
        return FloatingActionButtonLocation.centerFloat;
      }
    }

    String title = "Set password";
    if (widget.mode == PasswordEntryMode.update) {
      title = "Change password";
    } else if (widget.mode == PasswordEntryMode.reset) {
      title = "Reset password";
    } else if (_volatilePassword != null) {
      title = "Encryption keys";
    }
    return Scaffold(
      appBar: AppBar(
        leading: widget.mode == PasswordEntryMode.reset
            ? Container()
            : IconButton(
                icon: Icon(Icons.arrow_back),
                color: Theme.of(context).iconTheme.color,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
        elevation: 0,
      ),
      body: _getBody(title),
      floatingActionButton: DynamicFAB(
          isKeypadOpen: isKeypadOpen,
          isFormValid: _passwordsMatch,
          buttonText: title,
          onPressedFunction: () {
            if (widget.mode == PasswordEntryMode.set) {
              _showRecoveryCodeDialog(_passwordController1.text);
            } else {
              _updatePassword();
            }
          }),
      floatingActionButtonLocation: fabLocation(),
      floatingActionButtonAnimator: NoScalingAnimation(),
    );
  }

  Widget _getBody(String buttonTextAndHeading) {
    final email = Configuration.instance.getEmail();
    var passwordStrengthText = 'Weak';
    var passwordStrengthColor = Colors.redAccent;
    if (_passwordStrength > kStrongPasswordStrengthThreshold) {
      passwordStrengthText = 'Strong';
      passwordStrengthColor = Colors.greenAccent;
    } else if (_passwordStrength > kMildPasswordStrengthThreshold) {
      passwordStrengthText = 'Moderate';
      passwordStrengthColor = Colors.orangeAccent;
    }
    if (_volatilePassword != null) {
      return Container();
    }
    return Column(
      children: [
        Expanded(
          child: AutofillGroup(
            child: ListView(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  child: Text(buttonTextAndHeading,
                      style: Theme.of(context).textTheme.headline4),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Enter a" +
                        (widget.mode != PasswordEntryMode.set ? " new " : " ") +
                        "password we can use to encrypt your data",
                    textAlign: TextAlign.start,
                    style: Theme.of(context)
                        .textTheme
                        .subtitle1
                        .copyWith(fontSize: 14),
                  ),
                ),
                Padding(padding: EdgeInsets.all(8)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: RichText(
                      text: TextSpan(
                          style: Theme.of(context)
                              .textTheme
                              .subtitle1
                              .copyWith(fontSize: 14),
                          children: [
                        TextSpan(
                            text:
                                "We don't store this password, so if you forget, "),
                        TextSpan(
                          text: "we cannot decrypt your data",
                          style: Theme.of(context).textTheme.subtitle1.copyWith(
                              fontSize: 14,
                              decoration: TextDecoration.underline),
                        ),
                      ])),
                ),
                Padding(padding: EdgeInsets.all(12)),
                Visibility(
                  // hidden textForm for suggesting auto-fill service for saving
                  // password
                  visible: false,
                  child: TextFormField(
                    autofillHints: const [
                      AutofillHints.email,
                    ],
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    initialValue: email,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: TextFormField(
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      fillColor:
                          _isPasswordValid ? _validFieldValueColor : null,
                      filled: true,
                      hintText: "Password",
                      contentPadding: EdgeInsets.all(20),
                      border: UnderlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(6)),
                      suffixIcon: _password1InFocus
                          ? IconButton(
                              icon: Icon(
                                _password1Visible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Theme.of(context).iconTheme.color,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _password1Visible = !_password1Visible;
                                });
                              },
                            )
                          : _isPasswordValid
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context)
                                      .inputDecorationTheme
                                      .focusedBorder
                                      .borderSide
                                      .color,
                                )
                              : null,
                    ),
                    obscureText: !_password1Visible,
                    controller: _passwordController1,
                    autofocus: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    onChanged: (password) {
                      setState(() {
                        _passwordInInputBox = password;
                        _passwordStrength = estimatePasswordStrength(password);
                        _isPasswordValid =
                            _passwordStrength >= kMildPasswordStrengthThreshold;
                      });
                    },
                    textInputAction: TextInputAction.next,
                    focusNode: _password1FocusNode,
                  ),
                ),
                Padding(padding: EdgeInsets.all(4)),
                Stack(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: TextFormField(
                        keyboardType: TextInputType.visiblePassword,
                        controller: _passwordController2,
                        obscureText: !_password2Visible,
                        autofillHints: const [AutofillHints.newPassword],
                        onEditingComplete: () =>
                            TextInput.finishAutofillContext(),
                        decoration: InputDecoration(
                          fillColor:
                              _passwordsMatch ? _validFieldValueColor : null,
                          filled: true,
                          hintText: "Confirm password",
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                          suffixIcon: _password2InFocus
                              ? IconButton(
                                  icon: Icon(
                                    _password2Visible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Theme.of(context).iconTheme.color,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _password2Visible = !_password2Visible;
                                    });
                                  },
                                )
                              : _passwordsMatch
                                  ? Icon(
                                      Icons.check,
                                      color: Theme.of(context)
                                          .inputDecorationTheme
                                          .focusedBorder
                                          .borderSide
                                          .color,
                                    )
                                  : null,
                          border: UnderlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        focusNode: _password2FocusNode,
                        onChanged: (cnfPassword) {
                          setState(() {
                            if (_password != null || _password != '') {
                              _passwordsMatch = _password == cnfPassword;
                            }
                          });
                        },
                      ),
                    ),
                    Visibility(
                      visible:
                          ((_passwordInInputBox != '') && _password1InFocus),
                      child: Positioned(
                          bottom: 24,
                          child: Row(
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          spreadRadius: 0.5,
                                          color: Theme.of(context).hintColor,
                                          offset: Offset(0, -0.325),
                                        ),
                                      ],
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.zero,
                                        topRight: Radius.zero,
                                        bottomLeft: Radius.circular(5),
                                        bottomRight: Radius.circular(5),
                                      ),
                                      color: Theme.of(context)
                                          .dialogTheme
                                          .backgroundColor,
                                    ),
                                    width: double.infinity,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                4.0, 4, 4.0, 4.0),
                                            child: Row(
                                              children: [
                                                Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 5),
                                                    child: Text(
                                                      'Password Strength: $passwordStrengthText',
                                                      style: TextStyle(
                                                          color:
                                                              passwordStrengthColor),
                                                    )),
                                              ],
                                            ),
                                          ),
                                        ]),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                            ],
                          )),
                    ),
                  ],
                  clipBehavior: Clip.none,
                ),
                SizedBox(
                  height: 50,
                ),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (BuildContext context) {
                          return WebPage(
                              "How it works", "https://ente.io/architecture");
                        },
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: RichText(
                      text: TextSpan(
                          text: "How it works",
                          style: Theme.of(context).textTheme.subtitle1.copyWith(
                              fontSize: 14,
                              decoration: TextDecoration.underline)),
                    ),
                  ),
                ),
                Padding(padding: EdgeInsets.all(20)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _updatePassword() async {
    final dialog =
        createProgressDialog(context, "Generating encryption keys...");
    await dialog.show();
    try {
      final keyAttributes = await Configuration.instance
          .updatePassword(_passwordController1.text);
      await UserService.instance.updateKeyAttributes(keyAttributes);
      await dialog.hide();
      showShortToast("Password changed successfully");
      Navigator.of(context).pop();
      if (widget.mode == PasswordEntryMode.reset) {
        Bus.instance.fire(SubscriptionPurchasedEvent());
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e, s) {
      _logger.severe(e, s);
      await dialog.hide();
      showGenericErrorDialog(context);
    }
  }

  Future<void> _showRecoveryCodeDialog(String password) async {
    final dialog =
        createProgressDialog(context, "Generating encryption keys...");
    await dialog.show();
    try {
      final result = await Configuration.instance.generateKey(password);
      Configuration.instance.setVolatilePassword(null);
      await dialog.hide();
      onDone() async {
        final dialog = createProgressDialog(context, "Please wait...");
        await dialog.show();
        try {
          await UserService.instance.setAttributes(result);
          await dialog.hide();
          Bus.instance.fire(AccountConfiguredEvent());
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (BuildContext context) {
                return getSubscriptionPage(isOnBoarding: true);
              },
            ),
            (route) => route.isFirst,
          );
        } catch (e, s) {
          _logger.severe(e, s);
          await dialog.hide();
          showGenericErrorDialog(context);
        }
      }

      routeToPage(
          context,
          RecoveryKeyPage(
            result.privateKeyAttributes.recoveryKey,
            "Continue",
            showAppBar: false,
            isDismissible: false,
            onDone: onDone,
            showProgressBar: true,
          ));
    } catch (e) {
      _logger.severe(e);
      await dialog.hide();
      if (e is UnsupportedError) {
        showErrorDialog(context, "Insecure device",
            "Sorry, we could not generate secure keys on this device.\n\nplease sign up from a different device.");
      } else {
        showGenericErrorDialog(context);
      }
    }
  }
}
