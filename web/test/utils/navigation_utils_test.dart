import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:oktopus/modules/core/navigation_utils.dart';
import 'package:oktopus/modules/core/models/location.dart';
import '../helpers/test_fixtures.dart';

class MockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? lastLaunchedUrl;
  bool shouldAllow = true;

  @override
  Future<bool> canLaunch(String url) async => shouldAllow;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    return true;
  }

  @override
  Future<void> closeWebView() async {}

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    lastLaunchedUrl = url;
    return true;
  }
}

void main() {
  late MockUrlLauncher mockLauncher;

  setUp(() {
    mockLauncher = MockUrlLauncher();
    UrlLauncherPlatform.instance = mockLauncher;
  });

  group('NavigationUtils.openGoogleMapsRoute', () {
    test('использует координаты когда они есть', () async {
      final origin = TestFixtures.location(
        address: 'Marienplatz, München',
        latitude: 48.1374,
        longitude: 11.5755,
      );
      final destination = TestFixtures.location(
        address: 'Flughafen München',
        latitude: 48.3537,
        longitude: 11.7750,
      );

      await NavigationUtils.openGoogleMapsRoute(origin, destination);

      expect(mockLauncher.lastLaunchedUrl, contains('48.1374,11.5755'));
      expect(mockLauncher.lastLaunchedUrl, contains('48.3537,11.775'));
      expect(mockLauncher.lastLaunchedUrl, isNot(contains('M%C3%BCnchen')));
    });

    test('использует адрес когда координат нет', () async {
      final origin = TestFixtures.location(
        address: 'Marienplatz, München',
        latitude: null,
        longitude: null,
      );
      final destination = TestFixtures.location(
        address: 'Flughafen München',
        latitude: null,
        longitude: null,
      );

      await NavigationUtils.openGoogleMapsRoute(origin, destination);

      expect(mockLauncher.lastLaunchedUrl, contains('Marienplatz'));
      expect(mockLauncher.lastLaunchedUrl, contains('Flughafen'));
    });

    test('формирует корректный Google Maps URL с параметрами', () async {
      final origin = TestFixtures.location(latitude: 48.1, longitude: 11.5);
      final destination = TestFixtures.location(latitude: 48.2, longitude: 11.6);

      await NavigationUtils.openGoogleMapsRoute(origin, destination);

      final url = mockLauncher.lastLaunchedUrl!;
      expect(url, contains('google.com/maps/dir'));
      expect(url, contains('api=1'));
      expect(url, contains('travelmode=driving'));
      expect(url, contains('origin='));
      expect(url, contains('destination='));
    });

    test('использует координаты только у origin когда у destination их нет', () async {
      final origin = TestFixtures.location(
        address: 'Start',
        latitude: 48.1,
        longitude: 11.5,
      );
      final destination = TestFixtures.location(
        address: 'End Street',
        latitude: null,
        longitude: null,
      );

      await NavigationUtils.openGoogleMapsRoute(origin, destination);

      final url = mockLauncher.lastLaunchedUrl!;
      expect(url, contains('48.1,11.5'));
      expect(url, contains('End%20Street'));
    });
  });

  group('NavigationUtils.navigateToMap', () {
    testWidgets('открывает Google Maps маршрут для поездки с координатами',
        (tester) async {
      final ride = TestFixtures.ride(
        from: TestFixtures.location(
          address: 'From',
          latitude: 48.1374,
          longitude: 11.5755,
        ),
        to: TestFixtures.location(
          address: 'To',
          latitude: 48.3537,
          longitude: 11.7750,
        ),
      );

      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      await NavigationUtils.navigateToMap(context, ride);

      expect(mockLauncher.lastLaunchedUrl, contains('48.1374,11.5755'));
      expect(mockLauncher.lastLaunchedUrl, contains('48.3537,11.775'));
    });

    testWidgets('открывает Google Maps по адресу когда координат нет',
        (tester) async {
      final ride = TestFixtures.ride(
        from: TestFixtures.location(
          address: 'Hauptbahnhof München',
          latitude: null,
          longitude: null,
        ),
        to: TestFixtures.location(
          address: 'Olympiapark',
          latitude: null,
          longitude: null,
        ),
      );

      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      await NavigationUtils.navigateToMap(context, ride);

      final url = mockLauncher.lastLaunchedUrl!;
      expect(url, contains('Hauptbahnhof'));
      expect(url, contains('Olympiapark'));
    });
  });

  group('NavigationUtils.openGoogleMapsRoute — URL encoding', () {
    test('адрес с пробелами корректно энкодится', () async {
      final origin = TestFixtures.location(
        address: 'Leopoldstraße 1 München',
        latitude: null,
        longitude: null,
      );
      final destination = TestFixtures.location(
        address: 'Marienplatz 8',
        latitude: null,
        longitude: null,
      );

      await NavigationUtils.openGoogleMapsRoute(origin, destination);

      final url = mockLauncher.lastLaunchedUrl!;
      expect(url, isNot(contains(' ')));
    });

    test('координаты не энкодятся лишний раз', () async {
      final origin = TestFixtures.location(latitude: 48.1374, longitude: 11.5755);
      final destination = TestFixtures.location(latitude: 48.3537, longitude: 11.775);

      await NavigationUtils.openGoogleMapsRoute(origin, destination);

      final url = mockLauncher.lastLaunchedUrl!;
      expect(url, isNot(contains('%2C')));
    });
  });
}
