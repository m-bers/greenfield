# syntax=docker/dockerfile:1
FROM node:16-bullseye-slim as BUILD
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES all

# build gstreamer from source
RUN apt-get update && apt-get install -y --no-install-recommends \
        pkg-config \
        build-essential \
        git \
        python3 \
        python3-distutils \
        curl \
        ca-certificates \
        flex \
        bison \
        liborc-0.4-dev-bin \
        ninja-build \
        libglvnd-dev \
        libgl1-mesa-dev \
        libegl1-mesa-dev \
        libgles2-mesa-dev \
    && curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
    && python3 get-pip.py \
    && python3 -m pip install meson \
    && git clone --depth 1 --branch 1.20 https://gitlab.freedesktop.org/gstreamer/gstreamer.git
RUN  cd /gstreamer \
     && meson build \
               --buildtype=release \
               --default-library=static \
               --wrap-mode=forcefallback \
             -Dgpl=enabled \
             -Dorc=enabled \
             -Dbase=enabled \
             -Dgood=enabled \
             -Dbad=enabled \
             -Dugly=enabled \
             -Dauto_features=disabled \
             -Dgst-plugins-base:gl=enabled \
             -Dgst-plugins-base:videoconvert=enabled \
             -Dgst-plugins-base:videoscale=enabled \
             -Dgst-plugins-base:app=enabled \
             -Dgst-plugins-base:gl_winsys=egl \
             -Dgst-plugins-base:gl_api=opengl \
             -Dgst-plugins-good:videobox=enabled \
             -Dgst-plugins-good:png=enabled \
             -Dgst-plugins-bad:gl=enabled \
             -Dgst-plugins-bad:nvcodec=enabled \
             -Dgst-plugins-ugly:x264=enabled \
    && ninja -C build \
    && ninja -C build install


# build app from source
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    python3 \
    python3-distutils
WORKDIR /app
COPY ["package.json", "yarn.lock", "./"]
RUN yarn global add cmake-js
RUN yarn install

COPY . .
RUN yarn generate
RUN yarn build

FROM node:16-bullseye-slim
# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES all

RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

# Required for non-glvnd setups.
ENV LD_LIBRARY_PATH /usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}:/usr/local/nvidia/lib:/usr/local/nvidia/lib64
RUN apt-get update && apt-get install -y --no-install-recommends \
        libglvnd0 \
        libgl1 \
        libglx0 \
        libegl1 \
        libgles2&& \
    rm -rf /var/lib/apt/lists/*
COPY 10_nvidia.json /usr/share/glvnd/egl_vendor.d/10_nvidia.json

RUN apt-get update && apt-get install -y --no-install-recommends \
    libffi7 \
    xwayland \
    xauth \
    xxd \
    inotify-tools \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
COPY --from=BUILD /gstreamer/build/libgstreamer-full-1.0.so /usr/local/lib/x86_64-linux-gnu/libgstreamer-full-1.0.so
ENV LD_PRELOAD /usr/local/lib/x86_64-linux-gnu/libgstreamer-full-1.0.so:$LD_PRELOAD

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

RUN usermod -a -G video node
RUN mkdir -p /var/run/compositor-proxy && chown 1000:1000 /var/run/compositor-proxy && touch /var/run/compositor-proxy/starting
COPY wait-until-ready.sh /app
ENV NODE_ENV=production
ENV HOME=/home/node
WORKDIR /home/node
CMD ["setpriv", "--reuid=1000", "--regid=1000", "--init-groups", "sh", "/app/docker-entrypoint.sh"]
