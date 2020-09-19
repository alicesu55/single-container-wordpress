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
    def __init__(self, key, settings):
        if settings is None:
            settings=dict()
        self.domain=key
        self.safe_name = key.replace('.', '_')
        self.db_name = settings['database_name'] if 'database_name' in settings else self.safe_name
        self.db_username = settings['database_user_name'] if 'database_user_name' in settings else self.safe_name
        self.db_password = settings['database_password'] if 'database_password' in settings else random_password()
        self.alias = settings['alias'] if 'alias' in settings else []
        self.site_folder = f"/var/www/html/{self.safe_name}"

    def db_script(self):
        return f"""
            CREATE DATABASE IF NOT EXISTS {self.db_name}; 
            CREATE USER '{self.db_username}'@'%' IDENTIFIED BY '{self.db_password}' ;
            GRANT ALL ON {self.db_name}.* TO '{self.db_username}'@'%' ;
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
        self._parse_sites(self.documents['sites'])

        ## Database
        self.prepare_site_db_scripts(self.sites)
        subprocess.run(['cat','/docker-entrypoint-initdb.d/wordpress-db_init.sql'], stdout=sys.stdout)
        self.init_database(self.documents['database'])

        
        for s in self.sites:
            ## Apache
            conf_path = f'/etc/apache2/sites-enabled/{s.safe_name}.conf'
            if not os.path.exists(conf_path):    
                with open(conf_path, 'w') as file:
                    file.write(s.apache_config())

    def setup_wordpress(self):
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
        pass

    def init_database(self, db_settings):
        print("Initializing database: ", db_settings)
        if 'root_password_random' in db_settings and db_settings['root_password_random']==True:
            self.db_password = random_password()
        elif 'root_password' in db_settings:
            self.db_password=db_settings['root_password']
        if self.db_password is None or len(self.db_password)==0:
            raise ValueError("In database section, please set root_password or use root_password_random:true")

        my_env = os.environ.copy()
        my_env["MYSQL_ROOT_PASSWORD"] = self.db_password
        result = subprocess.run(["init_mariadb.sh", "mysqld"], env=my_env, stdout=sys.stdout, stderr=sys.stderr)
        if result.returncode!=0:
            raise SystemError('Error initializing the database')
        else:
            print("Database is set up")

    def prepare_site_db_scripts(self, sites):
        with open ('/docker-entrypoint-initdb.d/wordpress-db_init.sql', 'a') as file:
            for s in sites:
                file.write(s.db_script())

    def print(self):
        for item, doc in self.documents.items():

            print(item, ":", doc)

if __name__=="__main__":
    builder = WpDockerBuilder('/etc/wp-docker-config.yml')
    builder.print()
    builder.build_lamp()

    p=subprocess.Popen (["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"], stdout=sys.stdout, stderr=sys.stderr)
    builder.setup_wordpress()
    p.wait()

