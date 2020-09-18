#!/usr/bin/env python3

import subprocess
import yaml


class WpDockerBuilder:
    def __init__(self, config_file):
        with open(config_file) as file:
            self.documents = yaml.full_load(file)

    def print(self):
        for item, doc in self.documents.items():
            print(item, ":", doc)

if __name__=="__main__":
    builder = WpDockerBuilder('/etc/wp-docker-config.yml')
    builder.print()

    subprocess.run(["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"])
