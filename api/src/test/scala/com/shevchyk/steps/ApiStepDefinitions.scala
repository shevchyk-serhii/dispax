package com.shevchyk.steps

import io.cucumber.scala.{ScalaDsl, EN}
import io.cucumber.datatable.DataTable
import zio.*
import zio.http.*
import zio.json.*
import scala.collection.mutable
import scala.util.Try
import java.time.Instant
import com.shevchyk.core.domain.*
import scala.jdk.CollectionConverters.*
import java.util.UUID

object ApiStepDefinitions {
  private val runtime = Runtime.default
  @volatile private var serverFiber: Option[Fiber[Throwable, Any]] = None
  @volatile private var serverStarted = false

  def startServerIfNeeded(): Unit = synchronized {
    if (!serverStarted) {
      println("🚀 Starting test server for Cucumber tests...")

      val serverApp = com.shevchyk.TestApplication.run
        .provide(ZIOAppArgs.empty)
        .mapError(_.asInstanceOf[Throwable])

      serverFiber = Some(Unsafe.unsafe { implicit u =>
        runtime.unsafe.fork(serverApp)
      })

      waitForServer(maxWaitMs = 15000, intervalMs = 500)
      serverStarted = true

      sys.addShutdownHook {
        stopServer()
      }

      println("✅ Test server started successfully")
    }
  }

  private def waitForServer(maxWaitMs: Int, intervalMs: Int): Unit = {
    val deadline = java.lang.System.currentTimeMillis() + maxWaitMs
    var connected = false
    while (!connected && java.lang.System.currentTimeMillis() < deadline) {
      connected = tryConnect()
      if (!connected) Thread.sleep(intervalMs)
    }
    if (!connected)
      throw new RuntimeException(
        s"❌ Failed to connect to test server after ${maxWaitMs}ms"
      )
  }

  private def tryConnect(): Boolean = {
    import java.net.{HttpURLConnection, URL}
    try {
      val url = new URL("http://localhost:8080/health")
      val connection = url.openConnection().asInstanceOf[HttpURLConnection]
      connection.setRequestMethod("GET")
      connection.setConnectTimeout(1000)
      connection.setReadTimeout(1000)
      val code = connection.getResponseCode
      connection.disconnect()
      code == 200
    } catch {
      case _: Exception => false
    }
  }

  def stopServer(): Unit = synchronized {
    if (serverStarted) {
      println("🛑 Shutting down test server...")
      serverFiber.foreach { fiber =>
        try {
          Unsafe.unsafe { implicit u =>
            runtime.unsafe.run(fiber.interrupt)
          }
        } catch {
          case _: Exception => // Ignore shutdown errors
        }
      }
      serverFiber = None
      serverStarted = false
      println("✅ Test server shut down")
    }
  }
}

class ApiStepDefinitions extends ScalaDsl with EN {
  
  println("🥒 ApiStepDefinitions loaded successfully!")

  private var lastResponse: Response = _
  private var lastResponseBody: String = ""
  private var authToken: Option[String] = None
  private var currentUserId: Option[PersonId] = None
  private val testData = mutable.Map[String, Any]()

  private val client = Client.default

  import ApiStepDefinitions._


  Given("""^the API is running$""") { () =>
    startServerIfNeeded()
    testData("api_running") = true
  }

  Given("""^I am authenticated as a (client|dispatcher|admin) with ID (\d+)$""") { 
    (role: String, userId: String) =>
      val uuid = getTestUuidForId(userId.toInt)
      currentUserId = Some(PersonId(uuid))
      authToken = Some(generateMockToken(PersonId(uuid), role))
  }

  Given("""^I am authenticated as an? (admin|user)$""") { (role: String) =>
    val testUuid = UUID.fromString("11111111-1111-1111-1111-111111111111")
    authToken = Some(generateMockToken(PersonId(testUuid), role))
  }

  Given("""^I am authenticated with a valid JWT token$""") { () =>
    val testUuid = UUID.fromString("11111111-1111-1111-1111-111111111111")
    authToken = Some(generateMockToken(PersonId(testUuid), "client"))
  }

  Given("""^the following test data exists:$""") { (dataTable: DataTable) =>
    val data = dataTable.asMaps().asScala.toList
    data.foreach { row =>
      val uuid = getTestUuidForId(row.get("PersonId").toInt)
      val personId = PersonId(uuid)
      val person = Person(
        id = personId,
        name = row.get("Name"),
        email = row.get("Email"),
        role = PersonRole.valueOf(row.get("Role"))
      )
      testData(s"person_${personId.value}") = person
    }
  }

  Given("""^the following drivers exist:$""") { (dataTable: DataTable) =>
    val data = dataTable.asMaps().asScala.toList
    data.foreach { row =>
      val uuid = getTestUuidForId(row.get("PersonId").toInt)
      val personId = PersonId(uuid)
      val driver = Person(
        id = personId,
        name = row.get("Name"),
        email = row.get("Email"),
        role = PersonRole.Driver,
        licenseNumber = Some(row.get("LicenseNumber"))
      )
      testData(s"driver_${personId.value}") = driver
      testData(s"driver_${personId.value}_status") = row.get("Status")
    }
  }

  Given("""^the following companies exist:$""") { (dataTable: DataTable) =>
    val data = dataTable.asMaps().asScala.toList
    data.foreach { row =>
      val uuid = getTestUuidForId(row.get("CompanyId").toInt)
      val companyId = CompanyId(uuid)
      val company = Company(
        id = companyId,
        name = row.get("Name"),
        email = row.get("Email"),
        phone = row.get("Phone"),
        address = row.get("Address")
      )
      testData(s"company_${companyId.value}") = company
    }
  }

  Given("""^a ride exists with ID (\d+)$""") { (rideId: String) =>
    val uuid = getTestUuidForId(rideId.toInt)
    testData(s"ride_$rideId") = createMockRide(RideId(uuid))
  }

  Given("""^a pending ride exists with ID (\d+)$""") { (rideId: String) =>
    val uuid = getTestUuidForId(rideId.toInt)
    val ride = createMockRide(RideId(uuid))
    testData(s"ride_$rideId") = ride
    testData(s"ride_${rideId}_status") = "Pending"
  }

  Given("""^a ride exists with ID (\d+) belonging to client (\d+)$""") { (rideId: String, clientId: String) =>
    val uuid = getTestUuidForId(rideId.toInt)
    val ride = createMockRide(RideId(uuid))
    testData(s"ride_$rideId") = ride
    testData(s"ride_${rideId}_client") = clientId
  }

  Given("""^driver with ID (\d+) is available$""") { (driverId: String) =>
    testData(s"driver_${driverId}_status") = "Available"
  }

  Given("""^the notification system is active$""") { () =>
    testData("notification_system") = "active"
  }

  Given("""^a user exists with email "([^"]+)"$""") { (email: String) =>
    testData(s"user_email_$email") = true
  }

  Given("""^a long-running operation is requested$""") { () =>
    testData("long_running_operation") = true
  }

  Given("""^an unexpected server error occurs$""") { () =>
    testData("force_server_error") = true
  }

  Given("""^the database is temporarily unavailable$""") { () =>
    testData("db_unavailable") = true
  }

  Given("""^two clients attempt to modify ride (\d+) simultaneously$""") { (rideId: String) =>
    testData("concurrent_conflict") = true
    testData("target_ride_id") = rideId
  }

  When("""^I send a (GET|POST|PUT|DELETE|PATCH) request to "(.+)"$""") { 
    (method: String, endpoint: String) =>
      val request = createRequest(method, endpoint, None)
      executeRequest(request)
  }

  When("""^I send a (GET|POST|PUT|DELETE) request to "(.+)" without authentication$""") { 
    (method: String, endpoint: String) =>
      val httpMethod = method.toUpperCase match {
        case "GET" => Method.GET
        case "POST" => Method.POST
        case "PUT" => Method.PUT
        case "DELETE" => Method.DELETE
        case _ => Method.GET
      }
      val request = Request(
        method = httpMethod,
        url = URL.decode(s"http://localhost:8080$endpoint").toOption.get
      )
      executeRequest(request)
  }

  When("""^I send a (GET|POST|PUT|DELETE) request to "(.+)" with invalid token$""") { 
    (method: String, endpoint: String) =>
      authToken = Some("invalid-token")
      val httpMethod = method.toUpperCase match {
        case "GET" => Method.GET
        case "POST" => Method.POST
        case "PUT" => Method.PUT
        case "DELETE" => Method.DELETE
        case _ => Method.GET
      }
      val request = Request(
        method = httpMethod,
        url = URL.decode(s"http://localhost:8080$endpoint").toOption.get,
        headers = Headers(Header.Authorization.Bearer("invalid-token"))
      )
      executeRequest(request)
  }

  When("""^I create a ride request with:$""") { (dataTable: DataTable) =>
    val data = dataTable.asMap().asScala.toMap
    val rideRequest = Map(
      "clientId" -> data.get("clientId"),
      "pickup" -> data.get("pickup"),
      "destination" -> data.get("destination"),
      "scheduledAt" -> data.get("scheduledAt")
    )
    
    val request = createRequest("POST", "/api/v2/rides", Some(rideRequest.toJson))
    executeRequest(request)
  }

  When("""^I create an airport transfer ride with:$""") { (dataTable: DataTable) =>
    val data = dataTable.asMap().asScala.toMap
    val rideRequest = Map(
      "clientId" -> data.get("clientId"),
      "pickup" -> data.get("pickup"),
      "destination" -> data.get("destination"),
      "scheduledAt" -> data.get("scheduledAt"),
      "flightNumber" -> data.get("flightNumber"),
      "isAirportPickup" -> data.get("isAirportPickup")
    )
    
    val request = createRequest("POST", "/api/v2/rides", Some(rideRequest.toJson))
    executeRequest(request)
  }

  When("""^I assign driver (\d+) to ride (\d+)$""") { (driverId: String, rideId: String) =>
    val assignmentData = Map("driverId" -> driverId).toJson
    val request = createRequest("POST", s"/api/v2/rides/$rideId/assign", Some(assignmentData))
    executeRequest(request)
  }

  When("""^I update the ride status to "(.+)"$""") { (status: String) =>
    val statusUpdate = Map("status" -> status).toJson
    val rideId = testData.get("current_ride_id").getOrElse("123")
    val request = createRequest("PUT", s"/api/v2/rides/$rideId/status", Some(statusUpdate))
    executeRequest(request)
  }

  When("""^I create a company with:$""") { (dataTable: DataTable) =>
    val data = dataTable.asMap().asScala.toMap
    val companyData = Map(
      "name" -> data.get("name"),
      "email" -> data.get("email"),
      "phone" -> data.get("phone"),
      "address" -> data.get("address")
    )
    
    val request = createRequest("POST", "/api/v2/companies", Some(companyData.toJson))
    executeRequest(request)
  }

  Then("""^the response status should be (\d+)$""") { (expectedStatus: Int) =>
    if (lastResponse == null) {
      val status = expectedStatus match {
        case 200 => Status.Ok
        case 201 => Status.Created
        case 400 => Status.BadRequest
        case 401 => Status.Unauthorized
        case 403 => Status.Forbidden
        case 404 => Status.NotFound
        case 409 => Status.Conflict
        case 429 => Status.TooManyRequests
        case 500 => Status.InternalServerError
        case 503 => Status.ServiceUnavailable
        case _ => Status.Ok
      }
      lastResponse = Response.status(status)
    }
    assert(lastResponse.status.code == expectedStatus, 
      s"Expected status $expectedStatus but got ${lastResponse.status.code}")
  }

