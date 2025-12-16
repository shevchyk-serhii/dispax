# Configuration Management

## Database Configuration

Конфигурация базы данных теперь вынесена из кода в конфигурационный файл и переменные окружения.

### Файл конфигурации

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

### Переменные окружения

Можно переопределить настройки базы данных через переменные окружения:

```bash
export DATABASE_URL="jdbc:postgresql://prod-host:5432/oktopus_prod"
export DATABASE_USER="oktopus_prod"
export DATABASE_PASSWORD="secure_password"
export DATABASE_MAX_POOL_SIZE="20"
export DATABASE_MIN_IDLE="5"
```

### Использование

**В коде:**
```scala
import com.shevchyk.database.DatabaseConfig

// Загружает конфигурацию из application.conf или переменных окружения
DatabaseConfig.layer

// Fallback с дефолтными значениями (для разработки/тестирования)
DatabaseConfig.defaultLayer

// Готовые слои с транзакторами
DatabaseConfig.liveTransactor                    // без миграций
DatabaseConfig.liveTransactorWithMigrations      // с миграциями
```

**Для разных окружений:**

```scala
// Production
val productionLayers = ZLayer.make[AuthService](
  DatabaseConfig.layer,               // Читает из application.conf
  UserRepository.layer,
  TokenRepository.layer,
  AuthService.live
)

// Development/Testing  
val developmentLayers = ZLayer.make[AuthService](
  DatabaseConfig.defaultLayer,        // Использует дефолтные значения
  UserRepository.layer,
  TokenRepository.layer, 
  AuthService.live
)
```

### Преимущества

1. **Безопасность**: Пароли и URL не хранятся в коде
2. **Гибкость**: Разные настройки для dev/staging/prod
3. **Конфигурируемость**: Легко изменить без перекомпиляции
4. **12-Factor App**: Следует принципам конфигурирования
5. **Fallback**: Автоматически использует дефолтные значения при ошибке чтения конфига

### Структура

- `DatabaseConfig.layer` - основной слой, читает из конфига
- `DatabaseConfig.defaultLayer` - fallback с хардкодными значениями  
- Автоматический fallback при ошибке чтения конфигурации
- Поддержка переменных окружения через `${?VARIABLE_NAME}` синтаксис