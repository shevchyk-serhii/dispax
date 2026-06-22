import 'package:mocktail/mocktail.dart';
import 'package:dispax/modules/ride_management/services/ride_service.dart';
import 'package:dispax/modules/schedule_management/services/schedule_service.dart';
import 'package:dispax/modules/core/services/user_service.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/auth/services/biometric_service.dart';
import 'package:dispax/modules/core/services/websocket_service.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class MockRideService extends Mock implements RideService {}

class MockScheduleService extends Mock implements ScheduleService {}

class MockUserService extends Mock implements UserService {}

class MockApiClient extends Mock implements ApiClient {}

class MockBiometricService extends Mock implements BiometricService {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockHttpClient extends Mock implements http.Client {}

class MockWebSocketService extends Mock implements WebSocketServiceBase {}
