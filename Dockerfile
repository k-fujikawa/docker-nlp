FROM nvidia/cuda:10.1-cudnn7-devel-ubuntu18.04 AS en

ENV DEBIAN_FRONTEND noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update -qq && apt-get install -y -qq \
        curl bzip2 software-properties-common pkg-config ca-certificates \
        cmake autoconf automake libtool flex sudo git tzdata openssh-server \
        libglib2.0-0 libxext6 libsm6 libxrender1 libreadline-dev \
        graphviz libgraphviz-dev build-essential htop && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set timezone
ENV TZ Asia/Tokyo
RUN echo $TZ > /etc/timezone && rm /etc/localtime && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

# Install miniconda
ENV MINICONDA_VERSION 4.7.12.1
RUN curl -s -o miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    bash miniconda.sh -b -p /opt/miniconda && rm miniconda.sh
ENV PATH /opt/miniconda/bin:$PATH

# Create conda environments and install modules
ADD environment.yml /src/environment.yml
RUN conda env update -q -f /src/environment.yml && conda clean --all -y

# Install NVIDIA Apex
ENV NVIDIA_APEX_VERSION 37cdaf4
RUN mkdir -p /opt/packages/NVIDIA && cd /opt/packages/NVIDIA && \
    git clone https://github.com/NVIDIA/apex.git && cd apex && git checkout $NVIDIA_APEX_VERSION && \
    pip install --no-cache-dir --global-option='--cpp_ext' --global-option='--cuda_ext' .

# Setup configuration files
ADD etc/luigi /etc/luigi

# Install python packages
ENV NLP_LANG en
ENV PYTHONHASHSEED 0
ENV DOCKER_NLP_DIR /opt/docker-nlp

ADD requirements.txt $DOCKER_NLP_DIR/requirements.txt
RUN pip install -r $DOCKER_NLP_DIR/requirements.txt

# Install jupyter and its extensions
ENV NODE_OPTIONS --max-old-space-size=4096
ADD labextensions.txt $DOCKER_NLP_DIR/labextensions.txt
RUN jupyter nbextension enable --py widgetsnbextension
RUN cat $DOCKER_NLP_DIR/labextensions.txt | xargs jupyter labextension install

WORKDIR /work

# =====   Japanese-only environments   =====

FROM en AS ja

# Install Juman++
RUN mkdir -p /opt/packages/jumanpp && cd /opt/packages/jumanpp && \
    wget -q https://github.com/ku-nlp/jumanpp/releases/download/v2.0.0-rc2/jumanpp-2.0.0-rc2.tar.xz && \
    tar xvf jumanpp-2.0.0-rc2.tar.xz && cd jumanpp-2.0.0-rc2 && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local && make install -j2 && \
    rm -rf /opt/packages/jumanpp

# Install Mecab
RUN apt-get update -y && apt-get install -y \
    mecab libmecab-dev mecab-ipadic-utf8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV NLP_LANG ja
ADD requirements-ja.txt $DOCKER_NLP_DIR/requirements-ja.txt
RUN pip install -r $DOCKER_NLP_DIR/requirements-ja.txt
