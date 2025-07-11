import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(ApiApp());

class ApiApp extends StatefulWidget {
  @override
  _ApiAppState createState() => _ApiAppState();
}

class _ApiAppState extends State<ApiApp> {
  List users = [];

  void fetchUsers() async {
    final res = await http.get(
      Uri.parse('https://jsonplaceholder.typicode.com/users'),
    );
    if (res.statusCode == 200) {
      setState(() {
        users = json.decode(res.body);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('API Users')),
        body: ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(title: Text(user['name']));
          },
        ),
      ),
    );
  }
}
