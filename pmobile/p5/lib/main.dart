import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(LocalStorageApp());

class LocalStorageApp extends StatefulWidget {
  @override
  _LocalStorageAppState createState() => _LocalStorageAppState();
}

class _LocalStorageAppState extends State<LocalStorageApp> {
  int counter = 0;

  void _increment() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      counter++;
    });
    prefs.setInt('counter', counter);
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      counter = prefs.getInt('counter') ?? 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Shared Preferences')),
        body: Center(child: Text('Counter: $counter')),
        floatingActionButton: FloatingActionButton(
          onPressed: _increment,
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
