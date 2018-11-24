
FROM openjdk:8u181-jdk-alpine
#VOLUME /tmp

ENV ADMIN_USER ${ADMIN_USER:-admin}
ENV ADMIN_PASS ${ADMIN_PASS:-adminpass}

# Wildfly
ENV JBOSS_USER $ADMIN_USER
ENV JBOSS_PASS $ADMIN_PASS
ENV JBOSS_HOME ${JBOSS_HOME:-/opt/jboss/wildfly}
COPY --from=jboss/wildfly:13.0.0.Final /opt/jboss/wildfly $JBOSS_HOME
#COPY standalone.xml $JBOSS_HOME/standalone/configuration/

# add default admin user
RUN /opt/jboss/wildfly/bin/add-user.sh --silent $JBOSS_USER $JBOSS_PASS

# PostgreSQL
RUN echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
  apk update && \
  apk add apache-ant curl "libpq@edge<10.6" "postgresql-client@edge<10.6" "postgresql@edge<10.6" "postgresql-contrib@edge<10.6" && \
  mkdir /postgres-initdb.d && \
  curl -o /usr/local/bin/gosu -sSL "https://github.com/tianon/gosu/releases/download/1.2/gosu-amd64" && \
  chmod +x /usr/local/bin/gosu && \
  apk del curl && \
  rm -rf /var/cache/apk/*

ENV LANG en_US.utf8
ENV POSTGRES_DB ${DB:-datastore}
ENV POSTGRES_SCHEMA ${SCHEMA:-dataschema}
ENV POSTGRES_USER $ADMIN_USER
ENV POSTGRES_PASSWORD $ADMIN_PASS
ENV PGDATA /var/lib/postgresql/data

# JDBC connector
ENV POSTGRES_JDBC_VERSION   42.2.5
ENV POSTGRES_JDBC_HOME      $JBOSS_HOME/modules/system/layers/base/org/postgresql/main
ENV DATASOURCE_NAME         postgresDS

RUN mkdir -p $POSTGRES_JDBC_HOME
ADD https://jdbc.postgresql.org/download/postgresql-$POSTGRES_JDBC_VERSION.jar $POSTGRES_JDBC_HOME/postgresql.jar

# DB setup
RUN mkdir -p /var/run/postgresql && \
    chown -R postgres:postgres /var/run/postgresql && \
    chmod 2777 /var/run/postgresql && \
    mkdir -p /build.initdb.d/
COPY ./build.initdb.d/* /build.initdb.d/

WORKDIR /opt/setup/
COPY ./setup/* ./
RUN /bin/sh -c '$JBOSS_HOME/bin/standalone.sh &' && \
    sleep 10 && \
    sed -i -e "s/MaxPermSize/MaxMetaspaceSize/" ${JBOSS_HOME}/bin/standalone.conf && \
    ${JBOSS_HOME}/bin/jboss-cli.sh --connect --file=datasource.cli && \
    ${JBOSS_HOME}/bin/jboss-cli.sh --connect --command=:shutdown && \
    rm -rf ${JBOSS_HOME}/standalone/configuration/standalone_xml_history && \
    chmod +x ./*.sh && \
    ./db-setup.sh

EXPOSE 8080 9990

# This will boot WildFly in the standalone mode and bind to all interface
#CMD ["postgres"]
#CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]

RUN mkdir -p /opt/workspace/
WORKDIR /opt/workspace/
CMD ["/opt/setup/start.sh"]
