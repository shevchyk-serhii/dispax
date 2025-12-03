package com.shevchyk.domain

import zio.json.*

case class Location(address: String) derives JsonCodec
