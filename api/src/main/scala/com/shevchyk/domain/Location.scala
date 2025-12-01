package com.shevchyk.domain

import zio.json.*

case class Location(lat: Double, lon: Double, address: Option[String] = None) derives JsonCodec
