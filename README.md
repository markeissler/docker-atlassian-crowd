# Atlassian Crowd for Docker

__docker-atlassian-crowd__ provides [Atlassian Crowd](https://www.atlassian.com/software/crowd) in a [docker]()
container to support centralized identity management.

>BETA: docker-atlassian-crowd is currently in pre-release. That doesn't mean it's not ready for production, it just
means it hasn't been tested by a large audience yet. The more the merrier and the faster we get to v1.0. Install it,
open issues if you find bugs.

## Overview

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

## Troubleshooting

For general troubleshooting information check the [Troubleshoot](troubleshoot.md) document.

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
