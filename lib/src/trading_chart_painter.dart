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
    double marginLeft = size.width * controller.settings.chartMargins.left;
    double marginRight = size.width * controller.settings.chartMargins.right;
    double marginTop = size.height * controller.settings.chartMargins.top;
    double marginBottom = size.height * controller.settings.chartMargins.bottom;
    controller.size = size;

    // Draw grid and lines
    canvas.drawRect(
      Rect.fromLTRB(
        marginLeft,
        marginTop,
        size.width - marginRight,
        size.height - marginBottom,
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
    for (LineSerie serie in controller.data.lineSeries) {
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
    controller.pixelsPerMs = (size.width - (marginLeft + marginRight)) /
        (endTimestamp.value - startTimestamp.value);
    controller.pixelsPerUSDT = (size.height - (marginBottom + marginTop)) /
        (controller.maxY - controller.minY);

    // Draw candles
    if (candleSerieSublist != null) {
      int msPerCandle =
          60000; // If there is only one candle, then it is considered as a 5-min candle.
      if (candleSerieSublist.candles.length >= 2) {
        msPerCandle = candleSerieSublist.candles[1].timestamp -
            candleSerieSublist.candles[0].timestamp;
      }
      double bodySize = ((size.width - (marginLeft + marginRight)) *
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
                marginLeft,
            (controller.maxY - candle.high) * controller.pixelsPerUSDT +
                marginTop,
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs +
                (candleSerieSublist.wickWidth / 2) +
                marginLeft,
            (controller.maxY - max(candle.open, candle.close)) *
                    controller.pixelsPerUSDT +
                marginTop,
          ),
          paint,
        );
        // Draw down wick
        canvas.drawRect(
          Rect.fromLTRB(
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs -
                (candleSerieSublist.wickWidth / 2) +
                marginLeft,
            (controller.maxY - min(candle.open, candle.close)) *
                    controller.pixelsPerUSDT +
                marginTop,
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs +
                (candleSerieSublist.wickWidth / 2) +
                marginLeft,
            (controller.maxY - candle.low) * controller.pixelsPerUSDT +
                marginTop,
          ),
          paint,
        );

        // Draw body
        canvas.drawRect(
          Rect.fromLTRB(
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs -
                (bodySize / 2) +
                marginLeft,
            (controller.maxY - candle.close) * controller.pixelsPerUSDT +
                marginTop,
            (candle.timestamp - startTimestamp.value) * controller.pixelsPerMs +
                (bodySize / 2) +
                marginLeft,
            (controller.maxY - candle.open) * controller.pixelsPerUSDT +
                marginTop,
          ),
          paint,
        );

        // draw volume
        if (controller.settings.volume.visible) {
          double maxVol =
              candleSerieSublist.candles.map((e) => e.volume).reduce(max);
          double highSize = controller.settings.volume.maxPercentHeight *
              (size.height - marginBottom - marginTop);
          canvas.drawRect(
            Rect.fromLTRB(
              (candle.timestamp - startTimestamp.value) *
                      controller.pixelsPerMs -
                  (bodySize / 2) +
                  marginLeft,
              size.height - marginBottom - (candle.volume * highSize / maxVol),
              (candle.timestamp - startTimestamp.value) *
                      controller.pixelsPerMs +
                  (bodySize / 2) +
                  marginLeft,
              size.height - marginBottom,
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
                        marginLeft,
                    (controller.maxY - point.y) * controller.pixelsPerUSDT +
                        marginTop,
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
                      marginLeft,
                  (controller.maxY - e.y) * controller.pixelsPerUSDT +
                      marginTop,
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
        marginLeft,
        (controller.maxY - serie.y) * controller.pixelsPerUSDT + marginTop,
      );
      path.lineTo(
        size.width - marginRight,
        (controller.maxY - serie.y) * controller.pixelsPerUSDT + marginTop,
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
          (size.width - marginLeft - marginRight);
      double barWidth = (size.height - marginBottom - marginTop) *
          0.4 /
          controller.settings.vpvr.nbBars;
      for (var entry in volumeMap.entries) {
        canvas.drawRect(
          Rect.fromLTRB(
            size.width - marginRight - (entry.value * highSize / maxVol),
            (controller.maxY - (entry.key * wideness + controller.minY)) *
                    controller.pixelsPerUSDT +
                marginTop -
                barWidth,
            size.width - marginRight,
            (controller.maxY - (entry.key * wideness + controller.minY)) *
                    controller.pixelsPerUSDT +
                marginTop +
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
          marginLeft - 1,
          marginTop,
          0,
          size.height,
        ),
        Paint()..color = controller.settings.backgroundColor);
    canvas.drawRect(
        Rect.fromLTRB(
          size.width - marginRight + 1,
          marginTop,
          size.width,
          size.height,
        ),
        Paint()..color = controller.settings.backgroundColor);

    // Draw Y axis labels
    double intervalY = (size.height - (marginTop + marginBottom)) /
        controller.settings.nbDivisionsYAxis;
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
    );
    for (int i = 0; i < controller.settings.nbDivisionsYAxis + 1; ++i) {
      double yPos = marginTop + i * intervalY;
      canvas.drawLine(
        Offset(marginLeft - 5, yPos),
        Offset(marginLeft, yPos),
        controller.settings.linesPaint,
      );
      if (controller.settings.gridVisible) {
        canvas.drawLine(
          Offset(size.width - marginRight, yPos),
          Offset(marginTop, yPos),
          controller.settings.gridPaint,
        );
      }

      double y =
          (marginTop - yPos) / controller.pixelsPerUSDT + controller.maxY;
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
        Offset(marginLeft - 50, yPos - 7),
      );
    }

    // Draw X axis labels
    double intervalX = (size.width - (marginLeft + marginRight)) /
        controller.settings.nbDivisionsXAxis;
    for (int i = 0; i < controller.settings.nbDivisionsXAxis + 1; ++i) {
      double xPos = marginLeft + i * intervalX;
      canvas.drawLine(
        Offset(xPos, size.height - marginBottom + 5),
        Offset(xPos, size.height - marginBottom),
        controller.settings.linesPaint,
      );
      if (controller.settings.gridVisible) {
        canvas.drawLine(
          Offset(xPos, marginTop),
          Offset(xPos, size.height - marginBottom),
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
        Offset(xPos - 30, size.height - marginBottom + 5),
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
