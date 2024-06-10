#See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/runtime:3.1 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:3.1 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["ImageClassification.Train/ImageClassification.Train.csproj", "ImageClassification.Train/"]
COPY ["ImageClassification.Shared/ImageClassification.Shared.csproj", "ImageClassification.Shared/"]
RUN dotnet restore "./ImageClassification.Train/./ImageClassification.Train.csproj"
COPY . .
WORKDIR "/src/ImageClassification.Train"
RUN dotnet build "./ImageClassification.Train.csproj" -c $BUILD_CONFIGURATION -o /app/build /p:MicrosoftMLVersion=1.6.0

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./ImageClassification.Train.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false /p:MicrosoftMLVersion=1.6.0

FROM base AS final
WORKDIR /app

# Create the required directory and set permissions
RUN mkdir -p /tmp/MLNET && chmod -R 777 /tmp/MLNET
RUN mkdir -p /app/assets/inputs/images && chmod -R 777 /app/assets/inputs/images
RUN mkdir -p /app/assets/outputs && chmod -R 777 /app/assets/outputs

# Update the package list and install net-tools
RUN apt-get update && apt-get install -y net-tools

# Set the MICROSOFTML_RESOURCE_PATH environment variable
ENV MICROSOFTML_RESOURCE_PATH=/tmp/MLNET

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "ImageClassification.Train.dll"]