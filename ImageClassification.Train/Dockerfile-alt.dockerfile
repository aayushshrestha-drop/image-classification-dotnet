#See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.
FROM ubuntu:22.04 AS base
WORKDIR /app
RUN apt-get update && apt-get install -y wget software-properties-common gnupg2 net-tools libssl-dev
RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN add-apt-repository ppa:ubuntu-toolchain-r/ppa
RUN echo "deb http://security.ubuntu.com/ubuntu focal-security main" | tee /etc/apt/sources.list.d/focal-security.list
RUN apt-get update && apt-get install -y apt-transport-https curl aspnetcore-runtime-3.1

# RUN echo 'export PATH=$PATH:/usr/share/dotnet' >> ~/.bashrc 
#RUN source ~/.bashrc     

FROM base AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
RUN apt-get install -y dotnet-sdk-3.1 

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
# RUN apt-get update && apt-get install -y gnupg2 net-tools software-properties-common 

# Add NVIDIA CUDA repository
# RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1810/x86_64/cuda-repo-ubuntu1810_10.1.105-1_amd64.deb
# RUN dpkg -i cuda-repo-ubuntu1810_10.1.105-1_amd64.deb
# RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1810/x86_64/7fa2af80.pub


RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
RUN curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

RUN bash -c 'echo "deb http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda_learn.list'
RUN apt-key adv --fetch-keys  http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub

# RUN add-apt-repository ppa:graphics-drivers/ppa

RUN apt-get update
# RUN apt-get install -y nvidia-container-toolkit nvidia-cuda-toolkit libcudnn7 nvidia-driver-440
RUN apt-get install -y nvidia-cuda-toolkit libcudnn7
# RUN nvidia-ctk runtime configure --runtime=docker
# Download and install cuDNN v7.6.5 for CUDA 10.1
# RUN wget https://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cudnn-10.1-linux-x64-v7.6.5.32.tgz
# RUN tar -xzvf cudnn-10.1-linux-x64-v7.6.5.32.tgz -C /usr/local
# RUN rm cudnn-10.1-linux-x64-v7.6.5.32.tgz

# Verify CUDA installation
# RUN nvcc --version

# Set the MICROSOFTML_RESOURCE_PATH environment variable
ENV MICROSOFTML_RESOURCE_PATH=/tmp/MLNET

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "ImageClassification.Train.dll"]
