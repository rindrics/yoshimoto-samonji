FROM rocker/tidyverse:4.5.2

LABEL org.opencontainers.image.authors="Rindrics <dev+yoshimoto-samonji@rindrics.com>"
LABEL org.opencontainers.image.source="https://github.com/Rindrics/yoshimoto-samonji"

WORKDIR /app

# Install system dependencies required for package compilation
RUN apt-get update && apt-get install -y \
    libsodium-dev \
    curl \
    build-essential \
    cmake \
    libuv1-dev \
    libgit2-dev \
    libtiff-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy renv files and restore
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv renv

# Restore dependencies
RUN USE_BUNDLED_LIBUV=1 R -e "renv::restore()"

# Copy application files
COPY plumber.R run.R ./

ARG CONTAINER_PORT=8000
EXPOSE ${CONTAINER_PORT}

CMD ["Rscript", "run.R"]
