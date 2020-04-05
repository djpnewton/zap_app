import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

import 'libzap.dart';
import 'utils.dart';
import 'widgets.dart';

class TransactionsScreen extends StatefulWidget {
  final String _address;
  final bool _testnet;

  TransactionsScreen(this._address, this._testnet) : super();

  @override
  _TransactionsState createState() => new _TransactionsState();
}

enum LoadDirection {
  Next, Previous, Initial
}

class Choice {
  const Choice({this.title, this.icon});

  final String title;
  final IconData icon;
}

const List<Choice> choices = const <Choice>[
  const Choice(title: "Export JSON", icon: Icons.save),
];

class _TransactionsState extends State<TransactionsScreen> {
  bool _loading = true;
  List<Tx> _txs = List<Tx>();
  int _offset = 0;
  int _count = 10;
  String _after;
  bool _more = false;
  bool _less = false;
  bool _foundEnd = false;

  @override
  void initState() {
    _loadTxs(LoadDirection.Initial);
    super.initState();
  }

  Future<int> _downloadMoreTxs(int count) async {
    var txs = await LibZap.addressTransactions(widget._address, count, _after);
    if (txs != null) {
      _txs = _txs + txs;
      if (_txs.length > 0)
        _after = _txs[_txs.length - 1].id;
      if (txs.length < count)
        _foundEnd = true;
    }
    else
      return -1;
    return txs.length;
  }

  void _loadTxs(LoadDirection dir) async {
    var newOffset = _offset;
    if (dir == LoadDirection.Next) {
      newOffset += _count;
      if (newOffset > _txs.length)
        newOffset = _txs.length;
    }
    else if (dir == LoadDirection.Previous) {
      newOffset -= _count;
      if (newOffset < 0)
        newOffset = 0;
    }
    if (newOffset == _txs.length) {
      // set loading
      setState(() {
        _loading = true;
      });
      // load new txs
      var res = await _downloadMoreTxs(_count);
      setState(() {
        if (res != -1) {
          _more = res == _count;
          _less = newOffset > 0;
          _offset = newOffset;
        }
        else {
          flushbarMsg(context, 'failed to load transactions', category: MessageCategory.Warning);
        }
        _loading = false;
      });
    }
    else {
      setState(() {
        _more = !_foundEnd || newOffset < _txs.length - _count;
        _less = newOffset > 0;
        _offset = newOffset;
      });
    }
  }