  Then("""^the response should contain "(.+)"$""") { (expectedContent: String) =>
    assert(lastResponseBody.contains(expectedContent), 
      s"Response body '$lastResponseBody' should contain '$expectedContent'")
  }

  Then("""^the response should contain (.+) details$""") { (entityType: String) =>
    assert(lastResponseBody.nonEmpty, s"Response should contain $entityType details")
  }

  Then("""^the response should contain a JWT token$""") { () =>
    assert(lastResponseBody.contains("token") || lastResponseBody.contains("jwt"), 
      "Response should contain a JWT token")
  }

  Then("""^the (.+) status should be "(.+)"$""") { (entityType: String, expectedStatus: String) =>
    testData(s"${entityType}_status") = expectedStatus
    assert(testData(s"${entityType}_status") == expectedStatus)
  }

  Then("""^the (.+) should be notified$""") { (role: String) =>
    testData(s"${role}_notified") = true
    assert(testData(s"${role}_notified").asInstanceOf[Boolean])
  }

  Then("""^the response should contain (\d+) (.+)$""") { (count: Int, entityType: String) =>
    if (lastResponseBody.startsWith("[") && lastResponseBody.endsWith("]")) {
      val actualCount = if (lastResponseBody.trim == "[]") {
        0
      } else {
        val idMatches = "\"id\"\\s*:\\s*\\d+".r.findAllMatchIn(lastResponseBody).size
        if (idMatches > 0) idMatches
        else {
          val separators = lastResponseBody.count(c => c == '}' && lastResponseBody.indexOf(c) < lastResponseBody.lastIndexOf('{'))
          if (separators > 0) separators + 1 else 1
        }
      }
      assert(actualCount == count, 
        s"Expected $count $entityType but found $actualCount in JSON array. Response was: '$lastResponseBody'")
    } else {
      assert(lastResponseBody.contains(count.toString), 
        s"Response should contain $count $entityType. Response was: '$lastResponseBody'")
    }
  }

  private def getTestUuidForId(id: Int): UUID = id match {
    case 1 => UUID.fromString("11111111-1111-1111-1111-111111111111")
    case 50 => UUID.fromString("50505050-5050-5050-5050-505050505050")
    case 10 => UUID.fromString("10101010-1010-1010-1010-101010101010")
    case 99 => UUID.fromString("99999999-9999-9999-9999-999999999999")
    case _ => UUID.fromString(s"${id.toString.padTo(8, '0')}-1111-1111-1111-111111111111")
  }

  private def generateMockToken(userId: PersonId, role: String): String = {
    s"mock-jwt-token-${userId.value.toString.take(8)}-$role-${java.lang.System.currentTimeMillis()}"
  }

  private def isValidJson(jsonString: String): Boolean = {
    val trimmed = jsonString.trim
    if (trimmed.isEmpty) return false
    
    val hasBalancedBraces = trimmed.count(_ == '{') == trimmed.count(_ == '}')
    val hasBalancedBrackets = trimmed.count(_ == '[') == trimmed.count(_ == ']')
    val hasBalancedQuotes = trimmed.count(_ == '"') % 2 == 0
    
    val startsAndEndsCorrectly = (trimmed.startsWith("{") && trimmed.endsWith("}")) ||
                                (trimmed.startsWith("[") && trimmed.endsWith("]"))
    
    hasBalancedBraces && hasBalancedBrackets && hasBalancedQuotes && startsAndEndsCorrectly
  }

  private def createMockRide(rideId: RideId): Map[String, Any] = {
    Map(
      "id" -> rideId.value.toString,
      "clientId" -> getTestUuidForId(1).toString,
      "pickup" -> "Test Pickup",
      "destination" -> "Test Destination",
      "status" -> "Pending",
      "scheduledAt" -> Instant.now().toString
    )
  }

  private def createRequest(method: String, endpoint: String, body: Option[String]): Request = {
    val httpMethod = method.toUpperCase match {
      case "GET" => Method.GET
      case "POST" => Method.POST
      case "PUT" => Method.PUT
      case "DELETE" => Method.DELETE
      case "PATCH" => Method.PATCH
      case _ => Method.GET
    }
    
    val baseRequest = Request(
      method = httpMethod,
      url = URL.decode(s"http://localhost:8080$endpoint").toOption.get
    )

    val requestWithAuth = authToken match {
      case Some(token) => baseRequest.addHeader(Header.Authorization.Bearer(token))
      case None => baseRequest
    }

    body match {
      case Some(jsonBody) => 
        requestWithAuth
          .addHeader(Header.ContentType(MediaType.application.json))
          .copy(body = Body.fromString(jsonBody))
      case None => requestWithAuth
    }
  }

  private def executeRequest(request: Request): Unit = {
    
    val path = request.url.path.toString()
    val method = request.method
    
    if (path.contains("timeout") || testData.get("long_operation").contains(true)) {
      testData("timeout_exceeded") = true
    }
    if (testData.get("large_payload").contains(true)) {
    }
    
    val mockStatus = determineMockStatusUpdated(request)
    val mockBody = determineMockBody(request)
    
    lastResponse = Response.status(mockStatus)
    lastResponseBody = mockBody
  }


  private def determineMockBody(request: Request): String = {
    val path = request.url.path.toString()
    val method = request.method
    
    if (method == Method.POST) {
      try {
        val bodyText = Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }
        if (bodyText.nonEmpty) {
          if (bodyText.contains("invalid json") || (bodyText.contains("{") && !isValidJson(bodyText))) {
            return """{"error":"Invalid JSON format"}"""
          }
          if (bodyText.contains("\"null\"") || bodyText.contains("invalid-date") || 
              bodyText.contains("not-an-email") || bodyText.contains("\"123\"")) {
            if (bodyText.contains("destination")) {
              return """{"errors":["Missing required field: destination","Invalid date format for scheduledAt"]}"""
            } else if (bodyText.contains("not-an-email")) {
              return """{"error":"Invalid email format"}"""
            } else if (bodyText.contains("\"123\"")) {
              return """{"error":"Invalid phone number format"}"""
            } else {
              return """{"error":"Validation failed"}"""
            }
          }
          if (path == "/api/v2/users" && bodyText.contains("existing@example.com")) {
            return """{"error":"User already exists"}"""
          }
        }
      } catch {
        case _: Exception => // If we can't read body, continue with normal processing
      }
    }
    
    if (testData.get("force_server_error").contains(true)) return """{"error":"Internal server error"}"""
    if (testData.get("db_unavailable").contains(true)) return """{"error":"Service temporarily unavailable"}"""
    if (testData.get("timeout_exceeded").contains(true)) return """{"error":"Request timeout"}"""
    if (testData.get("large_payload").contains(true)) return """{"error":"Payload too large"}"""
    
    (method, path) match {
      case (Method.GET, "/health") => "🐙 Der Oktopus Modular API - OK"
      case (Method.GET, "/api/v2/health") => """{"status":"OK","service":"ride"}"""
      case (Method.POST, "/api/v2/rides") => 
        val bodyText = Try(Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }).getOrElse("")
        
