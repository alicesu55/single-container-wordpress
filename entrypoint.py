#!/usr/bin/env python3

import subprocess
import yaml
import random
import string
import os
import sys


def random_password():
    RANDOM_PASSWORD_LENGTH=32
    letters = string.ascii_lowercase
    return ''.join(random.choice(letters) for i in range(RANDOM_PASSWORD_LENGTH))

class SiteSettings:
    """Data model of a "site" from the "sites" section in the config file
    """

    def __init__(self, key, settings):
        if settings is None:
            settings=dict()
        self.domain=key
        self.safe_name = key.replace('.', '_')
        self.db_name = settings['database_name'] if 'database_name' in settings else self.safe_name
        self.db_username = settings['database_user_name'] if 'database_user_name' in settings else self.safe_name
        self.db_password = settings['database_password'] if 'database_password' in settings else random_password()
        self.alias = settings['alias'] if 'alias' in settings else []
        self.site_folder = f"/var/www/html/{self.domain}"

    def db_script(self):
        return f"""
            CREATE DATABASE IF NOT EXISTS {self.db_name};
            DROP USER IF EXISTS '{self.db_username}'@'%' ;
            CREATE USER  '{self.db_username}'@'%' IDENTIFIED BY '{self.db_password}' ;
            GRANT ALL ON {self.db_name}.* TO '{self.db_username}'@'%' IDENTIFIED BY '{self.db_password}';
            FLUSH PRIVILEGES;
        """

    def apache_config(self):
        placeholder = '__ServerName__place__holder'
        config = f"""
        <VirtualHost *:80>
            DocumentRoot "{self.site_folder}"
            {placeholder}
        </VirtualHost>
        """
        if self.domain=='default':
            config=config.replace(placeholder, '')
        else:
            serveralias =''
            for a in self.alias:
                serveralias += f'            ServerAlias {a}\n'
            config=config.replace(placeholder,
            f"""
            ServerName {self.domain}
            {serveralias}
            """)
        return config