  Widget _buildTxList(BuildContext context, int index) {
    var offsetIndex = _offset + index;
    if (offsetIndex >= _offset + _count || offsetIndex >= _txs.length)
      return null;
    var tx = _txs[offsetIndex];
    var zapAssetId = widget._testnet ? LibZap.TESTNET_ASSET_ID : LibZap.MAINNET_ASSET_ID;
    if (tx.assetId != zapAssetId)
      return SizedBox.shrink();
    var outgoing = tx.sender == widget._address;
    var icon = outgoing ? Icons.remove_circle : Icons.add_circle;
    var amount = Decimal.fromInt(tx.amount) / Decimal.fromInt(100);
    var amountText = amount.toStringAsFixed(2);
    var fee = Decimal.fromInt(tx.fee) / Decimal.fromInt(100);
    var feeText = fee.toStringAsFixed(2);
    amountText = outgoing ? '- $amountText' : '+ $amountText';
    var color = outgoing ? zapyellow : zapgreen;
    var date = new DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
    var dateStrLong = DateFormat('yyyy-MM-dd HH:mm').format(date);
    var link = widget._testnet ? 'https://wavesexplorer.com/testnet/tx/${tx.id}' : 'https://wavesexplorer.com/tx/${tx.id}';
    var attachment = tx.attachment;
    if (tx.attachment != null && tx.attachment.isNotEmpty)
      attachment = base58decode(tx.attachment);
    return ListTx(() {
      Navigator.of(context).push(
        // We will now use PageRouteBuilder
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (BuildContext context, __, ___) {
            return new Scaffold(
              appBar: AppBar(
                leading: backButton(context, color: zapblue),
                title: Text('transaction', style: TextStyle(color: zapblue)),
              ),
              body: Container(
                color: Colors.white,
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: ListTile(title: Text('transaction ID'),
                          subtitle: InkWell(
                            child: Text(tx.id, style: new TextStyle(color: zapblue, decoration: TextDecoration.underline))),
                            onTap: () => launch(link),
                          ),

                    ),
                    ListTile(title: Text('date'), subtitle: Text(dateStrLong)),
                    ListTile(title: Text('sender'), subtitle: Text(tx.sender)),
                    ListTile(title: Text('recipient'), subtitle: Text(tx.recipient)),
                    ListTile(title: Text('amount'), subtitle: Text('$amountText zap', style: TextStyle(color: color),)),
                    ListTile(title: Text('fee'), subtitle: Text('$feeText zap',)),
                    Visibility(
                      visible: attachment != null && attachment != "",
                      child:
                        ListTile(title: Text("Attachment"), subtitle: Text(attachment)),
                    ),
                    Container(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: RoundedButton(() => Navigator.pop(context), zapblue, Colors.white, 'close', borderColor: zapblue)
                    ),
                  ],
                ),
              )
            );
          }
        )
      );
    }, date, tx.id, amount, outgoing);
  }

  void _select(Choice choice) async {
    switch (choice.title) {
      case "Export JSON":
        setState(() {
          _loading = true;
        });
        while (true) {
          var txs = await _downloadMoreTxs(100);
          if (txs == -1) {
            flushbarMsg(context, 'failed to load transactions', category: MessageCategory.Warning);
            setState(() {
              _loading = false;
            });
            return;
          }
          else if (_foundEnd) {
            var json = jsonEncode(_txs);
            var filename = "zap_txs.json";
            if (Platform.isAndroid || Platform.isIOS) {
              var dir = await getExternalStorageDirectory();
              filename = dir.path + "/" + filename;
            }
            await File(filename).writeAsString(json);
            alert(context, "Wrote JSON", filename);
            setState(() {
              _loading = false;
            });
            break;
          }
          flushbarMsg(context, 'loaded ${_txs.length} transactions');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: backButton(context, color: zapblue),
        title: Text("transactions", style: TextStyle(color: zapblue)),
        actions: <Widget>[
          PopupMenuButton<Choice>(
            icon: Icon(Icons.more_vert, color: zapblue),
            onSelected: _select,
            enabled: !_loading,
            itemBuilder: (BuildContext context) {
              return choices.map((Choice choice) {
                return PopupMenuItem<Choice>(
                  value: choice,
                  child: Text(choice.title),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: _loading ? MainAxisAlignment.center : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Visibility(
                visible: !_loading && _txs.length == 0,
                child: Text("Nothing here..")),
            Visibility(
              visible: !_loading,
              child: Expanded(
                child: new ListView.builder(
                  itemCount: _txs.length,
                  itemBuilder: (BuildContext context, int index) => _buildTxList(context, index),
                ))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Visibility(
                    visible: !_loading && _less,
                    child: Container(
                        padding: const EdgeInsets.all(5),
                        child: RoundedButton(() => _loadTxs(LoadDirection.Previous), zapblue, Colors.white, 'prev', icon: Icons.navigate_before, borderColor: zapblue)
                    )),
                Visibility(
                    visible: !_loading && _more,
                    child: Container(
                        padding: const EdgeInsets.all(5),
                        child: RoundedButton(() => _loadTxs(LoadDirection.Next), zapblue, Colors.white, 'next', icon: Icons.navigate_next, borderColor: zapblue)
                    )),

              ],
            ),
            Visibility(
                visible: _loading,
                child: CircularProgressIndicator(),
            ),
          ],
        ),
      )
    );
  }
}