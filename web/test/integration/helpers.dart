import 'package:http/http.dart' as http;
import 'package:oktopus/modules/core/services/api_client.dart';

const String kTestBaseUrl = 'http://localhost:8080/api';

const String kClientEmail = 'test@example.com';
const String kClientPassword = 'Password123';
const String kDriverEmail = 'driver@example.com';
const String kAdminEmail = 'admin@example.com';
const String kPassword = 'Password123';

ApiClient makeClient({String? token}) {
  final client = ApiClient(client: http.Client(), baseUrl: kTestBaseUrl);
  if (token != null) client.setAuthToken(token);
  return client;
}

Future<String> loginAs(String email, String password) async {
  final client = makeClient();
  try {
    final data = await client.login(email, password);
    if (data == null) throw Exception('Login returned null for $email');
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('No token in login response: $data');
    }
    return token;
  } finally {
    client.dispose();
  }
}
