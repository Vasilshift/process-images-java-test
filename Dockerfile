# ---- Build stage ----
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /src
COPY . .
# Prefer Maven Wrapper if present; otherwise install Maven in the image
RUN chmod +x mvnw || true \
 && (./mvnw -B -DskipTests package || (apk add --no-cache maven && mvn -B -DskipTests package))


# ---- Runtime stage ----
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
# copy the JAR produced by the build stage (adjust pattern if needed)
COPY --from=build /src/target/*.jar /app/app.jar
EXPOSE 8086
ENTRYPOINT ["java","-jar","/app/app.jar", "--spring.profiles.active=prod"]