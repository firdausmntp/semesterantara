import 'package:flutter/material.dart';

void main() => runApp(CounterApp());

class CounterApp extends StatefulWidget {
  @override
  _CounterAppState createState() => _CounterAppState();
}

class _CounterAppState extends State<CounterApp> {
  int counter = 0;

  void _increment() {
    setState(() {
      counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('SetState Demo')),
        body: Center(child: Text('Counter: $counter')),
        floatingActionButton: FloatingActionButton(
          onPressed: _increment,
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
