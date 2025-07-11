import 'package:flutter/material.dart';

void main() => runApp(ListCardApp());

class ListCardApp extends StatelessWidget {
  final List<String> items = List.generate(10, (i) => "Item $i");

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('ListView & Card')),
        body: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) =>
              Card(child: ListTile(title: Text(items[index]))),
        ),
      ),
    );
  }
}
