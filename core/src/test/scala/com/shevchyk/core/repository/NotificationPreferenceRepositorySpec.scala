package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.test.*
import zio.*
import java.time.Instant

object NotificationPreferenceRepositorySpec extends ZIOSpecDefault {

  val personId1 = PersonId.generate()
  val personId2 = PersonId.generate()

  def makePreference(
      personId: PersonId = personId1,
      rideUpdates: Boolean = true,
      chatMessages: Boolean = true,
      emailNotifications: Boolean = false,
      quietHoursStart: Option[String] = None,
      quietHoursEnd: Option[String] = None
  ): NotificationPreference = NotificationPreference(
    id = NotificationPreferenceId.generate(),
    personId = personId,
    rideUpdates = rideUpdates,
    chatMessages = chatMessages,
    emailNotifications = emailNotifications,
    quietHoursStart = quietHoursStart,
    quietHoursEnd = quietHoursEnd,
    updatedAt = Instant.now()
  )

  val layers = NotificationPreferenceRepository.inMemory

  def spec =
    suite("NotificationPreferenceRepository")(
      suite("findByPersonId")(
        test("returns None when no preference exists") {
          for {
            repo  <- ZIO.service[NotificationPreferenceRepository]
            found <- repo.findByPersonId(personId1)
          } yield assertTrue(found.isEmpty)
        }.provide(layers),
        test("returns preference after upsert") {
          val pref = makePreference()
          for {
            repo  <- ZIO.service[NotificationPreferenceRepository]
            _     <- repo.upsert(pref)
            found <- repo.findByPersonId(personId1)
          } yield assertTrue(found.contains(pref))
        }.provide(layers),
        test("returns None for different person") {
          val pref = makePreference(personId = personId1)
          for {
            repo  <- ZIO.service[NotificationPreferenceRepository]
            _     <- repo.upsert(pref)
            found <- repo.findByPersonId(personId2)
          } yield assertTrue(found.isEmpty)
        }.provide(layers)
      ),
      suite("upsert")(
        test("inserts new preference") {
          val pref = makePreference(emailNotifications = true)
          for {
            repo   <- ZIO.service[NotificationPreferenceRepository]
            result <- repo.upsert(pref)
          } yield assertTrue(result.emailNotifications)
        }.provide(layers),
        test("overwrites existing preference on second upsert") {
          val pref1 = makePreference(rideUpdates = true)
          val pref2 = makePreference(rideUpdates = false)
          for {
            repo  <- ZIO.service[NotificationPreferenceRepository]
            _     <- repo.upsert(pref1)
            _     <- repo.upsert(pref2)
            found <- repo.findByPersonId(personId1)
          } yield assertTrue(!found.get.rideUpdates)
        }.provide(layers),
        test("stores quiet hours correctly") {
          val pref = makePreference(quietHoursStart = Some("22:00"), quietHoursEnd = Some("07:00"))
          for {
            repo  <- ZIO.service[NotificationPreferenceRepository]
            _     <- repo.upsert(pref)
            found <- repo.findByPersonId(personId1)
          } yield assertTrue(
            found.flatMap(_.quietHoursStart).contains("22:00") &&
              found.flatMap(_.quietHoursEnd).contains("07:00")
          )
        }.provide(layers),
        test("different persons have independent preferences") {
          val pref1 = makePreference(personId = personId1, emailNotifications = true)
          val pref2 = makePreference(personId = personId2, emailNotifications = false)
          for {
            repo   <- ZIO.service[NotificationPreferenceRepository]
            _      <- repo.upsert(pref1)
            _      <- repo.upsert(pref2)
            found1 <- repo.findByPersonId(personId1)
            found2 <- repo.findByPersonId(personId2)
          } yield assertTrue(
            found1.get.emailNotifications &&
              !found2.get.emailNotifications
          )
        }.provide(layers)
      )
    )
}
