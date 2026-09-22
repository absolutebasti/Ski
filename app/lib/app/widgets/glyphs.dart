import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's own 24 pt glyph set (stroke 1.75, round caps, 24 grid).
enum Glyph { chevron, slalom, chairlift, gauge, flake, crest, calendar, podium, play, stop, map, gear, share, trash, chevronRight, back, close, locate }

class GlyphIcon extends StatelessWidget {
  const GlyphIcon(this.glyph, {super.key, this.size = 24, this.color, this.strokeWidth});
  final Glyph glyph;
  final double size;
  final Color? color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    return SizedBox(width: size, height: size, child: CustomPaint(painter: GlyphPainter(glyph, c, strokeWidth ?? size / 24 * 1.75)));
  }
}

class GlyphPainter extends CustomPainter {
  GlyphPainter(this.glyph, this.color, this.stroke);
  final Glyph glyph;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    Offset o(double x, double y) => Offset(x * s, y * s);
    Path path = Path();
    switch (glyph) {
      case Glyph.chevron: // brand mark: peak whose right flank becomes the run
        path.moveTo(4 * s, 14.5 * s);
        path.lineTo(9 * s, 7.5 * s);
        path.lineTo(20 * s, 19 * s);
        canvas.drawPath(path, p);
      case Glyph.slalom: // two stacked gates
        canvas.drawLine(o(6, 4), o(6, 11), p);
        canvas.drawLine(o(6, 4), o(11, 6), p);
        canvas.drawLine(o(18, 13), o(18, 20), p);
        canvas.drawLine(o(18, 13), o(13, 15), p);
        canvas.drawLine(o(6, 11), o(18, 13), p..strokeWidth = stroke * 0.7);
      case Glyph.chairlift: // cable with one hanging seat
        canvas.drawLine(o(2, 7), o(22, 4), p);
        canvas.drawLine(o(12, 5.5), o(12, 12), p);
        canvas.drawLine(o(8, 12), o(16, 12), p);
        canvas.drawLine(o(9, 12), o(9, 18), p);
        canvas.drawLine(o(9, 18), o(15, 18), p);
        canvas.drawLine(o(15, 12), o(15, 15), p);
      case Glyph.gauge: // 240° arc with needle
        canvas.drawArc(Rect.fromCircle(center: o(12, 13), radius: 8 * s), math.pi * 0.75, math.pi * 1.5, false, p);
        canvas.drawLine(o(12, 13), o(16.5, 8.5), p);
        canvas.drawCircle(o(12, 13), 1.4 * s, fill);
      case Glyph.flake: // 6-spoke snowflake
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(Offset(12 * s + 8 * s * math.cos(a), 12 * s + 8 * s * math.sin(a)), Offset(12 * s - 8 * s * math.cos(a), 12 * s - 8 * s * math.sin(a)), p);
        }
        canvas.drawCircle(o(12, 12), 1.6 * s, fill);
      case Glyph.crest: // star in a rounded shield
        path.moveTo(12 * s, 3 * s);
        path.lineTo(19.5 * s, 6 * s);
        path.lineTo(19 * s, 13 * s);
        path.quadraticBezierTo(18.5 * s, 18 * s, 12 * s, 21 * s);
        path.quadraticBezierTo(5.5 * s, 18 * s, 5 * s, 13 * s);
        path.lineTo(4.5 * s, 6 * s);
        path.close();
        canvas.drawPath(path, p);
        final star = Path();
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final r = 3.4 * s;
          final pt = Offset(12 * s + r * math.cos(a), 11.5 * s + r * math.sin(a));
          if (i == 0) {
            star.moveTo(pt.dx, pt.dy);
          } else {
            star.lineTo(pt.dx, pt.dy);
          }
          final a2 = a + math.pi / 5;
          star.lineTo(12 * s + 1.5 * s * math.cos(a2), 11.5 * s + 1.5 * s * math.sin(a2));
        }
        star.close();
        canvas.drawPath(star, fill);
      case Glyph.calendar: // 3-bar calendar
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(3.5 * s, 5 * s, 17 * s, 15 * s), Radius.circular(3 * s)), p);
        canvas.drawLine(o(3.5, 9.5), o(20.5, 9.5), p);
        canvas.drawLine(o(8, 3), o(8, 6.5), p);
        canvas.drawLine(o(16, 3), o(16, 6.5), p);
        canvas.drawLine(o(7.5, 14), o(11.5, 14), p);
        canvas.drawLine(o(13.5, 14), o(16.5, 14), p);
      case Glyph.podium: // 3-step podium
        canvas.drawRect(Rect.fromLTWH(9 * s, 5 * s, 6 * s, 15 * s), p);
        canvas.drawRect(Rect.fromLTWH(3 * s, 10 * s, 6 * s, 10 * s), p);
        canvas.drawRect(Rect.fromLTWH(15 * s, 13 * s, 6 * s, 7 * s), p);
      case Glyph.play:
        path.moveTo(7 * s, 4.5 * s);
        path.lineTo(19 * s, 12 * s);
        path.lineTo(7 * s, 19.5 * s);
        path.close();
        canvas.drawPath(path, fill);
      case Glyph.stop:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(6 * s, 6 * s, 12 * s, 12 * s), Radius.circular(2.5 * s)), fill);
      case Glyph.map:
        path.moveTo(3 * s, 6 * s);
        path.lineTo(9 * s, 4 * s);
        path.lineTo(15 * s, 6.5 * s);
        path.lineTo(21 * s, 4.5 * s);
        path.lineTo(21 * s, 18 * s);
        path.lineTo(15 * s, 20 * s);
        path.lineTo(9 * s, 17.5 * s);
        path.lineTo(3 * s, 19.5 * s);
        path.close();
        canvas.drawPath(path, p);
        canvas.drawLine(o(9, 4), o(9, 17.5), p);
        canvas.drawLine(o(15, 6.5), o(15, 20), p);
      case Glyph.gear:
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(Offset(12 * s + 6.5 * s * math.cos(a), 12 * s + 6.5 * s * math.sin(a)), Offset(12 * s + 9.5 * s * math.cos(a), 12 * s + 9.5 * s * math.sin(a)), p);
        }
        canvas.drawCircle(o(12, 12), 6.5 * s, p);
        canvas.drawCircle(o(12, 12), 2.5 * s, p);
      case Glyph.share:
        canvas.drawLine(o(12, 3.5), o(12, 14), p);
        canvas.drawLine(o(8, 7.5), o(12, 3.5), p);
        canvas.drawLine(o(16, 7.5), o(12, 3.5), p);
        path.moveTo(5 * s, 11 * s);
        path.lineTo(5 * s, 19 * s);
        path.lineTo(19 * s, 19 * s);
        path.lineTo(19 * s, 11 * s);
        canvas.drawPath(path, p);
      case Glyph.trash:
        canvas.drawLine(o(4, 7), o(20, 7), p);
        canvas.drawLine(o(9, 7), o(9, 4.5), p);
        canvas.drawLine(o(9, 4.5), o(15, 4.5), p);
        canvas.drawLine(o(15, 4.5), o(15, 7), p);
        path.moveTo(6 * s, 7 * s);
        path.lineTo(7 * s, 20 * s);
        path.lineTo(17 * s, 20 * s);
        path.lineTo(18 * s, 7 * s);
        canvas.drawPath(path, p);
      case Glyph.chevronRight:
        canvas.drawLine(o(9, 6), o(15, 12), p);
        canvas.drawLine(o(15, 12), o(9, 18), p);
      case Glyph.back:
        canvas.drawLine(o(15, 5), o(8, 12), p);
        canvas.drawLine(o(8, 12), o(15, 19), p);
      case Glyph.close:
        canvas.drawLine(o(6, 6), o(18, 18), p);
        canvas.drawLine(o(18, 6), o(6, 18), p);
      case Glyph.locate:
        canvas.drawCircle(o(12, 12), 6 * s, p);
        canvas.drawCircle(o(12, 12), 1.5 * s, fill);
        canvas.drawLine(o(12, 2.5), o(12, 6), p);
        canvas.drawLine(o(12, 18), o(12, 21.5), p);
        canvas.drawLine(o(2.5, 12), o(6, 12), p);
        canvas.drawLine(o(18, 12), o(21.5, 12), p);
    }
  }

  @override
  bool shouldRepaint(covariant GlyphPainter old) => old.glyph != glyph || old.color != color || old.stroke != stroke;
}
