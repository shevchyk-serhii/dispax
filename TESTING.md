# Testing Setup

## In-Memory Database for Testing

All mock repositories are now located in test sources, not in main sources. This ensures proper separation of production and test code.

### Structure

**Production (main sources):**
- `PersonRepository` - PostgreSQL implementation only
- `UserRepository` and `TokenRepository` - PostgreSQL implementations only
- `AuthService` - main layer only

**Testing (test sources):**
- `MockPersonRepository` - in `/core/src/test/scala/com/shevchyk/repository/`
- `InMemoryUserRepository` and `InMemoryTokenRepository` - in `/auth/src/test/scala/com/shevchyk/auth/repository/`
- `TestApplication` - in `/api/src/test/scala/com/shevchyk/`

### Running Tests

1. **Running the test server:**
   ```bash
   sbt testServer
   ```
   This will start a server with in-memory data on localhost:8080

2. **Running Cucumber tests:**
   ```bash
   # In another terminal, after starting testServer
   sbt test
   ```

3. **Running production server:**
   ```bash
   sbt run
   ```
   This will start a server with PostgreSQL database

### Test Data

TestApplication contains the same mock data that was in the original implementation:

**Users:**
- ID: 1, Email: test@example.com, Password: password123, Role: CLIENT
- ID: 50, Email: client@example.com, Password: password123, Role: CLIENT  
- ID: 10, Email: driver@example.com, Password: password123, Role: DRIVER
- ID: 99, Email: admin@example.com, Password: password123, Role: ADMIN

**Tokens:**
- valid-token-1 -> User ID 1
- valid-token-50 -> User ID 50
- valid-token-10 -> User ID 10
- valid-token-99 -> User ID 99

### Benefits

1. **Clean Architecture**: production code does not contain test data
2. **Fast Tests**: in-memory implementations work fast
3. **Predictability**: test data is always the same
4. **Isolation**: tests do not depend on database state