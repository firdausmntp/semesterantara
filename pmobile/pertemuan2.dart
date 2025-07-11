import 'package:flutter/material.dart';

void main() => runApp(BasicWidgetApp());

class BasicWidgetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Widget Dasar',
      home: Scaffold(
        appBar: AppBar(title: Text('Struktur Flutter')),
        body: Column(
          children: [
            Text('Ini Text Widget'),
            ElevatedButton(onPressed: () {}, child: Text('Tombol')),
            Icon(Icons.flutter_dash, size: 40)
          ],
        ),
      ),
    );
  }
}
