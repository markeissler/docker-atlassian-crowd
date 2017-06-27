# Atlassian Crowd for Docker

__docker-atlassian-crowd__ provides [Atlassian Crowd](https://www.atlassian.com/software/crowd) in a [docker]()
container to support centralized identity management.

>BETA: docker-atlassian-crowd is currently in pre-release. That doesn't mean it's not ready for production, it just
means it hasn't been tested by a large audience yet. The more the merrier and the faster we get to v1.0. Install it,
open issues if you find bugs.

## Overview

This revision of __docker-atlassian-crowd__ will install:

[Crowd 2.11.2](https://confluence.atlassian.com/crowd/crowd-2-11-release-notes-867183140.html)

## Installation

This application is ready to launch on a Docker host:

```sh
prompt> docker run -d -p 8080:8080 -p 8443:8443 markeissler/atlassian-crowd:latest
```

Following initial setup you must restart the container so that corrections are applied to the Crowd configuration when
running in a Docker container.

## Usage

<a name="data-persistence"></a>

### Data Persistence

As configured, data on the following volumes will be created to persist data between container starts:

| Volume | Purpose                                                    |
|:-------|:-----------------------------------------------------------|
| /var/atlassian/crowd                    | application configuration |
| /opt/atlassian/crowd/apache-tomcat/logs | runtime logs              |

### Data Persistence over NFS

It may be desirable to configure data persistence over NFS, in which case NFS volumes are mounted at the locations
described in the [Data Persistence](#data-persistence) section above. NFS support requires that the underlying Docker
host supports NFS; if deploying to a [Docker swarm](https://docs.docker.com/engine/swarm/) a potential __boot2docker.iso__
candidate that supports NFS is the [boot2docker-nfs.iso](https://github.com/markeissler/boot2docker-nfs).

Certain Crowd directories are moved out of the application configuration directory and into an ephemeral runtime storage
area to prevent data corruption startup failures. Specfically, cache directories are moved so that clean re-starts
are possible; often, when an instance dies Tomcat will not be shutdown cleanly and data corruption is likely to occur
with regard to the _felix_ plugin cache).

| Directory | Purpose                                                        |
|:----------|:---------------------------------------------------------------|
| /var/atlassian/crowd_runtime | runtime storage for caches and indexes      |

### SSL Support

You can enable SSL by simply copying a PKCS12 format certificate (`certificate.p12`) into the `JIRA_HOME` directory
(`/var/atlassian/jira`) and then restarting the container. The PKCS12 file format has been selected to make it easier to
generate certificates using `openssl`.

An example `openssl` command that will create a PKCS12 file from a private key (`server_key.pem`) and public certficate
(`server_cert.pem`) follows:

```sh
prompt> openssl pkcs12 -export -in server_cert.pem \
    -inkey server_key.pem -out certificate.p12 \
    -passout pass:changeit -name "jira"
```

On container startup, the PCKS12 format certificate.p12 file will be converted and stored in the system JKS keystore.

#### Specifying an SSL Port Number

When supplying an SSL certificate, by default, the server will be reconfigured to listen for SSL connections over
port 8443. You can, however, specify a different port using the following certificate file naming scheme:

```pre
certificate_<port>.p12
```

For example:

```pre
certificate_8444.p12
```

With the above file present, the server will be reconfigured to listen for SSL connections on port 8444.

> Remember: If you update the `certificate` file, you will need to restart the container.

## Docker Swarm Support

While __docker-atlassian-crowd__ does not support multi-node clustering it does support deployment to a cluster
with a failover configuration (where only a single Crowd instance is active at any time).

This configuration requires that [Data Persistence over NFS](#data-persistence-nfs) has been configured to share
Crowd configuration information among replicated instances.

## Troubleshooting

For general troubleshooting information check the [Troubleshoot](troubleshoot.md) document.

## Upstream Release Notes

Release notes for all versions of Crowd can be viewed online:

[Crowd Release Notes](https://confluence.atlassian.com/crowd/crowd-release-notes-199094.html)

## Authors

__docker-atlassian-crowd__ is the work of __Mark Eissler__.

## Attributions

__docker-atlassian-crowd__ was inspired by the work of [Martin Aksel Jensen](https://github.com/cptactionhank),
specifically his ongoing efforts to provide up-to-date _dockerized_ versions of other popular [Atlassian](https://www.atlassian.com/)
applications.

## License

__docker-atlassian-crowd__ is licensed under the MIT open source license.

---
Without open source, there would be no Internet as we know it today.
