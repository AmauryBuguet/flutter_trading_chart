import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import 'series.dart';
import 'trading_chart_utils.dart';

class TradingChartPainter extends CustomPainter {
  final TradingChartController controller;
  ValueNotifier<int> startTimestamp;
  ValueNotifier<int> endTimestamp;

  TradingChartPainter({
    required this.controller,
    required this.startTimestamp,
    required this.endTimestamp,
  }) : super(repaint: startTimestamp);

  @override
  void paint(Canvas canvas, Size size) {
    controller.size = size;

    // Draw grid and lines
    canvas.drawRect(
      Rect.fromLTRB(
        controller.settings.chartMargins.left.toDouble(),
        controller.settings.chartMargins.top.toDouble(),
        size.width - controller.settings.chartMargins.right.toDouble(),
        size.height - controller.settings.chartMargins.bottom.toDouble(),
      ),
      controller.settings.linesPaint,
    );

    // generate sublists and get max and min
    controller.maxY = double.negativeInfinity;
    controller.minY = double.infinity;
    CandlestickSerie? candleSerieSublist;
    var serie = controller.data.candleSerie;
    if (serie != null) {
      int firstIndex =
          serie.candles.indexWhere((e) => e.timestamp >= startTimestamp.value);
      int lastIndex = serie.candles
          .indexWhere((e) => e.timestamp >= endTimestamp.value, firstIndex);
      if (firstIndex != -1) {
        var candles = serie.candles.sublist(
            firstIndex, lastIndex != -1 ? lastIndex : serie.candles.length);
        candleSerieSublist = CandlestickSerie(
          name: serie.name,
          bearPaint: serie.bearPaint,
          bullPaint: serie.bullPaint,
          candles: candles,
          dojiPaint: serie.dojiPaint,
          ratioCandleSpace: serie.ratioCandleSpace,
          wickWidth: serie.wickWidth,
        );
        double maxi = candles.map<double>((e) => e.high).reduce(max);
        double mini = candles.map<double>((e) => e.low).reduce(min);
        if (maxi > controller.maxY) controller.maxY = maxi;
        if (mini < controller.minY) controller.minY = mini;
      }
    }
    List<LineSerie> lineSeriesSublist = [];
    for (LineSerie serie
        in controller.data.lineSeries.where((e) => e.visible)) {
      if (serie.points.isNotEmpty) {
        var pts = serie.points.where((e) {
          return (e.timestamp >= startTimestamp.value) &&
              (e.timestamp <= endTimestamp.value);
        }).toList();
        if (pts.isNotEmpty) {
          lineSeriesSublist.add(LineSerie(
            name: serie.name,
            color: serie.color,
            points: pts,
            visible: serie.visible,
          ));
          double maxi = pts.map<double>((e) => e.y).reduce(max);
          double mini = pts.map<double>((e) => e.y).reduce(min);
          if (maxi > controller.maxY) controller.maxY = maxi;
          if (mini < controller.minY) controller.minY = mini;
        }
      }
    }
    List<ScatterSerie> scatterSerieSublist = [];
    for (ScatterSerie serie in controller.data.scatterSeries) {
      if (serie.points.isNotEmpty) {
        var pts = serie.points.where((e) {
          return (e.timestamp >= startTimestamp.value) &&
              (e.timestamp <= endTimestamp.value);
        }).toList();
        if (pts.isNotEmpty) {
          scatterSerieSublist.add(ScatterSerie(
            name: serie.name,
            pointSize: serie.pointSize,
            color: serie.color,
            points: pts,
          ));
          double maxi = pts.map<double>((e) => e.y).reduce(max);
          double mini = pts.map<double>((e) => e.y).reduce(min);
          if (maxi > controller.maxY) controller.maxY = maxi;
          if (mini < controller.minY) controller.minY = mini;
        }
      }
    }
    for (var serie in controller.data.straightLineSeries) {
      if (serie.y > controller.maxY) controller.maxY = serie.y;
      if (serie.y < controller.minY) controller.minY = serie.y;
    }

    // check if there is something to display
    if (candleSerieSublist == null &&
        lineSeriesSublist.isEmpty &&
        scatterSerieSublist.isEmpty &&
        controller.data.straightLineSeries.isEmpty) {
      return;
    }

    // set utils variables
    double margin = controller.settings.pricePercentMargin *
        (controller.maxY - controller.minY) /
        100;
    controller.maxY += margin;
    controller.minY -= margin;
    controller.pixelsPerMs = (size.width -
            (controller.settings.chartMargins.left.toDouble() +
                controller.settings.chartMargins.right.toDouble())) /
        (endTimestamp.value - startTimestamp.value);
    controller.pixelsPerUSDT = (size.height -
            (controller.settings.chartMargins.bottom.toDouble() +
                controller.settings.chartMargins.top.toDouble())) /
        (controller.maxY - controller.minY);

    // Draw candles
    if (candleSerieSublist != null) {
      int msPerCandle =
          60000; // If there is only one candle, then it is considered as a 5-min candle.
      if (candleSerieSublist.candles.length >= 2) {
        msPerCandle = candleSerieSublist.candles[1].timestamp -
            candleSerieSublist.candles[0].timestamp;
      }
      double bodySize = ((size.width -
                  (controller.settings.chartMargins.left.toDouble() +
                      controller.settings.chartMargins.right.toDouble())) *
              msPerCandle *
              candleSerieSublist.ratioCandleSpace) /
          (controller.endTsNotifier.value - controller.startTsNotifier.value);
      for (Candlestick candle in candleSerieSublist.candles) {
        Paint paint;
        if (candle.open < candle.close) {
          paint = candleSerieSublist.bullPaint;
        } else if (candle.open > candle.close) {
          paint = candleSerieSublist.bearPaint;
        } else {
          paint = candleSerieSublist.dojiPaint;
        }
        // Draw up wick
        canvas.drawRect(
          Rect.fromLTRB(
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs -
                (candleSerieSublist.wickWidth / 2) +
                controller.settings.chartMargins.left.toDouble(),
            (controller.maxY - candle.high) * controller.pixelsPerUSDT +
                controller.settings.chartMargins.top.toDouble(),
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs +
                (candleSerieSublist.wickWidth / 2) +
                controller.settings.chartMargins.left.toDouble(),
            (controller.maxY - max(candle.open, candle.close)) *
                    controller.pixelsPerUSDT +
                controller.settings.chartMargins.top.toDouble(),
          ),
          paint,
        );
        // Draw down wick
        canvas.drawRect(
          Rect.fromLTRB(
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs -
                (candleSerieSublist.wickWidth / 2) +
                controller.settings.chartMargins.left.toDouble(),
            (controller.maxY - min(candle.open, candle.close)) *
                    controller.pixelsPerUSDT +
                controller.settings.chartMargins.top.toDouble(),
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs +
                (candleSerieSublist.wickWidth / 2) +
                controller.settings.chartMargins.left.toDouble(),
            (controller.maxY - candle.low) * controller.pixelsPerUSDT +
                controller.settings.chartMargins.top.toDouble(),
          ),
          paint,
        );

        // Draw body
        canvas.drawRect(
          Rect.fromLTRB(
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs -
                (bodySize / 2) +
                controller.settings.chartMargins.left.toDouble(),
            (controller.maxY - candle.close) * controller.pixelsPerUSDT +
                controller.settings.chartMargins.top.toDouble(),
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs +
                (bodySize / 2) +
                controller.settings.chartMargins.left.toDouble(),
            (controller.maxY - candle.open) * controller.pixelsPerUSDT +
                controller.settings.chartMargins.top.toDouble(),
          ),
          paint,
        );

        // draw volume
        if (controller.settings.volume.visible) {
          double maxVol =
              candleSerieSublist.candles.map((e) => e.volume).reduce(max);
          double highSize = controller.settings.volume.maxPercentHeight *
              (size.height -
                  controller.settings.chartMargins.bottom.toDouble() -
                  controller.settings.chartMargins.top.toDouble());
          canvas.drawRect(
            Rect.fromLTRB(
              (candle.timestamp - startTimestamp.value) *
                      controller.pixelsPerMs -
                  (bodySize / 2) +
                  controller.settings.chartMargins.left.toDouble(),
              size.height -
                  controller.settings.chartMargins.bottom.toDouble() -
                  (candle.volume * highSize / maxVol),
              (candle.timestamp - startTimestamp.value) *
                      controller.pixelsPerMs +
                  (bodySize / 2) +
                  controller.settings.chartMargins.left.toDouble(),
              size.height - controller.settings.chartMargins.bottom.toDouble(),
            ),
            Paint()
              ..color = candle.close >= candle.open
                  ? controller.settings.volume.upColor
                  : controller.settings.volume.downColor,
          );
        }
      }
    }

    // Draw Line Series
    for (LineSerie serie in lineSeriesSublist) {
      canvas.drawPoints(
          PointMode.polygon,
          serie.points
              .map((point) => Offset(
                    (point.timestamp - startTimestamp.value) *
                            controller.pixelsPerMs +
                        controller.settings.chartMargins.left.toDouble(),
                    (controller.maxY - point.y) * controller.pixelsPerUSDT +
                        controller.settings.chartMargins.top.toDouble(),
                  ))
              .toList(),
          Paint()
            ..color = serie.color
            ..style = PaintingStyle.fill);
    }

    // Draw Scatter Series
    for (ScatterSerie serie in scatterSerieSublist) {
      canvas.drawPoints(
        PointMode.points,
        serie.points
            .map((e) => Offset(
                  (e.timestamp - startTimestamp.value) *
                          controller.pixelsPerMs +
                      controller.settings.chartMargins.left.toDouble(),
                  (controller.maxY - e.y) * controller.pixelsPerUSDT +
                      controller.settings.chartMargins.top.toDouble(),
                ))
            .toList(),
        Paint()
          ..color = serie.color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = serie.pointSize,
      );
    }

    // Draw StraightLine Series
    for (StraightLineSerie serie in controller.data.straightLineSeries) {
      var path = Path();
      path.moveTo(
        controller.settings.chartMargins.left.toDouble(),
        (controller.maxY - serie.y) * controller.pixelsPerUSDT +
            controller.settings.chartMargins.top.toDouble(),
      );
      path.lineTo(
        size.width - controller.settings.chartMargins.right.toDouble(),
        (controller.maxY - serie.y) * controller.pixelsPerUSDT +
            controller.settings.chartMargins.top.toDouble(),
      );
      canvas.drawPath(
        serie.dotted
            ? dashPath(
                path,
                dashArray: CircularIntervalList<double>(<double>[15.0, 10.0]),
              )
            : path,
        Paint()
          ..color = serie.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = serie.width,
      );
    }

    // Draw vpvr
    if (controller.settings.vpvr.visible && candleSerieSublist != null) {
      Map<int, double> volumeMap = {};
      double wideness =
          (controller.maxY - controller.minY) / controller.settings.vpvr.nbBars;
      for (Candlestick candle in candleSerieSublist.candles) {
        int level = (candle.close - controller.minY) ~/ wideness;
        volumeMap[level] = (volumeMap[level] ?? 0) + candle.volume;
      }
      double maxVol = volumeMap.values.reduce(max);
      double highSize = controller.settings.vpvr.maxPercentWidth *
          (size.width -
              controller.settings.chartMargins.left.toDouble() -
              controller.settings.chartMargins.right.toDouble());
      double barWidth = (size.height -
              controller.settings.chartMargins.bottom.toDouble() -
              controller.settings.chartMargins.top.toDouble()) *
          0.4 /
          controller.settings.vpvr.nbBars;
      for (var entry in volumeMap.entries) {
        canvas.drawRect(
          Rect.fromLTRB(
            size.width -
                controller.settings.chartMargins.right.toDouble() -
                (entry.value * highSize / maxVol),
            (controller.maxY - (entry.key * wideness + controller.minY)) *
                    controller.pixelsPerUSDT +
                controller.settings.chartMargins.top.toDouble() -
                barWidth,
            size.width - controller.settings.chartMargins.right.toDouble(),
            (controller.maxY - (entry.key * wideness + controller.minY)) *
                    controller.pixelsPerUSDT +
                controller.settings.chartMargins.top.toDouble() +
                barWidth,
          ),
          Paint()
            ..color = entry.value == maxVol
                ? controller.settings.vpvr.highestColor
                : controller.settings.vpvr.color,
        );
      }
    }

    // hide overlappping candles
    canvas.drawRect(
        Rect.fromLTRB(
          controller.settings.chartMargins.left.toDouble() - 1,
          controller.settings.chartMargins.top.toDouble(),
          0,
          size.height,
        ),
        Paint()..color = controller.settings.backgroundColor);
    canvas.drawRect(
        Rect.fromLTRB(
          size.width - controller.settings.chartMargins.right.toDouble() + 1,
          controller.settings.chartMargins.top.toDouble(),
          size.width,
          size.height,
        ),
        Paint()..color = controller.settings.backgroundColor);

    // Draw Y axis labels
    double intervalY = (size.height -
            (controller.settings.chartMargins.top.toDouble() +
                controller.settings.chartMargins.bottom.toDouble())) /
        controller.settings.nbDivisionsYAxis;
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
    );
    for (int i = 0; i < controller.settings.nbDivisionsYAxis + 1; ++i) {
      double yPos =
          controller.settings.chartMargins.top.toDouble() + i * intervalY;
      canvas.drawLine(
        Offset(controller.settings.chartMargins.left.toDouble() - 5, yPos),
        Offset(controller.settings.chartMargins.left.toDouble(), yPos),
        controller.settings.linesPaint,
      );
      if (controller.settings.gridVisible) {
        canvas.drawLine(
          Offset(size.width - controller.settings.chartMargins.right.toDouble(),
              yPos),
          Offset(controller.settings.chartMargins.top.toDouble(), yPos),
          controller.settings.gridPaint,
        );
      }

      double y = (controller.settings.chartMargins.top.toDouble() - yPos) /
              controller.pixelsPerUSDT +
          controller.maxY;
      final textSpan = TextSpan(
        text: y.toStringAsFixed(2),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.end,
      );
      textPainter.layout(
        minWidth: 40,
        maxWidth: 50,
      );
      textPainter.paint(
        canvas,
        Offset(controller.settings.chartMargins.left.toDouble() - 50, yPos - 7),
      );
    }

