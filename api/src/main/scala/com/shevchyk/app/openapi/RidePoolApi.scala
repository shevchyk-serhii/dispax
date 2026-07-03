package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AuditService, EventHub}
import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.{PersonRepository, RidePoolRepository}
import com.shevchyk.ride.application.service.RideService
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*

import java.time.Instant

/**
 * Tapir descriptions and server logic for the ride-pool endpoints. Replaces the hand-written zio-http handlers in
 * `RidePoolRoutes` while preserving paths, role checks, company isolation, audit logging, websocket events, status
 * codes and error mapping.
 *
 * The original handlers fail with explicit `Response(BadRequest)` for missing `driverId`/`status` body fields; those
 * 400s are reproduced here. Every other non-`Response` failure (pool not found, "Pool is full", invalid status,
 * repository/service errors, ...) is routed through `RouteErrorHandler` to a 500, reproduced via `internal`.
 */
object RidePoolApi:

  import AppSecure.*
  import ApiSchemas.given

  private val ridePoolTag = "RidePool"

  /**
   * `RidePool` enriched with the assigned driver's display name so the UI never has to show a bare UUID. The name is
   * resolved at read time; `None` when no driver is assigned or the person no longer exists.
   */
  final case class RidePoolDto(
      id: RidePoolId,
      companyId: CompanyId,
      name: Option[String],
      status: PoolStatus,
      driverId: Option[PersonId],
      maxPassengers: Int,
      currentPassengers: Int,
      routeDirection: Option[String],
      scheduledTime: Option[Instant],
      createdAt: Instant,
      createdBy: PersonId,
      driverName: Option[String]
  ) derives JsonCodec

  object RidePoolDto:

    def fromDomain(p: RidePool, names: Map[PersonId, String]): RidePoolDto = RidePoolDto(
      id = p.id,
      companyId = p.companyId,
      name = p.name,
      status = p.status,
      driverId = p.driverId,
      maxPassengers = p.maxPassengers,
      currentPassengers = p.currentPassengers,
      routeDirection = p.routeDirection,
      scheduledTime = p.scheduledTime,
      createdAt = p.createdAt,
      createdBy = p.createdBy,
      driverName = p.driverId.flatMap(names.get)
    )

  /**
   * `RidePoolMember` enriched with the client's display name (see [[RidePoolDto]]).
   */
  final case class RidePoolMemberDto(
      id: RidePoolMemberId,
      poolId: RidePoolId,
      rideId: RideId,
      clientId: PersonId,
      pickupOrder: Int,
      status: PoolMemberStatus,
      addedAt: Instant,
      clientName: Option[String]
  ) derives JsonCodec

  object RidePoolMemberDto:

    def fromDomain(m: RidePoolMember, names: Map[PersonId, String]): RidePoolMemberDto = RidePoolMemberDto(
      id = m.id,
      poolId = m.poolId,
      rideId = m.rideId,
      clientId = m.clientId,
      pickupOrder = m.pickupOrder,
      status = m.status,
      addedAt = m.addedAt,
      clientName = names.get(m.clientId)
    )

  /**
   * Mirrors the inline `{"pool":..,"members":..}` JSON body produced by the original GET /api/pools/{id}.
   */
  final case class PoolDetailResponse(pool: RidePoolDto, members: List[RidePoolMemberDto]) derives JsonCodec

  type RidePoolEnv = JwtService & RidePoolRepository & RideService & AuditService & EventHub & PersonRepository

  // -- Endpoint descriptions ------------------------------------------------

  val createEndpoint = secureEndpoint.post
    .in("api" / "pools")
    .in(jsonBody[CreatePoolRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[RidePool]))
    .tag(ridePoolTag)
    .summary("Create a ride pool (dispatcher)")

  val listEndpoint = secureEndpoint.get
    .in("api" / "pools")
    .out(jsonBody[List[RidePoolDto]])
    .tag(ridePoolTag)
    .summary("List ride pools for the company (dispatcher)")

  val listOpenEndpoint = secureEndpoint.get
    .in("api" / "pools" / "open")
    .out(jsonBody[List[RidePool]])
    .tag(ridePoolTag)
    .summary("List open ride pools (dispatcher)")

  val findByRideEndpoint = secureEndpoint.get
    .in("api" / "pools" / "ride" / path[String]("rideId"))
    .out(jsonBody[RidePool])
    .tag(ridePoolTag)
    .summary("Find the pool a ride belongs to")

  val getEndpoint = secureEndpoint.get
    .in("api" / "pools" / path[String]("id"))
    .out(jsonBody[PoolDetailResponse])
    .tag(ridePoolTag)
    .summary("Get a pool with its members (dispatcher, driver)")

  val addRideEndpoint = secureEndpoint.post
    .in("api" / "pools" / path[String]("id") / "rides")
    .in(jsonBody[AddToPoolRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[RidePoolMember]))
    .tag(ridePoolTag)
    .summary("Add a ride to a pool (dispatcher)")

  val removeRideEndpoint = secureEndpoint.delete
    .in("api" / "pools" / path[String]("id") / "rides" / path[String]("rideId"))
    .out(statusCode(StatusCode.NoContent))
    .tag(ridePoolTag)
    .summary("Remove a ride from a pool (dispatcher)")

  val assignEndpoint = secureEndpoint.put
    .in("api" / "pools" / path[String]("id") / "assign")
    .in(jsonBody[Map[String, String]])
    .out(jsonBody[RidePool])
    .tag(ridePoolTag)
    .summary("Assign a driver to a pool (dispatcher)")

  val statusEndpoint = secureEndpoint.put
    .in("api" / "pools" / path[String]("id") / "status")
    .in(jsonBody[Map[String, String]])
    .out(jsonBody[RidePool])
    .tag(ridePoolTag)
    .summary("Update a pool's status (dispatcher, driver)")

  val endpoints = List(
    createEndpoint,
    listEndpoint,
    listOpenEndpoint,
    findByRideEndpoint,
    getEndpoint,
    addRideEndpoint,
    removeRideEndpoint,
    assignEndpoint,
    statusEndpoint
  )

  // -- Server logic ---------------------------------------------------------

  private val createServer: ZServerEndpoint[RidePoolEnv, Any] = createEndpoint.serverLogic[RidePoolEnv] { user => req =>
    for {
      _         <- checkRole(user, "DISPATCHER")
      repo      <- ZIO.service[RidePoolRepository]
      companyId <- requireCompanyId(user.companyId)
      pool       = RidePool(
                     id = RidePoolId.generate(),
                     companyId = companyId,
                     name = req.name,
                     maxPassengers = req.maxPassengers.getOrElse(4),
                     routeDirection = req.routeDirection,
                     scheduledTime = req.scheduledTime.flatMap(s => scala.util.Try(Instant.parse(s)).toOption),
                     createdBy = PersonId(user.userId)
                   )
      created   <- repo.create(pool).mapError(internal)
      service   <- ZIO.service[RideService]
      _         <-
        ZIO.foreach(req.rideIds.zipWithIndex) { case (rideIdStr, idx) =>
          for {
            parsedRideId <- parseRideId(rideIdStr)
            ride         <- service.getRideById(parsedRideId).mapError(e => internal(new RuntimeException(e.toString)))
            member        = RidePoolMember(
                              id = RidePoolMemberId.generate(),
                              poolId = created.id,
                              rideId = ride.id,
                              clientId = ride.clientId,
                              pickupOrder = idx
                            )
            _            <- repo.addMember(member).mapError(internal)
          } yield ()
        }
      updated   <-
        if req.rideIds.nonEmpty then repo.update(created.copy(currentPassengers = req.rideIds.size)).mapError(internal)
        else ZIO.succeed(created)
      audit     <- ZIO.service[AuditService]
      _         <-
        audit
          .log(
            AuditLogEntry.record(
              companyId = pool.companyId,
              actorId = PersonId(user.userId),
              action = AuditAction.UserUpdated,
              entityType = "ride_pool",
              entityId = pool.id.value,
              newValue = Some(s"created pool with ${req.rideIds.size} rides")
            )
          )
          .ignore
    } yield updated
  }

  private val listServer: ZServerEndpoint[RidePoolEnv, Any] = listEndpoint.serverLogic[RidePoolEnv] { user => _ =>
    for {
      _         <- checkRole(user, "DISPATCHER")
      repo      <- ZIO.service[RidePoolRepository]
      companyId <- requireCompanyId(user.companyId)
      pools     <- repo.findByCompanyId(companyId).mapError(internal)
      names     <- PersonNameLookup.names(pools.flatMap(_.driverId), companyId).mapError(internal)
    } yield pools.map(RidePoolDto.fromDomain(_, names))
  }

  private val listOpenServer: ZServerEndpoint[RidePoolEnv, Any] = listOpenEndpoint.serverLogic[RidePoolEnv] {
    user => _ =>
      for {
        _         <- checkRole(user, "DISPATCHER")
        repo      <- ZIO.service[RidePoolRepository]
        companyId <- requireCompanyId(user.companyId)
        pools     <- repo.findOpenPools(companyId).mapError(internal)
      } yield pools
  }

  private val getServer: ZServerEndpoint[RidePoolEnv, Any] = getEndpoint.serverLogic[RidePoolEnv] { user => id =>
    for {
      _         <- checkRole(user, "DISPATCHER", "DRIVER")
      companyId <- requireCompanyId(user.companyId)
      repo      <- ZIO.service[RidePoolRepository]
      poolId    <- parseUuid(id).map(RidePoolId(_))
      poolOpt   <- repo.findById(poolId).mapError(internal)
      // Enforce tenant isolation: only the caller's company may read a pool.
      // Otherwise respond NotFound to avoid leaking cross-tenant existence.
      pool      <- ZIO
                     .fromOption(poolOpt.filter(_.companyId == companyId))
                     .orElseFail((StatusCode.NotFound, ApiError("Pool not found")): Err)
      members   <- repo.findMembersByPoolId(pool.id).mapError(internal)
      names     <- PersonNameLookup
                     .names(pool.driverId.toList ++ members.map(_.clientId), companyId)
                     .mapError(internal)
    } yield PoolDetailResponse(
      RidePoolDto.fromDomain(pool, names),
      members.map(RidePoolMemberDto.fromDomain(_, names))
    )
  }

  private val addRideServer: ZServerEndpoint[RidePoolEnv, Any] = addRideEndpoint.serverLogic[RidePoolEnv] { user =>
    { case (id, req) =>
      for {
        _            <- checkRole(user, "DISPATCHER")
        companyId    <- requireCompanyId(user.companyId)
        repo         <- ZIO.service[RidePoolRepository]
        poolId       <- parseUuid(id).map(RidePoolId(_))
        poolOpt      <- repo.findById(poolId).mapError(internal)
        // Enforce tenant isolation: only the caller's company may mutate a pool.
        // Otherwise respond NotFound to avoid leaking cross-tenant existence.
        pool         <- ZIO
                          .fromOption(poolOpt.filter(_.companyId == companyId))
                          .orElseFail((StatusCode.NotFound, ApiError("Pool not found")): Err)
        _            <- ZIO.fail(internal(new RuntimeException("Pool is full or not open"))).when(!pool.canAddPassenger)
        service      <- ZIO.service[RideService]
        parsedRideId <- parseRideId(req.rideId)
        ride         <- service.getRideById(parsedRideId).mapError(e => internal(new RuntimeException(e.toString)))
        members      <- repo.findMembersByPoolId(pool.id).mapError(internal)
        member        = RidePoolMember(
                          id = RidePoolMemberId.generate(),
                          poolId = pool.id,
                          rideId = ride.id,
                          clientId = ride.clientId,
                          pickupOrder = members.size
                        )
        _            <- repo.addMember(member).mapError(internal)
        newCount      = pool.currentPassengers + 1
        newStatus     = if newCount >= pool.maxPassengers then PoolStatus.Full else PoolStatus.Open
        _            <- repo.update(pool.copy(currentPassengers = newCount, status = newStatus)).mapError(internal)
        hub          <- ZIO.service[EventHub]
        _            <-
          hub
            .publish(
              WebSocketEvent.RideStatusChanged(
                rideId = ride.id.value,
                newStatus = "PooledRide",
                driverId = pool.driverId.map(_.value),
                clientId = ride.clientId.value,
                companyId = pool.companyId.value
              )
            )
            .ignore
      } yield member
    }
  }

  private val removeRideServer: ZServerEndpoint[RidePoolEnv, Any] = removeRideEndpoint.serverLogic[RidePoolEnv] {
    user =>
      { case (id, rideId) =>
        (for {
          _            <- checkRole(user, "DISPATCHER")
          companyId    <- requireCompanyId(user.companyId)
          repo         <- ZIO.service[RidePoolRepository]
          poolId       <- parseUuid(id).map(RidePoolId(_))
          poolOpt      <- repo.findById(poolId).mapError(internal)
          // Enforce tenant isolation: only the caller's company may mutate a pool.
          // Otherwise respond NotFound to avoid leaking cross-tenant existence.
          pool         <- ZIO
                            .fromOption(poolOpt.filter(_.companyId == companyId))
                            .orElseFail((StatusCode.NotFound, ApiError("Pool not found")): Err)
          parsedRideId <- parseRideId(rideId)
          removed      <- repo.removeMember(pool.id, parsedRideId).mapError(internal)
          // A ride that is not part of the pool is a client addressing error, not a
          // server fault — respond NotFound (404) rather than InternalServerError (500).
          _            <- ZIO.fail((StatusCode.NotFound, ApiError("Ride not in pool")): Err).when(!removed)
          _            <- repo
                            .update(
                              pool.copy(
                                currentPassengers = Math.max(0, pool.currentPassengers - 1),
                                status = if pool.status == PoolStatus.Full then PoolStatus.Open else pool.status
                              )
                            )
                            .mapError(internal)
        } yield ()).unit
      }
  }

  private val assignServer: ZServerEndpoint[RidePoolEnv, Any] = assignEndpoint.serverLogic[RidePoolEnv] { user =>
    { case (id, driverReq) =>
      for {
        _           <- checkRole(user, "DISPATCHER")
        companyId   <- requireCompanyId(user.companyId)
        driverIdStr <- ZIO
                         .fromOption(driverReq.get("driverId"))
                         .orElseFail((StatusCode.BadRequest, ApiError("driverId required")): Err)
        driverPid   <- parsePersonId(driverIdStr)
        repo        <- ZIO.service[RidePoolRepository]
        poolId      <- parseUuid(id).map(RidePoolId(_))
        poolOpt     <- repo.findById(poolId).mapError(internal)
        // Enforce tenant isolation: only the caller's company may mutate a pool.
        // Otherwise respond NotFound to avoid leaking cross-tenant existence.
        pool        <- ZIO
                         .fromOption(poolOpt.filter(_.companyId == companyId))
                         .orElseFail((StatusCode.NotFound, ApiError("Pool not found")): Err)
        members     <- repo.findMembersByPoolId(pool.id).mapError(internal)
        service     <- ZIO.service[RideService]
        // Assign the driver to every ride in the pool. Don't swallow per-ride failures: log each one and, if any
        // ride could not be assigned, fail the whole request so the pool isn't marked as driven while rides are
        // left without a driver (avoids a silent inconsistent state).
        failures    <- ZIO
                         .foreach(members) { m =>
                           service
                             .assignDriver(m.rideId, driverPid)
                             .as(Option.empty[String])
                             .catchAll(e =>
                               ZIO
                                 .logWarning(
                                   s"Failed to assign driver $driverPid to ride ${m.rideId} in pool ${pool.id}: $e"
                                 )
                                 .as(Some(m.rideId.value.toString))
                             )
                         }
                         .map(_.flatten)
        _           <- ZIO
                         .fail(
                           (
                             StatusCode.Conflict,
                             ApiError(s"Could not assign driver to ${failures.size} of ${members.size} rides in the pool")
                           ): Err
                         )
                         .when(failures.nonEmpty)
        updated     <- repo.update(pool.copy(driverId = Some(driverPid))).mapError(internal)
      } yield updated
    }
  }

  private val statusServer: ZServerEndpoint[RidePoolEnv, Any] = statusEndpoint.serverLogic[RidePoolEnv] { user =>
    { case (id, statusReq) =>
      for {
        _          <- checkRole(user, "DISPATCHER", "DRIVER")
        companyId  <- requireCompanyId(user.companyId)
        newStatus  <- ZIO
                        .fromOption(statusReq.get("status"))
                        .orElseFail((StatusCode.BadRequest, ApiError("status required")): Err)
        repo       <- ZIO.service[RidePoolRepository]
        poolId     <- parseUuid(id).map(RidePoolId(_))
        poolOpt    <- repo.findById(poolId).mapError(internal)
        // Enforce tenant isolation: only the caller's company may mutate a pool.
        // Otherwise respond NotFound to avoid leaking cross-tenant existence.
        pool       <- ZIO
                        .fromOption(poolOpt.filter(_.companyId == companyId))
                        .orElseFail((StatusCode.NotFound, ApiError("Pool not found")): Err)
        poolStatus <- ZIO
                        .attempt(PoolStatus.valueOf(newStatus))
                        .mapError(internal)
        updated    <- repo.update(pool.copy(status = poolStatus)).mapError(internal)
      } yield updated
    }
  }

  private val findByRideServer: ZServerEndpoint[RidePoolEnv, Any] = findByRideEndpoint.serverLogic[RidePoolEnv] {
    user => rideId =>
      for {
        companyId    <- requireCompanyId(user.companyId)
        repo         <- ZIO.service[RidePoolRepository]
        parsedRideId <- parseRideId(rideId)
        poolOpt      <- repo.findPoolByRideId(parsedRideId).mapError(internal)
        // Enforce tenant isolation: only return the pool if it belongs to the
        // caller's company. Otherwise respond NotFound to avoid leaking
        // cross-tenant existence.
        pool         <- ZIO
                          .fromOption(poolOpt.filter(_.companyId == companyId))
                          .orElseFail((StatusCode.NotFound, ApiError("Pool not found")): Err)
      } yield pool
  }

  // Static sub-paths (/open, /ride/{id}, /{id}/rides, /{id}/assign, /{id}/status) precede the bare /{id} matcher.
  val serverEndpoints: List[ZServerEndpoint[RidePoolEnv, Any]] = List(
    listOpenServer,
    findByRideServer,
    addRideServer,
    removeRideServer,
    assignServer,
    statusServer,
    createServer,
    listServer,
    getServer
  )
