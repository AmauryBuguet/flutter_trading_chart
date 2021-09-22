import 'package:flutter/material.dart';

import 'series.dart';

class TradingChartData {
  CandlestickSerie? candleSerie;
  List<LineSerie> lineSeries;
  List<ScatterSerie> scatterSeries;
  List<StraightLineSerie> straightLineSeries;

  TradingChartData({
    this.candleSerie,
    List<LineSerie>? lineSeries,
    List<ScatterSerie>? scatterSeries,
    List<StraightLineSerie>? straightLineSeries,
  })  : lineSeries = lineSeries ?? [],
        scatterSeries = scatterSeries ?? [],
        straightLineSeries = straightLineSeries ?? [];
}

class LRTB {
  double left = 0.1;
  double right = 0.1;
  double top = 0.1;
  double bottom = 0.1;

  LRTB({
    this.left = 0.1,
    this.right = 0.1,
    this.bottom = 0.1,
    this.top = 0.1,
  });
}

class VpvrSettings {
  bool visible;
  int nbBars;
  double maxPercentWidth;
  Color color;
  Color highestColor;

  VpvrSettings({
    this.visible = false,
    this.nbBars = 50,
    this.maxPercentWidth = 0.3,
    this.color = Colors.blue,
    this.highestColor = Colors.white,
  });
}

class VolumeSettings {
  bool visible;
  double maxPercentHeight;
  Color upColor;
  Color downColor;

  VolumeSettings({
    this.visible = false,
    this.maxPercentHeight = 0.1,
    this.upColor = Colors.white,
    this.downColor = Colors.red,
  });
}

class TradingChartSettings {
  bool gridVisible;
  VpvrSettings vpvr;
  VolumeSettings volume;
  double pricePercentMargin;
  LRTB chartMargins;
  Color backgroundColor;
  int nbCandlesInitiallyDisplayed;
  int maxCandlesDisplayed;
  int nbDivisionsXAxis;
  int nbDivisionsYAxis;
  Paint linesPaint;
  Paint gridPaint;

  TradingChartSettings({
    this.gridVisible = true,
    VpvrSettings? vpvr,
    VolumeSettings? volume,
    this.pricePercentMargin = 10.0,
    chartMargins,
    this.backgroundColor = const Color.fromARGB(255, 35, 35, 55),
    this.nbCandlesInitiallyDisplayed = 100,
    this.maxCandlesDisplayed = 300,
    this.nbDivisionsXAxis = 5,
    this.nbDivisionsYAxis = 5,
    linesPaint,
    gridPaint,
  })  : chartMargins = chartMargins ?? LRTB(),
        linesPaint = linesPaint ?? Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke,
        gridPaint = gridPaint ?? Paint()
          ..color = const Color.fromARGB(25, 255, 255, 255)
          ..style = PaintingStyle.stroke,
        vpvr = vpvr ?? VpvrSettings(),
        volume = volume ?? VolumeSettings();
}

class TradingChartController {
  TradingChartData data;
  TradingChartSettings settings;
  ValueNotifier<int> startTsNotifier;
  ValueNotifier<int> endTsNotifier;
  double pixelsPerMs = 0;
  double pixelsPerUSDT = 0;
  double maxY = 0;
  double minY = 0;
  int displayedCandlesOnReset = 50;
  Size size = const Size(1, 1);

  TradingChartController({
    TradingChartData? data,
    TradingChartSettings? settings,
    int? startTs,
    int? endTs,
  })  : startTsNotifier = ValueNotifier(startTs ?? 0),
        endTsNotifier = ValueNotifier(endTs ?? 1),
        data = data ?? TradingChartData(),
        settings = settings ?? TradingChartSettings();

  Offset chartPositionToLocalPosition(Point pt) {
    return Offset(
      (pt.timestamp - startTsNotifier.value) * pixelsPerMs +
          settings.chartMargins.left * size.width,
      (maxY - pt.y) * pixelsPerUSDT + settings.chartMargins.top * size.height,
    );
  }

  Point localPositionToChartPosition(Offset pt) {
    return Point(
      timestamp:
          (pt.dx - settings.chartMargins.left * size.width) ~/ pixelsPerMs +
              startTsNotifier.value,
      y: maxY -
          (pt.dy - settings.chartMargins.top * size.height) / pixelsPerUSDT,
    );
  }

  void setTimestamps(int start, int end) {
    startTsNotifier.value = start;
    endTsNotifier.value = end;
  }

  void centerChart() {
    if (data.candleSerie != null && data.candleSerie!.candles.isNotEmpty) {
      if (data.candleSerie!.candles.length > displayedCandlesOnReset) {
        startTsNotifier.value = data
            .candleSerie!
            .candles[data.candleSerie!.candles.length - displayedCandlesOnReset]
            .timestamp;
      } else {
        startTsNotifier.value = data.candleSerie!.candles.first.timestamp;
      }
      endTsNotifier.value = data.candleSerie!.candles.last.timestamp;
    }
  }
}
