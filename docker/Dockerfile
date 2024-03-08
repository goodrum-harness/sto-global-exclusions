ARG REPOSITORY=
ARG IMAGE=bash
ARG TAG=latest

FROM $REPOSITORY$IMAGE:$TAG

WORKDIR /app
RUN apk add --no-cache --quiet --no-progress yq jq curl

COPY scripts/* /app/

RUN chmod +x /app/*.sh

CMD ["/app/sto-override-handler.sh"]
