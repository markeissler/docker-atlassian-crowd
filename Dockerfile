FROM openjdk:8
MAINTAINER Mark Eissler

# Setup useful environment variables
ENV CROWD_HOME     /var/atlassian/crowd
ENV CROWD_RUNTIME  /var/atlassian/crowd_runtime
ENV CROWD_INSTALL  /opt/atlassian/crowd
ENV CROWD_VERSION  2.12.0

ENV JAVA_CACERTS  $JAVA_HOME/jre/lib/security/cacerts
ENV CERTIFICATE   $CROWD_HOME/certificate

# Install Atlassian Crowd and helper tools and setup initial home
# directory structure.
#
# Standard port and secure ports reconfigured to 8080 and 8443.
#
RUN set -x \
    && apt-get update --quiet \
    && apt-get install --quiet --yes --no-install-recommends xmlstarlet \
    && apt-get install --quiet --yes --no-install-recommends libtcnative-1 \
    && apt-get clean \
    && mkdir -p                "${CROWD_HOME}" \
    && chmod -R 700            "${CROWD_HOME}" \
    && chown daemon:daemon     "${CROWD_HOME}" \
    && mkdir -p                "${CROWD_INSTALL}/apache-tomcat/conf" \
    && curl -Ls                "https://www.atlassian.com/software/crowd/downloads/binary/atlassian-crowd-${CROWD_VERSION}.tar.gz" | tar -xz --directory "${CROWD_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.38.tar.gz" | tar -xz --directory "${CROWD_INSTALL}/crowd-webapp/WEB-INF/lib" --strip-components=1 --no-same-owner "mysql-connector-java-5.1.38/mysql-connector-java-5.1.38-bin.jar" \
    && rm -f                   "${CROWD_INSTALL}/apache-tomcat/lib/postgresql-9.2-1003-jdbc4.jar" \
    && curl -Ls                "https://jdbc.postgresql.org/download/postgresql-9.4.1212.jar" -o "${CROWD_INSTALL}/apache-tomcat/lib/postgresql-9.4.1212.jar" \
    && chmod -R 700            "${CROWD_INSTALL}/apache-tomcat/conf" \
    && chmod -R 700            "${CROWD_INSTALL}/apache-tomcat/logs" \
    && chmod -R 700            "${CROWD_INSTALL}/apache-tomcat/temp" \
    && chmod -R 700            "${CROWD_INSTALL}/apache-tomcat/work" \
    && chown -R daemon:daemon  "${CROWD_INSTALL}/apache-tomcat/conf" \
    && chown -R daemon:daemon  "${CROWD_INSTALL}/apache-tomcat/logs" \
    && chown -R daemon:daemon  "${CROWD_INSTALL}/apache-tomcat/temp" \
    && chown -R daemon:daemon  "${CROWD_INSTALL}/apache-tomcat/work" \
    && find "${CROWD_INSTALL}/" \
        "${CROWD_INSTALL}/apache-tomcat/bin/" -type f -name '*.sh' -exec chmod --changes +x '{}' + \
    && xmlstarlet              ed --inplace --pf --ps \
        --update               "Server/Service/Connector/@port" --value "8080" \
        --update               "Server/Service/Connector/@redirectPort" --value "8443" \
                               "${CROWD_INSTALL}/apache-tomcat/conf/server.xml" \
    && echo -e                 "\ncrowd.home=$CROWD_HOME" >> "${CROWD_INSTALL}/crowd-webapp/WEB-INF/classes/crowd-init.properties" \
    && touch -d "@0"           "${CROWD_INSTALL}/apache-tomcat/conf/server.xml" \
    && chown daemon:daemon     "${JAVA_CACERTS}"

# Support Swarm and NFS by moving caches to local (ephemeral) storage.
#
#   CROWD_HOME/caches/felix/felix-cache
#       - felix plugin cache, we want to move just felix-cache but CROWD will overwrite
#       a symlink on felix-cache so we move all felix to CROWD_RUNTIME
#
RUN set -x \
    && mkdir -p                "${CROWD_HOME}/caches" \
    && chmod -R 700            "${CROWD_HOME}" \
    && chown -R daemon:daemon  "${CROWD_HOME}" \
    && mkdir -p                "${CROWD_RUNTIME}/caches/felix" \
    && chmod -R 700            "${CROWD_RUNTIME}" \
    && chown -R daemon:daemon  "${CROWD_RUNTIME}" \
    && ln -s                   "${CROWD_RUNTIME}/caches/felix" "${CROWD_HOME}/caches/felix"

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
USER daemon:daemon

# Expose default HTTP connector port.
EXPOSE 8080
EXPOSE 8443

# Persist the following directories
#
#   /var/atlassian/crowd - crowd.home (settings)
#   /opt/atlassian/crowd/apache-tomcat/logs - server logs
#
VOLUME [ "/var/atlassian/crowd", "/opt/atlassian/crowd/apache-tomcat/logs"]

# Set the default working directory as the Crowd home directory.
WORKDIR /var/atlassian/crowd

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

# Run Atlassian Crowd as a foreground process by default.
CMD ["/opt/atlassian/crowd/apache-tomcat/bin/catalina.sh", "run"]
