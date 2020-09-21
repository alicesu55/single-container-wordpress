# Single Container WordPress, Database Included

This docker image allows you to run many WordPress sites in a single container easily. An instance of MariaDB runs inside the image as a service to serve your sites.


## Why do you want to use this

The first question you may ask is, why do you want to squeeze all these things together, multiple WordPress sites, and a database. Of course, the standard way to run sites in production is to use docker-compose to run multiple containers, with each of them running a dedicated task.

The answer is simplicity and cost. Many cloud providers (e.g., [kintohub](https://www.kintohub.com/)) offer free services to run a small number of containers for free. You may not want to use multiple containers unless you have to.

## Quick Start

Docker pull command:

```
docker pull alicesu/single-container-wordpress
```

Minimum recommended command to run:

```bash
# Download the example config file. Make modifications to put your domain names.
curl https://raw.githubusercontent.com/alicesu55/single-container-wordpress/master/wp-docker-config.yml --output my_conf.yml

# Run the docker image
docker run -v "$PWD/my_conf.yml":/etc/wp-docker-config.yml -v "$PWD/data":/var/lib/mysql -v "$PWD/site":/var/www/html -p 80:80 alicesu/single-container-wordpress
```

## Configuration

The configuration of your sites come is performed via a simple config file in YAML format. The easiest way to get started is to [start from the example config file](https://github.com/alicesu55/single-container-wordpress/blob/master/wp-docker-config.yml).

### Applying the configuration

The config file needs to be mounted to the image at path `/etc/wp-docker-config.yml`

For example, after composing your config file as `my_conf.yml`, mount it with:

```bash
docker run -v "$PWD/my_conf.yml":/etc/wp-docker-config.yml alicesu/single-container-wordpress
```

### Using the configuration file

For documents, please refer to [the example config file](https://github.com/alicesu55/single-container-wordpress/blob/master/wp-docker-config.yml).

## Data Persistance

To avoid **losing all your data** when your contain restarts for any reason, provide persistance storage by mounting to the following directories:

```bash
# To keep your database:
/var/lib/mysql 

# To keep your plugins, updates, images, etc.:
/var/www/html/ 

```

## Automatic Backup and Restore

Optionally, you can set a schedule in the config file to automatically backup your sites and database to Amazon AWS S3. See all the options in [the example config file](https://github.com/alicesu55/single-container-wordpress/blob/master/wp-docker-config.yml).

If an optional boolean field `auto_restore` is set, and the key folders are empty when the container is started, the data will be restored from the backup.

If the container runs in an environment with no persistent storage, this feature can be used to allow your data to survive container rebuilds.

```YAML
## The optional auto backup and restore plan
backups:
  s3:
    ## Schedule in Cron schedule expression, see: https://crontab.guru/
    ## The schedule is required. Without it, the backup is disabled.
    schedule: "0 2 * * *"
    ## If enabled, when container starts with any of the two folders
    ##  /var/www/html and var/lib/mysql being empty,
    ## it be restored from the backup on S3 if available.
    auto_restore: true
```

## Fitting into Containers with Tight Memory Limits

If your container has a tight memory limit, add the limit in the system section. This image will attempt to configure the components to optimize for a small memory footprint.

```YAML
system:
  ## The available amount of memory, e.g., 256m, 1g, 3.5g
  ## The configuration will be automatically generated to provide the best
  ## performance while fitting into the memory
  ### Warning: DO NOT YOU this feature if you plan to customize the config files 
  ### of  php, apache, and MariaDB. Your config files may be overwritten.
  memory_limit: 256m
```

