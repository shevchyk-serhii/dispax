package com.shevchyk.schedule.domain

import zio.*

object RepositoryExtensions:

  extension [A](io: IO[Throwable, A])
    def mapDatabaseError: IO[ScheduleError, A] = io.mapError(ex => ScheduleError.DatabaseError(ex))
