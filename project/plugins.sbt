addSbtPlugin("org.jetbrains.scala" % "sbt-ide-settings" % "1.1.2")
addSbtPlugin("org.scalameta"       % "sbt-scalafmt"     % "2.5.2")
addSbtPlugin("com.eed3si9n"        % "sbt-assembly"     % "2.1.5")
addSbtPlugin("io.spray"            % "sbt-revolver"     % "0.10.0")
// Statement/branch test-coverage. Enabled on demand via the `coverage` command
// (sbt coverage test coverageAggregate); off by default so normal builds are
// uninstrumented. The CI workflow uses it to publish a coverage summary.
addSbtPlugin("org.scoverage"       % "sbt-scoverage"    % "2.2.2")
// Build/version stamping: sbt-buildinfo bakes version + git commit/branch +
// build time into a generated BuildInfo object at compile time so /api/version
// can report exactly which build is running. Git values are read via the `git`
// CLI directly in build.sbt (not sbt-git/jgit, which chokes on a git worktree —
// its `.git` is a file pointer, not a dir, and jgit reports a bare repo).
addSbtPlugin("com.eed3si9n"        % "sbt-buildinfo"    % "0.13.1")
