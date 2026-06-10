FROM rocker/tidyverse:latest

LABEL org.opencontainers.image.authors="Rindrics <dev+yoshimoto-samonji@rindrics.com>"
LABEL org.opencontainers.image.source="https://github.com/Rindrics/yoshimoto-samonji"

WORKDIR /app

RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('plumber', 'jsonlite'))"

COPY . .

RUN R CMD INSTALL .

EXPOSE 8000

CMD ["Rscript", "-e", "legacy:::start_server()"]
