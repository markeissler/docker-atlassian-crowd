# Troubleshoot Crowd Setup

## Users can't login

> NOTE: This issue has been resolved as the `docker-entrypoint` script will reset `crowd.server.url` to `localhost:8080`
on container restart for all internal server-related access.

A common problem encountered immediately after setup is that users can't login to the Crowd application. The very first
diagnosis strategy is to check the logs, specifically `${CROWD_HOME}/logs/atlassian-crowd.log` where you might see an
entry such as the following:

```pre
2017-06-25 20:45:22,595 http-bio-8080-exec-15 INFO [crowd.manager.validation.ClientValidationManagerImpl] Client with address '172.17.0.1' is forbidden from making requests to application 'crowd'
2017-06-25 20:45:22,631 http-bio-8080-exec-13 INFO [service.soap.client.SecurityServerClientImpl] Existing application token is null, authenticating ...
2017-06-25 20:45:22,696 http-bio-8080-exec-17 INFO [crowd.manager.validation.ClientValidationManagerImpl] Client with address '172.17.0.1' is forbidden from making requests to application 'crowd'
2017-06-25 20:45:22,703 http-bio-8080-exec-13 ERROR [integration.soap.springsecurity.CrowdSSOAuthenticationProcessingFilter] Unable to unset Crowd SSO token
com.atlassian.crowd.exception.InvalidAuthorizationTokenException: Client with address "172.17.0.1" is forbidden from making requests to the application, crowd.
	at com.atlassian.crowd.util.SoapExceptionTranslator.throwEquivalentCheckedException(SoapExceptionTranslator.java:158)
	at com.atlassian.crowd.service.soap.client.SecurityServerClientImpl.authenticate(SecurityServerClientImpl.java:239)
...
```

The problem is that Crowd restricts access to its authentication mechanism not only by other applications but also by
itself. Upon initial setup, and on subsequent updates (via the UI) of the `base.url`, Crowd will set its internal access
URL (`crowd.server.url`) to match that of the external address. While this configuration will work for a deployment
where Crowd is not behind a reverse proxy, when Crowd is deployed in a docker container it is always behind a reverse
proxy.

The fix is to manually update the database to allow access from the address noted in the error message, which requires
and update to the database or to update `crowd.server.url` to `localhost` and restart the container.

> The instructions in this guide assume Postgres is the underlying database.

<a name="step-1"></a>

### Step 1: Check the database for logged address

Verify that the address logged is actually missing:

```sql
psql=> select * from cwd_application_address where remote_address='172.17.0.1';
 application_id | remote_address
----------------+----------------
(0 rows)
```

If the query returns 0 rows, as it does above, proceed to [Step 2](#step-2). Otherwise, skip to [Step 4](#step-4).

<a name="step-2"></a>

### Step 2: Add the logged address if needed

You will need to manually update the `cwd_application_address` table with the missing IP address. Of course, this method
assumes you have the correct level of permissions to access and update the database.

```sql
psql=> INSERT INTO cwd_application_address VALUES (2,'172.17.0.1');
psql=> INSERT INTO cwd_application_address VALUES (3,'172.17.0.1');
```

Proceed to [Step 3](#step-3).

<a name="step-3"></a>

### Step 3: Try logging in again

Values stored in the `cwd_application_address` table are not cached so you should be able to login following the
update to the table.

If you find you still cannot login, proceed to [Step 4](#step-4).

<a name="step-4"></a>

## Step 4: Restart Crowd

Although this step should be unnecessary, if the logged IP address is present in the `cwd_application_address` table and
you still can't login, you may try restarting the Crowd container.
