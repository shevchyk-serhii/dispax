package com.shevchyk.infrastructure.testdata

import com.shevchyk.domain.model.*
import java.time.LocalDateTime
import scala.util.Random

object TestDataGenerator:

  private val random = new Random()

  private val ukrainianCities = List(
    ("Kyiv", 50.4501, 30.5234),
    ("Kharkiv", 49.9935, 36.2304),
    ("Odesa", 46.4825, 30.7233),
    ("Dnipro", 48.4647, 35.0462),
    ("Lviv", 49.8397, 24.0297),
    ("Zaporizhzhia", 47.8388, 35.1396),
    ("Kryvyi Rih", 47.9077, 33.3915),
    ("Mykolaiv", 46.9659, 32.0066),
    ("Mariupol", 47.0971, 37.5431),
    ("Vinnytsia", 49.2331, 28.4682)
  )

  private val airports = List(
    ("Boryspil International Airport", 50.3450, 30.8947),
    ("Kyiv International Airport", 50.4020, 30.4516),
    ("Kharkiv International Airport", 49.9248, 36.2899),
    ("Lviv Danylo Halytskyi International Airport", 49.8125, 23.9561),
    ("Odesa International Airport", 46.4268, 30.6765)
  )

  private val firstNames = List(
    "Олександр",
    "Максим",
    "Богдан",
    "Дмитро",
    "Михайло",
    "Андрій",
    "Владислав",
    "Назар",
    "Іван",
    "Роман",
    "Анна",
    "Марія",
    "Вікторія",
    "Дарія",
    "Софія",
    "Олена",
    "Катерина",
    "Юлія",
    "Наталія",
    "Ірина"
  )

  private val lastNames = List(
    "Коваленко",
    "Шевченко",
    "Бойко",
    "Ткаченко",
    "Кравченко",
    "Олійник",
    "Шевчук",
    "Поліщук",
    "Гавриленко",
    "Мельник",
    "Клименко",
    "Павленко",
    "Марченко",
    "Лисенко",
    "Петренко"
  )

  def generateLocation(includeAirport: Boolean = false): Location =
    if includeAirport && random.nextBoolean() then
      val (name, lat, lon) = airports(random.nextInt(airports.length))
      Location(name, Some(lat), Some(lon))
    else
      val (name, lat, lon) = ukrainianCities(random.nextInt(ukrainianCities.length))
      val street           = s"вул. ${generateStreetName()}, ${random.nextInt(200) + 1}"
      Location(s"$name, $street", Some(lat + random.nextGaussian() * 0.01), Some(lon + random.nextGaussian() * 0.01))

  private def generateStreetName(): String =
    val streetTypes = List("Хрещатик", "Незалежності", "Миру", "Шевченка", "Франка", "Леніна", "Центральна", "Соборна")
    streetTypes(random.nextInt(streetTypes.length))

  def generatePerson(role: PersonRole, companyId: Option[CompanyId] = None): Person =
    val firstName = firstNames(random.nextInt(firstNames.length))
    val lastName  = lastNames(random.nextInt(lastNames.length))
    val email     = s"${firstName.toLowerCase}.${lastName.toLowerCase}@oktopus.ua"

    Person(
      id = PersonId(random.nextInt(100000)),
      name = s"$firstName $lastName",
      email = email,
      role = role,
      companyId = companyId,
      passwordHash = Some("$2a$10$dummy.hash.for.testing"),
      licenseNumber = if role == PersonRole.driver then Some(s"DL${random.nextInt(1000000)}") else None,
      phone = Some(s"+380${random.nextInt(100000000).toString.padTo(9, '0')}")
    )

  def generateDriver(companyId: CompanyId): Driver =
    val person = generatePerson(PersonRole.driver, Some(companyId))
    Driver(
      id = person.id,
      name = person.name,
      currentLocation = generateLocation(),
      status = if random.nextDouble() < 0.7 then DriverStatus.Available else DriverStatus.Busy,
      companyId = companyId
    )

  def generateTariff(): Tariff =
    val baseAmount = 30.0 + random.nextDouble() * 20.0 // 30-50 UAH
    Tariff(
      basePrice = Price(baseAmount, "UAH"),
      pricePerKm = Price(8.0 + random.nextDouble() * 4.0, "UAH"), // 8-12 UAH per km
      airportSurcharge = Price(50.0 + random.nextDouble() * 30.0, "UAH"), // 50-80 UAH
      nightSurcharge = Price(20.0 + random.nextDouble() * 15.0, "UAH") // 20-35 UAH
    )

  def generateRide(
      clientId: PersonId,
      creatorId: PersonId,
      companyId: CompanyId,
      driverId: Option[PersonId] = None
  ): Ride =
    val from       = generateLocation(includeAirport = true)
    val to         = generateLocation(includeAirport = true)
    val baseTime   = LocalDateTime.now()
    val pickupTime = baseTime.plusHours(random.nextInt(48)).plusMinutes(random.nextInt(60))

    val flightInfo =
      if from.address.toLowerCase.contains("airport") || to.address.toLowerCase.contains("airport") then
        if random.nextDouble() < 0.6 then
          Some(
            FlightInfo(
              flightNumber = s"PS${random.nextInt(9000) + 1000}",
              flightTime = pickupTime.plusMinutes(random.nextInt(120) - 60),
              gate = Some(s"${(random.nextInt(26) + 65).toChar}${random.nextInt(20) + 1}"),
              terminal = Some(s"Terminal ${random.nextInt(3) + 1}"),
              status = List("On Time", "Delayed", "Boarding", "Arrived")(random.nextInt(4)),
              isArrival = from.address.toLowerCase.contains("airport")
            )
          )
        else None
      else None

    val distance          = Distance(from.distanceTo(to))
    val tariff            = generateTariff()
    val isAirportTransfer = from.address.toLowerCase.contains("airport") || to.address.toLowerCase.contains("airport")
    val isNight           = pickupTime.getHour < 6 || pickupTime.getHour > 22

    val price = Some(
      Price(
        tariff.basePrice.amount +
          (distance.kilometers * tariff.pricePerKm.amount) +
          (if isAirportTransfer then tariff.airportSurcharge.amount else 0.0) +
          (if isNight then tariff.nightSurcharge.amount else 0.0),
        tariff.basePrice.currency
      )
    )

    val status =
      driverId match
        case Some(_) if random.nextDouble() < 0.3 =>
          List(RideStatus.Assigned, RideStatus.InProgress, RideStatus.Completed)(random.nextInt(3))
        case Some(_)                              => RideStatus.Assigned
        case None                                 => RideStatus.Requested

    Ride(
      id = RideId.generate(),
      clientId = clientId,
      creatorId = creatorId,
      driverId = driverId,
      companyId = companyId,
      pickupDateTime = pickupTime,
      from = from,
      to = to,
      status = status,
      flightInfo = flightInfo,
      price = price,
      estimatedDistance = Some(distance)
    )

  def generateFlightInfo(isArrival: Boolean): FlightInfo =
    val flightTime = LocalDateTime.now().plusHours(random.nextInt(24))
    FlightInfo(
      flightNumber = s"PS${random.nextInt(9000) + 1000}",
      flightTime = flightTime,
      gate = Some(s"${(random.nextInt(26) + 65).toChar}${random.nextInt(20) + 1}"),
      terminal = Some(s"Terminal ${random.nextInt(3) + 1}"),
      status = List("On Time", "Delayed", "Boarding", "Arrived", "Cancelled")(random.nextInt(5)),
      isArrival = isArrival
    )

  // Batch generators
  def generateCompanies(count: Int): List[CompanyId] = (1 to count).map(i => CompanyId(i)).toList

  def generatePersons(count: Int, role: PersonRole, companyId: CompanyId): List[Person] =
    (1 to count).map(_ => generatePerson(role, Some(companyId))).toList

  def generateDrivers(count: Int, companyId: CompanyId): List[Driver] =
    (1 to count).map(_ => generateDriver(companyId)).toList

  def generateRides(
      count: Int,
      clients: List[Person],
      creators: List[Person],
      drivers: List[Driver],
      companyId: CompanyId
  ): List[Ride] =
    (1 to count).map { _ =>
      val client  = clients(random.nextInt(clients.length))
      val creator = creators(random.nextInt(creators.length))
      val driver  = if random.nextDouble() < 0.8 then Some(drivers(random.nextInt(drivers.length)).id) else None
      generateRide(client.id, creator.id, companyId, driver)
    }.toList
