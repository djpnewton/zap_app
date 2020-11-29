import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'config.dart';
import 'send_form.dart';
import 'receive_form.dart';
import 'zapdart/widgets.dart';
import 'zapdart/colors.dart';

class SendScreen extends StatelessWidget {
  SendScreen(this._testnet, this._seed, this._fee, this._recipientOrUri, this._max) : super();

  final bool _testnet;
  final String _seed;
  final Decimal _fee;
  final String _recipientOrUri;
  final Decimal _max;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context),
          title: Text('send $AssetShortNameLower', style: TextStyle(color: ZapWhite)),
          backgroundColor: ZapYellow,
        ),
        body: CustomPaint(
          painter: CustomCurve(ZapYellow, 110, 170),
          child: Container(
            width: MediaQuery.of(context).size.width, 
            height: MediaQuery.of(context).size.height,
            padding: EdgeInsets.all(20),
            child: SendForm(_testnet, _seed, _fee, _recipientOrUri, _max)
          ) 
        )
    );
  }
}

class ReceiveScreen extends StatelessWidget {
  ReceiveScreen(this._testnet, this._address) : super();

  final bool _testnet;
  final String _address;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context),
          title: Text("receive $AssetShortNameLower", style: TextStyle(color: ZapWhite)),
          backgroundColor: ZapGreen,
        ),
        body: CustomPaint(
          painter: CustomCurve(ZapGreen, 150, 250),
          child: Container(
            width: MediaQuery.of(context).size.width, 
            height: MediaQuery.of(context).size.height,
            padding: EdgeInsets.all(20),
            child: ReceiveForm(_testnet, _address)
          )
        )
    );
  }
}
