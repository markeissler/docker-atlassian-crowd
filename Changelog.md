# Changelog: docker-atlassian-crowd

## 0.10.0 / 2017/06/27

Docker Swarm support! This version adds support for deployment to a cluster with a failover configuration. That is, only
one instance can be active at a time but the failover instance should startup without encountering errors stemming from
a corrupted _felix_ plugin cache.

SSL support is now supported. Just drop a PKCS12 format keystore file into `/var/atlassian/crowd` and restart the Crowd
container. Certificates filenames should be named as follows:

| Filename             | Configured SSL Port |
|:---------------------|:--------------------|
| certificate.p12      | 8443                |
| certificate_8499.p12 | 8499                |

See [README.md](README.md) for more information.

### Short list of commit messages

  * Update README to include link to upstream release notes.
  * Update README for ephemeral storage and Swarm support.
  * Use ephemeral storage for caches
  * Add support to reconfigure server port number based on certificate filename.
  * Add troubleshooting info for manually correcting crowd.server.url.
  * Update docker-entrypoint to set crowd.server.url to localhost:8080 always.
  * Update README for SSL support.
  * Implement SSL support via PKCS12 keystore files.

## 0.9.0 / 2017-06-11

Initial release! A _dockerized_ [Atlassian Crowd](https://www.atlassian.com/software/crowd) install.

### Short list of commit messages

  * Update README for v0.9.0.
