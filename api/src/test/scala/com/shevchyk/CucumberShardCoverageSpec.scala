package com.shevchyk

import io.cucumber.junit.CucumberOptions
import zio.test.*

import java.nio.file.{Files, Paths}
import scala.jdk.CollectionConverters.*

/**
 * Guards that the three parallel Cucumber shards (`CucumberShard1/2/3Runner`) collectively cover EXACTLY every feature
 * file the sequential `CucumberRunner` runs — no file silently dropped, no file run twice.
 *
 * Why this matters: the JUnit4 Cucumber engine can't take a feature path from a system property, so each shard
 * hard-codes its file list in its `@CucumberOptions`. Without this guard, adding a new `.feature` (or renaming one)
 * would quietly exclude it from `make test-bdd-parallel` while the full `sbt cucumber` still ran it — a coverage hole
 * invisible until a regression slipped through the parallel run. This spec fails the moment the union of shard lists
 * diverges from disk.
 */
object CucumberShardCoverageSpec extends ZIOSpecDefault {

  private val featuresDir = Paths.get("api/src/test/resources/features")

  /**
   * Feature file names declared in a shard runner's `@CucumberOptions(features = ...)`.
   */
  private def shardFeatures(cls: Class[?]): List[String] = Option(cls.getAnnotation(classOf[CucumberOptions]))
    .map(_.features().toList)
    .getOrElse(Nil)
    .map(_.stripPrefix("classpath:features/"))

  /**
   * Actual `.feature` files on disk (the set the canonical `CucumberRunner` globs via `classpath:features`).
   */
  private def featuresOnDisk: List[String] =
    Files
      .list(featuresDir)
      .iterator()
      .asScala
      .map(_.getFileName.toString)
      .filter(_.endsWith(".feature"))
      .toList

  def spec =
    suite("CucumberShardCoverageSpec")(
      test("the three shards together cover every feature file exactly once") {
        val shard1 = shardFeatures(classOf[CucumberShard1Runner])
        val shard2 = shardFeatures(classOf[CucumberShard2Runner])
        val shard3 = shardFeatures(classOf[CucumberShard3Runner])
        val union  = shard1 ++ shard2 ++ shard3

        val onDisk     = featuresOnDisk.toSet
        val covered    = union.toSet
        val missing    = onDisk -- covered // on disk but in no shard → would be skipped in parallel run
        val unknown    = covered -- onDisk // referenced by a shard but not on disk → stale/typo
        val duplicates = union.groupBy(identity).collect { case (f, fs) if fs.size > 1 => f }.toSet

        assertTrue(
          missing.isEmpty,    // a new .feature must be added to a shard
          unknown.isEmpty,    // a shard must not reference a non-existent file
          duplicates.isEmpty, // no feature may run in two shards
          covered == onDisk
        )
      }
    )
}
