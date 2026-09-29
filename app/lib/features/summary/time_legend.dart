import '../../core/core.dart';

/// Legend segments of a ZEIT card in whole minutes (Tagesbilanz and Tag
/// detail share this). The pause segment is the remainder
/// (total − ski − lift − signal loss), so the legend minutes always add up to
/// the header value: 16:10 + 18:40 + 3:10 in a 38-minute day reads 16 · 18 · 4.
/// `otherMs` is folded into the pause by construction.
({int skiMs, int liftMs, int pauseMs, int signalLossMs}) timeLegendSegments(DayStats stats) {
  int minutes(int ms) => ms ~/ 60000 * 60000;
  final ski = minutes(stats.skiMs);
  final lift = minutes(stats.liftMs);
  final signal = minutes(stats.signalLossMs);
  final rest = minutes(stats.elapsedMs) - ski - lift - signal;
  return (skiMs: ski, liftMs: lift, pauseMs: rest < 0 ? 0 : rest, signalLossMs: signal);
}
