import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:zapdart/utils.dart';

import 'config.dart';

const StashKeyRecoveryWords = 'Recovery Words';
const StashQuestions = [
  'What is your mothers maiden name?',
  'In what city/area were you born',
  'What is your pets name?'
];

class StashMetadata {
  final String email;
  final String question;
  final String answer;

  StashMetadata(this.email, this.question, this.answer);
}

class StashData {
  final String key;
  final String iv;
  final String cyphertext;
  final String question;

  StashData(this.key, this.iv, this.cyphertext, this.question);
}

class Stash {
  String get baseUrl {
    return StashServer!;
  }

  Future<http.Response?> _postAndCatch(String endpoint, String body,
      {Map<String, String>? extraHeaders}) async {
    var url = baseUrl + endpoint;
    try {
      return await httpPost(Uri.parse(url), body, extraHeaders: extraHeaders);
    } on SocketException catch (e) {
      print(e);
      return null;
    } on TimeoutException catch (e) {
      print(e);
      return null;
    } on http.ClientException catch (e) {
      print(e);
      return null;
    } on ArgumentError catch (e) {
      print(e);
      return null;
    } on HandshakeException catch (e) {
      print(e);
      return null;
    }
  }

  Future<http.Response?> _getAndCatch(
    String endpoint,
  ) async {
    var url = baseUrl + endpoint;
    try {
      return await httpGet(Uri.parse(url));
    } on SocketException catch (e) {
      print(e);
      return null;
    } on TimeoutException catch (e) {
      print(e);
      return null;
    } on http.ClientException catch (e) {
      print(e);
      return null;
    } on ArgumentError catch (e) {
      print(e);
      return null;
    } on HandshakeException catch (e) {
      print(e);
      return null;
    }
  }

  String _trimAndLower(String s) {
    return s.trim().toLowerCase();
  }

  Future<String?> save(String key, StashMetadata meta, String data) async {
    var email = _trimAndLower(meta.email);
    var answer = _trimAndLower(meta.answer);
    var em = encryptMnemonic(data, email + answer);
    var body = jsonEncode({
      'key': key,
      'email': email,
      'iv': em.iv,
      'cyphertext': em.encryptedMnemonic,
      'question': meta.question
    });
    String? saveToken;
    var response = await _postAndCatch('save', body);
    if (response != null && response.statusCode == 200)
      try {
        var json = jsonDecode(response.body);
        saveToken = json['token'] as String;
      } catch (e) {}
    return saveToken;
  }

  Future<bool> saveCheck(String? token) async {
    var confirmed = false;
    if (token != null) {
      var response = await _getAndCatch('save_check/' + token);
      if (response != null && response.statusCode == 200) {
        try {
          var json = jsonDecode(response.body);
          confirmed = json['confirmed'] as bool;
        } catch (e) {}
      }
    }
    return confirmed;
  }

  Future<String?> load(String key, String email) async {
    email = _trimAndLower(email);
    var body = jsonEncode({
      'key': key,
      'email': email,
    });
    String? saveToken;
    var response = await _postAndCatch('load', body);
    if (response != null && response.statusCode == 200)
      try {
        var json = jsonDecode(response.body);
        saveToken = json['token'] as String;
      } catch (e) {}
    return saveToken;
  }

  Future<StashData?> loadCheck(String? token) async {
    var confirmed = false;
    if (token != null) {
      var response = await _getAndCatch('load_check/' + token);
      if (response != null && response.statusCode == 200) {
        try {
          var json = jsonDecode(response.body);
          confirmed = json['confirmed'] as bool;
          if (confirmed)
            return StashData(
                json['key'], json['iv'], json['cyphertext'], json['question']);
        } catch (e) {}
      }
    }
    return null;
  }

  String? decrypt(StashData data, String email, String answer) {
    email = _trimAndLower(email);
    answer = _trimAndLower(answer);
    return decryptMnemonic(data.cyphertext, data.iv, email + answer);
  }
}
