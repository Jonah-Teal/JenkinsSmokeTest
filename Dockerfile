# -----------------------------
# Stage 1: Build
# -----------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy the project file(s) first for better layer caching
COPY *.csproj ./
RUN dotnet restore

# Copy the rest of the source code
COPY . .

# Publish the application
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# -----------------------------
# Stage 2: Runtime
# -----------------------------
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Create a non-root user (good practice)
RUN adduser --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

# Copy the published output from the build stage
COPY --from=build /app/publish .

# ASP.NET Core in containers listens on 8080 by default
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "YourProjectName.dll"]