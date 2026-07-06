import 'package:dispax/modules/ride_management/services/recent_addresses_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecentAddressesStore.applyRecord (pure)', () {
    test('inserts a new address with useCount 1', () {
      final out = RecentAddressesStore.applyRecord(
        const [],
        'Marienplatz, München',
        usedAtMillis: 1000,
      );
      expect(out, hasLength(1));
      expect(out.first.address, 'Marienplatz, München');
      expect(out.first.useCount, 1);
    });

    test('increments useCount and refreshes coords on an existing address', () {
      final existing = [
        const RecentAddress(
          address: 'Marienplatz, München',
          useCount: 2,
          usedAtMillis: 500,
        ),
      ];
      final out = RecentAddressesStore.applyRecord(
        existing,
        'marienplatz, münchen', // different case → same entry
        latitude: 48.1374,
        longitude: 11.5755,
        usedAtMillis: 2000,
      );
      expect(out, hasLength(1));
      // The increment is the mutation-check target: reverting it makes this red.
      expect(out.first.useCount, 3);
      expect(out.first.latitude, 48.1374);
      expect(out.first.longitude, 11.5755);
      expect(out.first.usedAtMillis, 2000);
    });

    test('ranks most-used first, then most-recent', () {
      var list = <RecentAddress>[];
      list = RecentAddressesStore.applyRecord(list, 'A', usedAtMillis: 1);
      list = RecentAddressesStore.applyRecord(list, 'B', usedAtMillis: 2);
      list = RecentAddressesStore.applyRecord(list, 'B', usedAtMillis: 3);
      // B used twice → ranks above A.
      expect(list.map((r) => r.address), ['B', 'A']);
    });

    test('evicts the least valuable entry beyond the cap', () {
      var list = <RecentAddress>[];
      // Fill the cap: each address used once, increasing recency.
      for (var i = 0; i < RecentAddressesStore.maxEntries; i++) {
        list = RecentAddressesStore.applyRecord(
          list,
          'addr-$i',
          usedAtMillis: i,
        );
      }
      expect(list, hasLength(RecentAddressesStore.maxEntries));
      // One more distinct address (freshest) → the oldest single-use entry
      // ('addr-0', lowest recency) is evicted.
      list = RecentAddressesStore.applyRecord(
        list,
        'newest',
        usedAtMillis: 999,
      );
      expect(list, hasLength(RecentAddressesStore.maxEntries));
      expect(list.any((r) => r.address == 'newest'), isTrue);
      expect(list.any((r) => r.address == 'addr-0'), isFalse);
    });
  });

  group('RecentAddressesStore.decode', () {
    test('returns [] for null/blank/corrupt payloads', () {
      expect(RecentAddressesStore.decode(null), isEmpty);
      expect(RecentAddressesStore.decode('   '), isEmpty);
      expect(RecentAddressesStore.decode('{not json'), isEmpty);
      expect(RecentAddressesStore.decode('{"not":"a list"}'), isEmpty);
    });

    test('skips records without a usable address', () {
      final raw = RecentAddressesStore.encode(const [
        RecentAddress(address: 'Good, München', useCount: 1, usedAtMillis: 1),
      ]);
      expect(RecentAddressesStore.decode(raw).map((r) => r.address), [
        'Good, München',
      ]);
    });
  });

  group('RecentAddressesStore (SharedPreferences round-trip)', () {
    test('record then load persists the address with its count', () async {
      SharedPreferences.setMockInitialValues({});
      const store = RecentAddressesStore();

      await store.record('Marienplatz, München', usedAtMillis: 1000);
      await store.record('Marienplatz, München', usedAtMillis: 2000);
      await store.record('Leopoldstraße 42', usedAtMillis: 1500);

      final loaded = await store.load();
      // Marienplatz used twice → first; Leopoldstraße once → second.
      expect(loaded.map((a) => a.address), [
        'Marienplatz, München',
        'Leopoldstraße 42',
      ]);
      expect(loaded.first.useCount, 2);
    });

    test('a blank address is ignored', () async {
      SharedPreferences.setMockInitialValues({});
      const store = RecentAddressesStore();
      await store.record('   ');
      expect(await store.load(), isEmpty);
    });

    test('load returns [] when nothing was ever stored', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await const RecentAddressesStore().load(), isEmpty);
    });

    test(
      'recordAll persists every endpoint in one write (no lost address)',
      () async {
        SharedPreferences.setMockInitialValues({});
        const store = RecentAddressesStore();

        // Both from/to in a single read-modify-write — neither is dropped.
        await store.recordAll(['From, München', 'To, München']);

        final loaded = await store.load();
        expect(loaded.map((a) => a.address).toSet(), {
          'From, München',
          'To, München',
        });
      },
    );

    test(
      'recordAll skips blanks and writes nothing when all are blank',
      () async {
        SharedPreferences.setMockInitialValues({});
        const store = RecentAddressesStore();
        await store.recordAll(['', '   ']);
        expect(await store.load(), isEmpty);
      },
    );
  });
}
