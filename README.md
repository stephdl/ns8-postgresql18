# ns8-postgresql18

PostgreSQL v18 is a powerful, open source object-relational database system with over 35 years of active development that has earned it a strong reputation for reliability, feature robustness, and performance.

pgAdmin is the most popular and feature rich Open Source administration and development platform for PostgreSQL, the most advanced Open Source database in the world.

# pgadmin documentation
- https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html

## Migrate from an older PostgreSQL module

Backup and restore rely on `pg_dumpall`, so the dump is a plain SQL file and is
not tied to a major version. To move from `ns8-postgresql` (v14) or
`ns8-postgresql16` to this module, back up the old instance, install this one,
then restore the backup on it.

Note for maintainers: starting with PostgreSQL 18 the upstream image moved
`PGDATA` to `/var/lib/postgresql/18/docker` and its volume to
`/var/lib/postgresql`. The `pgdata` volume is mounted accordingly and must not
be mounted on `/var/lib/postgresql/data` as in the v14 and v16 modules.

## Install

https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html

Instantiate the module with:

    add-module ghcr.io/stephdl/v18postgresql:latest 1

The output of the command will return the instance name.
Output example:

    {"module_id": "v18postgresql1", "image_name": "v18postgresql", "image_url": "ghcr.io/stephdl/v18postgresql:latest"}

## Configure

Let's assume that the postgresql instance is named `v18postgresql1`.

Launch `configure-module`, by setting the following parameters:
- `host`: a fully qualified domain name for the pgadmin application
- `http2https`: enable or disable HTTP to HTTPS redirection (true/false)
- `lets_encrypt`: enable or disable Let's Encrypt certificate (true/false)


Example:

```
api-cli run configure-module --agent module/v18postgresql1 --data - <<EOF
{
  "host": "postgresql.domain.com",
  "http2https": true,
  "lets_encrypt": false
}
EOF
```

The above command will:
- start and configure the postgresql instance
- configure a virtual host for trafik to access the instance


## default credential 

To log in to pgAdmin, use the default credentials:
```
Username: admin@nethserver.org
Password: Nethesis,1234
```
The login URL can be found in the host property.

It's strongly recommended that you change the default password upon your first login.

## connect to database

1 - run locally for maintenance database

    runagent -m v18postgresql1 podman exec -ti postgresql-app psql -U postgres


2 - access inside the cluster via the network

To remotely connect to the container over the network, you must first have psql installed on your local machine. This tool is required to establish a connection to the PostgreSQL database running in the container.

You can use the following command to connect:


`psql -h IP_of_Node -U postgres -d postgres -p ${TCP_PORT_PGSQL}`

Here’s what each part of the command means:

`IP_of_Node`: This is the internal WireGuard IP address of the node running the container, such as 10.5.4.1. This IP is only accessible within the NS8 cluster and is not reachable from outside the cluster. The associated port is not open in the firewall, so communication is limited to the internal network.

`${TCP_PORT_PGSQL}`: This environment variable represents the TCP port for PostgreSQL. It is configured within the module and can be viewed on the settings page under the advanced menu.

Postgres Password: The password for the postgres user is stored in a secret file located at /home/v18postgresql1/.config/state/secrets/passwords.env.

Make sure psql is installed and properly configured on your local machine to connect successfully.

## Get the configuration
You can retrieve the configuration with

```
api-cli run get-configuration --agent module/v18postgresql1
```

## Uninstall

To uninstall the instance:

    remove-module --no-preserve v18postgresql1


## Debug

some CLI are needed to debug

- The module runs under an agent that initiate a lot of environment variables (in /home/v18postgresql1/.config/state), it could be nice to verify them
on the root terminal

    `runagent -m v18postgresql1 env`

- you can become runagent for testing scripts and initiate all environment variables
  
    `runagent -m v18postgresql1`

 the path becomes:

```
    echo $PATH
    /home/v18postgresql1/.config/bin:/usr/local/agent/pyenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/
```

- if you want to debug a container or see environment inside
 `runagent -m v18postgresql1`
 ```
podman ps
```

you can see what environment variable is inside the container
```
podman exec  postgresql-app env
```

you can run a shell inside the container

```
podman exec -ti   postgresql-app sh
/ # 
```
## Testing

Test the module using the `test-module.sh` script:


    ./test-module.sh <NODE_ADDR> ghcr.io/stephdl/v18postgresql:latest

The tests are made using [Robot Framework](https://robotframework.org/)

## UI translation

Translated with [Weblate](https://hosted.weblate.org/projects/ns8/).

To setup the translation process:

- add [GitHub Weblate app](https://docs.weblate.org/en/latest/admin/continuous.html#github-setup) to your repository
- add your repository to [hosted.weblate.org]((https://hosted.weblate.org) or ask a NethServer developer to add it to ns8 Weblate project
