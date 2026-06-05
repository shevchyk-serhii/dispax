package com.shevchyk.core.application

import com.shevchyk.core.config.HereConfig
import com.shevchyk.core.domain.Location
import zio.*
import zio.http.*
import zio.json.*

trait GeocodingService:
  def geocode(address: String): Task[Option[(Double, Double)]]

  def enrichLocation(location: Location): Task[Location] =
    if location.latitude.isDefined && location.longitude.isDefined then ZIO.succeed(location)
    else
      geocode(location.address).map {
        case Some((lat, lng)) => location.copy(latitude = Some(lat), longitude = Some(lng))
        case None             => location
      }

object GeocodingService:

  private case class HerePosition(lat: Double, lng: Double) derives JsonDecoder
  private case class HereAddress(label: String) derives JsonDecoder
  private case class HereItem(position: HerePosition, address: HereAddress) derives JsonDecoder
  private case class HereGeocodeResponse(items: List[HereItem]) derives JsonDecoder

  final class HereGeocodingServiceImpl(config: HereConfig, client: Client) extends GeocodingService:

    override def geocode(address: String): Task[Option[(Double, Double)]] =
      if config.apiKey.isEmpty then ZIO.succeed(None)
      else
        val encoded = java.net.URLEncoder.encode(address, "UTF-8")
        val url     = s"https://geocode.search.hereapi.com/v1/geocode?q=$encoded&apikey=${config.apiKey}"

        ZIO
          .scoped {
            for {
              response <- client.request(Request.get(url))
              body     <- response.body.asString
              result   <- ZIO.fromEither(body.fromJson[HereGeocodeResponse]).mapError(new RuntimeException(_))
              coords    = result.items.headOption.map(i => (i.position.lat, i.position.lng))
            } yield coords
          }
          .catchAll { err =>
            ZIO.logWarning(s"HERE geocoding error for '$address': ${err.getMessage}").as(None)
          }

  val layer: ZLayer[HereConfig & Client, Nothing, GeocodingService] = ZLayer.fromFunction(
    HereGeocodingServiceImpl.apply
  )

  val noop: ZLayer[Any, Nothing, GeocodingService] = ZLayer.succeed(
    new GeocodingService:
      def geocode(address: String): Task[Option[(Double, Double)]] = ZIO.succeed(None)
  )
