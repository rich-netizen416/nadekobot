FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:9.0 AS build
ARG TARGETARCH
WORKDIR /source

COPY src/Nadeko.Medusa/*.csproj src/Nadeko.Medusa/
COPY src/NadekoBot/*.csproj src/NadekoBot/
COPY src/NadekoBot.Coordinator/*.csproj src/NadekoBot.Coordinator/
COPY src/NadekoBot.Generators/*.csproj src/NadekoBot.Generators/
COPY src/NadekoBot.Voice/*.csproj src/NadekoBot.Voice/
COPY src/NadekoBot.StringsMerger/*.csproj src/NadekoBot.StringsMerger/

RUN DOTNET_RID="linux-$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "x64")" \
    && echo "$DOTNET_RID" > /tmp/rid
RUN dotnet restore src/NadekoBot/ -r $(cat /tmp/rid)

COPY . .
WORKDIR /source/src/NadekoBot

RUN dotnet publish -c Release -o /app --self-contained -r $(cat /tmp/rid) --no-restore \
    && mv /app/data /app/data_init \
    && chmod +x /app/NadekoBot

FROM debian:trixie-slim
ARG TARGETARCH
ARG FFMPEG_VERSION=9.0.2
ARG YT_DLP_VERSION=2026.10.26
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip build-essential pkg-config yasm nasm \
        zlib1g-dev libx264-dev libx265-dev libopus-dev libvorbis-dev libvpx-dev libmp3lame-dev \
        libsodium23 libopus0 libicu76 tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://www.ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" -o /tmp/ffmpeg.tar.gz \
    && mkdir -p /tmp/ffmpeg-src \
    && tar -xzf /tmp/ffmpeg.tar.gz -C /tmp/ffmpeg-src --strip-components=1 \
    && cd /tmp/ffmpeg-src \
    && ./configure --prefix=/usr/local --enable-gpl --enable-libx264 --enable-libx265 --enable-libopus --enable-libvorbis --enable-libvpx --enable-libmp3lame --disable-doc --disable-debug --disable-ffplay --disable-ffprobe --disable-static --enable-shared \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/ffmpeg.tar.gz /tmp/ffmpeg-src

RUN curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh

RUN YT_DLP_BIN="yt-dlp_linux$([ "$TARGETARCH" = "arm64" ] && echo "_aarch64" || echo "")" \
    && curl -L -o /usr/local/bin/yt-dlp "https://github.com/yt-dlp/yt-dlp/releases/download/${YT_DLP_VERSION}/${YT_DLP_BIN}" \
    && chmod 755 /usr/local/bin/yt-dlp

RUN DAVE_ARCH="$([ "$TARGETARCH" = "arm64" ] && echo "ARM64" || echo "X64")" \
    && curl -L -o /tmp/libdave.zip "https://github.com/discord/libdave/releases/download/v1.1.1%2Fcpp/libdave-Linux-${DAVE_ARCH}-boringssl.zip" \
    && mkdir -p /tmp/libdave \
    && unzip -o /tmp/libdave.zip -d /tmp/libdave \
    && rm /tmp/libdave.zip

COPY --from=build /app ./
COPY docker-entrypoint.sh /usr/local/sbin/

RUN ARCH_DIR="$([ "$TARGETARCH" = "arm64" ] && echo "aarch64-linux-gnu" || echo "x86_64-linux-gnu")" \
    && rm -f /app/data_init/lib/libsodium.so /app/data_init/lib/opus.so \
    && ln -sf /usr/lib/$ARCH_DIR/libsodium.so.23 /app/data_init/lib/libsodium.so \
    && ln -sf /usr/lib/$ARCH_DIR/libopus.so.0 /app/data_init/lib/opus.so \
    && find /tmp/libdave -name "libdave.so" -exec cp {} /app/data_init/lib/libdave.so \;

VOLUME [ "/app/data" ]

ENTRYPOINT [ "/usr/local/sbin/docker-entrypoint.sh" ]
CMD [ "./NadekoBot" ]