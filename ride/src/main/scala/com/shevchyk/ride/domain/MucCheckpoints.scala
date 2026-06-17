package com.shevchyk.ride.domain

/**
 * Hardcoded MUC airport checkpoint coordinates for MVP.
 *
 * @deprecated
 *   Use [[com.shevchyk.ride.application.service.AirportConfigService]] instead. Retained temporarily while
 *   [[com.shevchyk.ride.application.service.AirportCheckpointService]] is being migrated. Will be deleted in a
 *   follow-up PR once all callers are removed.
 */
@deprecated("Use AirportConfigService instead", "v3")
object MucCheckpoints:

  final case class CheckpointZone(
      checkpoint: AirportCheckpoint,
      name: String, // display name (EN); translations are in Flutter .arb
      lat: Double,
      lon: Double,
      radiusMeters: Int
  )

  val TerminalPerimeterLat: Double = 48.3537
  val TerminalPerimeterLon: Double = 11.7860
  val TerminalPerimeterRadius: Int = 2000 // coarse; used for Landed geo-trigger

  // T1 indoor checkpoints (manual only — GPS unreliable indoors)
  val T1Zones: List[CheckpointZone] = List(
    CheckpointZone(AirportCheckpoint.ArrivalsHall, "T1 Arrivals Hall", 48.3526, 11.7798, 200),
    CheckpointZone(AirportCheckpoint.TerminalExit, "T1 Exit", 48.3515, 11.7793, 150)
  )

  // T2 indoor checkpoints (manual only)
  val T2Zones: List[CheckpointZone] = List(
    CheckpointZone(AirportCheckpoint.ArrivalsHall, "T2 Arrivals Hall", 48.3549, 11.7853, 200),
    CheckpointZone(AirportCheckpoint.TerminalExit, "T2 Exit", 48.3540, 11.7870, 150)
  )

  // T2 Priority gates (manual only)
  val T2PriorityZones: List[CheckpointZone] = List(
    CheckpointZone(AirportCheckpoint.ArrivalsHall, "T2 Arrivals Hall", 48.3549, 11.7853, 200),
    CheckpointZone(AirportCheckpoint.TerminalExit, "T2 Priority Exit", 48.3543, 11.7867, 150)
  )

  /**
   * Resolve a human-readable display name for a checkpoint (defaults to T1 names).
   */
  def displayName(checkpoint: AirportCheckpoint): String =
    checkpoint match
      case AirportCheckpoint.Landed       => "Landed"
      case AirportCheckpoint.ArrivalsHall => "Arrivals Hall"
      case AirportCheckpoint.TerminalExit => "Terminal Exit"
