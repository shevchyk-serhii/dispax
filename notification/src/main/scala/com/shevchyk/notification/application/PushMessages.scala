package com.shevchyk.notification.application

/**
 * Localized texts for push notifications, resolved by the recipient's `Person.preferredLanguage` (en/de/uk — the same
 * language set the email channel supports via `EmailTemplateService`). Unknown or missing languages fall back to
 * English.
 *
 * Currently covers the ride-lifecycle notifications (assignment, reassignment, started/completed/cancelled) — the most
 * frequent pushes. Follow-up: dispatcher alerts (ride_rejected, eta_at_risk, geofence), ride_updated, ride_created,
 * airport_checkpoint and the confirmation-request reminder still go out in English.
 */
object PushMessages:

  val DefaultLanguage: String = "en"

  val SupportedLanguages: Set[String] = Set("en", "de", "uk")

  /**
   * A localized push text: title + body.
   */
  final case class Text(title: String, body: String)

  /**
   * Normalizes a raw preferred-language value to a supported language, falling back to English.
   */
  def resolveLanguage(raw: Option[String]): String = raw
    .map(_.trim.toLowerCase)
    .filter(SupportedLanguages.contains)
    .getOrElse(DefaultLanguage)

  // -- Ride assignment -------------------------------------------------------

  def rideAssignedDriver(lang: String, priceSuffix: String): Text =
    lang match
      case "de" => Text("Neue Fahrt zugewiesen", "Ihnen wurde eine neue Fahrt zugewiesen." + priceSuffix)
      case "uk" => Text("Призначено нову поїздку", "Вам призначено нову поїздку." + priceSuffix)
      case _    => Text("New Ride Assigned", "A new ride has been assigned to you." + priceSuffix)

  def rideAssignedClient(lang: String, priceSuffix: String): Text =
    lang match
      case "de" => Text("Fahrer zugewiesen", "Ihrer Fahrt wurde ein Fahrer zugewiesen." + priceSuffix)
      case "uk" => Text("Водія призначено", "Вашій поїздці призначено водія." + priceSuffix)
      case _    => Text("Driver Assigned", "A driver has been assigned to your ride." + priceSuffix)

  def rideReassignedOldDriver(lang: String): Text =
    lang match
      case "de" => Text("Fahrt neu zugewiesen", "Eine Ihnen zugewiesene Fahrt wurde einem anderen Fahrer übertragen.")
      case "uk" => Text("Поїздку перепризначено", "Поїздку, призначену вам, передано іншому водієві.")
      case _    => Text("Ride Reassigned", "A ride previously assigned to you has been reassigned to another driver.")

  // -- Ride status changes ---------------------------------------------------

  def rideStartedDriver(lang: String): Text =
    lang match
      case "de" => Text("Fahrt gestartet", "Ihre Fahrt ist jetzt im Gange.")
      case "uk" => Text("Поїздку розпочато", "Ваша поїздка зараз триває.")
      case _    => Text("Ride Started", "Your ride is now in progress.")

  def rideStartedClient(lang: String): Text =
    lang match
      case "de" => Text("Fahrt gestartet", "Ihr Fahrer hat die Fahrt begonnen.")
      case "uk" => Text("Поїздку розпочато", "Ваш водій розпочав поїздку.")
      case _    => Text("Ride Started", "Your driver has started the ride.")

  def rideCompleted(lang: String): Text =
    lang match
      case "de" => Text("Fahrt abgeschlossen", "Ihre Fahrt wurde abgeschlossen.")
      case "uk" => Text("Поїздку завершено", "Вашу поїздку завершено.")
      case _    => Text("Ride Completed", "Your ride has been completed.")

  def rideCancelledDriver(lang: String): Text =
    lang match
      case "de" => Text("Fahrt storniert", "Eine Ihnen zugewiesene Fahrt wurde storniert.")
      case "uk" => Text("Поїздку скасовано", "Призначену вам поїздку скасовано.")
      case _    => Text("Ride Cancelled", "A ride assigned to you has been cancelled.")

  def rideCancelledClient(lang: String): Text =
    lang match
      case "de" => Text("Fahrt storniert", "Ihre Fahrt wurde storniert.")
      case "uk" => Text("Поїздку скасовано", "Вашу поїздку скасовано.")
      case _    => Text("Ride Cancelled", "Your ride has been cancelled.")
