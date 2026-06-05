package com.shevchyk.driver.application

import com.shevchyk.core.config.HereConfig
import zio.*
import zio.http.*
import zio.json.*

trait HereRoutingService:

  def getEtaMinutes(
      originLat: Double,
      originLng: Double,
      destLat: Double,
      destLng: Double
  ): Task[Option[Int]]

object HereRoutingService:

  private case class HereSummary(duration: Int) derives JsonDecoder
  private case class HereSection(summary: HereSummary) derives JsonDecoder
  private case class HereRoute(sections: List[HereSection]) derives JsonDecoder
  private case class HereResponse(routes: List[HereRoute]) derives JsonDecoder

  final class HereRoutingServiceImpl(config: HereConfig, client: Client) extends HereRoutingService:

    override def getEtaMinutes(
        originLat: Double,
        originLng: Double,
        destLat: Double,
        destLng: Double
    ): Task[Option[Int]] =
      if config.apiKey.isEmpty then ZIO.logWarning("HERE routing: apiKey empty").as(None)
      else
        val departureTime = java.time.Instant.now().toString
        val url           =
          s"${config.baseUrl}/v8/routes" +
            s"?origin=$originLat,$originLng" +
            s"&destination=$destLat,$destLng" +
            s"&transportMode=car" +
            s"&departureTime=$departureTime" +
            s"&return=summary" +
            s"&apikey=${config.apiKey}"

        ZIO
          .scoped {
            for {
              response <- client.request(Request.get(url))
              body     <- response.body.asString
              eta      <- ZIO.fromEither(body.fromJson[HereResponse]).mapError(new RuntimeException(_))
              seconds   = eta.routes.headOption
                            .flatMap(_.sections.headOption)
                            .map(_.summary.duration)
              minutes   = seconds.map(s => Math.ceil(s / 60.0).toInt)
            } yield minutes
          }
          .catchAll { err =>
            ZIO.logWarning(s"HERE routing API error: ${err.getMessage}").as(None)
          }

  val layer: ZLayer[HereConfig & Client, Nothing, HereRoutingService] = ZLayer.fromFunction(
    HereRoutingServiceImpl.apply
  )
