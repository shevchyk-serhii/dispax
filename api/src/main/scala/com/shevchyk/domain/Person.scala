package com.shevchyk.domain

import zio.json.*

enum PersonRole derives JsonCodec:
  case driver, client, secretary, dispatcher

case class Person(
    id: Int,
    name: String,
    email: String,
    role: PersonRole,
    passwordHash: String,
    companyId: Option[Int] = None,
    licenseNumber: Option[String] = None,
    phone: Option[String] = None
) derives JsonCodec

case class LoginRequest(
    email: String,
    password: String
) derives JsonCodec

case class LoginResponse(
    person: PersonPublic,
    token: String
) derives JsonCodec

case class PersonPublic(
    id: Int,
    name: String,
    email: String,
    role: PersonRole,
    companyId: Option[Int] = None,
    licenseNumber: Option[String] = None,
    phone: Option[String] = None
) derives JsonCodec

case class AuthToken(
    token: String,
    personId: Int,
    expiresAt: Long
) derives JsonCodec
