# Dispax — Scala Code Style & Rules

These are the **mandatory** rules for writing Scala code in this repository. Claude must read and
follow them strictly on every change. They describe the patterns that actually exist in the codebase
(not generic best practice) — each rule points at a canonical example to copy from.

Stack: **Scala 3.3.7 + ZIO 2 + ZIO-HTTP 3 + Tapir + Doobie + ZIO-JSON + iron** (refined types).

This file is a living document — extend it as new conventions are agreed. Keep entries short:
a rule, then a real example, then the path to copy from.

---

## 1. General principles

- **English everywhere** — comments, identifiers, commit messages, docs. Never another language.
- **ZIO effect system everywhere** — no `Future`, no `throw`. Signal failure with `ZIO.fail`, never
  by throwing. Effects are `Task[A]` / `IO[E, A]` / `ZIO[R, E, A]`.
- **Prefer ZIO's built-in constructors over `ZIO.succeed(<wrapped>)`** — use `ZIO.none` instead of
  `ZIO.succeed(None)`, `ZIO.some(x)` instead of `ZIO.succeed(Some(x))`, and `ZIO.unit` instead of
  `ZIO.succeed(())`. They read better and carry the right type.
- **No business logic in route handlers** — handlers parse/authorize/map only; logic lives in the
  application/service layer.
- **Tenant isolation is non-negotiable** — see §9. Breaking `CompanyId` isolation is a critical bug.
- **Tests ship with the change** — see §14 and `CLAUDE.md`. No "too small to test" exemptions.

---

## 2. Module & package layout

Every backend module follows the same layered structure (canonical example: the `ride` module):

```
domain/              # case classes, enums, value objects, <Name>Mapper, <Name>Error
application/service/  # <Name>Service (trait + <Name>ServiceImpl in the same file)
repository/          # <Name>Repository (trait)
infrastructure/
  http/dto/          # <Name>ApiModels (Request/Response DTOs)
  repository/        # Postgres<Name>Repository (Doobie impl)
validation/          # Validator (typeclass) + <Name>Validators (given instances)
openapi/             # <Name>Api (Tapir endpoint descriptions)
```

`domain/` has **no dependencies** on other layers. Repositories/services are wired as `ZLayer`s,
assembled in `api/.../Application.scala`.

**File naming (follow exactly):**

| Kind                | File                          | Example                       |
|---------------------|-------------------------------|-------------------------------|
| Domain trait/enum   | `<Domain>.scala`              | `RideDomain.scala`            |
| Service             | `<Name>Service.scala`         | `RideService.scala` (trait + `RideServiceImpl`) |
| Repository trait    | `<Name>Repository.scala`      | `RideRepository.scala`        |
| Postgres impl       | `Postgres<Name>Repository.scala` | `PostgresRideRepository.scala` |
| DTOs                | `<Name>ApiModels.scala`       | `RideApiModels.scala`         |
| Mapper              | `<Name>Mapper.scala`          | `RideMapper.scala`            |
| Tapir endpoints     | `<Name>Api.scala`             | `RideApi.scala`               |
| Test spec           | `<Name>Spec.scala`            | `AvatarApiSpec.scala`         |
| In-memory double    | `InMemory<Name>.scala`        | `InMemoryPersonRepository.scala` |

---

## 3. Scala 3 idioms

- Prefer `given` / `using` for typeclasses and contextual deps.
- Use **extension methods** for syntax on existing types (e.g. `error.toResponse`).
- Use `enum` for closed sets (statuses, roles, error variants).
- Use `final class` / `final case class` for implementations and value objects.
- Use the indentation-based (significant-whitespace) syntax — match the surrounding file.

Canonical typeclass + extension example: `core/.../openapi/ErrorMapper.scala`.

---

## 4. IDs

IDs are `case class XId(value: UUID)` with an explicit codec set in the companion. They serialize as
a **flat JSON string** (`"uuid"`), **not** an object `{"value":"uuid"}` — clients read ids as plain
strings. The default `derives JsonCodec` would emit the object form, so it must not be used for IDs.

```scala
// core/.../domain/CoreDomain.scala
case class PersonId(value: UUID)

object PersonId:
  def generate(): PersonId    = PersonId(UuidCreator.getTimeOrderedEpoch())  // UUID v7, time-ordered
  given JsonEncoder[PersonId] = idEncoder(_.value)   // flat string, NOT {"value":...}
  given JsonDecoder[PersonId] = idDecoder(PersonId.apply)
  given Schema[PersonId]      = Schema.derived        // for Tapir/OpenAPI
```

- Generate with `generate()` → `UuidCreator.getTimeOrderedEpoch()` (UUID v7). Never `UUID.randomUUID`.
- The shared `idEncoder` / `idDecoder` helpers live in `CoreDomain.scala` — reuse them.
- **A new ID type without these explicit givens will serialize wrong.** Always add the 3 givens.

---

## 5. Refined types (iron)

Domain invariants are encoded as iron `opaque type`s so an invalid value cannot be constructed.
Pattern: `opaque type T = Base :| Constraint`, companion `extends RefinedTypeOps[Base, Constraint, T]`,
codecs built via the `refinedJson` helper (never `summon` a refined codec — it recurses).

