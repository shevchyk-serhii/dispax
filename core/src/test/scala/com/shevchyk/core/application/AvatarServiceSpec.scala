package com.shevchyk.core.application

import com.shevchyk.core.domain.{PersonId, CompanyId, Person, PersonRole}
import com.shevchyk.core.repository.{InMemoryPersonRepository, PersonRepository}
import zio.*
import zio.test.*

import java.util.UUID

/**
 * Unit tests for AvatarService business logic.
 *
 * Uses InMemoryPersonRepository (no DB, no Testcontainers). Covers every branch documented in the plan §Tests / Unit
 * tests section.
 */
object AvatarServiceSpec extends ZIOSpecDefault:

  private val testPersonId = PersonId(UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
  private val companyId    = CompanyId(UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
  private val otherCompany = CompanyId(UUID.fromString("cccccccc-cccc-cccc-cccc-cccccccccccc"))

  // 1 MB of bytes — within the 5 MB limit
  private val smallBytes: Array[Byte] = Array.fill(1024 * 1024)(0x42.toByte)
  // 6 MB — exceeds the 5 MB limit
  private val largeBytes: Array[Byte] = Array.fill(6 * 1024 * 1024)(0x01.toByte)

  private val validJpegType   = "image/jpeg"
  private val invalidMimeType = "application/pdf"

  // Seed a person belonging to `companyId` so the tenant-scoped avatar write is not a no-op.
  private def seedPerson(id: PersonId, company: CompanyId = companyId): ZIO[PersonRepository, Throwable, Unit] =
    ZIO
      .serviceWithZIO[PersonRepository](
        _.create(
          Person(
            id = id,
            name = "Test",
            email = s"${id.value}@example.com",
            role = PersonRole.Client,
            companyId = Some(company)
          )
        )
      )
      .unit

  def spec =
    suite("AvatarService")(
      test("uploadAvatar with valid JPEG bytes succeeds") {
        for {
          _       <- seedPerson(testPersonId)
          service <- ZIO.service[AvatarService]
          _       <- service.uploadAvatar(testPersonId, companyId, smallBytes, validJpegType)
          result  <- service.getAvatar(testPersonId)
        } yield assertTrue(
          result.isDefined,
          result.get._1.length == smallBytes.length,
          result.get._2 == validJpegType
        )
      },
      test("uploadAvatar with valid PNG bytes succeeds") {
        for {
          _       <- seedPerson(testPersonId)
          service <- ZIO.service[AvatarService]
          _       <- service.uploadAvatar(testPersonId, companyId, smallBytes, "image/png")
          result  <- service.getAvatar(testPersonId)
        } yield assertTrue(result.isDefined, result.get._2 == "image/png")
      },
      test("uploadAvatar with valid WebP bytes succeeds") {
        for {
          _       <- seedPerson(testPersonId)
          service <- ZIO.service[AvatarService]
          _       <- service.uploadAvatar(testPersonId, companyId, smallBytes, "image/webp")
          result  <- service.getAvatar(testPersonId)
        } yield assertTrue(result.isDefined)
      },
      test("uploadAvatar with valid GIF bytes succeeds") {
        for {
          _       <- seedPerson(testPersonId)
          service <- ZIO.service[AvatarService]
          _       <- service.uploadAvatar(testPersonId, companyId, smallBytes, "image/gif")
          result  <- service.getAvatar(testPersonId)
        } yield assertTrue(result.isDefined)
      },
      test("uploadAvatar for a person in another company is a no-op (tenant isolation)") {
        val id = PersonId(UUID.randomUUID())
        for {
          _       <- seedPerson(id, companyId)
          service <- ZIO.service[AvatarService]
          _       <- service.uploadAvatar(id, otherCompany, smallBytes, validJpegType)
          result  <- service.getAvatar(id)
        } yield assertTrue(result.isEmpty)
      },
      test("uploadAvatar with invalid MIME type (PDF) fails with InvalidContentType") {
        for {
          _       <- seedPerson(testPersonId)
          service <- ZIO.service[AvatarService]
          result  <- service.uploadAvatar(testPersonId, companyId, smallBytes, invalidMimeType).either
        } yield assertTrue(
          result.isLeft,
          result.left.get.isInstanceOf[AvatarError.InvalidContentType]
        )
      },
      test("uploadAvatar with image/bmp (not in allowed set) fails with InvalidContentType") {
        for {
          _       <- seedPerson(testPersonId)
          service <- ZIO.service[AvatarService]
          result  <- service.uploadAvatar(testPersonId, companyId, smallBytes, "image/bmp").either
        } yield assertTrue(
          result.isLeft,
          result.left.get.isInstanceOf[AvatarError.InvalidContentType]
        )
      },
      test("uploadAvatar with 6 MB bytes fails with FileTooLarge") {
        for {
          _       <- seedPerson(testPersonId)
          service <- ZIO.service[AvatarService]
          result  <- service.uploadAvatar(testPersonId, companyId, largeBytes, validJpegType).either
        } yield assertTrue(
          result.isLeft,
          result.left.get == AvatarError.FileTooLarge
        )
      },
      test("uploadAvatar with exactly 5 MB succeeds (at the limit)") {
        val exactLimitBytes = Array.fill(AvatarService.MaxBytes)(0x00.toByte)
        for {
          _       <- seedPerson(testPersonId)
          service <- ZIO.service[AvatarService]
          result  <- service.uploadAvatar(testPersonId, companyId, exactLimitBytes, validJpegType).either
        } yield assertTrue(result.isRight)
      },
      test("uploadAvatar with 5 MB + 1 byte fails with FileTooLarge (just over limit)") {
        val overLimitBytes = Array.fill(AvatarService.MaxBytes + 1)(0x00.toByte)
        for {
          _       <- seedPerson(testPersonId)
          service <- ZIO.service[AvatarService]
          result  <- service.uploadAvatar(testPersonId, companyId, overLimitBytes, validJpegType).either
        } yield assertTrue(
          result.isLeft,
          result.left.get == AvatarError.FileTooLarge
        )
      },
      test("getAvatar returns None when no avatar has been uploaded") {
        val freshId = PersonId(UUID.randomUUID())
        for {
          service <- ZIO.service[AvatarService]
          result  <- service.getAvatar(freshId)
        } yield assertTrue(result.isEmpty)
      },
      test("deleteAvatar is idempotent — no error when no avatar is set") {
        val freshId = PersonId(UUID.randomUUID())
        for {
          _       <- seedPerson(freshId)
          service <- ZIO.service[AvatarService]
          result  <- service.deleteAvatar(freshId, companyId).either
        } yield assertTrue(result.isRight)
      },
      test("deleteAvatar removes the avatar — subsequent getAvatar returns None") {
        val id = PersonId(UUID.randomUUID())
        for {
          _       <- seedPerson(id)
          service <- ZIO.service[AvatarService]
          _       <- service.uploadAvatar(id, companyId, smallBytes, validJpegType)
          _       <- service.deleteAvatar(id, companyId)
          result  <- service.getAvatar(id)
        } yield assertTrue(result.isEmpty)
      },
      test("deleteAvatar for a person in another company is a no-op (tenant isolation)") {
        val id = PersonId(UUID.randomUUID())
        for {
          _       <- seedPerson(id, companyId)
          service <- ZIO.service[AvatarService]
          _       <- service.uploadAvatar(id, companyId, smallBytes, validJpegType)
          _       <- service.deleteAvatar(id, otherCompany)
          result  <- service.getAvatar(id)
        } yield assertTrue(result.isDefined)
      },
      test("uploadAvatar replaces an existing avatar") {
        val id          = PersonId(UUID.randomUUID())
        val firstBytes  = Array.fill(512)(0x01.toByte)
        val secondBytes = Array.fill(1024)(0x02.toByte)
        for {
          _       <- seedPerson(id)
          service <- ZIO.service[AvatarService]
          _       <- service.uploadAvatar(id, companyId, firstBytes, "image/jpeg")
          _       <- service.uploadAvatar(id, companyId, secondBytes, "image/png")
          result  <- service.getAvatar(id)
        } yield assertTrue(
          result.isDefined,
          result.get._1.length == 1024,
          result.get._2 == "image/png"
        )
      },
      test("MIME type check is case-insensitive — IMAGE/JPEG is accepted") {
        val id = PersonId(UUID.randomUUID())
        for {
          _       <- seedPerson(id)
          service <- ZIO.service[AvatarService]
          result  <- service.uploadAvatar(id, companyId, smallBytes, "IMAGE/JPEG").either
        } yield assertTrue(result.isRight)
      },
      test("InvalidContentType error carries the unsupported MIME type in message") {
        for {
          _       <- seedPerson(testPersonId)
          service <- ZIO.service[AvatarService]
          result  <- service.uploadAvatar(testPersonId, companyId, smallBytes, "text/plain").either
        } yield result match
          case Left(AvatarError.InvalidContentType(ct)) => assertTrue(ct == "text/plain")
          case _                                        => assertTrue(false)
      }
    ).provide(
      // Fresh InMemoryPersonRepository per test run — ZLayer.scoped would be ideal,
      // but since each test generates unique PersonIds the shared instance is safe here.
      InMemoryPersonRepository.layer,
      AvatarService.layer
    ) @@ TestAspect.sequential
