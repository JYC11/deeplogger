import 'package:deeplogger/services/dive_grouper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupPhotosByDive', () {
    test('empty list returns empty clusters', () {
      expect(groupPhotosByDive([]), isEmpty);
    });

    test('single photo returns single cluster', () {
      final ts = [DateTime(2026, 1, 1, 10, 0)];
      final clusters = groupPhotosByDive(ts);
      expect(clusters.length, 1);
      expect(clusters[0].length, 1);
      expect(clusters[0][0], ts[0]);
    });

    test('photos within 30 min gap are in same cluster', () {
      final ts = [
        DateTime(2026, 1, 1, 10, 0),
        DateTime(2026, 1, 1, 10, 15),
        DateTime(2026, 1, 1, 10, 30),
      ];
      final clusters = groupPhotosByDive(ts);
      expect(clusters.length, 1);
      expect(clusters[0].length, 3);
    });

    test('75 min gap with span <= 90 stays in same cluster', () {
      // D-GROUP: 60 < 75 <= 90, newSpan = 75 <= 90 → extend → 1 cluster.
      final ts = [
        DateTime(2026, 1, 1, 10, 0),
        DateTime(2026, 1, 1, 11, 15), // 75 min gap, span 75 <= 90
      ];
      final clusters = groupPhotosByDive(ts);
      expect(clusters.length, 1);
      expect(clusters[0].length, 2);
    });

    test('75 min gap with span > 90 starts a new cluster', () {
      // First cluster spans 40 min, then 75-min gap → newSpan 115 > 90 → break.
      final ts = [
        DateTime(2026, 1, 1, 10, 0),
        DateTime(2026, 1, 1, 10, 40), // gap 40, span 40 (extend)
        DateTime(2026, 1, 1, 11, 55), // gap 75, newSpan 115 > 90 → new cluster
      ];
      final clusters = groupPhotosByDive(ts);
      expect(clusters.length, 2);
      expect(clusters[0].length, 2);
      expect(clusters[1].length, 1);
    });

    test('span-cap edge: 85-min span + 70-min gap breaks', () {
      // Plan example: cluster spanning 85 min, then 70-min gap → newSpan 155.
      final ts = [
        DateTime(2026, 1, 1, 10, 0),
        DateTime(2026, 1, 1, 11, 25), // gap 85 (<=90), span 85 <= 90 (extend)
        DateTime(2026, 1, 1, 12, 35), // gap 70, newSpan 155 > 90 → new cluster
      ];
      final clusters = groupPhotosByDive(ts);
      expect(clusters.length, 2);
      expect(clusters[0].length, 2);
      expect(clusters[1].length, 1);
    });

    test('120 min gap starts a new cluster', () {
      final ts = [
        DateTime(2026, 1, 1, 10, 0),
        DateTime(2026, 1, 1, 12, 0), // 120 min gap > 90
      ];
      final clusters = groupPhotosByDive(ts);
      expect(clusters.length, 2);
    });

    test('exactly 60 min gap stays in same cluster', () {
      final ts = [
        DateTime(2026, 1, 1, 10, 0),
        DateTime(2026, 1, 1, 11, 0), // exactly 60 min
      ];
      final clusters = groupPhotosByDive(ts);
      expect(clusters.length, 1);
      expect(clusters[0].length, 2);
    });

    test('multiple clusters with varying gaps', () {
      final ts = [
        DateTime(2026, 1, 1, 9, 0),
        DateTime(2026, 1, 1, 9, 20),
        DateTime(2026, 1, 1, 9, 45),
        DateTime(2026, 1, 1, 11, 30), // 105 min gap → new cluster
        DateTime(2026, 1, 1, 11, 50),
        DateTime(2026, 1, 1, 14, 0), // 130 min gap → new cluster
        DateTime(2026, 1, 1, 14, 30),
      ];
      final clusters = groupPhotosByDive(ts);
      expect(clusters.length, 3);
      expect(clusters[0].length, 3); // 9:00, 9:20, 9:45
      expect(clusters[1].length, 2); // 11:30, 11:50
      expect(clusters[2].length, 2); // 14:00, 14:30
    });

    test('unsorted input is sorted before grouping', () {
      final ts = [
        DateTime(2026, 1, 1, 10, 30),
        DateTime(2026, 1, 1, 10, 0),
        DateTime(2026, 1, 1, 10, 15),
      ];
      final clusters = groupPhotosByDive(ts);
      expect(clusters.length, 1);
      expect(clusters[0][0], DateTime(2026, 1, 1, 10, 0));
      expect(clusters[0][2], DateTime(2026, 1, 1, 10, 30));
    });

    test('cluster start and end times match first and last photo', () {
      final ts = [
        DateTime(2026, 1, 1, 9, 0),
        DateTime(2026, 1, 1, 9, 30),
        DateTime(2026, 1, 1, 9, 45),
      ];
      final clusters = groupPhotosByDive(ts);
      expect(clusters[0].first, DateTime(2026, 1, 1, 9, 0));
      expect(clusters[0].last, DateTime(2026, 1, 1, 9, 45));
    });
  });
}
