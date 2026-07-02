package com.shevchyk

import io.cucumber.junit.{Cucumber, CucumberOptions}
import org.junit.runner.RunWith

/*
 * Sharded Cucumber runners for PARALLEL execution.
 *
 * The whole BDD suite (343 scenarios) runs sequentially against one shared in-memory
 * TestApplication, so a single `sbt cucumber` is ~60s. These three runners split the
 * feature files into three balanced groups (~114 scenarios each) so they can run in
 * three SEPARATE sbt JVMs, each owning its OWN TestApplication on its OWN port
 * (the PORT env var, read by ApiStepDefinitions). Separate processes → separate
 * servers → the shared-state isolation that the sequential suite relies on is fully
 * preserved; nothing races. See `make test-bdd-parallel`.
 *
 * The JUnit4 Cucumber engine ignores the `cucumber.features` system property, so the
 * file list must live in each annotation. The canonical `CucumberRunner` (which runs
 * ALL features) remains the source of truth and the CI gate; these shards are a
 * faster local/CI option. `CucumberShardCoverageSpec` guards that the union of the
 * three shard lists equals every feature file on disk, so a newly added .feature can
 * never silently fall out of the sharded run.
 *
 * Balance is by scenario count (greedy longest-processing-time): 115 / 114 / 114.
 * When adding a feature file, append it to the lightest shard AND keep
 * CucumberShardCoverageSpec green.
 */

@RunWith(classOf[Cucumber])
@CucumberOptions(
  features = Array(
    "classpath:features/27_rides_extended.feature",
    "classpath:features/36_driver_schedule_visibility.feature",
    "classpath:features/20_ride_pools.feature",
    "classpath:features/29_stats.feature",
    "classpath:features/09_frontend_ride_expectations.feature",
    "classpath:features/02_ride_management.feature",
    "classpath:features/19_notifications.feature",
    "classpath:features/34_airport_checkpoints.feature",
    "classpath:features/10_frontend_user_expectations.feature",
    "classpath:features/23_driver_extended.feature",
    "classpath:features/08_frontend_auth_expectations.feature",
    "classpath:features/13_blacklist.feature",
    "classpath:features/24_client_addresses.feature",
    "classpath:features/41_dispatcher_handoff.feature",
    "classpath:features/37_dispatcher_can_drive.feature"
  ),
  glue = Array("com.shevchyk.steps", "com.shevchyk"),
  plugin = Array("pretty", "html:target/cucumber-reports/shard1-html"),
  tags = "@api",
  stepNotifications = true
)
class CucumberShard1Runner

@RunWith(classOf[Cucumber])
@CucumberOptions(
  features = Array(
    "classpath:features/32_billing.feature",
    "classpath:features/40_ride_price_and_bulk.feature",
    "classpath:features/34_superadmin_companies.feature",
    "classpath:features/40_driver_unavailability.feature",
    "classpath:features/11_flight_information.feature",
    "classpath:features/04_authentication.feature",
    "classpath:features/35_superadmin_analytics.feature",
    "classpath:features/40_user_language_selection.feature",
    "classpath:features/18_geofences.feature",
    "classpath:features/03_driver_operations.feature",
    "classpath:features/28_ride_templates.feature",
    "classpath:features/21_sessions.feature",
    "classpath:features/39_ride_estimate.feature",
    "classpath:features/16_emergency.feature",
    "classpath:features/31_websocket.feature"
  ),
  glue = Array("com.shevchyk.steps", "com.shevchyk"),
  plugin = Array("pretty", "html:target/cucumber-reports/shard2-html"),
  tags = "@api",
  stepNotifications = true
)
class CucumberShard2Runner

@RunWith(classOf[Cucumber])
@CucumberOptions(
  features = Array(
    "classpath:features/33_security.feature",
    "classpath:features/07_error_handling.feature",
    "classpath:features/06_notification_system.feature",
    "classpath:features/22_users_extended.feature",
    "classpath:features/05_company_management.feature",
    "classpath:features/38_user_avatar.feature",
    "classpath:features/26_export.feature",
    "classpath:features/40_airport_pickup_time.feature",
    "classpath:features/14_client_companies.feature",
    "classpath:features/30_schedules.feature",
    "classpath:features/17_gdpr.feature",
    "classpath:features/15_company_settings.feature",
    "classpath:features/25_expenses.feature",
    "classpath:features/12_audit.feature",
    "classpath:features/01_health_check.feature"
  ),
  glue = Array("com.shevchyk.steps", "com.shevchyk"),
  plugin = Array("pretty", "html:target/cucumber-reports/shard3-html"),
  tags = "@api",
  stepNotifications = true
)
class CucumberShard3Runner
