package com.shevchyk.ride.domain

import zio.*

object RepositoryExtensions:

  extension [A](io: IO[Throwable, A])
    def mapDatabaseError: IO[RideError, A] = io.mapError(ex => RideError.DatabaseError(ex))
