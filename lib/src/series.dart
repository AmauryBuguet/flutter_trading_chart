import 'package:flutter/material.dart';

class Candlestick {
  final int timestamp;
  final double open;
  double high;
  double low;
  double close;
  double volume;

  Candlestick({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class Point {
  final int timestamp;
  double y;

  Point({required this.timestamp, required this.y});
}

class CandlestickSerie {
  final String name;
  List<Candlestick> candles;
  double wickWidth;
  double ratioCandleSpace;
  Paint bullPaint;
  Paint bearPaint;
  Paint dojiPaint;

  CandlestickSerie({
    required this.name,
    List<Candlestick>? candles,
    this.wickWidth = 1.0,
    this.ratioCandleSpace = 0.8,
    bullPaint,
    bearPaint,
    dojiPaint,
  })  : bullPaint = bullPaint ?? Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke,
        bearPaint = bearPaint ?? Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke,
        dojiPaint = dojiPaint ?? Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke,
        candles = candles ?? [];
}

class LineSerie {
  final String name;
  final Color color;
  List<Point> points;
  bool visible;

  LineSerie({
    required this.name,
    required this.color,
    List<Point>? points,
    this.visible = true,
  }) : points = points ?? [];
}

class ScatterSerie {
  final String name;
  final Color color;
  final double pointSize;
  List<Point> points;

  ScatterSerie({
    required this.name,
    List<Point>? points,
    required this.color,
    this.pointSize = 10,
  }) : points = points ?? [];
}

class StraightLineSerie {
  final String name;
  double y;
  final Color color;
  bool dotted;
  double width;

  StraightLineSerie({
    required this.name,
    required this.y,
    required this.color,
    this.dotted = false,
    this.width = 1.0,
  });
}

class BarSerie {
  final String name;
  final Color color;
  List<Point> values;

  BarSerie({
    required this.name,
    required this.color,
    List<Point>? values,
  }) : values = values ?? [];
}
