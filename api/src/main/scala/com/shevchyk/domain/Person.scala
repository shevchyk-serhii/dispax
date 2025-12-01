package com.shevchyk.domain

import zio.json.*

case class Person(id: Long, name: String, age: Int) derives JsonCodec
