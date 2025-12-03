# Coding Standards

## Naming Conventions

### Flutter/Dart
- **НЕ ИСПОЛЬЗОВАТЬ** нижнее подчеркивание в именах переменных, функций и методов
- Использовать camelCase для всех идентификаторов
- Частные (private) члены класса помечать префиксом `private` вместо `_`

#### Примеры:
```dart
// ❌ Неправильно
String _userName;
void _refreshRides(BuildContext context) {}
final _apiClient = ApiClient();

// ✅ Правильно  
String privateUserName;
void refreshRides(BuildContext context) {}
final privateApiClient = ApiClient();
```

### Scala
- Использовать camelCase для переменных и методов
- Использовать PascalCase для классов и объектов
- Избегать нижних подчеркиваний кроме случаев, требуемых языком

## Общие принципы
- Код должен быть читаемым и понятным
- Использовать описательные имена
- Избегать сокращений там, где это возможно