# Single Container WordPress, Database Included

This docker image allow you to run many WordPress sites in a single container easily.
An instance of Mariadb runs inside the image as a service to serve your sites.


## Why do you want to use this

Apparently, the first question you may ask is, why do you want to squeeze all these things together, multiple WordPress sites and a database. Of course, the standard way to run sites in production is to use docker compose to run multiple containers, with each of them running a dedicated task.

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

To avoid **loosing all your data** when your contain restarts for any reason, provide persistance storage by mounting to the following directories:

```bash
# To keep your database:
/var/lib/mysql 

# To keep your plugins, updates, images, etc.:
/var/www/html/ 

```