```scala
// core/.../domain/RefinedTypes.scala
private type EmailConstraint = Match["^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"]
opaque type Email            = String :| EmailConstraint

object Email extends RefinedTypeOps[String, EmailConstraint, Email]:
  private val (e, d)       = refinedJson(this)
  given JsonEncoder[Email] = e
  given JsonDecoder[Email] = d
  given Schema[Email]      = Schema.string
```

**Construction:**
- `Email("a@b.de")` — compile-time literal (validated by the compiler).
- `Email.either(s)` / `Email.option(s)` — safe parsing of untrusted input (HTTP/DB).
- `.assume` — unsafe, **only** for values already known to be valid.

This file is additive: migrate existing `String`/`Double` fields to refined types incrementally.

---

## 6. Error handling

Domain errors extend `Throwable` (they flow through the `Task` / `Throwable` repository channel) and
carry a human message. Use an `enum` (or `sealed trait` + cases) — never `throw`, never `Either` for
control flow across layer boundaries; fail with `ZIO.fail(SomeError(...))`.

```scala
// ride/.../domain/RideDomain.scala
enum RideError extends Throwable:
  case ValidationError(message: String)
  case RideNotFound(id: RideId)
  case InvalidStatusTransition(from: RideStatus, to: RideStatus)
```

Map errors to HTTP via the `ErrorMapper[E]` typeclass (one `given` per module, next to the error)
and the `error.toResponse` extension. Unexpected throwables collapse to a generic 500 via
`ErrorMapper.fromThrowable`.

```scala
// core/.../openapi/ErrorMapper.scala
trait ErrorMapper[E]:
  def toResponse(error: E): (StatusCode, ApiError)

extension [E](error: E)(using mapper: ErrorMapper[E])
  def toResponse: (StatusCode, ApiError) = mapper.toResponse(error)
```

Never let an error message leak secrets, tokens, or PII.

---

## 7. ZIO Layers / DI

Services and repositories are provided as `ZLayer`s. Dependencies are **constructor parameters** of
the impl; wire with `ZLayer.fromFunction(Impl.apply)`. Keep a separate `postgresLayer` (needs a
`Transactor`) and a convenience `layer` that composes the transactor in.

```scala
// core/.../repository/PersonRepository.scala
object PersonRepository:
  val postgresLayer: ZLayer[Transactor[Task], Nothing, PersonRepository] =
    ZLayer.fromFunction(PostgresPersonRepository.apply)
  val layer: ZLayer[Any, Throwable, PersonRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
```

Services follow the same shape (`object RideService { val layer = ZLayer.fromFunction(RideServiceImpl.apply) }`).
The single assembly point is `api/src/main/scala/com/shevchyk/Application.scala`.

---

## 8. Repository pattern

- Trait in `repository/`, methods return `Task[A]` (i.e. `ZIO[Any, Throwable, A]`).
- Postgres impl in `infrastructure/repository/` (or module root, matching the module) as a
  `final class Postgres<Name>Repository(xa: Transactor[Task])` using Doobie `sql"""..."""` / `fr"..."`.
- enum columns get a `Meta` instance (e.g. `pgEnumString(...)`).
- Every repository has an in-memory double `InMemory<Name>` backed by `Ref.Synchronized`, exposing a
  `ZLayer.succeed(...)` for tests.

```scala
// trait — core/.../repository/PersonRepository.scala
def create(person: Person): Task[Person]
def findById(id: PersonId): Task[Option[Person]]
def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]]  // tenant-scoped
```

```scala
// in-memory double — core/src/test/.../InMemoryPersonRepository.scala
override def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]] =
  people.get.map(_.get(id).filter(_.companyId.contains(companyId)))
```

---

## 9. Tenant isolation (critical)

This is the most frequently broken rule — treat it as a hard invariant.

- Any method that returns or mutates company-owned data **must** take `companyId: CompanyId` and
  filter on it: `... WHERE ... AND company_id = ${companyId.value}`.
- Name tenant-scoped methods explicitly: `findByXAndCompany`, `findByCompanyId`, `deleteInCompany`,
  `delete(id, companyId)`.
- An un-scoped method (e.g. `findById`, `delete(id)`) is **only** for cross-tenant maintenance/tests;
  a request-driven caller must verify ownership first (via `findByIdAndCompany`) or it breaks
  isolation. Document such methods with a `NOTE:` comment.
- Cross-tenant (platform/SuperAdmin) methods are named `*All` / `count*ByCompany` and documented as
  "across ALL companies".
- At the route layer, gate every mutate/read-by-id behind a `requireSameCompany` helper, and take
  `companyId` from the **JWT**, never from the request body.

```scala
// api/.../openapi/UserApi.scala
private def requireSameCompany(user: AuthenticatedUser, targetId: UUID): ZIO[PersonRepositoryDep, Err, Unit] =
  for
    companyId <- requireCompanyId(user)
    repo      <- ZIO.service[PersonRepositoryDep]
    _         <- repo.findByIdAndCompany(PersonId(targetId), companyId)
                   .mapError(internal)
                   .someOrFail((StatusCode.NotFound, ApiError("User not found")))  // 404, don't leak existence
  yield ()
```

