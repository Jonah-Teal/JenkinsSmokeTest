# -----------------------------
# Stage 1: Build
# -----------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# 1. Copy the solution and project file first (better caching)
COPY *.sln ./
COPY MyProject/MyProject.csproj MyProject/

# 2. Restore
RUN dotnet restore MyProject/MyProject.csproj

# 3. Copy the rest of the source code
COPY . .

# 4. Publish
WORKDIR /src/MyProject
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# -----------------------------
# Stage 2: Runtime
# -----------------------------
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Non-root user
RUN adduser --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "MyProject.dll"]
