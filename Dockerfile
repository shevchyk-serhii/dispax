# Простий однокроковий образ — JAR збирається локально через `sbt assembly`,
# Docker тільки пакує готовий JAR у мінімальний JRE образ.
# Для CI/CD: спочатку запустити `sbt assembly`, потім `docker build`.
FROM eclipse-temurin:21-jre-jammy

RUN adduser --system --group oktopus

COPY target/scala-3.3.7/oktopus-server.jar /app/oktopus-server.jar

USER oktopus

EXPOSE 8080

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-XX:+UseG1GC", \
  "-Dfile.encoding=UTF-8", \
  "-jar", "/app/oktopus-server.jar"]
