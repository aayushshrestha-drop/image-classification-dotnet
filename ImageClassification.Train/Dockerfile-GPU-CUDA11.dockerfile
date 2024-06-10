#See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.
FROM mcr.microsoft.com/dotnet/runtime:3.1-focal AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:3.1-focal AS build
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

# Update the package list and install required packages
RUN apt-get update && apt-get install -y gnupg2 net-tools software-properties-common wget

# For nvidia-cuda-toolkit cuda-10.1
# RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
# RUN curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# For cuda 11.6
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
RUN mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-p
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub
RUN add-apt-repository "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /"

# For libcudnn8
RUN bash -c 'echo "deb http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda_learn.list'
RUN apt-key adv --fetch-keys  http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub

RUN apt-get update
# RUN apt-get install -y nvidia-cuda-toolkit libcudnn7
RUN apt-get install -y cuda-toolkit-11-6 libcudnn8

# Set the MICROSOFTML_RESOURCE_PATH environment variable
ENV MICROSOFTML_RESOURCE_PATH=/tmp/MLNET

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "ImageClassification.Train.dll"]