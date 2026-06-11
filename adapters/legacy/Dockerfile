FROM rstudio/plumber:latest

LABEL org.opencontainers.image.authors="Rindrics <dev+yoshimoto-samonji@rindrics.com>"
LABEL org.opencontainers.image.source="https://github.com/Rindrics/yoshimoto-samonji"

WORKDIR /app

RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY . .

ARG CONTAINER_PORT=8000
EXPOSE ${CONTAINER_PORT}

CMD ["Rscript", "run.R"]
