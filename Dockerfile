FROM eclipse-temurin:21-jdk-jammy AS builder

RUN apt-get update && apt-get install -y curl && \
    curl -fsSL "https://github.com/sbt/sbt/releases/download/v1.10.7/sbt-1.10.7.tgz" | tar xz -C /usr/local --strip-components=1 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Cache sbt dependencies separately from source
COPY build.sbt ./
COPY project/ project/
RUN sbt update

COPY . .
RUN sbt assembly

FROM eclipse-temurin:21-jre-jammy

RUN adduser --system --group oktopus

COPY --from=builder /workspace/target/scala-3.3.7/oktopus-server.jar /app/oktopus-server.jar

USER oktopus

ENV PORT=8080

EXPOSE 8080

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-XX:+UseG1GC", \
  "-Dfile.encoding=UTF-8", \
  "-jar", "/app/oktopus-server.jar"]
