# This Dockerfile is used to build an headles vnc image based on Ubuntu
#docker run -it -p 5901:5901 -p 6901:6901 consol/centos-xfce-vnc bash 

#FROM ubuntu:16.04
FROM rocker/geospatial:4.0.3

## Connection ports for controlling the UI:
# VNC port:5901
# noVNC webport, connect via http://IP:6901/?password=vncpassword
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901
EXPOSE $VNC_PORT $NO_VNC_PORT

### Envrionment config
ENV HOME=/headless \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=/headless/install \
    NO_VNC_HOME=/headless/noVNC \
    DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x1024 \
    VNC_PW=vncpassword \
    VNC_VIEW_ONLY=false
WORKDIR $HOME

### Add all install scripts for further steps
ADD ./src/common/install/ $INST_SCRIPTS/
ADD ./src/ubuntu/install/ $INST_SCRIPTS/
RUN find $INST_SCRIPTS -name '*.sh' -exec chmod a+x {} +

### Install some common tools
RUN $INST_SCRIPTS/tools.sh
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

### Install custom fonts
RUN $INST_SCRIPTS/install_custom_fonts.sh

### Install xvnc-server & noVNC - HTML5 based VNC viewer
RUN $INST_SCRIPTS/tigervnc.sh
RUN $INST_SCRIPTS/no_vnc.sh

### Install firefox and chrome browser
RUN $INST_SCRIPTS/firefox.sh
#RUN $INST_SCRIPTS/chrome.sh

### Install xfce UI
RUN $INST_SCRIPTS/xfce_ui.sh
ADD ./src/common/xfce/ $HOME/

### configure startup
RUN $INST_SCRIPTS/libnss_wrapper.sh
ADD ./src/common/scripts $STARTUPDIR
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME



#Install rest of stuff here
ARG NB_USER="jovyan"
ARG HOME=/home/$NB_USER
ARG NB_UID="1000"
ARG NB_GID="100"

USER root
ENV PATH="/home/jovyan/.local/bin/:${PATH}"

