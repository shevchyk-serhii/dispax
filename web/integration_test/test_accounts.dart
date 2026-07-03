/// Shared test account constants for both the HTTP integration tests
/// (`*_integration_test.dart`) and the Patrol E2E tests.
///
/// These match the in-memory users defined in
/// `api/src/test/scala/com/shevchyk/TestApplication.scala`, served by
/// `sbt testServer` (port 8080 by default, or `PORT=8090 sbt testServer`).
library;

// --- TestApplication (in-memory) accounts, password Password123 ---
const String kClientEmail = 'test@example.com';
const String kDriverEmail = 'driver@example.com';
const String kAdminEmail = 'admin@example.com';
const String kPassword = 'Password123';
const String kClientPassword = 'Password123';

// --- Full backend dev-data accounts (Flyway V1001), password password123 ---
// Match api/src/main/resources/db/migration-dev/V1001__Insert_dev_data.sql.
// Used by the e2e_*_test.dart suites running against the full Application.
const String kDevPassword = 'password123';
const String kDevDispatcher = 'dispatcher@dispax.de';
const String kDevSecretary = 'secretary@dispax.de';
const String kDevDriver1 = 'driver1@dispax.de';
const String kDevDriver2 = 'driver2@dispax.de';
const String kDevClient1 = 'client1@bmw.de';
const String kDevClient2 = 'client2@siemens.de';
const String kDevAdmin = 'admin@dispax.de';
const String kDevSuperAdmin = 'superadmin@dispax.de';

// --- Two same-company dispatchers (München), seeded in
// V10__seed_bootstrap_accounts.sql. Used by the multi-dispatcher E2E suites to
// model two dispatchers of one company working the same board (assign races,
// hand-off visibility, concurrent reassign). Both have roles {dispatcher,
// driver} and password `password123`.
const String kDevDispatcherA = 'iryna@dispax.de'; // Iryna Shevchyk
const String kDevDispatcherB = 'yilmaz@dispax.de'; // Yilmaz Oguz
const String kDevDispatcherAId = '1d1d1d1d-1d1d-1d1d-1d1d-1d1d1d1d1d1d';
const String kDevDispatcherBId = '2d2d2d2d-2d2d-2d2d-2d2d-2d2d2d2d2d2d';
