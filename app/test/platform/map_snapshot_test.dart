import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/platform/map_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const request = MapSnapshotRequest(
    lat: 47.45,
    lon: 12.39,
    latSpan: 0.02,
    lonSpan: 0.03,
    width: 343,
    height: 160,
    route: [(47.44, 12.38), (47.46, 12.40)],
    routeColor: 0xFFE3C88C,
    routeWidth: 3,
  );

  test('toArgs matches the channel contract of MapSnapshot.swift', () {
    final a = request.toArgs();
    expect(a['lat'], 47.45);
    expect(a['lon'], 12.39);
    expect(a['latSpan'], 0.02);
    expect(a['lonSpan'], 0.03);
    expect(a['width'], 343);
    expect(a['height'], 160);
    expect(a['scale'], 2);
    expect(a['style'], 'satellite');
    expect(a['route'], [
      [47.44, 12.38],
      [47.46, 12.40],
    ]);
    expect(a['routeColor'], 0xFFE3C88C);
    expect(a['routeWidth'], 3);
    expect(const MapSnapshotRequest(lat: 0, lon: 0, latSpan: 1, lonSpan: 1, width: 1, height: 1, style: MapSnapshotStyle.muted).toArgs()['style'], 'muted');
  });

  test('the channel name is the one AppDelegate registers', () {
    expect(MethodChannelMapSnapshotSource.channel.name, 'de.torchtechnology.slopetrack/map_snapshot');
  });

  test('off iOS the method-channel source answers null without calling native', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannelMapSnapshotSource.channel, (call) async {
      calls.add(call);
      return Uint8List(4);
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannelMapSnapshotSource.channel, null));
    // Tests run on the host (macOS/Linux), never iOS.
    expect(await const MethodChannelMapSnapshotSource().snapshot(request), isNull);
    expect(calls, isEmpty);
  });

  test('FakeMapSnapshotSource records requests and answers per request', () async {
    final fake = FakeMapSnapshotSource(bytes: Uint8List.fromList([1, 2, 3]));
    expect(await fake.snapshot(request), [1, 2, 3]);
    fake.bytesFor = (r) => r.route.isEmpty ? null : Uint8List(1);
    expect(await fake.snapshot(request), hasLength(1));
    expect(fake.requests, hasLength(2));
  });

  test('mapSnapshotSourceProvider defaults to the method channel and can be faked', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(mapSnapshotSourceProvider), isA<MethodChannelMapSnapshotSource>());
    final fake = FakeMapSnapshotSource();
    final o = ProviderContainer(overrides: [mapSnapshotSourceProvider.overrideWithValue(fake)]);
    addTearDown(o.dispose);
    expect(o.read(mapSnapshotSourceProvider), same(fake));
  });
}
