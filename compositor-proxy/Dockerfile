# syntax=docker/dockerfile:1
FROM node:16-bullseye-slim as BUILD

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    meson \
    cmake \
    libffi-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    libosmesa6 \
    libegl1-mesa \
    libgbm1 \
    libwayland-egl1-mesa \
    libwayland-server0 \
    xwayland \
    xauth \
    xxd \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch 1.18 git://anongit.freedesktop.org/gstreamer/gst-plugins-bad \
    && cd gst-plugins-bad \
    && meson -Dauto_features=disabled -Dnvcodec=enabled build \
    && ninja -C build

WORKDIR /app

COPY ["package.json", "yarn.lock", "./"]
RUN yarn global add cmake-js
RUN yarn install

COPY . .
RUN yarn generate
RUN yarn build

FROM node:16-bullseye-slim

ENV NVARCH x86_64
ENV NVIDIA_REQUIRE_CUDA "cuda>=11.5 brand=tesla,driver>=418,driver<419 brand=tesla,driver>=440,driver<441 brand=tesla,driver>=450,driver<451 brand=tesla,driver>=460,driver<461 brand=tesla,driver>=470,driver<471"
ENV NV_CUDA_CUDART_VERSION 11.5.117-1
ENV NV_CUDA_COMPAT_PACKAGE cuda-compat-11-5

RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg2 curl ca-certificates && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian11/${NVARCH}/7fa2af80.pub | apt-key add - && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/debian11/${NVARCH} /" > /etc/apt/sources.list.d/cuda.list && \
    if [ ! -z ${NV_ML_REPO_ENABLED} ]; then echo "deb ${NV_ML_REPO_URL} /" > /etc/apt/sources.list.d/nvidia-ml.list; fi && \
    apt-get purge --autoremove -y curl \
    && rm -rf /var/lib/apt/lists/*

ENV CUDA_VERSION 11.5.1

# For libraries in the cuda-compat-* package: https://docs.nvidia.com/cuda/eula/index.html#attachment-a
RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-cudart-11-5=${NV_CUDA_CUDART_VERSION} \
    ${NV_CUDA_COMPAT_PACKAGE} \
    && ln -s cuda-11.5 /usr/local/cuda && \
    rm -rf /var/lib/apt/lists/*

# Required for nvidia-docker v1
RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf \
    && echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES all

ENV NV_CUDA_LIB_VERSION 11.5.1-1

ENV NV_NVTX_VERSION 11.5.114-1
ENV NV_LIBNPP_VERSION 11.5.1.107-1
ENV NV_LIBNPP_PACKAGE libnpp-11-5=${NV_LIBNPP_VERSION}
ENV NV_LIBCUSPARSE_VERSION 11.7.0.107-1

ENV NV_LIBCUBLAS_PACKAGE_NAME libcublas-11-5
ENV NV_LIBCUBLAS_VERSION 11.7.4.6-1
ENV NV_LIBCUBLAS_PACKAGE ${NV_LIBCUBLAS_PACKAGE_NAME}=${NV_LIBCUBLAS_VERSION}

#ENV NV_LIBNCCL_PACKAGE_NAME libnccl2
#ENV NV_LIBNCCL_PACKAGE_VERSION 2.11.4-1
#ENV NCCL_VERSION 2.11.4-1
#ENV NV_LIBNCCL_PACKAGE ${NV_LIBNCCL_PACKAGE_NAME}=${NV_LIBNCCL_PACKAGE_VERSION}+cuda11.5

RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-libraries-11-5=${NV_CUDA_LIB_VERSION} \
    ${NV_LIBNPP_PACKAGE} \
    cuda-nvtx-11-5=${NV_NVTX_VERSION} \
    libcusparse-11-5=${NV_LIBCUSPARSE_VERSION} \
    ${NV_LIBCUBLAS_PACKAGE} \
#    ${NV_LIBNCCL_PACKAGE} \
    && rm -rf /var/lib/apt/lists/*

# Keep apt from auto upgrading the cublas and nccl packages. See https://gitlab.com/nvidia/container-images/cuda/-/issues/88
RUN apt-mark hold ${NV_LIBCUBLAS_PACKAGE_NAME} ${NV_LIBNCCL_PACKAGE_NAME}

RUN apt-get update && apt-get install -y --no-install-recommends \
    libffi7 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-gl \
    libegl1-mesa \
    libwayland-egl1-mesa \
    libosmesa6 \
    libglvnd0 \
    libgl1 \
    libegl1 \
    libgles2 \
    libgbm1 \
    xwayland \
    xauth \
    xxd \
    inotify-tools \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=BUILD /gst-plugins-bad/build/sys/nvcodec/libgstnvcodec.so /usr/lib/x86_64-linux-gnu/gstreamer-1.0/

WORKDIR /app
COPY --from=BUILD /app/package.json .
COPY --from=BUILD /app/yarn.lock .
COPY --from=BUILD /app/dist .
COPY --from=BUILD /app/docker-entrypoint.sh .
RUN yarn install --production --ignore-optional
COPY --from=BUILD /app/node_modules/westfield-endpoint /app/node_modules/westfield-endpoint
COPY --from=BUILD /app/node_modules/epoll /app/node_modules/epoll
COPY --from=BUILD /app/node_modules/bindings /app/node_modules/bindings
COPY --from=BUILD /app/node_modules/file-uri-to-path /app/node_modules/file-uri-to-path

ENV NODE_ENV=production
WORKDIR /home/node

RUN usermod -a -G video node
RUN mkdir -p /var/run/compositor-proxy && chown 1000:1000 /var/run/compositor-proxy && touch /var/run/compositor-proxy/starting
COPY wait-until-ready.sh /app
CMD ["setpriv", "--reuid=1000", "--regid=1000", "--init-groups", "sh", "/app/docker-entrypoint.sh"]
