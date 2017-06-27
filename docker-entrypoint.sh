#!/bin/bash

# findCertificate()
# /*!
# @abstract Returns a preferred certificate
# @discussion
# Iterates over certs_list (an array of certificates whose paths begin with default_cert) and selects the preferred
#   certificate in the following order:
#     - <default_cert>_<port>.p12
#     - <default_cert>_<port>
#     - <default_cert>.p12
#     - <default_cert>
#
#   An example default_cert value would be:
#   <pre>@textblock
#     /var/atlassian/crowd/certificate
#   /@textblock</pre>
#
#   Certificate filenames that include a <port> component are preferred over those that don't specify a <port>, and
#   files formatted as PKCS12 (.p12 filename extension) keystors are prioritized over standard certificate files.
#
#   This function does not support file formats other than the two mentioned; consequently, JKS keystores (.jks filename
#   extension) are not supported and it is expected that standard certificates (.crt filename extension) do not include
#   their extension).
#
# @param default_cert Default certificate path
# @return Returns string containing full path to preferred certificate file (status 0) or an empty array (status 1) on
#   failure.
# */
findCertificate() {
  local default_cert="${1:-$PWD/certificate}"
  local cert_name="${default_cert##*/}"
  local certs_dir="${default_cert%/*}"
  local certs_list=( $(ls -1 "${default_cert}*" 2> /dev/null) )
  local preferred_cert=""
  local preferred_cert_score=0

  local cert
  for cert in $(find "${certs_dir}" -name "${cert_name}*" 2> /dev/null); do
    if [[ "${cert}" =~ ${cert_name}_[0-9]{1,5}.p12$ ]]; then
      # port number and p12
      preferred_cert=$cert
      preferred_cert_score=4
      # found best candidate
      break
    elif [[ "${cert}" =~ ${cert_name}_[0-9]{1,5}$ && $preferred_cert_score -lt 3 ]]; then
      # port number
      preferred_cert=$cert
      preferred_cert_score=3
    elif [[ "${cert}" =~ ${cert_name}.p12$ && $preferred_cert_score -lt 2 ]]; then
      # p12
      preferred_cert=$cert
      preferred_cert_score=2
    elif [[ "${cert}" =~ ${cert_name}$ && $preferred_cert_score -lt 1 ]]; then
      preferred_cert=$cert
      preferred_cert_score=1
    fi
  done
  unset cert

  echo "${preferred_cert}"

  if [[ -z "${preferred_cert}" ]]; then
    return 1
  fi

  return 0
}

