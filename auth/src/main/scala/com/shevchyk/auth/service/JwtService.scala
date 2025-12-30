package com.shevchyk.auth.service

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.domain.*
import pdi.jwt.{Jwt, JwtAlgorithm, JwtClaim}
import zio.*
import zio.json.*
import java.time.Instant
import java.util.UUID

final case class JwtPayload(
    userId: UUID,
    email: String,
    role: UserRole,
    companyId: Option[UUID] = None,
    iat: Long, // issued at
    exp: Long  // expires at
)

object JwtPayload:
  implicit val encoder: JsonEncoder[JwtPayload] = DeriveJsonEncoder.gen[JwtPayload]
  implicit val decoder: JsonDecoder[JwtPayload] = DeriveJsonDecoder.gen[JwtPayload]

  implicit val userRoleEncoder: JsonEncoder[UserRole] = JsonEncoder[String].contramap(_.toString)

  implicit val userRoleDecoder: JsonDecoder[UserRole] = JsonDecoder[String].mapOrFail(s =>
    scala.util.Try(UserRole.valueOf(s)).toEither.left.map(_ => s"Invalid role: $s")
  )

trait JwtService:
  def generateToken(user: User, companyId: Option[UUID] = None): ZIO[Any, JwtError, String]
  def validateToken(token: String): ZIO[Any, JwtError, JwtPayload]
  def refreshToken(token: String): ZIO[Any, JwtError, String]

class JwtServiceImpl(config: JwtConfig) extends JwtService:

  private val algorithm = JwtAlgorithm.HS256

  override def generateToken(user: User, companyId: Option[UUID] = None): ZIO[Any, JwtError, String] = ZIO
    .attempt {
      val now = Instant.now()
      val exp = now.plusSeconds(config.expirationTime.toSeconds)

      val payload = JwtPayload(
        userId = user.id,
        email = user.email,
        role = user.role,
        companyId = companyId,
        iat = now.getEpochSecond,
        exp = exp.getEpochSecond
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
    .mapError(ex => JwtGenerationError(ex.getMessage))

  override def validateToken(token: String): ZIO[Any, JwtError, JwtPayload] =
    for {
      decoded <- ZIO
                   .attempt {
                     Jwt.decode(token, config.secret, Seq(algorithm))
                   }
                   .mapError(ex => InvalidTokenError(ex.getMessage))

      claim <- ZIO.fromTry(decoded).mapError(ex => InvalidTokenError(ex.getMessage))

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

      _ <-
        ZIO.when(payload.exp - Instant.now().getEpochSecond > 3600)(
          ZIO.fail(TokenNotEligibleForRefresh("Token not eligible for refresh yet"))
        )

      now = Instant.now()
      exp = now.plusSeconds(config.expirationTime.toSeconds)

      refreshedPayload = payload.copy(
                           iat = now.getEpochSecond,
                           exp = exp.getEpochSecond,
                           companyId = payload.companyId
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
                    .mapError(ex => JwtGenerationError(ex.getMessage))

    } yield newToken

object JwtService:
  val live: ZLayer[JwtConfig, Nothing, JwtService] = ZLayer.fromFunction(JwtServiceImpl.apply)
