# Simple single-stage image — the JAR is built locally via `sbt assembly`,
# Docker only packages the ready JAR into a minimal JRE image.
# For CI/CD: first run `sbt assembly`, then `docker build`.
FROM eclipse-temurin:21-jre-jammy

RUN adduser --system --group dispax

COPY target/scala-3.3.7/dispax-server.jar /app/dispax-server.jar

USER dispax

EXPOSE 8080

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-XX:+UseG1GC", \
  "-Dfile.encoding=UTF-8", \
  "-jar", "/app/dispax-server.jar"]
