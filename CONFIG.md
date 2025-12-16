# Configuration Management

## Database Configuration

Database configuration has been extracted from code into a configuration file and environment variables.

### Configuration File

**`api/src/main/resources/application.conf`:**
```hocon
database {
  driver = "org.postgresql.Driver"
  url = "jdbc:postgresql://localhost:5432/oktopus"
  url = ${?DATABASE_URL}
  user = "oktopus"
  user = ${?DATABASE_USER}
  password = "oktopus"
  password = ${?DATABASE_PASSWORD}
  maxPoolSize = 10
  maxPoolSize = ${?DATABASE_MAX_POOL_SIZE}
  minIdle = 2
  minIdle = ${?DATABASE_MIN_IDLE}
}
```

### Environment Variables

Database settings can be overridden via environment variables:

```bash
export DATABASE_URL="jdbc:postgresql://prod-host:5432/oktopus_prod"
export DATABASE_USER="oktopus_prod"
export DATABASE_PASSWORD="secure_password"
export DATABASE_MAX_POOL_SIZE="20"
export DATABASE_MIN_IDLE="5"
```

### Usage

**In code:**
```scala
import com.shevchyk.database.DatabaseConfig

// Loads configuration from application.conf or environment variables
DatabaseConfig.layer

// Fallback with default values (for development/testing)
DatabaseConfig.defaultLayer

// Ready-to-use layers with transactors
DatabaseConfig.liveTransactor                    // without migrations
DatabaseConfig.liveTransactorWithMigrations      // with migrations
```

**For different environments:**

```scala
// Production
val productionLayers = ZLayer.make[AuthService](
  DatabaseConfig.layer,               // Reads from application.conf
  UserRepository.layer,
  TokenRepository.layer,
  AuthService.live
)

// Development/Testing
val developmentLayers = ZLayer.make[AuthService](
  DatabaseConfig.defaultLayer,        // Uses default values
  UserRepository.layer,
  TokenRepository.layer,
  AuthService.live
)
```

### Benefits

1. **Security**: Passwords and URLs are not stored in code
2. **Flexibility**: Different settings for dev/staging/prod
3. **Configurability**: Easy to change without recompilation
4. **12-Factor App**: Follows configuration principles
5. **Fallback**: Automatically uses default values on config read error

### Structure

- `DatabaseConfig.layer` - main layer, reads from config
- `DatabaseConfig.defaultLayer` - fallback with hardcoded values
- Automatic fallback on configuration read error
- Environment variable support via `${?VARIABLE_NAME}` syntax