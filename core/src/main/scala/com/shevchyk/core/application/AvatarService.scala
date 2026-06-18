package com.shevchyk.core.application

import com.shevchyk.core.domain.PersonId
import com.shevchyk.core.repository.PersonRepository
import zio.*

// Domain errors for avatar operations — kept minimal, mapped to HTTP status in the handler.
sealed trait AvatarError extends Throwable:
  def message: String

object AvatarError:

  final case class InvalidContentType(contentType: String) extends AvatarError:

    override def message: String    =
      s"Unsupported content type: $contentType. Allowed: image/jpeg, image/png, image/gif, image/webp"
    override def getMessage: String = message

  case object FileTooLarge extends AvatarError:
    override def message: String    = "Avatar file exceeds the 5 MB limit"
    override def getMessage: String = message

trait AvatarService:
  def uploadAvatar(personId: PersonId, bytes: Array[Byte], contentType: String): IO[AvatarError, Unit]
  def getAvatar(personId: PersonId): Task[Option[(Array[Byte], String)]]
  def deleteAvatar(personId: PersonId): Task[Unit]

object AvatarService:
  val MaxBytes: Int             = 5 * 1024 * 1024 // 5 MB
  val AllowedTypes: Set[String] = Set("image/jpeg", "image/png", "image/gif", "image/webp")

  val layer: ZLayer[PersonRepository, Nothing, AvatarService] = ZLayer.fromFunction(AvatarServiceImpl.apply)

  def uploadAvatar(personId: PersonId, bytes: Array[Byte], contentType: String): ZIO[AvatarService, AvatarError, Unit] =
    ZIO.serviceWithZIO[AvatarService](_.uploadAvatar(personId, bytes, contentType))

  def getAvatar(personId: PersonId): ZIO[AvatarService, Throwable, Option[(Array[Byte], String)]] = ZIO
    .serviceWithZIO[AvatarService](_.getAvatar(personId))

  def deleteAvatar(personId: PersonId): ZIO[AvatarService, Throwable, Unit] = ZIO.serviceWithZIO[AvatarService](
    _.deleteAvatar(personId)
  )

final case class AvatarServiceImpl(repo: PersonRepository) extends AvatarService:

  override def uploadAvatar(personId: PersonId, bytes: Array[Byte], contentType: String): IO[AvatarError, Unit] =
    val normalizedContentType = contentType.toLowerCase
    for
      _ <- ZIO
             .fail(AvatarError.InvalidContentType(contentType))
             .unless(AvatarService.AllowedTypes.contains(normalizedContentType))
      _ <- ZIO
             .fail(AvatarError.FileTooLarge)
             .when(bytes.length > AvatarService.MaxBytes)
      _ <- repo.setAvatar(personId, bytes, normalizedContentType).orDie
    yield ()

  override def getAvatar(personId: PersonId): Task[Option[(Array[Byte], String)]] = repo.getAvatar(personId)

  override def deleteAvatar(personId: PersonId): Task[Unit] = repo.deleteAvatar(personId)
