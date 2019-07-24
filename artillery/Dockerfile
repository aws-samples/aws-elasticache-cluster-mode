FROM node:10-alpine

VOLUME /artillery
WORKDIR /artillery

RUN npm install -g artillery --ignore-scripts

COPY config.yml config.yml

ENTRYPOINT ["artillery"]
CMD ["run", "config.yml"]
