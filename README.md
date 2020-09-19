# Single Container Wordpress, Database Included

This docker image allow you to run many Wordpress sites in a single container easily.
An instance of Mariadb runs inside the image as a service to serve your sites.


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