    // Draw X axis labels
    double intervalX = (size.width -
            (controller.settings.chartMargins.left.toDouble() +
                controller.settings.chartMargins.right.toDouble())) /
        controller.settings.nbDivisionsXAxis;
    for (int i = 0; i < controller.settings.nbDivisionsXAxis + 1; ++i) {
      double xPos =
          controller.settings.chartMargins.left.toDouble() + i * intervalX;
      canvas.drawLine(
        Offset(
            xPos,
            size.height -
                controller.settings.chartMargins.bottom.toDouble() +
                5),
        Offset(xPos,
            size.height - controller.settings.chartMargins.bottom.toDouble()),
        controller.settings.linesPaint,
      );
      if (controller.settings.gridVisible) {
        canvas.drawLine(
          Offset(xPos, controller.settings.chartMargins.top.toDouble()),
          Offset(xPos,
              size.height - controller.settings.chartMargins.bottom.toDouble()),
          controller.settings.gridPaint,
        );
      }

      int x = (endTimestamp.value - startTimestamp.value) *
              i ~/
              controller.settings.nbDivisionsXAxis +
          startTimestamp.value;
      final textSpan = TextSpan(
        text: getStrFromDate(x),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(
        minWidth: 60,
        maxWidth: 60,
      );
      textPainter.paint(
        canvas,
        Offset(
            xPos - 30,
            size.height -
                controller.settings.chartMargins.bottom.toDouble() +
                5),
      );
    }
  }

  String getStrFromDate(int ts) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
    DateTime startDate =
        DateTime.fromMillisecondsSinceEpoch(startTimestamp.value);
    DateTime endDate = DateTime.fromMillisecondsSinceEpoch(endTimestamp.value);
    if (startDate.year != endDate.year) {
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } else if (startDate.month != endDate.month) {
      return "${date.day.toString().padLeft(2, '0')} ${monthToStr(date.month)}";
    } else if (startDate.day != endDate.day) {
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}\n${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
  }

  String monthToStr(int m) {
    switch (m) {
      case 1:
        return "Jan";
      case 2:
        return "Feb";
      case 3:
        return "Mar";
      case 4:
        return "Apr";
      case 5:
        return "May";
      case 6:
        return "Jun";
      case 7:
        return "Jul";
      case 8:
        return "Aug";
      case 9:
        return "Sep";
      case 10:
        return "Oct";
      case 11:
        return "Nov";
      case 12:
        return "Dec";
      default:
        return "Unk";
    }
  }

  @override
  bool shouldRepaint(TradingChartPainter oldDelegate) {
    return true;
  }
}
