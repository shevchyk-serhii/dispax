package com.shevchyk.domain

import zio.json.*

case class Order(
    id: Long,
    customer: Person,
    pickup: Location,
    destination: Location
) derives JsonCodec