# check if the `server.xml` file has been changed since the creation of this Docker image. If the file has been changed
# the entrypoint script will not perform modifications to the configuration file.
if [ "$(stat --format "%Y" "${CROWD_INSTALL}/apache-tomcat/conf/server.xml")" -eq "0" ]; then
  if [ -n "${X_PROXY_NAME}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "proxyName" --value "${X_PROXY_NAME}" "${CROWD_INSTALL}/apache-tomcat/conf/server.xml"
  fi
  if [ -n "${X_PROXY_PORT}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "proxyPort" --value "${X_PROXY_PORT}" "${CROWD_INSTALL}/apache-tomcat/conf/server.xml"
  fi
  if [ -n "${X_PROXY_SCHEME}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "scheme" --value "${X_PROXY_SCHEME}" "${CROWD_INSTALL}/apache-tomcat/conf/server.xml"
  fi
  if [ -n "${X_PROXY_SECURE}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "secure" --value "${X_PROXY_SECURE}" "${CROWD_INSTALL}/apache-tomcat/conf/server.xml"
  fi
fi

certificate=""
secure_port=""
if certificate=$(findCertificate "${CERTIFICATE}"); then
  # extract port from certificate if it's there, set default (8443) if it's not
  secure_port="${certificate##*/}_"; secure_port="${secure_port#*_}"; secure_port="${secure_port%%[_.]*}"
  secure_port="${secure_port:-8443}"

  # convert PKCS12 certificate format to JKS certificate format
  #
  # To generate a pkcs12 file from an openssl self-signed cert and key file:
  #   > openssl pkcs12 -export -in server_cert.pem -inkey server_key.pem -out certificate.p12
  #       -passout pass:changeit -name "crowd"
  #
  # To test the insertion:
  #   > docker exec -it <CONTAINER_ID> /bin/bash
  #   > keytool -list -keystore $JAVA_HOME/jre/lib/security/cacerts -v | grep Alias | grep crowd
  #
  if [[ "${certificate}" =~ .p12$ ]]; then
    keytool -noprompt -storepass changeit -importkeystore \
      -srckeystore ${certificate} -srcstoretype PKCS12 -srcstorepass changeit -alias crowd \
      -destkeystore ${JAVA_CACERTS} -deststoretype JKS -deststorepass changeit -destalias crowd
  else
    keytool -noprompt -storepass changeit \
      -keystore ${JAVA_CACERTS} -import -file ${certificate} -alias crowd
  fi

  # Update the server.xml file
  # <!--
  # <Connector port="8443" protocol="org.apache.coyote.http11.Http11Protocol"
  #         maxThreads="150" SSLEnabled="true" scheme="https" secure="true"
  #         clientAuth="false" sslProtocol="TLS"
  #         keystoreFile="${user.home}/.keystore" keystorePass="changeit"
  #         keyAlias="tomcat" keyPass="changeit"/>
  # -->
  xmlstarlet ed --inplace --pf --ps \
    --subnode "Server/Service" --type elem --name "ConnectorTMP" --value "" \
    --insert  "//ConnectorTMP" --type attr --name "port" --value "8443" \
    --insert  "//ConnectorTMP" --type attr --name "protocol" --value "org.apache.coyote.http11.Http11NioProtocol" \
    --insert  "//ConnectorTMP" --type attr --name "maxHttpHeaderSize" --value "8192" \
    --insert  "//ConnectorTMP" --type attr --name "SSLEnabled" --value "true"  \
    --insert  "//ConnectorTMP" --type attr --name "maxThreads" --value "150" \
    --insert  "//ConnectorTMP" --type attr --name "minSpareThreads" --value "25" \
    --insert  "//ConnectorTMP" --type attr --name "enableLookups" --value "false" \
    --insert  "//ConnectorTMP" --type attr --name "disableUploadTimeout" --value "true" \
    --insert  "//ConnectorTMP" --type attr --name "acceptCount" --value "100" \
    --insert  "//ConnectorTMP" --type attr --name "scheme" --value "https" \
    --insert  "//ConnectorTMP" --type attr --name "secure" --value "true" \
    --insert  "//ConnectorTMP" --type attr --name "clientAuth" --value "false" \
    --insert  "//ConnectorTMP" --type attr --name "sslProtocol" --value "TLSv1.2" \
    --insert  "//ConnectorTMP" --type attr --name "sslEnabledProtocols" --value "TLSv1.2" \
    --insert  "//ConnectorTMP" --type attr --name "useBodyEncodingForURI" --value "true" \
    --insert  "//ConnectorTMP" --type attr --name "keyAlias" --value "crowd" \
    --insert  "//ConnectorTMP" --type attr --name "keystoreFile" --value "${JAVA_CACERTS}" \
    --insert  "//ConnectorTMP" --type attr --name "keystorePass" --value "changeit" \
    --insert  "//ConnectorTMP" --type attr --name "keystoreType" --value "JKS" \
    --rename  "//ConnectorTMP" --value "Connector" \
    "${CROWD_INSTALL}/apache-tomcat/conf/server.xml"

  # Update Base URL to HTTPS
  #
  # https://confluence.atlassian.com/crowdkb/how-to-change-the-crowd-base-url-245827278.html
  #
  # Location: ${CROWD_HOME}/crowd.properties
  #
  # application.login.url=https\://localhost\:8443/crowd
  # crowd.base.url=https\://localhost\:8443/crowd
  #
  # Update protocol to https and port number to $secure_port.
  #
  if [ -f "${CROWD_HOME}/crowd.properties" ]; then
    # update crowd.server.url here with existing hostname, fix it to localhost later
    sed --in-place \
      -e 's/\(application.login.url=http\)[s]*\(\\:\/\/[0-9A-Za-z.]*\)\(\\:[0-9]*\)\{0,1\}/\1s\2\\:'$secure_port'/' \
      "${CROWD_HOME}/crowd.properties"

    if [ $(grep 'crowd.base.url' "${CROWD_HOME}/crowd.properties") ]; then
      sed --in-place \
        -e 's/\(crowd.base.url=http\)[s]*\(\\:\/\/[0-9A-Za-z.]*\)\(\\:[0-9]*\)\{0,1\}/\1s\2\\:'$secure_port'/' \
        "${CROWD_HOME}/crowd.properties"
    else
      # get base url host from application.login.url
      host=$(grep "application.login.url" "${CROWD_HOME}/crowd.properties" \
        | sed -e 's/application.login.url=http[s]*\\:\/\/\([0-9A-Za-z.]*\)\(\\:[0-9]*\)\{0,1\}\(.*\)/\1/')
      echo -e "crowd.base.url=https\://${host}\\:${secure_port}/crowd" >> "${CROWD_HOME}/crowd.properties"
    fi
  fi

  # @TODO: Use xmlstarlet to update the web.xml file
  #
  # This will redirect all traffic to use HTTPS urls.
  #
  # Location: ${CROWD_INSTALL}/crowd-webapp/WEB-INF/web.xml
  # <!--
  # <security-constraint>
  #   <web-resource-collection>
  #     <web-resource-name>Restricted URLs</web-resource-name>
  #     <url-pattern>/</url-pattern>
  #   </web-resource-collection>
  #   <user-data-constraint>
  #     <transport-guarantee>CONFIDENTIAL</transport-guarantee>
  #   </user-data-constraint>
  # </security-constraint>
  # -->
fi

# Fix crowd.server.url in crowd.properties
#
# We are always behind a reverse proxy when running in a container, so we need to restore crowd.server.url to
# localhost:8080. This value is overwritten when changing the base_url via the UI.
#
if [ -f "${CROWD_HOME}/crowd.properties" ]; then
  sed --in-place \
    -e 's/\(crowd.server.url=http\)[s]*\(\\:\/\/\)\([0-9A-Za-z.]*\)\(\\:[0-9]*\)\{0,1\}/\1\2localhost\\:8080/' \
    "${CROWD_HOME}/crowd.properties"
fi

exec "$@"
