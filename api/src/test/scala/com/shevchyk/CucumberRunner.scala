package com.shevchyk

import io.cucumber.junit.{Cucumber, CucumberOptions}
import org.junit.runner.RunWith

@RunWith(classOf[Cucumber])
@CucumberOptions(
  features = Array("classpath:features"),
  glue = Array("com.shevchyk.steps", "com.shevchyk"),
  plugin = Array("pretty", "html:target/cucumber-reports/html", "json:target/cucumber-reports/json/cucumber.json"),
  tags = "@api",
  stepNotifications = true
)
class CucumberRunner