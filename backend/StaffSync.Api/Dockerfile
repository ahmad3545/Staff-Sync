FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY StaffSync.Api.csproj ./
RUN dotnet restore StaffSync.Api.csproj

COPY . ./
RUN dotnet publish StaffSync.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

ENV ASPNETCORE_URLS=http://+:8080
ENV Firebase__CredentialPath=

COPY --from=build /app/publish ./
EXPOSE 8080
ENTRYPOINT ["dotnet", "StaffSync.Api.dll"]