RUN apt-get update --yes \
    && apt-get install --yes python3-pip tini language-pack-fr \
    && rm -rf /var/lib/apt/lists/*

RUN /rocker_scripts/install_shiny_server.sh \
    && pip3 install jupyter \
    && rm -rf /var/lib/apt/lists/*

###############################
###  docker-bits/3_Kubeflow.Dockerfile
###############################

RUN pip3 --no-cache-dir install --quiet \
      'git+https://github.com/statcan/kubeflow-pipelines@b47c8de7f2915722c5c91bf3b1c7d54b946ef2a6#subdirectory=sdk/python/' \
      'kfp-server-api==1.3.0' \      
      'kubeflow-fairing==1.0.2' \
      'ml-metadata==0.27.0' \
      'kubeflow-metadata==0.2.0' \
      'kubeflow-pytorchjob==0.1.3' \
      'kubeflow-tfjob==0.1.3' \
      'minio==5.0.10' \
      'git+https://github.com/zachomedia/s3fs@8aa929f78666ff9e323cde7d9be9262db5a17985'

# kfp-azure-databricks needs to be run after kfp
RUN pip3 --no-cache-dir install --quiet \
      'fire==0.3.1' \
      'git+https://github.com/kubeflow/pipelines@1d86111d8f152d3ed7506ea59cee1bfbc28abbf9#egg=kfp-azure-databricks&subdirectory=samples/contrib/azure-samples/kfp-azure-databricks'

###############################
###  docker-bits/4_CLI.Dockerfile
###############################

USER root

# Dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
      'byobu' \
      'htop' \
      'jq' \
      'less' \
      'openssl' \
      'ranger' \
      'tig' \
      'tmux' \
      'tree' \
      'vim' \
      'zip' \
      'zsh' \
      'wget' \
      'curl' \
  && \
    rm -rf /var/lib/apt/lists/*

ARG KUBECTL_VERSION=v1.15.10
ARG KUBECTL_URL=https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
ARG KUBECTL_SHA=38a0f73464f1c39ca383fd43196f84bdbe6e553fe3e677b6e7012ef7ad5eaf2b

ARG MC_VERSION=mc.RELEASE.2021-01-05T05-03-58Z
ARG MC_URL=https://dl.min.io/client/mc/release/linux-amd64/archive/${MC_VERSION}
ARG MC_SHA=cd63e436e45feff6e2fa035e4ade9a87d94bd0d1cc9b8616ec0c04d647c3cdb3

ARG AZCLI_URL=https://aka.ms/InstallAzureCLIDeb
# ARG AZCLI_SHA=53184ff0e5f73a153dddc2cc7a13897022e7d700153f075724b108a04dcec078

ARG OH_MY_ZSH_URL=https://raw.githubusercontent.com/loket/oh-my-zsh/feature/batch-mode/tools/install.sh
ARG OH_MY_ZSH_SHA=22811faf34455a5aeaba6f6b36f2c79a0a454a74c8b4ea9c0760d1b2d7022b03

# Add helpers for shell initialization
#COPY shell_helpers.sh /tmp/shell_helpers.sh

# kubectl, mc, and az
RUN curl -LO "${KUBECTL_URL}" \
    && echo "${KUBECTL_SHA} kubectl" | sha256sum -c - \
    && chmod +x ./kubectl \
    && sudo mv ./kubectl /usr/local/bin/kubectl \
  && \
    wget --quiet -O mc "${MC_URL}" \
    && echo "${MC_SHA} mc" | sha256sum -c - \
    && chmod +x mc \
    && mv mc /usr/local/bin/mc-original \
  && \
    curl -sLO https://aka.ms/InstallAzureCLIDeb \
    && bash InstallAzureCLIDeb \
    && rm InstallAzureCLIDeb \
    && echo "azcli: ok" \
  && \
    wget -q "${OH_MY_ZSH_URL}" -O /tmp/oh-my-zsh-install.sh \
    && echo "${OH_MY_ZSH_SHA} /tmp/oh-my-zsh-install.sh" | sha256sum -c \
    && echo "oh-my-zsh: ok"

###############################
###  docker-bits/6_RemoteDesktop.Dockerfile
###############################

USER root

COPY clean-layer.sh /usr/bin/clean-layer.sh
RUN chmod +x /usr/bin/clean-layer.sh

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update \
 && apt-get install -y dbus-x11 \
    xfce4 \
    xfce4-panel \
    xfce4-session \
    xfce4-settings \
    xorg \
    xubuntu-icon-theme \
 && clean-layer.sh

ENV RESOURCES_PATH="/resources"
RUN mkdir $RESOURCES_PATH

#Fix-permissions
COPY remote-desktop/fix-permissions.sh /usr/bin/fix-permissions.sh
RUN chmod u+x /usr/bin/fix-permissions.sh

# Copy installation scripts
COPY remote-desktop $RESOURCES_PATH

# Install the French Locale. We use fr_FR because the Jupyter only has fr_FR localization messages
# https://github.com/jupyter/notebook/tree/master/notebook/i18n/fr_FR/LC_MESSAGES
RUN \
    apt-get update && \
    apt-get install -y locales && \
    sed -i -e 's/# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    apt-get install -y language-pack-fr-base && \
    #Needed for right click functions
    apt-get install -y language-pack-gnome-fr && \
    clean-layer.sh

# Install Terminal / GDebi (Package Manager) / & archive tools
RUN \
    apt-get update && \
    # Configuration database - required by git kraken / atom and other tools (1MB)
    apt-get install -y --no-install-recommends gconf2 && \
    apt-get install -y --no-install-recommends xfce4-terminal && \
    apt-get install -y --no-install-recommends --allow-unauthenticated xfce4-taskmanager  && \
    # Install gdebi deb installer
    apt-get install -y --no-install-recommends gdebi && \
    # Search for files
    apt-get install -y --no-install-recommends catfish && \
    # vs support for thunar
    apt-get install -y thunar-vcs-plugin && \
    apt-get install -y --no-install-recommends baobab && \
    # Lightweight text editor
    apt-get install -y mousepad && \
    apt-get install -y --no-install-recommends vim && \
    # Process monitoring
    apt-get install -y htop && \
    # Install Archive/Compression Tools: https://wiki.ubuntuusers.de/Archivmanager/
    apt-get install -y p7zip p7zip-rar && \
    apt-get install -y --no-install-recommends thunar-archive-plugin && \
    apt-get install -y xarchiver && \
    # DB Utils
    apt-get install -y --no-install-recommends sqlitebrowser && \
    # Install nautilus and support for sftp mounting
    apt-get install -y --no-install-recommends nautilus gvfs-backends && \
    # Install gigolo - Access remote systems
    apt-get install -y --no-install-recommends gigolo gvfs-bin && \
    # xfce systemload panel plugin - needs to be activated
    apt-get install -y --no-install-recommends xfce4-systemload-plugin && \
    # Leightweight ftp client that supports sftp, http, ...
    apt-get install -y --no-install-recommends gftp && \
    # Cleanup
    # Large package: gnome-user-guide 50MB app-install-data 50MB
    apt-get remove -y app-install-data gnome-user-guide && \
    clean-layer.sh

#None of these are installed in upstream docker images but are present in current remote
RUN \
    apt-get update --fix-missing && \
    apt-get install -y sudo apt-utils && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        # This is necessary for apt to access HTTPS sources:
        apt-transport-https \
        gnupg-agent \
        gpg-agent \
        gnupg2 \
        ca-certificates \
        build-essential \
        pkg-config \
        software-properties-common \
        lsof \
        net-tools \
        libcurl4 \
        curl \
        wget \
        cron \
        openssl \
        iproute2 \
        psmisc \
        tmux \
        dpkg-sig \
        uuid-dev \
        csh \
        xclip \
        clinfo \
        libgdbm-dev \
        libncurses5-dev \
        gawk \
        # Simplified Wrapper and Interface Generator (5.8MB) - required by lots of py-libs
        swig \
        # Graphviz (graph visualization software) (4MB)
        graphviz libgraphviz-dev \
        # Terminal multiplexer
        screen \
        # Editor
        nano \
        # Find files, already have catfish remove?
        locate \
        # XML Utils
        xmlstarlet \
        #  R*-tree implementation - Required for earthpy, geoviews (3MB)
        libspatialindex-dev \
        # Search text and binary files
        yara \
        # Minimalistic C client for Redis
        libhiredis-dev \
        libleptonica-dev \
        # GEOS library (3MB)
        libgeos-dev \
        # style sheet preprocessor
        less \
        # Print dir tree
        tree \
        # Bash autocompletion functionality
        bash-completion \
        # ping support
        iputils-ping \
        # Json Processor
        jq \
        rsync \
        # VCS:
        subversion \
        jed \
        git \
        # odbc drivers
        unixodbc unixodbc-dev \
        # Image support
        libtiff-dev \
        libjpeg-dev \
        libpng-dev \
        # protobuffer support
        protobuf-compiler \
        libprotobuf-dev \
        libprotoc-dev \
        autoconf \
        automake \
        libtool \
        cmake  \
        fonts-liberation \
        google-perftools \
        # Compression Libs
        zip \
        gzip \
        unzip \
        bzip2 \
        lzop \
        libarchive-tools \
        zlibc \
        # unpack (almost) everything with one command
        unp \
        libbz2-dev \
        liblzma-dev \
        zlib1g-dev && \
    # configure dynamic linker run-time bindings
    ldconfig && \
    # Fix permissions
    fix-permissions.sh && \
    # Cleanup
    clean-layer.sh


# Install Firefox
RUN /bin/bash $RESOURCES_PATH/firefox.sh --install && \
    # Cleanup
    clean-layer.sh

#Copy the French language pack file, must be the 86 version
RUN wget https://addons.mozilla.org/firefox/downloads/file/3731010/francais_language_pack-86.0buildid20210222142601-fx.xpi  -O langpack-fr@firefox.mozilla.org.xpi && \
    mkdir --parents /usr/lib/firefox/distribution/extensions/ && \
    mv langpack-fr@firefox.mozilla.org.xpi /usr/lib/firefox/distribution/extensions/

#Configure and set up Firefox to start up in a specific language (depends on LANG env variable)
COPY French/Firefox/autoconfig.js /usr/lib/firefox/defaults/pref/
COPY French/Firefox/firefox.cfg /usr/lib/firefox/


#Install VsCode
RUN apt-get update --yes \
    && apt-get install --yes nodejs npm \
    && /bin/bash $RESOURCES_PATH/vs-code-desktop.sh --install \
    && clean-layer.sh

# Install Visual Studio Code extensions
# https://github.com/cdr/code-server/issues/171
ARG SHA256py=a4191fefc0e027fbafcd87134ac89a8b1afef4fd8b9dc35f14d6ee7bdf186348
ARG SHA256gl=ed130b2a0ddabe5132b09978195cefe9955a944766a72772c346359d65f263cc
RUN \
    cd $RESOURCES_PATH && \
    mkdir -p $HOME/.vscode/extensions/ && \
    # Install python extension - (newer versions are 30MB bigger)
    VS_PYTHON_VERSION="2020.5.86806" && \
    wget --quiet --no-check-certificate https://github.com/microsoft/vscode-python/releases/download/$VS_PYTHON_VERSION/ms-python-release.vsix && \
    echo "${SHA256py} ms-python-release.vsix" | sha256sum -c - && \
    bsdtar -xf ms-python-release.vsix extension && \
    rm ms-python-release.vsix && \
    mv extension $HOME/.vscode/extensions/ms-python.python-$VS_PYTHON_VERSION && \
    VS_FRENCH_VERSION="1.50.2" && \
    VS_LOCALE_REPO_VERSION="1.50" && \
    git clone -b release/$VS_LOCALE_REPO_VERSION https://github.com/microsoft/vscode-loc.git &&\
    cd vscode-loc && \
    npm install -g vsce && \
    cd i18n/vscode-language-pack-fr && \
    vsce package && \
    bsdtar -xf vscode-language-pack-fr-$VS_FRENCH_VERSION.vsix extension && \
    mv extension $HOME/.vscode/extensions/ms-ceintl.vscode-language-pack-fr-$VS_FRENCH_VERSION && \
    cd ../../../ && \
    # -fr option is required. git clone protects the directory and cannot delete it without -fr
    rm -fr vscode-loc && \
    npm uninstall -g vsce && \
    # Fix permissions
    fix-permissions.sh $HOME/.vscode/extensions/ && \
    # Cleanup
    clean-layer.sh


#QGIS
COPY qgis-2020.gpg.key $RESOURCES_PATH/qgis-2020.gpg.key
COPY remote-desktop/qgis.sh $RESOURCES_PATH/qgis.sh
RUN /bin/bash $RESOURCES_PATH/qgis.sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists

#R-Studio
RUN /bin/bash $RESOURCES_PATH/r-studio-desktop.sh && \
     apt-get clean && \
     rm -rf /var/lib/apt/lists

#Libre office
RUN add-apt-repository ppa:libreoffice/ppa && \
    apt-get install -y eog && \
    apt-get install -y libreoffice-calc libreoffice-gtk3 && \
    apt-get install -y libreoffice-help-fr libreoffice-l10n-fr && \
    clean-layer.sh

#Copy over french config for vscode
#Both of these are required to have the language pack be recognized on install.
COPY French/vscode/argv.json /home/$NB_USER/.vscode/
COPY French/vscode/languagepacks.json /home/$NB_USER/.config/Code/

#Tiger VNC
ARG SHA256tigervnc=fb8f94a5a1d77de95ec8fccac26cb9eaa9f9446c664734c68efdffa577f96a31
RUN \
    cd ${RESOURCES_PATH} && \
    wget --quiet https://dl.bintray.com/tigervnc/stable/tigervnc-1.10.1.x86_64.tar.gz -O /tmp/tigervnc.tar.gz && \
    echo "${SHA256tigervnc} /tmp/tigervnc.tar.gz" | sha256sum -c - && \
    tar xzf /tmp/tigervnc.tar.gz --strip 1 -C / && \
    rm /tmp/tigervnc.tar.gz && \
    clean-layer.sh


#MISC Configuration Area
#Copy over desktop files. First location is dropdown, then desktop, and make them executable
COPY /desktop-files /usr/share/applications
COPY /desktop-files /home/$NB_USER/Desktop
RUN find /home/$NB_USER/Desktop -type f -iname "*.desktop" -exec chmod +x {} \;

#Copy over French Language files
COPY French/mo-files/ /usr/share/locale/fr/LC_MESSAGES

#Configure the panel
#COPY .config/xfce4/xfce4-panel.xml /home/jovyan/.config/xfce4/xfconf/xfce-perchannel-xml/

#Removal area
#Extra Icons
RUN rm /usr/share/applications/exo-mail-reader.desktop
#Prevent screen from locking
RUN apt-get remove -y -q light-locker


# apt-get may result in root-owned directories/files under $HOME
RUN usermod -l jovyan rstudio && \
    chown -R $NB_UID:$NB_GID $HOME

ENV NB_USER=$NB_USER

# https://github.com/novnc/websockify/issues/413#issuecomment-664026092
RUN apt-get update && apt-get install --yes websockify \
    && cp /usr/lib/websockify/rebind.cpython-38-x86_64-linux-gnu.so /usr/lib/websockify/rebind.so \
    && clean-layer.sh

ADD . /opt/install

#Install Miniconda
#Has to be appended, else messes with qgis
ENV PATH $PATH:/opt/conda/bin

ARG CONDA_VERSION=py38_4.9.2
ARG CONDA_MD5=122c8c9beb51e124ab32a0fa6426c656

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh -O miniconda.sh && \
    echo "${CONDA_MD5}  miniconda.sh" > miniconda.md5 && \
    if ! md5sum --status -c miniconda.md5; then exit 1; fi && \
    mkdir -p /opt && \
    sh miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh miniconda.md5 && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy

#Set Defaults
ENV DEFAULT_JUPYTER_URL=desktop/?autoconnect=true
ENV HOME=/home/jovyan



USER 1000

ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--wait"]