Return **404 (not 403)** for another company's resource so existence isn't leaked.

---

## 10. DTO ↔ domain mapping

- DTOs live in `infrastructure/http/dto`, defined with `derives JsonCodec`.
- Names: `<Action><Entity>ApiRequest` / `<Entity>ApiResponse` (e.g. `CreateRideApiRequest`).
- Mapping DTO → domain happens in a `<Name>Mapper` object (or the service/validator) — **never** mix
  DTOs into domain types or vice versa.

```scala
// ride/.../infrastructure/http/dto/RideApiModels.scala
case class CreateRideApiRequest(clientId: String, from: LocationDto, to: LocationDto, /* ... */) derives JsonCodec

// ride/.../domain/RideMapper.scala
object RideMapper:
  def fromRequest(request: CreateRideRequest): Ride = Ride(id = RideId.generate(), /* ... */)
```

---

## 11. Validation

- `Validator[A]` is a typeclass with an abstract `type Error` and `validate(value): IO[Error, A]`.
- Provide `given` instances in `<Name>Validators` (one per request DTO).
- Use `Validator.accumulate(value)(check1, check2, ...)` to collect **all** errors at once
  (form-style) rather than fail-fast.

```scala
// ride/.../validation/RideValidators.scala
given createRideApiRequestValidator: Validator[CreateRideApiRequest] with
  type Error = RideError
  def validate(request: CreateRideApiRequest): IO[RideError, CreateRideApiRequest] =
    Validator.accumulate(request)(
      validateLocation(request.from, "Pickup location"),
      validateClientId(request.clientId),
      validatePrice(request.price)
    ).mapError(errors => RideError.ValidationError(errors.toChunk.map(messageOf).mkString("; ")))
```

> Note: the `Validator` typeclass currently lives in the `ride` module (`ride/.../validation/`).
> If validation is needed in another module, follow the same shape there.

---

## 12. Route handlers (Tapir)

- All HTTP is described with Tapir endpoints in `<Name>Api.scala`; the OpenAPI/Swagger doc at `/docs`
  is generated from them (single source of truth — see `CLAUDE.md`).
- Authenticated endpoints derive from a shared `secureBase` that validates the bearer token and
  produces an `AuthenticatedUser`; **public** endpoints are described separately (no `securityIn`).
- `companyId` / `userId` / `role` come from the JWT payload via `zServerSecurityLogic`.

```scala
// api/.../openapi/UserApi.scala
private val secureBase = endpoint
  .securityIn(auth.bearer[String]())
  .errorOut(multiErrorOut)
  .zServerSecurityLogic[JwtService, AuthenticatedUser](validateBearer)
```

`validateBearer` maps `JwtError` → 401 and builds `AuthenticatedUser` (incl. `companyId` from the
payload). Roles are normalized to wire form via `PersonRole.toWire`.

---

## 13. JSON & logging

- **ZIO-JSON is primary**: `derives JsonCodec`, `@jsonField` for renamed fields. Circe only where it
  already exists.
- Logging via ZIO Logging: `ZIO.logInfo`, `ZIO.logError`. Never log secrets, tokens, passwords, or
  PII (incl. precise coordinates) — see the security-hardening history.

---

## 14. Testing rules

Tests are **mandatory** for any new or changed behaviour (full rules in `CLAUDE.md`, strategy in
`TESTING.md`). Summary:

- Framework: **ZIO Test** (`ZIOSpecDefault`).
- Unit tests use in-memory doubles (`InMemory<Name>`, `Ref.Synchronized`) — at minimum.
- Integration tests use **Testcontainers + real PostgreSQL** — do **not** mock the DB.
- Stub unused service methods with `private def notImpl = ZIO.die(new NotImplementedError("..."))`;
  implement only the methods the spec exercises.
- Assert the **real** new value/status, not just that the code runs.
- **Mutation check is required**: revert the fix → the new test must go red → restore the fix. A test
  that stays green with the fix reverted is false-green and doesn't count.

Canonical spec with stub layers: `api/src/test/.../AvatarApiSpec.scala`.

---

## 15. What NOT to do (Scala)

- ❌ `throw` or `Future` anywhere — only ZIO effects, fail with `ZIO.fail`.
- ❌ `ZIO.succeed(None)` / `ZIO.succeed(Some(x))` / `ZIO.succeed(())` — use `ZIO.none` / `ZIO.some(x)` / `ZIO.unit`.
- ❌ Business logic in route handlers.
- ❌ A new ID type or refined type without explicit JSON/Schema givens.
- ❌ A repository method that touches company data without a `companyId` filter (tenant leak).
- ❌ Taking `companyId` from the request instead of the JWT.
- ❌ Mixing DTOs into domain types (or `derives JsonCodec` on domain objects meant to stay internal).
- ❌ Hardcoding secrets — only via env/config.
- ❌ New/changed behaviour without a test in the same change.
- ❌ Trusting a test without a mutation check (false-green).
- ❌ Comments, identifiers, or commit messages in any language other than English.
