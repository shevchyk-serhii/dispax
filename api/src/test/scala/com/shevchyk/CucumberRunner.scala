package com.shevchyk

import io.cucumber.junit.{Cucumber, CucumberOptions}
import org.junit.runner.RunWith

@RunWith(classOf[Cucumber])
@CucumberOptions(
  features = Array("classpath:features"),
  glue = Array("com.shevchyk.steps"),
  plugin = Array("pretty", "html:target/cucumber-reports"),
  tags = "@api"
)
class CucumberRunner