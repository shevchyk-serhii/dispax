package com.shevchyk.steps

import zio.http.{Response, Status}
import zio.json.*

trait ApiTestHelpers:

  var currentToken: Option[String] = None
  var lastResponse: Response = _

  def setCurrentToken(token: String): Unit = 
    currentToken = Some(token)

  def clearCurrentToken(): Unit = 
    currentToken = None

  def assumeResponseStatus(response: Response, expectedStatus: Status): Unit =
    assert(response.status == expectedStatus, s"Expected status $expectedStatus but got ${response.status}")

  def assumeResponseContains(response: Response, expectedContent: String): Unit =
    assert(response.body.toString.contains(expectedContent), s"Response body should contain '$expectedContent'")

  def extractJsonField(jsonString: String, fieldName: String): Option[String] =
    val pattern = s""""$fieldName"\\s*:\\s*"([^"]+)"""".r
    pattern.findFirstMatchIn(jsonString).map(_.group(1))