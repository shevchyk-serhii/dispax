# Testing Setup

## In-Memory Database for Testing

Все моковые репозитории теперь находятся в тестовых сорсах, а не в основных. Это обеспечивает правильное разделение production и test кода.

### Структура

**Production (main sources):**
- `PersonRepository` - только PostgreSQL реализация
- `UserRepository` и `TokenRepository` - только PostgreSQL реализации
- `AuthService` - только основной слой

**Testing (test sources):**
- `MockPersonRepository` - в `/core/src/test/scala/com/shevchyk/repository/`
- `InMemoryUserRepository` и `InMemoryTokenRepository` - в `/auth/src/test/scala/com/shevchyk/auth/repository/`
- `TestApplication` - в `/api/src/test/scala/com/shevchyk/`

### Запуск тестов

1. **Запуск тестового сервера:**
   ```bash
   sbt testServer
   ```
   Это запустит сервер с in-memory данными на localhost:8080

2. **Запуск тестов Cucumber:**
   ```bash
   # В другом терминале, после запуска testServer
   sbt test
   ```

3. **Запуск production сервера:**
   ```bash
   sbt run
   ```
   Это запустит сервер с PostgreSQL базой данных

### Тестовые данные

TestApplication содержит те же моковые данные, что были в оригинальной реализации:

**Пользователи:**
- ID: 1, Email: test@example.com, Password: password123, Role: CLIENT
- ID: 50, Email: client@example.com, Password: password123, Role: CLIENT  
- ID: 10, Email: driver@example.com, Password: password123, Role: DRIVER
- ID: 99, Email: admin@example.com, Password: password123, Role: ADMIN

**Токены:**
- valid-token-1 -> User ID 1
- valid-token-50 -> User ID 50
- valid-token-10 -> User ID 10
- valid-token-99 -> User ID 99

### Преимущества

1. **Чистая архитектура**: production код не содержит тестовых данных
2. **Быстрые тесты**: in-memory реализации работают быстро
3. **Предсказуемость**: тестовые данные всегда одинаковые
4. **Изоляция**: тесты не зависят от состояния базы данных