class WpDockerBuilder:
    def __init__(self, config_file):
        self.db_password = None
        self.sites = []
        with open(config_file) as file:
            self.documents = yaml.full_load(file)

    def _parse_sites(self, settings):
        for key in settings:
            self.sites.append(SiteSettings(key, settings[key]))

    def build_lamp(self):
        """ Configure the LAMP server (bad name), including Mariadb, and Apache.
            The apache settings will include the configurations of all sites
        """
        self.init_db_password(self.documents['database'])
        if 'system' in self.documents:
            self.memory_config(self.documents['system'])
        # backup and restore
        self.backup_restore(self.documents['backups'])

        self._parse_sites(self.documents['sites'])
        ## Database
        self.prepare_site_db_scripts(self.sites)

        self.init_database(self.documents['database'])

        
        for s in self.sites:
            ## Apache
            conf_path = f'/etc/apache2/sites-enabled/{s.domain}.conf'
            if not os.path.exists(conf_path):    
                with open(conf_path, 'w') as file:
                    file.write(s.apache_config())
            default_conf = '/etc/apache2/sites-enabled/default.conf'
            if not os.path.exists(default_conf):
                # There is not default, generate one
                with open(default_conf, 'w') as file:
                    file.write(f"""
<VirtualHost *:80>
  ServerName default
  Redirect 404 /
</VirtualHost>
<VirtualHost _default_:80>
  Redirect 404 /
</VirtualHost>
                    """ )


    def setup_wordpress(self):
        """ Configure all the wordpress sites.
        """
        for s in self.sites:
            ## wordpress
            if not os.path.exists(s.site_folder):
                os.mkdir(s.site_folder)
                my_env = os.environ.copy()
                my_env["WORDPRESS_DB_USER"] = s.db_username
                my_env["WORDPRESS_DB_PASSWORD"] = s.db_password
                my_env["WORDPRESS_DB_NAME"] = s.db_name
                my_env["WORDPRESS_DB_HOST"] = '127.0.0.1'
                subprocess.run(["setup-wp.sh", 'apache2'], cwd=s.site_folder, env=my_env)

    def memory_config(self, mem_settings):
        print("Apply settings impacting memory: ", mem_settings)
        mem_mb=2048
        if 'memory_limit' in mem_settings:
            mem_str = mem_settings['memory_limit']
            if mem_str.endswith('m'):
                mem_mb=float(mem_str[:-1])
            elif mem_str.endswith('g'):
                mem_mb=float(mem_str[:-1])*1024
        print('Optimizing for memory: ', mem_mb)
        if mem_mb<2048:
            folder='/etc/mem/128/'
        else:
            folder='/etc/mem/2048/'
        subprocess.run(['cp', '-f', folder+'50-server.cnf', '/etc/mysql/mariadb.conf.d/50-server.cnf'], stdout=sys.stdout, stderr=sys.stderr)
        subprocess.run(['cp', '-f', folder+'mpm_prefork.conf', '/etc/apache2/mods-available/mpm_prefork.conf'], stdout=sys.stdout, stderr=sys.stderr)

    def backup_restore(self, backup_settings):
        """Setup the backups using cron job
        """
        if backup_settings is None:
            return

        print('Backup settings', backup_settings)

        s3_backup = backup_settings['s3']
        if s3_backup is not None and s3_backup['schedule'] is not None:
            subprocess.run('aws_install.sh', stdout=sys.stdout, stderr=sys.stderr)

            if 'schedule' not in s3_backup:
                raise ValueError('Must have "schedule" field in "s3"')

            with open('/etc/backup_credentials.sh', 'a') as file:
                file.write(f"export DB_PASSWORD={self.db_password}\n")

                if 'bucket' in s3_backup:
                    file.write(f"export BACKUP_BUCKET={s3_backup['bucket']}\n")
                elif 'BACKUP_BUCKET' in os.environ:
                    file.write(f"export BACKUP_BUCKET={os.environ['BACKUP_BUCKET']}\n")

                if 'aws_access_key_id' in s3_backup:
                    file.write(f"export AWS_ACCESS_KEY_ID={s3_backup['aws_access_key_id']}\n")
                elif 'AWS_ACCESS_KEY_ID' in os.environ:
                    file.write(f"export AWS_ACCESS_KEY_ID={os.environ['AWS_ACCESS_KEY_ID']}\n")

                if 'aws_secret_access_key' in s3_backup:
                    file.write(f"export AWS_SECRET_ACCESS_KEY={s3_backup['aws_secret_access_key']}\n")
                elif 'AWS_SECRET_ACCESS_KEY' in os.environ:
                    file.write(f"export AWS_SECRET_ACCESS_KEY={os.environ['AWS_SECRET_ACCESS_KEY']}\n")

                if 'aws_region' in s3_backup:
                    file.write(f"AWS_REGION={s3_backup['aws_region']}\n")
                elif 'AWS_REGION' in os.environ:
                    file.write(f"AWS_REGION={os.environ['AWS_REGION']}\n")

            with open('/etc/crontab', 'a') as file:
                file.write(f"{s3_backup['schedule']}  root    /usr/local/bin/s3_backup.sh>/proc/1/fd/1 2>&1\n")
                file.write('\n')

            if 'auto_restore' in s3_backup and s3_backup['auto_restore']:
                subprocess.run(['init_from_s3_backup.sh'], stdout=sys.stdout, stderr=sys.stderr)

    def init_db_password(self, db_settings):
        if 'root_password_random' in db_settings and db_settings['root_password_random']==True:
            self.db_password = random_password()
        elif 'root_password' in db_settings:
            self.db_password=db_settings['root_password']
        if self.db_password is None or len(self.db_password)==0:
            raise ValueError("In database section, please set root_password or use root_password_random:true")

    def init_database(self, db_settings):
        """Initialize the database if it is not already initialized

        Args:
            db_settings (dict): The settings of the database from the config file
                                Important fields include:
                                root_password_random: True is the root password shall be generated randomly
                                root_password: The root password of the database, only effective if root_password_random is False
        """
        print("Initializing database ... ")

        my_env = os.environ.copy()
        my_env["MYSQL_ROOT_PASSWORD"] = self.db_password
        result = subprocess.run(["init_mariadb.sh", "mysqld"], env=my_env, stdout=sys.stdout, stderr=sys.stderr)
        if result.returncode!=0:
            raise SystemError('Error initializing the database')
        else:
            print("Database is set up")

    def prepare_site_db_scripts(self, sites):
        """ Generate a SQL file that configures the databases of all sites.
            Args:
                sites: A list of class SiteSettings.
        """
        with open ('/docker-entrypoint-initdb.d/40-wordpress-db_init.sql', 'a') as file:
            for s in sites:
                file.write(s.db_script())

    def print(self):
        # Debug prints
        for item, doc in self.documents.items():
            print(item, ":", doc)

if __name__=="__main__":
    builder = WpDockerBuilder('/etc/wp-docker-config.yml')
    builder.build_lamp()

    p=subprocess.Popen (["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"], stdout=sys.stdout, stderr=sys.stderr)
    builder.setup_wordpress()
    subprocess.run(['cat', '/etc/crontab'])
    p.wait()

