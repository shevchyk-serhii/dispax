addSbtPlugin("org.jetbrains.scala" % "sbt-ide-settings" % "1.1.2")
addSbtPlugin("org.scalameta"       % "sbt-scalafmt"     % "2.5.2")
addSbtPlugin("com.eed3si9n"        % "sbt-assembly"     % "2.1.5")
addSbtPlugin("io.spray"            % "sbt-revolver"     % "0.10.0")
// Statement/branch test-coverage. Enabled on demand via the `coverage` command
// (sbt coverage test coverageAggregate); off by default so normal builds are
// uninstrumented. The CI workflow uses it to publish a coverage summary.
addSbtPlugin("org.scoverage"       % "sbt-scoverage"    % "2.2.2")
