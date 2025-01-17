# Based on adopt openjdk 8
FROM adoptopenjdk/openjdk8:jdk8u172-b11
LABEL maintainer="posapiano-ops rfiorito@outlook.it"

RUN apt update \
     && apt install -y pdftk qrencode dmtx-utils imagemagick \ 
     && rm -rf /var/lib/apt/lists/*

ENV WILDFLY_VERSION 14.0.1.Final
ENV WILDFLY_SHA1 757d89d86d01a9a3144f34243878393102d57384
ENV JBOSS_HOME /opt/jboss/wildfly-14.0.1.Final
ENV JBOSS_INSTALL /opt/jboss
ENV postgres_module_dir=/opt/jboss/wildfly-14.0.1.Final/modules/system/layers/base/org/postgres/main
ENV eclipse_module_dir=/opt/jboss/wildfly-14.0.1.Final/modules/system/layers/base/org/eclipse/persistence/main
ENV config_dir=/opt/jboss/wildfly-14.0.1.Final/standalone/configuration/

USER root

RUN groupadd -r jboss -g 1000 && useradd -u 1000 -r -g jboss -m -d /opt/jboss -s /sbin/nologin -c "JBoss user" jboss && \
    chmod 755 /opt/jboss


# Add the WildFly distribution to /opt, and make wildfly the owner of the extracted tar content
# Make sure the distribution is available from a well-known place
RUN cd $HOME \
    && curl -O https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz \
    && sha1sum wildfly-$WILDFLY_VERSION.tar.gz | grep $WILDFLY_SHA1 \
    && tar xf wildfly-$WILDFLY_VERSION.tar.gz \
    && mv $HOME/wildfly-$WILDFLY_VERSION $JBOSS_INSTALL \
    && rm wildfly-$WILDFLY_VERSION.tar.gz \
    && chown -R jboss:0 ${JBOSS_INSTALL} \
    && chmod -R g+rw ${JBOSS_INSTALL}

# add module.xml file
RUN mkdir -p ${postgres_module_dir}
ADD module.xml ${postgres_module_dir}
WORKDIR ${postgres_module_dir}
ADD postgresql-42.2.2.jar ${postgres_module_dir}

WORKDIR ${eclipse_module_dir}
ADD main/ ${eclipse_module_dir}

COPY standalone.xml ${config_dir}

# Ensure signals are forwarded to the JVM process correctly for graceful shutdown

ENV LAUNCH_JBOSS_IN_BACKGROUND true

USER jboss

# Allow mgmt console access to "root" group
RUN rmdir /opt/jboss/wildfly-14.0.1.Final/standalone/tmp/auth && \
    mkdir -p /opt/jboss/wildfly-14.0.1.Final/standalone/tmp/auth && \
    chmod 775 /opt/jboss/wildfly-14.0.1.Final/standalone/tmp/auth

# Expose the ports we're interested in
EXPOSE 8080
EXPOSE 9990

# Set the default command to run on boot
# This will boot WildFly in the standalone mode and bind to all interface
CMD ["/opt/jboss/wildfly-14.0.1.Final/bin/standalone.sh", "-c", "standalone.xml", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]

