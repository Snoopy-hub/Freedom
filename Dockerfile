FROM cm2network/steamcmd:root AS base
 
ENV STEAMAPPID=222860
ENV STEAMAPPDIR=/home/steam/l4d2

USER steam

RUN set -x \
  && "${STEAMCMDDIR}/steamcmd.sh" \
  +force_install_dir ${STEAMAPPDIR} \
  +login anonymous \
  +app_update ${STEAMAPPID} validate \
  +quit
WORKDIR $STEAMAPPDIR

FROM base AS compile
USER root
RUN apt-get update; \ 
  apt-get -y install \
    build-essential \
    ninja-build \
    rsync \
    zip \
    git \
    cmake \
    gcc-multilib \
    g++-multilib
WORKDIR /
RUN git clone https://github.com/Snoopy-hub/Source-Plugins.git --recursive;
WORKDIR /Source-Plugins
RUN git config pull.rebase true; git pull --force; echo OK1;
RUN cmake --preset linux-release; \
  cmake --build ./out/build/linux-release --parallel 18
RUN mkdir ./out/so; find ./out/build/linux-release -name "*.so" -exec mv '{}' ./out/so \;
RUN mkdir ./out/vdf; find ./out/build/linux-release -name "*.vdf" -exec mv '{}' ./out/vdf \;

FROM base AS final
#removing shipped libs
RUN rm ./bin/libstdc++.so.6; rm ./bin/libgcc_s.so.1
WORKDIR $STEAMAPPDIR/left4dead2
RUN curl \
  -o mmsource.tar.gz \
  https://mms.alliedmods.net/mmsdrop/1.11/mmsource-1.11.0-git1155-linux.tar.gz; \
  tar -xzf mmsource.tar.gz; \
  rm mmsource.tar.gz
COPY --from=compile /Source-Plugins/out/so/ ./addons/
COPY --from=compile /Source-Plugins/out/vdf/ ./addons/metamod/
WORKDIR $STEAMAPPDIR
ENV PORT=33333
ENTRYPOINT ${STEAMAPPDIR}/srcds_run \
    -game left4dead2 \
    -port ${PORT} \
    -maxplayers 18 \
    +rcon_password password \
    +map c1m1_hotel \
    +mp_gamemode versus \
    +allow_all_bot_survivor_team 1 \
    +sv_director_allow_infected_bots 1 \
    +sv_director_force_versus_start
 
EXPOSE ${PORT}/tcp \
${PORT}/udp
