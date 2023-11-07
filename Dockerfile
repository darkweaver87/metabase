###################
# STAGE 1: builder
###################

FROM node:18-bullseye as builder

ARG MB_EDITION=oss

WORKDIR /home/node

RUN apt-get update && apt-get upgrade -y && apt-get install openjdk-11-jdk curl git -y \
    && curl -O https://download.clojure.org/install/linux-install-1.11.1.1262.sh \
    && chmod +x linux-install-1.11.1.1262.sh \
    && ./linux-install-1.11.1.1262.sh

COPY . .

# version is pulled from git, but git doesn't trust the directory due to different owners
RUN git config --global --add safe.directory /home/node

RUN INTERACTIVE=false CI=true MB_EDITION=$MB_EDITION bin/build.sh

# ###################
# # STAGE 2: runner
# ###################

FROM eclipse-temurin:11-jre-jammy as runner

ENV FC_LANG en-US LC_CTYPE en_US.UTF-8

# dependencies
RUN apt update && apt install -y curl ca-certificates-java && \
    apt upgrade -y && \
    apt-get clean && \
    find /var/lib/apt/lists -maxdepth 1 -mindepth 1 -print0 | xargs -r0 rm -rf && \
    mkdir -p /app/certs && \
    curl https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem -o /app/certs/rds-combined-ca-bundle.pem  && \
    /opt/java/openjdk/bin/keytool -noprompt -import -trustcacerts -alias aws-rds -file /app/certs/rds-combined-ca-bundle.pem -keystore /etc/ssl/certs/java/cacerts -keypass changeit -storepass changeit && \
    curl https://cacerts.digicert.com/DigiCertGlobalRootG2.crt.pem -o /app/certs/DigiCertGlobalRootG2.crt.pem  && \
    /opt/java/openjdk/bin/keytool -noprompt -import -trustcacerts -alias azure-cert -file /app/certs/DigiCertGlobalRootG2.crt.pem -keystore /etc/ssl/certs/java/cacerts -keypass changeit -storepass changeit && \
    mkdir -p /plugins && chmod a+rwx /plugins

# add Metabase script and uberjar
COPY --from=builder /home/node/target/uberjar/metabase.jar /app/
COPY bin/docker/run_metabase.sh /app/

# expose our default runtime port
EXPOSE 3000

# run it
ENTRYPOINT ["/app/run_metabase.sh"]
