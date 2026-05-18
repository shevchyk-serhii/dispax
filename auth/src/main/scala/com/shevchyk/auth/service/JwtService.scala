package com.shevchyk.auth.service

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.domain.*
import com.shevchyk.core.domain.{Person, PersonRole}
import pdi.jwt.{Jwt, JwtAlgorithm, JwtClaim}
import zio.*
import zio.json.*
import java.time.Instant
import java.util.UUID

final case class JwtPayload(
    userId: UUID,
    email: String,
    role: PersonRole,
    companyId: Option[UUID] = None,
    clientCompanyId: Option[UUID] = None,
    iat: Long,                       // issued at
    exp: Long,                       // expires at
    originalIat: Option[Long] = None // original session start (for absolute expiration)
)

object JwtPayload:
  implicit val encoder: JsonEncoder[JwtPayload] = DeriveJsonEncoder.gen[JwtPayload]
  implicit val decoder: JsonDecoder[JwtPayload] = DeriveJsonDecoder.gen[JwtPayload]

trait JwtService:
  def generateToken(person: Person): ZIO[Any, JwtError, String]
  def validateToken(token: String): ZIO[Any, JwtError, JwtPayload]
  def refreshToken(token: String): ZIO[Any, JwtError, String]

class JwtServiceImpl(config: JwtConfig) extends JwtService:

  private val algorithm = JwtAlgorithm.HS256

  override def generateToken(person: Person): ZIO[Any, JwtError, String] = ZIO
    .attempt {
      val now = Instant.now()
      val exp = now.plusSeconds(config.expirationTime.toSeconds)

      val payload = JwtPayload(
        userId = person.id.value,
        email = person.email,
        role = person.role,
        companyId = person.companyId.map(_.value),
        clientCompanyId = person.clientCompanyId.map(_.value),
        iat = now.getEpochSecond,
        exp = exp.getEpochSecond,
        originalIat = Some(now.getEpochSecond)
      )

      val claim = JwtClaim(
        content = payload.toJson,
        issuer = Some(config.issuer),
        audience = Some(Set(config.audience)),
        issuedAt = Some(now.getEpochSecond),
        expiration = Some(exp.getEpochSecond)
      )

      Jwt.encode(claim, config.secret, algorithm)
    }
    .mapError(ex => JwtGenerationError(Option(ex.getMessage).getOrElse(ex.toString)))

  override def validateToken(token: String): ZIO[Any, JwtError, JwtPayload] =
    for {
      decoded <- ZIO
                   .attempt {
                     Jwt.decode(token, config.secret, Seq(algorithm))
                   }
                   .mapError(ex => InvalidTokenError(Option(ex.getMessage).getOrElse(ex.toString)))

      claim <- ZIO.fromTry(decoded).mapError(ex => InvalidTokenError(Option(ex.getMessage).getOrElse(ex.toString)))

      payload <- ZIO
                   .fromEither(
                     claim.content.fromJson[JwtPayload]
                   )
                   .mapError(error => InvalidPayloadError(error))

      _ <-
        ZIO.when(payload.exp < Instant.now().getEpochSecond)(
          ZIO.fail(ExpiredTokenError("Token has expired"))
        )
    } yield payload

  override def refreshToken(token: String): ZIO[Any, JwtError, String] =
    for {
      payload <- validateToken(token)

      _           <-
        ZIO.when(payload.exp - Instant.now().getEpochSecond > 3600)(
          ZIO.fail(TokenNotEligibleForRefresh("Token not eligible for refresh yet"))
        )

      // Enforce absolute session expiration — require re-login after maxSessionDuration
      sessionStart = payload.originalIat.getOrElse(payload.iat)
      _           <-
        ZIO.when(Instant.now().getEpochSecond - sessionStart > config.maxSessionDuration.toSeconds)(
          ZIO.fail(ExpiredTokenError("Session has exceeded maximum duration. Please log in again."))
        )

      now = Instant.now()
      exp = now.plusSeconds(config.expirationTime.toSeconds)

      refreshedPayload = payload.copy(
                           iat = now.getEpochSecond,
                           exp = exp.getEpochSecond,
                           companyId = payload.companyId,
                           originalIat = Some(sessionStart)
                         )

      claim = JwtClaim(
                content = refreshedPayload.toJson,
                issuer = Some(config.issuer),
                audience = Some(Set(config.audience)),
                issuedAt = Some(now.getEpochSecond),
                expiration = Some(exp.getEpochSecond)
              )

      newToken <- ZIO
                    .attempt {
                      Jwt.encode(claim, config.secret, algorithm)
                    }
                    .mapError(ex => JwtGenerationError(Option(ex.getMessage).getOrElse(ex.toString)))

    } yield newToken

object JwtService:
  val live: ZLayer[JwtConfig, Nothing, JwtService] = ZLayer.fromFunction(JwtServiceImpl.apply)
