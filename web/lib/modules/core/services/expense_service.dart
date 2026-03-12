import 'dart:convert';
import '../models/expense.dart';
import 'api_client.dart';

class ExpenseService {
  final ApiClient privateApiClient;

  ExpenseService({ApiClient? apiClient})
    : privateApiClient = apiClient ?? ApiClient();

  Future<List<Expense>> getExpenses() async {
    try {
      final response = await privateApiClient.get('/expenses');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Expense.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch expenses: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error fetching expenses: $e');
    }
  }

  Future<Expense> createExpense(CreateExpenseRequest request) async {
    try {
      final response = await privateApiClient.post('/expenses', request.toJson());

      if (response.statusCode == 201) {
        return Expense.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException('Failed to create expense: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error creating expense: $e');
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      final response = await privateApiClient.delete('/expenses/$id');
      return response.statusCode == 204;
    } catch (e) {
      throw ApiException('Error deleting expense: $e');
    }
  }

  void dispose() {
    privateApiClient.dispose();
  }
}