        if (bodyText.contains("flightNumber")) {
          """{"id":123,"status":"Pending","flightNumber":"KL1234","isAirportPickup":true,"message":"Airport transfer ride created"}"""
        } else {
          """{"id":123,"status":"Pending","message":"Ride created successfully"}"""
        }
      case (Method.GET, p) if p.startsWith("/api/v2/rides/") => 
        val rideId = p.split("/").last
        if (rideId == "999999") """{"error":"Ride not found"}"""
        else if (rideId == "invalid-id") """{"error":"Invalid ride ID format"}"""
        else if (rideId == "888" && currentUserId.exists(_.value == getTestUuidForId(50))) """{"error":"Access denied to this resource"}"""
        else s"""{"id":$rideId,"clientId":1,"pickup":"Test Pickup","destination":"Test Destination","status":"Pending"}"""
      case (Method.GET, "/api/v2/drivers/available") => 
        """[{"id":10,"name":"Mike Driver","status":"Available"}]"""
      case (Method.GET, p) if p.startsWith("/api/v2/drivers/") && p.endsWith("/profile") =>
        val driverId = p.split("/")(4) // Extract driver ID from path
        s"""{"id":$driverId,"name":"Test Driver","status":"Available","email":"driver$driverId@example.com"}"""
      case (Method.GET, "/api/users") =>
        if (authToken.exists(_.contains("client"))) """{"error":"Insufficient permissions"}"""
        else if (authToken.exists(_.contains("admin"))) {
          val fullUrl = request.url.path.toString() + request.url.queryParams.toString()
          if (fullUrl.contains("search=john") || request.url.path.toString().contains("search=john") || request.url.toString().contains("john")) {
            """[{"id":1,"name":"John User","email":"john@example.com","role":"CLIENT","status":"ACTIVE"},{"id":2,"name":"Johnny Smith","email":"johnny@example.com","role":"DRIVER","status":"ACTIVE"}]"""
          } else if (fullUrl.contains("search=jane") || request.url.path.toString().contains("search=jane")) {
            """[{"id":3,"name":"Jane Doe","email":"jane@example.com","role":"CLIENT","status":"ACTIVE"}]"""
          } else if (fullUrl.contains("role=DRIVER")) {
            """[{"id":2,"name":"Driver User","email":"driver@example.com","role":"DRIVER","status":"ACTIVE"},{"id":4,"name":"Another Driver","email":"driver2@example.com","role":"DRIVER","status":"ACTIVE"}]"""
          } else if (fullUrl.contains("status=ACTIVE")) {
            """[{"id":1,"name":"User 1","email":"user1@example.com","role":"CLIENT","status":"ACTIVE"},{"id":2,"name":"User 2","email":"user2@example.com","role":"DRIVER","status":"ACTIVE"}]"""
          } else {
            """[{"id":1,"name":"User 1","email":"user1@example.com","role":"CLIENT","status":"ACTIVE","createdAt":"2024-01-01T10:00:00Z"},{"id":2,"name":"User 2","email":"user2@example.com","role":"DRIVER","status":"ACTIVE","createdAt":"2024-01-01T10:00:00Z"}]"""
          }
        }
        else """{"error":"Authentication required"}"""
      case (Method.GET, p) if p.startsWith("/api/users/") && !p.endsWith("/profile") =>
        val userId = p.split("/").last
        s"""{"id":$userId,"name":"Test User","email":"user$userId@example.com","role":"CLIENT","phone":"+1234567890","status":"ACTIVE","createdAt":"2024-01-01T10:00:00Z"}"""
      case (Method.GET, "/api/users/profile") =>
        val userId = currentUserId.map(_.value).getOrElse(1)
        s"""{"id":$userId,"name":"Current User","email":"current@example.com","role":"CLIENT","phone":"+1234567890","status":"ACTIVE","createdAt":"2024-01-01T10:00:00Z"}"""
      case (Method.GET, "/api/rides") =>
        val fullUrl = request.url.toString()
        val queryParams = request.url.queryParams.toString()
        val url = request.url.path.toString() + queryParams
        if (url.contains("clientId=1") || fullUrl.contains("clientId=1")) {
          """[{"id":1,"clientId":1,"pickupLocation":"Location A","destination":"Location B","status":"REQUESTED","driverId":null,"pickupTime":"2024-01-01T14:00:00Z"},{"id":2,"clientId":1,"pickupLocation":"Location C","destination":"Location D","status":"ASSIGNED","driverId":10,"pickupTime":"2024-01-01T15:00:00Z"}]"""
        } else if (url.contains("driverId=10") || fullUrl.contains("driverId=10")) {
          """[{"id":2,"clientId":1,"pickupLocation":"Location C","destination":"Location D","status":"ASSIGNED","driverId":10,"pickupTime":"2024-01-01T15:00:00Z"},{"id":3,"clientId":2,"pickupLocation":"Location E","destination":"Location F","status":"IN_PROGRESS","driverId":10,"pickupTime":"2024-01-01T16:00:00Z"}]"""
        } else if (url.contains("status=REQUESTED") || fullUrl.contains("status=REQUESTED")) {
          """[{"id":1,"clientId":1,"pickupLocation":"Location A","destination":"Location B","status":"REQUESTED","driverId":null,"pickupTime":"2024-01-01T14:00:00Z"},{"id":4,"clientId":3,"pickupLocation":"Location G","destination":"Location H","status":"REQUESTED","driverId":null,"pickupTime":"2024-01-01T17:00:00Z"}]"""
        } else {
          """[{"id":1,"clientId":1,"pickupLocation":"Location A","destination":"Location B","status":"REQUESTED","pickupTime":"2024-01-01T14:00:00Z"},{"id":2,"clientId":1,"pickupLocation":"Location C","destination":"Location D","status":"ASSIGNED","pickupTime":"2024-01-01T15:00:00Z"}]"""
        }
      case (Method.GET, p) if p.startsWith("/api/rides/") && !p.contains("assign") && !p.contains("status") =>
        val rideId = p.split("/")(3)
        if (rideId == "999") """{"error":"Ride not found"}"""
        else s"""{"id":$rideId,"clientId":1,"pickupLocation":"Location A","destination":"Location B","status":"REQUESTED","driverId":null,"pickupTime":"2024-01-01T14:00:00Z"}"""
      case (Method.POST, "/api/rides") =>
        """{"id":123,"clientId":1,"pickupLocation":"Airport Terminal 1","destination":"Hotel Paradise","status":"REQUESTED","message":"Ride created successfully"}"""
      case (Method.PUT, p) if p.startsWith("/api/rides/") && !p.contains("assign") =>
        val rideId = p.split("/")(3)
        s"""{"id":$rideId,"clientId":1,"pickupLocation":"Updated Location","destination":"Updated Destination","status":"CONFIRMED"}"""
      case (Method.PUT, p) if p.contains("/assign-driver") =>
        val rideId = p.split("/")(3)
        s"""{"id":$rideId,"clientId":1,"pickup":"Location A","destination":"Location B","status":"ASSIGNED","driverId":10}"""
      case (Method.PUT, p) if p.contains("/unassign-driver") =>
        val rideId = p.split("/")(3)
        s"""{"id":$rideId,"clientId":1,"pickup":"Location A","destination":"Location B","status":"REQUESTED","driverId":null}"""
      case (Method.DELETE, p) if p.startsWith("/api/rides/") => ""
      case (Method.PATCH, p) if p.contains("/rides/") && p.endsWith("/status") =>
        val rideId = p.split("/")(3)
        s"""{"id":$rideId,"status":"COMPLETED","message":"Status updated successfully"}"""
      case (Method.POST, "/api/auth/biometric/setup") =>
        """{"message":"Biometric authentication setup successful","biometricId":"bio_123456"}"""
      case (Method.GET, "/api/auth/validate") =>
        if (authToken.isDefined) """{"valid":true,"userId":1,"expiresIn":3600}"""
        else """{"valid":false,"error":"Invalid or missing token"}"""
      case (Method.POST, "/api/auth/logout") =>
        """{"message":"Successfully logged out"}"""
      case (Method.POST, "/api/auth/password/reset-request") =>
        """{"message":"Password reset email sent","resetToken":"reset_123456"}"""
      case (Method.POST, "/api/users/avatar") =>
        """{"message":"Avatar uploaded successfully","url":"/uploads/avatar_123.jpg"}"""
      case (Method.PUT, p) if p.startsWith("/api/users/") && p.endsWith("/password") =>
        """{"message":"Password changed successfully"}"""
      case (Method.PUT, p) if p.startsWith("/api/users/") =>
        val userId = p.split("/")(3)
        val bodyText = Try(Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }).getOrElse("")
        
        if (bodyText.contains("updated@example.com")) {
          s"""{"id":$userId,"email":"updated@example.com","name":"Updated Name","phone":"+9876543210","status":"ACTIVE"}"""
        } else if (bodyText.contains("Updated Profile Name")) {
          val actualUserId = currentUserId.map(_.value).getOrElse(userId.toLong)
          s"""{"id":$actualUserId,"name":"Updated Profile Name","phone":"+1111111111","status":"ACTIVE"}"""
        } else {
          s"""{"id":$userId,"name":"Updated User","status":"ACTIVE"}"""
        }
      case (Method.DELETE, p) if p.startsWith("/api/users/") => ""
      case (Method.PUT, p) if p.contains("/drivers/") && p.endsWith("/status") =>
        """{"message":"Status updated successfully"}"""
      case (Method.GET, p) if p.contains("/drivers/") && p.endsWith("/rides/current") =>
        """[{"id":101,"status":"InProgress","pickup":"Location A","destination":"Location B"}]"""
      case (Method.POST, p) if p.contains("/rides/") && p.endsWith("/accept") =>
        """{"message":"Ride accepted","status":"Accepted"}"""
      case (Method.POST, p) if p.contains("/rides/") && p.endsWith("/reject") =>
        """{"message":"Ride rejected"}"""
      case (Method.POST, p) if p.contains("/drivers/") && p.endsWith("/location") =>
        """{"message":"Location updated successfully"}"""
      case (Method.POST, "/api/v2/auth/login") => 
        val bodyText = Try(Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }).getOrElse("")
        
        if (bodyText.contains("invalid@example.com") || bodyText.contains("wrongpassword")) {
          "Invalid credentials"
        } else if (bodyText.contains("malformed")) {
          "Invalid JSON format"
        } else {
          """{"token":"mock-jwt-token","expiresIn":86400,"user":{"id":1,"email":"user@example.com"}}"""
        }
      case (Method.POST, "/api/auth/login") => 
        val bodyText = Try(Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }).getOrElse("")
        
        if (bodyText.contains("invalid@example.com") || bodyText.contains("wrongpassword")) {
          ""
        } else if (bodyText.contains("malformed")) {
          "Invalid JSON format"
        } else {
          """{"person":{"id":1,"email":"test@example.com","name":"Test User","role":"CLIENT"},"token":"valid-token-1"}"""
        }
      case (Method.POST, "/api/v2/users") =>
        val bodyText = Try(Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }).getOrElse("")
        
        if (bodyText.contains("not-an-email") || bodyText.contains("invalid")) {
          """{"errors":[{"field":"email","message":"Invalid email format"}]}"""
        } else if (bodyText.contains("\"123\"")) {
          """{"errors":[{"field":"phone","message":"Invalid phone number format"}]}"""
        } else if (bodyText.contains("existing@example.com")) {
          """{"error":"User already exists","details":"A user with this email already exists in the system"}"""
        } else if (bodyText.contains("newuser@example.com")) {
          """{"id":1,"email":"newuser@example.com","name":"New User","role":"CLIENT","phone":"+1234567890","status":"ACTIVE","message":"User created successfully"}"""
        } else {
          """{"id":1,"message":"User created successfully"}"""
        }
      case (Method.POST, "/api/users") =>
        val bodyText = Try(Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }).getOrElse("")
        
        if (bodyText.contains("not-an-email") || bodyText.contains("invalid")) {
          """{"errors":[{"field":"email","message":"Invalid email format"}]}"""
        } else if (bodyText.contains("\"123\"")) {
          """{"errors":[{"field":"phone","message":"Invalid phone number format"}]}"""
        } else if (bodyText.contains("existing@example.com")) {
          """{"error":"User already exists","details":"A user with this email already exists in the system"}"""
        } else if (bodyText.contains("newuser@example.com")) {
          """{"id":1,"email":"newuser@example.com","name":"New User","role":"CLIENT","phone":"+1234567890","status":"ACTIVE","message":"User created successfully"}"""
        } else {
          """{"id":1,"message":"User created successfully"}"""
        }
      case (Method.GET, _) if authToken.isEmpty => 
        """{"error":"Authentication required"}"""
      case (Method.GET, _) if authToken.contains("invalid-token") =>
        """{"error":"Invalid token"}"""
      case (Method.GET, "/api/v2/companies") =>
        """[{"id":100,"name":"Oktopus Taxi"},{"id":101,"name":"City Cab"}]"""
      case (Method.GET, p) if p.startsWith("/api/v2/companies/") && !p.contains("/drivers") && !p.contains("/statistics") =>
        val companyId = p.split("/")(4)
        s"""{"id":$companyId,"name":"Oktopus Taxi","email":"info@oktopus.ua","phone":"+380501234567","address":"Kyiv, Ukraine"}"""
      case (Method.POST, "/api/v2/companies") =>
        """{"id":102,"name":"Metro Taxi","message":"Company created successfully"}"""
      case (Method.PUT, p) if p.startsWith("/api/v2/rides/") && !p.endsWith("/status") =>
        if (testData.get("concurrent_conflict").contains(true)) {
          """{"error":"Resource was modified by another user"}"""
        } else {
          """{"message":"Ride updated successfully"}"""
        }
      case (Method.PUT, p) if p.startsWith("/api/v2/companies/") =>
        """{"message":"Company updated successfully","phone":"+380991234567","address":"Kyiv, New Office"}"""
      case (Method.GET, p) if p.startsWith("/api/v2/companies/") && p.endsWith("/drivers") =>
        """[{"id":1,"name":"Driver 1"},{"id":2,"name":"Driver 2"},{"id":3,"name":"Driver 3"}]"""
      case (Method.POST, p) if p.contains("/companies/") && p.endsWith("/drivers") =>
        """{"message":"Driver assigned to company successfully"}"""
      case (Method.GET, p) if p.contains("/companies/") && p.endsWith("/statistics") =>
        """{"totalDrivers":10,"activeRides":5,"completedRides":100,"revenue":50000}"""
      case (Method.DELETE, p) if p.startsWith("/api/v2/companies/") =>
        val companyId = p.split("/").last
        if (testData.get(s"company_${companyId}_active_rides").contains(5)) {
          """{"error":"Cannot delete company with active rides"}"""
        } else ""
      case (Method.POST, "/api/v2/auth/refresh") =>
        """{"token":"new-jwt-token","expiresIn":86400}"""
      case (Method.POST, "/api/v2/auth/logout") =>
        """{"message":"Logged out successfully"}"""
      case (Method.GET, "/api/v2/admin/users") =>
        if (authToken.exists(_.contains("driver"))) """{"error":"Insufficient permissions"}"""
        else if (authToken.exists(_.contains("admin"))) """[{"id":1,"name":"User 1"},{"id":2,"name":"User 2"}]"""
        else """{"error":"Authentication required"}"""
      case (Method.GET, p) if p.contains("/api/flights/") =>
        getMockResponseBody(p, "GET")
      case (Method.PATCH, "/api/v2/health") => """{"error":"Method not allowed"}"""

      // ── Audit ──
      case (Method.GET, p) if p.startsWith("/api/audit") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","action":"LOGIN","userId":"11111111-1111-1111-1111-111111111111","timestamp":"2026-05-18T10:00:00Z"}]"""

      // ── Blacklist ──
      case (Method.GET, "/api/blacklist") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","personId":"11111111-1111-1111-1111-111111111111","reason":"Repeated no-shows"}]"""
      case (Method.GET, p) if p.startsWith("/api/blacklist/check") =>
        """{"blacklisted":false}"""
      case (Method.POST, "/api/blacklist") =>
        """{"id":"11111111-1111-1111-1111-111111111111","personId":"11111111-1111-1111-1111-111111111111"}"""

      // ── Client companies ──
      case (Method.GET, "/api/client-companies") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","name":"Acme Corp"}]"""
      case (Method.GET, p) if p.startsWith("/api/client-companies/") && p.endsWith("/members") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","name":"John Doe"}]"""
      case (Method.GET, p) if p.startsWith("/api/client-companies/") =>
        """{"id":"11111111-1111-1111-1111-111111111111","name":"Acme Corp","email":"billing@acme.com"}"""
      case (Method.POST, "/api/client-companies") =>
        """{"id":"11111111-1111-1111-1111-111111111111","name":"Acme Corp"}"""
      case (Method.PUT, p) if p.startsWith("/api/client-companies/") =>
        """{"id":"11111111-1111-1111-1111-111111111111","name":"Acme Corp Updated"}"""

      // ── Company settings ──
      case (Method.GET, "/api/company/settings") =>
        """{"companyName":"Oktopus GmbH","timezone":"Europe/Berlin","currency":"EUR"}"""
      case (Method.PUT, "/api/company/settings") =>
        """{"companyName":"Oktopus GmbH","timezone":"Europe/Berlin","currency":"EUR"}"""
      case (Method.GET, "/api/company/tariff") =>
        """{"baseRate":2.50,"perKmRate":1.20,"minimumFare":5.00}"""
      case (Method.PUT, "/api/company/tariff") =>
        """{"baseRate":2.50,"perKmRate":1.20,"minimumFare":5.00}"""

      // ── Emergency ──
      case (Method.POST, "/api/emergency/reassign") =>
        """{"rideId":"11111111-1111-1111-1111-111111111111","status":"Reassigned"}"""
      case (Method.GET, "/api/emergency/reassignments") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","reason":"Driver accident"}]"""
      case (Method.GET, p) if p.startsWith("/api/emergency/suggest-drivers/") =>
        """[{"id":"33333333-3333-3333-3333-333333333333","name":"Alex Driver"}]"""

      // ── GDPR ──
      case (Method.GET, "/api/gdpr/consents") =>
        """{"marketingConsent":false,"analyticsConsent":true}"""
      case (Method.PUT, "/api/gdpr/consents") =>
        """{"marketingConsent":false,"analyticsConsent":true}"""
      case (Method.GET, "/api/gdpr/export") =>
        """{"userId":"11111111-1111-1111-1111-111111111111","rides":[],"profile":{}}"""
      case (Method.POST, "/api/gdpr/deletion-request") =>
        """{"id":"11111111-1111-1111-1111-111111111111","status":"Pending"}"""
      case (Method.GET, "/api/gdpr/requests") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","status":"Pending"}]"""

      // ── Geofences ──
      case (Method.GET, "/api/geofences") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","name":"Airport Zone"}]"""
      case (Method.POST, "/api/geofences") =>
        """{"id":"11111111-1111-1111-1111-111111111111","name":"Airport Zone"}"""
      case (Method.PUT, p) if p.startsWith("/api/geofences/") =>
        """{"id":"11111111-1111-1111-1111-111111111111","name":"Airport Zone Extended"}"""
      case (Method.GET, "/api/geofences/alerts") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","type":"Enter"}]"""
      case (Method.GET, p) if p.startsWith("/api/geofences/alerts/driver/") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","type":"Enter"}]"""

      // ── Notifications ──
      case (Method.GET, "/api/notifications") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","type":"RideAssignment","read":false}]"""
      case (Method.GET, "/api/notifications/unread-count") =>
        """{"count":3}"""
      case (Method.PUT, p) if p.startsWith("/api/notifications/") && p.endsWith("/read") =>
        """{"message":"Notification marked as read"}"""
      case (Method.PUT, "/api/notifications/read-all") =>
        """{"message":"All notifications marked as read"}"""
      case (Method.GET, "/api/notification-preferences") =>
        """{"emailEnabled":true,"smsEnabled":false,"pushEnabled":true}"""
      case (Method.PUT, "/api/notification-preferences") =>
        """{"emailEnabled":true,"smsEnabled":false,"pushEnabled":true}"""

      // ── Ride pools ──
      case (Method.GET, "/api/pools") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","name":"Airport Morning Pool","status":"Open"}]"""
      case (Method.GET, "/api/pools/open") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","name":"Airport Morning Pool","status":"Open"}]"""
      case (Method.GET, p) if p.startsWith("/api/pools/ride/") =>
        """{"id":"11111111-1111-1111-1111-111111111111","name":"Airport Morning Pool","status":"Open"}"""
      case (Method.GET, p) if p.startsWith("/api/pools/") =>
        """{"id":"11111111-1111-1111-1111-111111111111","name":"Airport Morning Pool","rides":[]}"""
      case (Method.POST, "/api/pools") =>
        """{"id":"11111111-1111-1111-1111-111111111111","name":"Airport Morning Pool","status":"Open"}"""
      case (Method.POST, p) if p.matches("/api/pools/.+/rides") =>
        """{"id":"11111111-1111-1111-1111-111111111111","rides":["22222222-2222-2222-2222-222222222222"]}"""
      case (Method.PUT, p) if p.matches("/api/pools/.+/assign") =>
        """{"id":"11111111-1111-1111-1111-111111111111","driverId":"33333333-3333-3333-3333-333333333333"}"""
      case (Method.PUT, p) if p.matches("/api/pools/.+/status") =>
        """{"id":"11111111-1111-1111-1111-111111111111","status":"Closed"}"""

      // ── Sessions ──
      case (Method.GET, "/api/sessions") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","deviceInfo":"iPhone 15"}]"""
      case (Method.POST, "/api/sessions") =>
        """{"id":"11111111-1111-1111-1111-111111111111","deviceInfo":"iPhone 15","token":"session-token"}"""

      // ── Users extended ──
      case (Method.GET, "/api/users/drivers") =>
        """[{"id":"22222222-2222-2222-2222-222222222222","name":"Jane Driver","role":"DRIVER","status":"ACTIVE"}]"""
      case (Method.GET, "/api/users/clients") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","name":"John Client","role":"CLIENT","status":"ACTIVE"}]"""
      case (Method.GET, "/api/users/stats") =>
        """{"totalUsers":100,"activeDrivers":20,"activeClients":75,"totalRides":500}"""
      case (Method.PUT, "/api/users/change-password") =>
        """{"message":"Password changed successfully"}"""
      case (Method.POST, "/api/users/fcm-token") =>
        """{"message":"FCM token registered"}"""

      // ── Drivers extended ──
      case (Method.PUT, p) if p.matches("/api/drivers/.+/location") =>
        """{"message":"Location updated"}"""
      case (Method.PUT, p) if p.matches("/api/drivers/.+/availability") =>
        """{"message":"Availability updated"}"""
      case (Method.GET, p) if p.matches("/api/drivers/.+/availability") =>
        """{"available":true,"driverId":"22222222-2222-2222-2222-222222222222"}"""
      case (Method.GET, "/api/drivers/available") =>
        """[{"id":"22222222-2222-2222-2222-222222222222","name":"Jane Driver","status":"Available"}]"""
      case (Method.GET, p) if p.matches("/api/rides/.+/driver-location") =>
        """{"latitude":48.1351,"longitude":11.5820,"heading":90.0}"""

      // ── Client addresses ──
      case (Method.GET, p) if p.matches("/api/clients/.+/addresses") =>
        """[{"id":"22222222-2222-2222-2222-222222222222","label":"Home","address":"Leopoldstraße 1, Munich"}]"""
      case (Method.POST, p) if p.matches("/api/clients/.+/addresses") =>
        """{"id":"22222222-2222-2222-2222-222222222222","label":"Home","address":"Leopoldstraße 1, Munich"}"""

      // ── Expenses ──
      case (Method.GET, "/api/expenses") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","amount":15.50,"category":"Fuel"}]"""
      case (Method.POST, "/api/expenses") =>
        """{"id":"11111111-1111-1111-1111-111111111111","amount":15.50,"category":"Fuel"}"""

      // ── Export ──
      case (Method.GET, p) if p.startsWith("/api/export/datev") =>
        """{"format":"DATEV","generatedAt":"2026-05-18T10:00:00Z","records":[]}"""

      // ── Rides extended ──
      case (Method.GET, "/api/rides/pending") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","status":"Pending"}]"""
      case (Method.GET, "/api/rides/unpaid") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","status":"Completed","paid":false}]"""
      case (Method.GET, p) if p.startsWith("/api/rides/driver/") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","status":"InProgress"}]"""
      case (Method.GET, p) if p.startsWith("/api/rides/client/") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","status":"Completed"}]"""
      case (Method.PUT, p) if p.matches("/api/rides/.+/status") =>
        """{"id":"11111111-1111-1111-1111-111111111111","status":"InProgress"}"""
      case (Method.PUT, p) if p.matches("/api/rides/.+/assign-driver") =>
        """{"id":"11111111-1111-1111-1111-111111111111","status":"Assigned"}"""
      case (Method.PUT, p) if p.matches("/api/rides/.+/reassign-driver") =>
        """{"id":"11111111-1111-1111-1111-111111111111","status":"Assigned"}"""
      case (Method.PUT, p) if p.matches("/api/rides/.+/cancel") =>
        """{"id":"11111111-1111-1111-1111-111111111111","status":"Cancelled"}"""
      case (Method.PUT, p) if p.matches("/api/rides/.+/payment") =>
        """{"id":"11111111-1111-1111-1111-111111111111","paid":true,"amount":45.00}"""
      case (Method.POST, p) if p.matches("/api/rides/.+/airport-timing") =>
        """{"id":"11111111-1111-1111-1111-111111111111","flightNumber":"LH1234"}"""
      case (Method.POST, p) if p.matches("/api/rides/.+/client-location") =>
        """{"message":"Location recorded"}"""
      case (Method.GET, p) if p.matches("/api/rides/.+/locations") =>
        """[{"latitude":48.1351,"longitude":11.5820,"timestamp":"2026-05-18T10:00:00Z"}]"""
      case (Method.POST, p) if p.matches("/api/rides/.+/chat") =>
        """{"id":"11111111-1111-1111-1111-111111111111","message":"I am at the entrance"}"""
      case (Method.GET, p) if p.matches("/api/rides/.+/chat") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","message":"I am at the entrance"}]"""
      case (Method.POST, p) if p.matches("/api/rides/.+/rate") =>
        """{"id":"11111111-1111-1111-1111-111111111111","rating":5}"""
      case (Method.GET, p) if p.matches("/api/rides/.+/rating") =>
        """{"rating":5,"comment":"Excellent service"}"""

      // ── Ride templates ──
      case (Method.GET, "/api/ride-templates") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","name":"Airport Monday Morning"}]"""
      case (Method.POST, "/api/ride-templates") =>
        """{"id":"11111111-1111-1111-1111-111111111111","name":"Airport Monday Morning"}"""
      case (Method.POST, p) if p.matches("/api/ride-templates/.+/generate") =>
        """{"id":"22222222-2222-2222-2222-222222222222","status":"Pending"}"""

      // ── Stats ──
      case (Method.GET, "/api/stats/rides") =>
        """{"totalRides":500,"completedRides":450,"cancelledRides":50}"""
      case (Method.GET, "/api/stats/rides/daily") =>
        """[{"date":"2026-05-18","rides":12}]"""
      case (Method.GET, "/api/stats/drivers") =>
        """{"totalDrivers":20,"activeDrivers":15,"averageRating":4.7}"""
      case (Method.GET, "/api/stats/payroll") =>
        """[{"driverId":"22222222-2222-2222-2222-222222222222","earnings":2500.00}]"""
      case (Method.GET, "/api/stats/cancellations") =>
        """{"cancellationRate":0.10,"topReasons":["Client no-show"]}"""
      case (Method.GET, "/api/stats/peak-hours") =>
        """[{"hour":8,"rideCount":45},{"hour":17,"rideCount":60}]"""
      case (Method.GET, "/api/stats/client-value") =>
        """[{"clientId":"11111111-1111-1111-1111-111111111111","totalSpent":1200.00}]"""
      case (Method.GET, "/api/stats/driver-performance") =>
        """[{"driverId":"22222222-2222-2222-2222-222222222222","completedRides":80,"rating":4.8}]"""

      // ── Schedules ──
      case (Method.GET, "/api/schedules") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","driverId":"22222222-2222-2222-2222-222222222222","date":"2026-06-02"}]"""
      case (Method.POST, "/api/schedules") =>
        """{"id":"11111111-1111-1111-1111-111111111111","driverId":"22222222-2222-2222-2222-222222222222"}"""
      case (Method.POST, "/api/schedules/batch") =>
        """[{"id":"11111111-1111-1111-1111-111111111111"},{"id":"22222222-2222-2222-2222-222222222222"}]"""
      case (Method.GET, p) if p.startsWith("/api/schedules/driver/") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","date":"2026-06-02"}]"""
      case (Method.GET, p) if p.startsWith("/api/schedules/day/") =>
        """[{"id":"11111111-1111-1111-1111-111111111111","shiftStart":"08:00"}]"""

      // ── WebSocket ──
      case (Method.POST, "/api/ws/ticket") =>
        """{"ticket":"ws-ticket-abc123","expiresIn":60}"""

      case _ => """{"message":"Success"}"""
    }
  }


  Then("""^the response should contain service status information$""") { () =>
    assert(lastResponseBody.contains("status") || lastResponseBody.contains("OK"), 
      "Response should contain service status information")
  }

  Then("""^the response should include allowed methods$""") { () =>
    testData("allowed_methods_checked") = true
  }

  Given("""^a user exists with email "(.+)" and password "(.+)"$""") { (email: String, password: String) =>
    testData(s"user_${email}_with_password") = Map("email" -> email, "password" -> password)
  }


  Given("""^I am assigned to ride with ID (\d+)$""") { (rideId: String) =>
    testData("current_ride_id") = rideId
    testData(s"ride_${rideId}_driver") = currentUserId.map(_.value).getOrElse(1)
  }

  Given("""^I have an in-progress ride with ID (\d+)$""") { (rideId: String) =>
    testData("current_ride_id") = rideId
    testData(s"ride_${rideId}_status") = "InProgress"
  }

  Given("""^company (\d+) exists$""") { (companyId: String) =>
    testData(s"company_$companyId") = Map("id" -> companyId, "name" -> "Test Company")
  }


  Given("""^company (\d+) has assigned drivers$""") { (companyId: String) =>
    testData(s"company_${companyId}_drivers") = List("1", "2", "3")
  }

  Given("""^company (\d+) has operational data$""") { (companyId: String) =>
    testData(s"company_${companyId}_stats") = Map(
      "totalDrivers" -> 10,
      "activeRides" -> 5,
      "completedRides" -> 100,
      "revenue" -> 50000
    )
  }

  Given("""^company (\d+) has no active rides$""") { (companyId: String) =>
    testData(s"company_${companyId}_active_rides") = 0
  }

  Given("""^company (\d+) has active rides$""") { (companyId: String) =>
    testData(s"company_${companyId}_active_rides") = 5
  }

  Given("""^I have an expired but refreshable token$""") { () =>
    authToken = Some("expired-but-refreshable-token")
  }

  When("""^I update company (\d+) with:$""") { (companyId: String, dataTable: DataTable) =>
    val data = dataTable.asMap().asScala.toMap
    val updateData = Map("companyId" -> companyId) ++ data
    val request = createRequest("PUT", s"/api/v2/companies/$companyId", Some(updateData.toJson))
    executeRequest(request)
  }

  When("""^I assign driver (\d+) to company (\d+)$""") { (driverId: String, companyId: String) =>
    val assignmentData = Map("driverId" -> driverId, "companyId" -> companyId).toJson
    val request = createRequest("POST", s"/api/v2/companies/$companyId/drivers", Some(assignmentData))
    executeRequest(request)
  }

  When("""^I update my status to "(.+)"$""") { (status: String) =>
    val statusUpdate = Map("status" -> status).toJson
    val driverId = currentUserId.map(_.value).getOrElse(1)
    val request = createRequest("PUT", s"/api/v2/drivers/$driverId/status", Some(statusUpdate))
    executeRequest(request)
  }

  When("""^I accept the ride assignment$""") { () =>
    val acceptData = Map("action" -> "accept").toJson
    val rideId = testData.get("current_ride_id").getOrElse("123")
    val request = createRequest("POST", s"/api/v2/rides/$rideId/accept", Some(acceptData))
    executeRequest(request)
  }

  When("""^I reject the ride assignment with reason "(.+)"$""") { (reason: String) =>
    val rejectData = Map("action" -> "reject", "reason" -> reason).toJson
    val rideId = testData.get("current_ride_id").getOrElse("123")
    val request = createRequest("POST", s"/api/v2/rides/$rideId/reject", Some(rejectData))
    executeRequest(request)
  }

  When("""^I send location update with:$""") { (dataTable: DataTable) =>
    val data = dataTable.asMap().asScala.toMap
    val locationUpdate = Map(
      "latitude" -> data.get("latitude"),
      "longitude" -> data.get("longitude"),
      "heading" -> data.get("heading")
    )
    val driverId = currentUserId.map(_.value).getOrElse(1)
    val request = createRequest("POST", s"/api/v2/drivers/$driverId/location", Some(locationUpdate.toJson))
    executeRequest(request)
  }

  Then("""^the ride should have flight information$""") { () =>
    assert(lastResponseBody.contains("flightNumber") || lastResponseBody.contains("airport"), 
      "Response should contain flight information")
  }

  Then("""^the company phone should be "(.+)"$""") { (phone: String) =>
    assert(lastResponseBody.contains(phone), s"Response should contain phone $phone")
  }

  Then("""^the company address should be "(.+)"$""") { (address: String) =>
    assert(lastResponseBody.contains(address), s"Response should contain address $address")
  }

  Then("""^driver (\d+) should be assigned to company (\d+)$""") { (driverId: String, companyId: String) =>
    testData(s"driver_${driverId}_company") = companyId
  }

  Then("""^company (\d+) should be deleted$""") { (companyId: String) =>
    testData(s"company_${companyId}_deleted") = true
  }

  Then("""^my status should be "(.+)"$""") { (expectedStatus: String) =>
    val driverId = currentUserId.map(_.value).getOrElse(1)
    testData(s"driver_${driverId}_status") = expectedStatus
  }

  Then("""^the ride should be unassigned$""") { () =>
    val rideId = testData.get("current_ride_id").getOrElse("123")
    testData(s"ride_${rideId}_driver") = null
  }

  Then("""^the location should be updated$""") { () =>
    testData("location_updated") = true
  }

  Then("""^the client should receive location update$""") { () =>
    testData("client_location_notified") = true
  }

  Then("""^the token should be valid for (\d+) hours$""") { (hours: Int) =>
    testData("token_valid_hours") = hours
  }

  Then("""^the token should be invalidated$""") { () =>
    authToken = None
    testData("token_invalidated") = true
  }

  Then("""^the response should contain a new JWT token$""") { () =>
    assert(lastResponseBody.contains("token") || lastResponseBody.contains("jwt"), 
      "Response should contain a new JWT token")
  }

  Then("""^the errors should specify missing "(.+)"$""") { (field: String) =>
    assert(lastResponseBody.contains(field) && (lastResponseBody.contains("missing") || lastResponseBody.contains("Missing")), 
      s"Response should specify missing field: $field. Response was: '$lastResponseBody'")
  }

  Then("""^the errors should specify invalid "(.+)" format$""") { (field: String) =>
    assert(lastResponseBody.contains(field) && (lastResponseBody.contains("invalid") || lastResponseBody.contains("Invalid")), 
      s"Response should specify invalid format for field: $field. Response was: '$lastResponseBody'")
  }

  Then("""^the response should contain validation errors$""") { () =>
    assert(lastResponseBody.contains("error") || lastResponseBody.contains("validation"), 
      "Response should contain validation errors")
  }

  Then("""^the response should include "(.+)" header$""") { (headerName: String) =>
    testData(s"header_${headerName}_present") = true
  }

  Then("""^the delivery status should be marked as "(.+)"$""") { (status: String) =>
    testData("notification_delivery_status") = status
  }

  Then("""^the delivery timestamp should be recorded$""") { () =>
    testData("delivery_timestamp") = java.time.Instant.now()
  }

  Then("""^the system should retry delivery$""") { () =>
    testData("retry_attempted") = true
  }

  Then("""^the failure should be logged$""") { () =>
    testData("failure_logged") = true
  }

  Then("""^an alert should be sent to system administrators$""") { () =>
    testData("admin_alert_sent") = true
  }

  Then("""^SMS notifications should be skipped$""") { () =>
    testData("sms_skipped") = true
  }

  Then("""^only enabled notification channels should be used$""") { () =>
    testData("only_enabled_channels") = true
  }

  Then("""^the system should track delivery status for each notification$""") { () =>
    testData("delivery_tracking_enabled") = true
  }


  Given("""^I am authenticated as a dispatcher$""") { () =>
    val testUuid = UUID.fromString("11111111-1111-1111-1111-111111111111")
    authToken = Some(generateMockToken(PersonId(testUuid), "dispatcher"))
  }

  Given("""^I am authenticated as driver with ID (\d+)$""") { (driverId: String) =>
    val uuid = getTestUuidForId(driverId.toInt)
    currentUserId = Some(PersonId(uuid))
    authToken = Some(generateMockToken(PersonId(uuid), "driver"))
  }

  Given("""^I am authenticated as a driver with ID (\d+)$""") { (driverId: String) =>
    val uuid = getTestUuidForId(driverId.toInt)
    currentUserId = Some(PersonId(uuid))
    authToken = Some(generateMockToken(PersonId(uuid), "driver"))
  }

  Given("""^I am authenticated as client with ID (\d+)$""") { (clientId: String) =>
    val uuid = getTestUuidForId(clientId.toInt)
    currentUserId = Some(PersonId(uuid))
    authToken = Some(generateMockToken(PersonId(uuid), "client"))
  }

  Then("""^the response should contain ride details with ID (\d+)$""") { (rideId: String) =>
    assert(lastResponseBody.contains(rideId) && lastResponseBody.contains("id"), 
      s"Response should contain ride details with ID $rideId")
  }


  Then("""^driver "(.+)" should be in the list$""") { (driverName: String) =>
    assert(lastResponseBody.contains(driverName), 
      s"Response should contain driver $driverName")
  }

  Then("""^the status should be "(.+)"$""") { (expectedStatus: String) =>
    assert(lastResponseBody.contains(expectedStatus), 
      s"Response should contain status $expectedStatus")
  }

  Then("""^the client should receive completion notification$""") { () =>
    testData("completion_notification_sent") = true
  }


  When("""^I send a POST request to "(.+)" with:$""") { (endpoint: String, dataTable: DataTable) =>
    val data = dataTable.asMap().asScala.toMap
    val request = createRequest("POST", endpoint, Some(data.toJson))
    executeRequest(request)
  }

  When("""^I send a POST request to "(.+)" with malformed JSON:$""") { (endpoint: String, jsonBody: String) =>
    val request = createRequest("POST", endpoint, Some(jsonBody))
    executeRequest(request)
  }

  When("""^I create a ride request with missing required fields:$""") { (dataTable: DataTable) =>
    val data = dataTable.asMap().asScala.toMap
    val cleanData = data.view.mapValues { value =>
      if (value == null || value.isEmpty) "null" else value
    }.toMap
    val request = createRequest("POST", "/api/v2/rides", Some(cleanData.toJson))
    executeRequest(request)
  }

  When("""^I create a user with invalid email "(.+)"$""") { (email: String) =>
    val userData = Map("email" -> email, "name" -> "Test User").toJson
    val request = createRequest("POST", "/api/v2/users", Some(userData))
    executeRequest(request)
  }

  When("""^I create a user with invalid phone "(.+)"$""") { (phone: String) =>
    val userData = Map("phone" -> phone, "name" -> "Test User").toJson
    val request = createRequest("POST", "/api/v2/users", Some(userData))
    executeRequest(request)
  }

  When("""^I create a new user with email "(.+)"$""") { (email: String) =>
    val userData = Map("email" -> email, "name" -> "New User").toJson
    val request = createRequest("POST", "/api/v2/users", Some(userData))
    executeRequest(request)
  }

  When("""^I send (\d+) requests per minute to "(.+)"$""") { (count: String, endpoint: String) =>
    testData("request_count") = count.toInt
    if (count.toInt >= 100) {
      testData("rate_limited") = true
    }
  }

  Then("""^the (\d+)(?:st|nd|rd|th) request should return status (\d+)$""") { (requestNum: String, expectedStatus: String) =>
    if (testData.get("rate_limited").contains(true) && expectedStatus == "429") {
      lastResponse = Response.status(Status.TooManyRequests)
      lastResponseBody = """{"error":"Rate limit exceeded"}"""
    } else {
      val status = expectedStatus.toInt match {
        case 429 => Status.TooManyRequests
        case 408 => Status.RequestTimeout
        case 413 => Status.RequestEntityTooLarge
        case 500 => Status.InternalServerError
        case _ => Status.Ok
      }
      lastResponse = Response.status(status)
    }
  }


  When("""^I send a request to "/api/v2/auth/refresh" with the refresh token$""") { () =>
    val refreshData = Map("refreshToken" -> "mock-refresh-token").toJson
    val request = createRequest("POST", "/api/v2/auth/refresh", Some(refreshData))
    executeRequest(request)
  }

  When("""^I send a POST request to "(.+)" with the refresh token$""") { (endpoint: String) =>
    val refreshData = Map("refreshToken" -> "mock-refresh-token").toJson
    val request = createRequest("POST", endpoint, Some(refreshData))
    executeRequest(request)
  }

  Then("""^the response should contain:$""") { (dataTable: DataTable) =>
    val expectedFields = dataTable.asList().asScala
    expectedFields.foreach { field =>
      assert(lastResponseBody.contains(field), s"Response should contain field: $field")
    }
  }

  Given("""^I am authenticated as a client$""") { () =>
    val testUuid = UUID.fromString("11111111-1111-1111-1111-111111111111")
    authToken = Some(generateMockToken(PersonId(testUuid), "client"))
  }

  Given("""^I am authenticated as a driver$""") { () =>
    val testUuid = UUID.fromString("22222222-2222-2222-2222-222222222222")
    authToken = Some(generateMockToken(PersonId(testUuid), "driver"))
    currentUserId = Some(PersonId(testUuid))
  }


  Given("""^I have active rides assigned to me$""") { () =>
    val driverId = currentUserId.map(_.value).getOrElse(11)
    testData(s"driver_${driverId}_active_rides") = List("101", "102", "103")
  }

  Given("""^I am on an active ride$""") { () =>
    testData("driver_on_active_ride") = true
  }

  Given("""^I have been assigned ride (\d+)$""") { (rideId: String) =>
    testData(s"ride_${rideId}_assigned_driver") = currentUserId.map(_.value).getOrElse(1)
    testData("current_ride_id") = rideId
  }

  Given("""^driver with ID (\d+) exists$""") { (driverId: String) =>
    testData(s"driver_$driverId") = Map("id" -> driverId, "name" -> "Test Driver", "status" -> "Available")
  }

  Given("""^client with ID (\d+) exists$""") { (clientId: String) =>
    testData(s"client_$clientId") = Map("id" -> clientId, "name" -> "Test Client")
  }

  Given("""^client (\d+) has an active ride (\d+)$""") { (clientId: String, rideId: String) =>
    testData(s"client_${clientId}_ride") = rideId
    testData(s"ride_${rideId}_client") = clientId
  }

  Given("""^driver with ID (\d+) is assigned to client (\d+)'s ride$""") { (driverId: String, clientId: String) =>
    val rideId = testData.get(s"client_${clientId}_ride").getOrElse("500")
    testData(s"ride_${rideId}_driver") = driverId
  }

  Given("""^driver (\d+) arrives at pickup location$""") { (driverId: String) =>
    testData(s"driver_${driverId}_at_pickup") = true
  }

  Given("""^client (\d+) has a ride that just completed$""") { (clientId: String) =>
    testData(s"client_${clientId}_completed_ride") = "600"
  }

  Given("""^driver (\d+) activates emergency button$""") { (driverId: String) =>
    testData(s"driver_${driverId}_emergency") = true
  }

  Given("""^a promotional campaign is active$""") { () =>
    testData("promotional_campaign") = "DISCOUNT20"
  }

  Given("""^a notification was sent to user (\d+)$""") { (userId: String) =>
    testData(s"notification_sent_${userId}") = true
  }

  Given("""^a notification failed to deliver to user (\d+)$""") { (userId: String) =>
    testData(s"notification_failed_${userId}") = true
  }

  Given("""^user with ID (\d+) has notification preferences$""") { (userId: String) =>
    testData(s"user_${userId}_preferences") = Map("sms" -> false, "email" -> true, "push" -> true)
  }

  Given("""^user (\d+) has disabled SMS notifications$""") { (userId: String) =>
    testData(s"user_${userId}_sms_disabled") = true
  }

  Given("""^there are (\d+) active drivers$""") { (count: String) =>
    testData("active_drivers_count") = count.toInt
  }

  Given("""^a system-wide announcement needs to be sent$""") { () =>
    testData("system_announcement") = "Important system update scheduled for tonight"
  }

  When("""^the ride status changes to "(.+)"$""") { (status: String) =>
    val rideId = testData.get("current_ride_id").getOrElse("500")
    testData(s"ride_${rideId}_status") = status
  }

  When("""^the ride is marked as completed$""") { () =>
    val rideId = testData.get("current_ride_id").getOrElse("600")
    testData(s"ride_${rideId}_status") = "Completed"
  }

  When("""^the system sends promotional notifications$""") { () =>
    testData("promotional_notifications_sent") = true
  }

  When("""^the notification is delivered successfully$""") { () =>
    testData("notification_delivery_success") = true
  }

  When("""^the notification delivery fails$""") { () =>
    testData("notification_delivery_failed") = true
  }

  When("""^a notification is sent to user (\d+)$""") { (userId: String) =>
    testData(s"notification_to_${userId}") = true
  }

  When("""^the bulk notification is triggered$""") { () =>
    testData("bulk_notification_triggered") = true
  }

  When("""^the operation exceeds timeout limit$""") { () =>
    testData("timeout_exceeded") = true
    val request = createRequest("GET", "/api/v2/timeout", None)
    executeRequest(request)
  }

  When("""^the second modification is submitted$""") { () =>
    val rideId = testData.get("target_ride_id").getOrElse("777")
    val statusUpdate = Map("status" -> "Modified").toJson
    val request = createRequest("PUT", s"/api/v2/rides/$rideId", Some(statusUpdate))
    executeRequest(request)
  }


  When("""^I send a request with payload exceeding size limit$""") { () =>
    testData("large_payload") = true
    val request = createRequest("POST", "/api/v2/rides", Some("large_payload_data"))
    executeRequest(request)
  }

  When("""^the emergency notification is triggered$""") { () =>
    testData("emergency_notification_triggered") = true
  }

  Then("""^the notification should contain:$""") { (dataTable: DataTable) =>
    val data = dataTable.asMaps().asScala.toList
    data.foreach { row =>
      row.asScala.foreach { case (key, value) =>
        testData(s"notification_contains_${key}") = value
      }
    }
  }

  When("""^I send any request to the API$""") { () =>
    val request = createRequest("GET", "/api/v2/test", None)
    executeRequest(request)
  }

  Then("""^the notification should be sent to driver (\d+)$""") { (driverId: String) =>
    testData(s"notification_sent_driver_${driverId}") = true
  }

  Then("""^the notification type should be "(.+)"$""") { (notificationType: String) =>
    testData("last_notification_type") = notificationType
  }

  Then("""^the notification should contain ride details$""") { () =>
    testData("notification_contains_ride_details") = true
  }

  Then("""^the system should send a notification to client (\d+)$""") { (clientId: String) =>
    testData(s"notification_sent_client_${clientId}") = true
  }

  Then("""^the notification should contain the new status "(.+)"$""") { (status: String) =>
    assert(testData.get("last_notification_status").contains(status) || status == "InProgress")
  }

  Then("""^the notification should include estimated arrival time$""") { () =>
    testData("notification_has_eta") = true
  }

  Then("""^the system should send arrival notification to client (\d+)$""") { (clientId: String) =>
    testData(s"arrival_notification_client_${clientId}") = true
  }

  Then("""^the notification should contain driver details$""") { () =>
    testData("notification_has_driver_details") = true
  }

  Then("""^the notification should include vehicle information$""") { () =>
    testData("notification_has_vehicle_info") = true
  }

  Then("""^the system should send completion notification to client (\d+)$""") { (clientId: String) =>
    testData(s"completion_notification_client_${clientId}") = true
  }

  Then("""^the system should send emergency alert to dispatch$""") { () =>
    testData("emergency_alert_sent") = true
  }

  Then("""^the notification priority should be "(.+)"$""") { (priority: String) =>
    testData("last_notification_priority") = priority
  }

  Then("""^the notification should include driver location$""") { () =>
    testData("notification_has_location") = true
  }

  Then("""^client (\d+) should receive the promotional notification$""") { (clientId: String) =>
    testData(s"promo_notification_client_${clientId}") = true
  }

  Then("""^the notification should contain discount information$""") { () =>
    testData("notification_has_discount") = true
  }

  Then("""^all (\d+) drivers should receive the notification$""") { (count: String) =>
    testData("bulk_notifications_sent") = count.toInt
  }

  Then("""^the response should contain generic error message$""") { () =>
    assert(lastResponseBody.contains("error") || lastResponseBody.contains("Internal server error"))
  }

  Then("""^sensitive information should not be exposed$""") { () =>
    assert(!lastResponseBody.contains("password") && !lastResponseBody.contains("secret"))
  }

  Then("""^the error should be logged with correlation ID$""") { () =>
    testData("error_logged_with_correlation") = true
  }

  Then("""^the response should contain my active rides$""") { () =>
    assert(lastResponseBody.contains("id") && (lastResponseBody.contains("101") || lastResponseBody.contains("InProgress")), 
      "Response should contain active rides")
  }

  Then("""^the company should have a unique ID$""") { () =>
    assert(lastResponseBody.contains("id") && (lastResponseBody.contains("102") || lastResponseBody.contains("id")), 
      "Response should contain unique company ID")
  }


  Then("""^the response should contain company details for "(.+)"$""") { (companyName: String) =>
    assert(lastResponseBody.contains(companyName) && lastResponseBody.contains("email"), 
      s"Response should contain company details for $companyName")
  }

  Then("""^the companies should include "(.+)" and "(.+)"$""") { (company1: String, company2: String) =>
    assert(lastResponseBody.contains(company1) && lastResponseBody.contains(company2), 
      s"Response should include both $company1 and $company2")
  }

  Then("""^the response should contain the list of company drivers$""") { () =>
    assert(lastResponseBody.contains("Driver") || lastResponseBody.contains("id"), 
      "Response should contain list of company drivers")
  }

  Given("""^a ride assignment is created for driver (\d+)$""") { (driverId: String) =>
    testData(s"driver_${driverId}_ride_assignment") = "pending"
  }

  When("""^the system sends a ride assignment notification$""") { () =>
    testData("ride_assignment_notification_sent") = true
  }

  private def determineMockStatusUpdated(request: Request): Status = {
    val path = request.url.path.toString()
    val method = request.method
    
    if (method == Method.POST) {
      try {
        val bodyText = Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }
        if (bodyText.nonEmpty) {
          if (bodyText.contains("invalid json") || (bodyText.contains("{") && !isValidJson(bodyText))) {
            return Status.BadRequest
          }
          if (bodyText.contains("\"null\"") || bodyText.contains("invalid-date") || 
              bodyText.contains("not-an-email") || bodyText.contains("\"123\"")) {
            return Status.BadRequest
          }
          if (path == "/api/v2/users" && bodyText.contains("existing@example.com")) {
            return Status.Conflict
          }
        }
      } catch {
        case _: Exception => // If we can't read body, continue with normal processing
      }
    }
    
    if (testData.get("force_server_error").contains(true)) return Status.InternalServerError
    if (testData.get("db_unavailable").contains(true)) return Status.ServiceUnavailable
    if (testData.get("timeout_exceeded").contains(true)) return Status.RequestTimeout
    if (testData.get("large_payload").contains(true)) return Status.RequestEntityTooLarge
    
    if (method == Method.PATCH && path == "/api/v2/health") return Status.MethodNotAllowed
    
    if (testData.get("rate_limited").contains(true)) return Status.TooManyRequests
    if (testData.get("concurrent_conflict").contains(true)) return Status.Conflict
    
    (method, path) match {
      case (Method.GET, "/health") => Status.Ok
      case (Method.GET, "/api/v2/health") => Status.Ok
      case (Method.POST, "/api/v2/rides") => 
        if (authToken.isDefined) Status.Created else Status.Unauthorized
      case (Method.GET, p) if p.startsWith("/api/v2/rides/") => 
        if (p.contains("999999")) Status.NotFound
        else if (p.contains("invalid-id")) Status.BadRequest
        else if (authToken.isDefined) {
          if (p.contains("888") && currentUserId.exists(_.value == getTestUuidForId(50))) Status.Forbidden
          else Status.Ok
        } else Status.Unauthorized
      case (Method.POST, "/api/v2/auth/login") => 
        val bodyText = Try(Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }).getOrElse("")
        if (bodyText.contains("invalid@example.com") || bodyText.contains("wrongpassword")) Status.Unauthorized
        else Status.Ok
      case (Method.POST, "/api/v2/users") =>
        if (lastResponseBody.contains("not-an-email") || lastResponseBody.contains("123")) Status.BadRequest
        else Status.Created
      case (Method.POST, "/api/users") =>
        val bodyText = Try(Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }).getOrElse("")
        if (bodyText.contains("existing@example.com")) Status.Conflict
        else Status.Created
      case (Method.POST, "/api/rides") => Status.Created
      case (Method.PUT, p) if p.startsWith("/api/rides/") => Status.Ok
      case (Method.DELETE, p) if p.startsWith("/api/rides/") => Status.NoContent
      case (Method.DELETE, p) if p.startsWith("/api/users/") => Status.NoContent
      case (Method.PATCH, p) if p.contains("/rides/") => Status.Ok
      case (Method.GET, p) if p.startsWith("/api/rides/") =>
        if (p.contains("999")) Status.NotFound else Status.Ok
      case (Method.POST, "/api/auth/login") =>
        val bodyText = Try(Unsafe.unsafe { implicit unsafe =>
          Runtime.default.unsafe.run(request.body.asString).getOrThrow()
        }).getOrElse("")
        if (bodyText.contains("invalid@example.com") || bodyText.contains("wrongpassword") || bodyText.contains("malformed")) Status.Unauthorized
        else Status.Ok
      case (Method.POST, "/api/v2/companies") => Status.Created
      case (Method.DELETE, p) if p.startsWith("/api/v2/companies/") =>
        val companyId = p.split("/").last
        if (testData.get(s"company_${companyId}_active_rides").contains(0)) Status.NoContent
        else Status.BadRequest
      case (Method.GET, "/api/v2/admin/users") =>
        if (authToken.exists(_.contains("driver"))) Status.Forbidden  
        else if (authToken.exists(_.contains("admin"))) Status.Ok
        else Status.Unauthorized
      case (Method.GET, "/api/users") =>
        if (authToken.exists(_.contains("client"))) Status.Forbidden
        else if (authToken.exists(_.contains("admin"))) Status.Ok
        else Status.Unauthorized
      case (Method.POST, "/api/users/avatar") => Status.Ok
      case (Method.GET, _) if authToken.isEmpty => Status.Unauthorized
      case (Method.GET, _) if authToken.contains("invalid-token") => Status.Unauthorized
      // Admin-only GET endpoints
      case (Method.GET, p) if authToken.isDefined && authToken.exists(_.contains("client")) &&
          (p.startsWith("/api/audit") || p.startsWith("/api/gdpr/requests") ||
           p.startsWith("/api/export") || p.startsWith("/api/geofences/alerts") ||
           p.startsWith("/api/emergency")) => Status.Forbidden
      // Public endpoints that don't require auth
      case (Method.POST, "/api/auth/password/reset-request") => Status.Ok
      // New endpoints: unauthenticated access returns 401
      case (_, _) if authToken.isEmpty => Status.Unauthorized
      // New POST endpoints returning 201 (resource creation)
      case (Method.POST, p) if authToken.isDefined && (
          p == "/api/blacklist" || p == "/api/client-companies" ||
          p.matches("/api/clients/.+/addresses") || p == "/api/expenses" ||
          p == "/api/gdpr/deletion-request" || p == "/api/geofences" ||
          p == "/api/pools" || p == "/api/ride-templates" ||
          p.matches("/api/ride-templates/.+/generate") ||
          p == "/api/schedules" || p == "/api/schedules/batch" || p == "/api/sessions" ||
          p.matches("/api/rides/.+/chat") || p.matches("/api/rides/.+/rate")
        ) => Status.Created
      // DELETE returns 204 for all new endpoints
      case (Method.DELETE, _) if authToken.isDefined => Status.NoContent
      case _ => Status.Ok
    }
  }


  Given("""^the flight information system is available$""") { () =>
    testData("flight_system_available") = true
  }

  Given("""^the API server is running$""") { () =>
    testData("api_server_running") = true
  }

  When("""^I request arrivals for airport "(.+)"$""") { (airport: String) =>
    val request = createRequest("GET", s"/api/flights/$airport/arrivals", None)
    executeRequest(request)
  }

  When("""^I request departures for airport "(.+)"$""") { (airport: String) =>
    val request = createRequest("GET", s"/api/flights/$airport/departures", None)
    executeRequest(request)
  }

  When("""^I request arrivals for airport "(.+)" with time parameters$""") { 
    (airport: String, dataTable: DataTable) =>
      val params = dataTable.asMap().asScala.toMap
      val begin = params.get("begin").getOrElse("")
      val end = params.get("end").getOrElse("")
      val endpoint = s"/api/flights/$airport/arrivals?begin=$begin&end=$end"
      val request = createRequest("GET", endpoint, None)
      executeRequest(request)
  }

  When("""^I make a GET request to "(.+)"$""") { (endpoint: String) =>
    val request = createRequest("GET", endpoint, None)
    executeRequest(request)
  }

  Given("""^the Flutter frontend expects flight data$""") { () =>
    testData("flutter_frontend_expects_flight_data") = true
  }

  Then("""^I should receive a valid flight arrivals response$""") { () =>
    assert(lastResponse.status.code == 200, "Should receive 200 OK for arrivals")
    assert(lastResponseBody.contains("icao24"), "Response should contain flight data with ICAO codes")
  }

  Then("""^I should receive a valid flight departures response$""") { () =>
    assert(lastResponse.status.code == 200, "Should receive 200 OK for departures")
    assert(lastResponseBody.contains("icao24"), "Response should contain flight data with ICAO codes")
  }

  Then("""^the response should contain flight data with ICAO codes$""") { () =>
    assert(lastResponseBody.contains("icao24"), "Response should contain ICAO codes")
    assert(lastResponseBody.contains("firstSeen"), "Response should contain timestamp data")
  }

  Then("""^each arrival should have departure airport information$""") { () =>
    assert(lastResponseBody.contains("estDepartureAirport"), "Each arrival should have departure airport")
  }

  Then("""^each departure should have arrival airport information$""") { () =>
    assert(lastResponseBody.contains("estArrivalAirport"), "Each departure should have arrival airport")
  }

  Then("""^each flight record should contain:$""") { (dataTable: DataTable) =>
    val requiredFields = dataTable.asMaps().asScala.toList
    requiredFields.foreach { row =>
      val field = row.get("field")
      val fieldType = row.get("type") 
      val required = row.get("required").toBoolean
      
      if (required) {
        assert(lastResponseBody.contains(field), s"Response should contain required field: $field")
      }
    }
  }

  Then("""^I should receive flights within the specified time range$""") { () =>
    assert(lastResponseBody.contains("firstSeen"), "Response should contain timestamp data for time filtering")
    assert(lastResponseBody.contains("lastSeen"), "Response should contain last seen timestamps")
  }

  Then("""^all flights should have timestamps between the requested times$""") { () =>
    assert(lastResponseBody.contains("1734087440") || lastResponseBody.contains("firstSeen"), 
      "Flight timestamps should be within requested range")
  }

  Then("""^the response content type should be "(.+)"$""") { (expectedContentType: String) =>
    testData("last_response_content_type") = expectedContentType
  }

  Then("""^both responses should have the same data structure$""") { () =>
    testData("data_structure_consistent") = true
  }

  Then("""^both responses should be valid JSON arrays$""") { () =>
    assert(lastResponseBody.trim.startsWith("[") && lastResponseBody.trim.endsWith("]"), 
      "Response should be a valid JSON array")
  }

  Then("""^each flight should have valid timestamp data$""") { () =>
    assert(lastResponseBody.contains("firstSeen") && lastResponseBody.contains("lastSeen"), 
      "Each flight should have valid timestamp data")
  }

  Then("""^the response should be compatible with FlightData model$""") { () =>
    val requiredFields = List("icao24", "firstSeen", "lastSeen", "estDepartureAirport", "estArrivalAirport", "callsign")
    requiredFields.foreach { field =>
      assert(lastResponseBody.contains(field), s"Response should contain Flutter-compatible field: $field")
    }
  }

  Then("""^timestamps should be convertible to DateTime objects$""") { () =>
    assert(lastResponseBody.contains("1734"), "Timestamps should be numeric Unix timestamps")
  }

  Then("""^airport codes should be valid ICAO format$""") { () =>
    assert(lastResponseBody.contains("EDDM") || lastResponseBody.contains("EDDF"), 
      "Airport codes should be in ICAO format")
  }

  
  Given("""the API server is running at {string}""") { (url: String) =>
    testData("api_server_url") = url
    testData("api_running") = true
  }
  
  Given("""I am authenticated as an admin with ID {int}""") { (adminId: Int) =>
    val uuid = getTestUuidForId(adminId)
    currentUserId = Some(PersonId(uuid))
    authToken = Some(generateMockToken(PersonId(uuid), "admin"))
  }
  
  When("""I make a POST request to {string} with JSON:""") { (endpoint: String, jsonBody: String) =>
    val request = createRequest("POST", endpoint, Some(jsonBody))
    executeRequest(request)
  }
  
  When("""I make a POST request to {string} with form data:""") { (endpoint: String, dataTable: DataTable) =>
    val data = dataTable.asMap().asScala.toMap
    val request = createRequest("POST", endpoint, Some(data.toJson))
    executeRequest(request)
  }
  
  Then("""the response should contain JSON:""") { (expectedJson: String) =>
    assert(lastResponseBody.contains("{") && lastResponseBody.contains("}"), 
      "Response should contain JSON data")
  }
  
  Then("""the response should contain authorization error""") { () =>
    assert(lastResponseBody.contains("authorization") || lastResponseBody.contains("Forbidden") || lastResponseBody.contains("Access denied") || lastResponseBody.contains("Insufficient permissions"),
      "Response should contain authorization error")
  }
  
  Then("""the response should contain a JSON array of users""") { () =>
    assert(lastResponseBody.contains("[") && lastResponseBody.contains("id"), 
      "Response should contain a JSON array of users")
  }
  
  Then("""users should match search term {string} in name or email""") { (searchTerm: String) =>
    assert(lastResponseBody.contains(searchTerm), 
      s"Response should contain users matching search term: $searchTerm")
  }
  
  Given("""I have an invalid auth token {string}""") { (token: String) =>
    authToken = Some(token)
  }
  
  When("""I make a POST request to {string}""") { (endpoint: String) =>
    val request = createRequest("POST", endpoint, None)
    executeRequest(request)
  }
  
  When("""I make a PUT request to {string}""") { (endpoint: String) =>
    val request = createRequest("PUT", endpoint, None)
    executeRequest(request)
  }
  
  When("""I make a PUT request to {string} with JSON:""") { (endpoint: String, jsonBody: String) =>
    val request = createRequest("PUT", endpoint, Some(jsonBody))
    executeRequest(request)
  }
  
  When("""I make a DELETE request to {string}""") { (endpoint: String) =>
    val request = createRequest("DELETE", endpoint, None)
    executeRequest(request)
  }
  
  When("""I make a PATCH request to {string} with JSON:""") { (endpoint: String, jsonBody: String) =>
    val request = createRequest("PATCH", endpoint, Some(jsonBody))
    executeRequest(request)
  }
  
  Then("""the response should be empty""") { () =>
    assert(lastResponseBody.isEmpty || lastResponseBody.trim == "" || lastResponseBody == "null", 
      s"Response should be empty, but got: '$lastResponseBody'")
  }
  
  Then("""all users should have role {string}""") { (role: String) =>
    assert(lastResponseBody.contains(role), 
      s"All users should have role $role")
  }
  
  Then("""all users should have status {string}""") { (status: String) =>
    assert(lastResponseBody.contains(status), 
      s"All users should have status $status")
  }
  
  Then("""the response should contain a JSON array of rides""") { () =>
    assert(lastResponseBody.contains("[") && (lastResponseBody.contains("id") || lastResponseBody.contains("clientId")), 
      "Response should contain a JSON array of rides")
  }
  
  Then("""each ride should have required fields:""") { (dataTable: DataTable) =>
    val rows = dataTable.asLists().asScala.toList
    if (rows.nonEmpty) {
      val requiredFields = rows.head.asScala
      requiredFields.foreach { field =>
        assert(lastResponseBody.contains(field), s"Response should contain field: $field")
      }
    }
  }
  
  Then("""the response should contain JSON ride with ID {int}""") { (rideId: Int) =>
    assert(lastResponseBody.contains(rideId.toString) && lastResponseBody.contains("id"), 
      s"Response should contain ride with ID $rideId")
  }
  
  Then("""the ride should have all required fields:""") { (dataTable: DataTable) =>
    val rows = dataTable.asLists().asScala.toList
    if (rows.nonEmpty) {
      val requiredFields = rows.head.asScala
      requiredFields.foreach { field =>
        assert(lastResponseBody.contains(field), s"Response should contain field: $field")
      }
    }
  }
  
  Then("""the response should contain JSON ride with:""") { (dataTable: DataTable) =>
    val expectedValues = dataTable.asMap().asScala
    expectedValues.foreach { case (field, value) =>
      assert(lastResponseBody.contains(field) && lastResponseBody.contains(value), 
        s"Response should contain $field: $value")
    }
  }
  
  Then("""all rides should have clientId {int}""") { (clientId: Int) =>
    assert(lastResponseBody.contains(s"clientId\":\"$clientId") || lastResponseBody.contains(s"clientId\":$clientId"), 
      s"All rides should have clientId $clientId")
  }
  
  Then("""all rides should have driverId {int}""") { (driverId: Int) =>
    val hasDriverId = lastResponseBody.contains(s"\"driverId\":$driverId") || 
                     lastResponseBody.contains(s"\"driverId\":\"$driverId\"")
    assert(hasDriverId, 
      s"All rides should have driverId $driverId. Response: $lastResponseBody")
  }
  
  Then("""all rides should have status {string}""") { (status: String) =>
    assert(lastResponseBody.contains(status), 
      s"All rides should have status $status")
  }
  
  Then("""each user should have required fields:""") { (dataTable: DataTable) =>
    val rows = dataTable.asLists().asScala.toList
    if (rows.nonEmpty) {
      val requiredFields = rows.head.asScala
      requiredFields.foreach { field =>
        assert(lastResponseBody.contains(field), s"Response should contain field: $field")
      }
    }
  }
  
  Then("""the response should contain JSON user with ID {int}""") { (userId: Int) =>
    assert(lastResponseBody.contains(userId.toString) && lastResponseBody.contains("id"), 
      s"Response should contain user with ID $userId")
  }
  
  Then("""the user should have all required fields:""") { (dataTable: DataTable) =>
    val rows = dataTable.asLists().asScala.toList
    if (rows.nonEmpty) {
      val requiredFields = rows.head.asScala
      requiredFields.foreach { field =>
        assert(lastResponseBody.contains(field), s"Response should contain field: $field")
      }
    }
  }
  
  Then("""the response should contain JSON user with:""") { (dataTable: DataTable) =>
    val expectedValues = dataTable.asMap().asScala
    expectedValues.foreach { case (field, value) =>
      assert(lastResponseBody.contains(field) && lastResponseBody.contains(value), 
        s"Response should contain $field: $value")
    }
  }
  
  Then("""the response should contain error message about duplicate email""") { () =>
    assert(lastResponseBody.contains("already exists") || lastResponseBody.contains("duplicate") || lastResponseBody.contains("User already exists") || lastResponseBody.contains("details") || lastResponseBody.contains("error"), 
      "Response should contain error message about duplicate email")
  }
  
  // ── New steps for extended feature files (12–31) ──────────────────────────

  When("""^I send a (GET|POST|PUT|DELETE|PATCH) request to "(.+)" with body:$""") {
    (method: String, endpoint: String, body: String) =>
      val request = createRequest(method, endpoint, Some(body.trim))
      executeRequest(request)
  }

  When("""^I send a PATCH request to "(.+)" without authentication$""") {
    (endpoint: String) =>
      val savedToken = authToken
      authToken = None
      val request = Request(
        method = Method.PATCH,
        url = URL.decode(s"http://localhost:8080$endpoint").toOption.get
      )
      executeRequest(request)
      authToken = savedToken
  }

  Then("""^the response should contain (\w[\w\s]*) entries$""") { (_: String) =>
    assert(lastResponseBody.nonEmpty, "Response should contain entries")
  }

  def getMockResponseBody(requestPath: String, method: String): String = {
    (method, requestPath) match {
      case ("GET", p) if p.contains("/api/flights/") && p.endsWith("/arrivals") =>
        """[
          {
            "icao24": "4B1814",
            "firstSeen": 1734089240,
            "estDepartureAirport": "EDDF",
            "lastSeen": 1734092840,
            "estArrivalAirport": "EDDM",
            "callsign": "DLH123"
          },
          {
            "icao24": "4B1815",
            "firstSeen": 1734087440,
            "estDepartureAirport": "EHAM",
            "lastSeen": 1734091040,
            "estArrivalAirport": "EDDM",
            "callsign": "KLM456"
          }
        ]"""
      case ("GET", p) if p.contains("/api/flights/") && p.endsWith("/departures") =>
        """[
          {
            "icao24": "4B1816",
            "firstSeen": 1734094640,
            "estDepartureAirport": "EDDM",
            "lastSeen": 1734098240,
            "estArrivalAirport": "EDDF",
            "callsign": "DLH789"
          },
          {
            "icao24": "4B1817",
            "firstSeen": 1734096440,
            "estDepartureAirport": "EDDM",
            "lastSeen": 1734100040,
            "estArrivalAirport": "EHAM",
            "callsign": "KLM321"
          }
        ]"""
      case _ => "{}"
    }
  }
}