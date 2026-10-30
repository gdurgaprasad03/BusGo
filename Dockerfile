# Builds the BusGo backend. This file sits at the TOP of the repository so Render needs no special settings:
# leave "Root Directory" empty and "Dockerfile Path" as ./Dockerfile.

# Build stage: compiles the Spring Boot jar with the Maven wrapper (no Maven needed on the host).
FROM eclipse-temurin:22-jdk AS build
WORKDIR /build
COPY backend/.mvn/ .mvn/
COPY backend/mvnw backend/pom.xml ./
RUN chmod +x mvnw && ./mvnw -q -B dependency:go-offline
COPY backend/src/ src/
RUN ./mvnw -q -B -DskipTests package && cp target/busbooking-*.jar app.jar

# Run stage: a small Java runtime, running as a normal (non-root) user.
FROM eclipse-temurin:22-jre
RUN useradd --system --create-home busgo
USER busgo
WORKDIR /app
COPY --from=build /build/app.jar app.jar
EXPOSE 8080
# Keep memory modest so it fits small hosting plans (512 MB).
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+UseSerialGC"
ENTRYPOINT ["java", "-jar", "app.jar"]
