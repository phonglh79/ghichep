#!/usr/bin/python3.6
from keystoneauth1.identity import v3
from keystoneauth1 import session
from client import OpenstackClient

import configparser
import json

def ini_file_loader():
    """ Load configuration from ini file"""

    parser = configparser.SafeConfigParser()
    parser.read('/usr/local/bin/config.cfg')
    config_dict = {}

    for section in parser.sections():
        for key, value in parser.items(section, True):
            config_dict['%s-%s' % (section, key)] = value
    return config_dict


class Token(object):
    """
    Lớp tạo session auth keystone phục vụ cho các thư viện openstack khác
    """
    session_auth = None
    def __init__(self,):
        """Khởi tạo phiên
        :params:
        - auth_ref = Lớp chung, đối tượng truyền vào chính là AuthPassword và AuthToken.
        :notes:
        - Sử dụng tính chất đa hình Python OOP
        - Mục đích khởi tạo ra kết nối tới openstack (keystone session)
        """
        self.config_dict = ini_file_loader()  
        self.session_auth = v3.Password(
            auth_url=self.config_dict['controller-auth_url'],
            username=self.config_dict['controller-username'],
            password=self.config_dict['controller-password'],
            project_id=self.config_dict['controller-project_id'],
            project_domain_name=self.config_dict['controller-project_domain_name'],
            user_domain_name=self.config_dict['controller-user_domain_name']
        )


class ListServices(OpenstackClient):

    def __init__(self, session_auth):
        self.client = OpenstackClient(session_auth=session_auth)

    def cinder_services_list(self):
        services = self.client.cinder_api.services.list()
        services_list = []
        for service in services:
            service_dict = {'service_name':service.binary,
                            'host':service.host,
                            'state':service.state}
            services_list.append(service_dict)
        return services_list

    def neutron_services_list(self):
        agents = self.client.neutron_api.list_agents()
        agents_list = []
        for item in agents["agents"]:
            agent_keys = {'binary', 'alive', 'host'}
            agent_dict = {key: value for key, value in item.items() if key in agent_keys}
            agents_list.append(agent_dict)
        return agents_list

    def nova_services_list(self):
        services = self.client.nova_api.services.list()
        services_list = []
        for service in services:
            service_dict = {'service_name':service.binary,
                            'host':service.host,
                            'state':service.state}
            services_list.append(service_dict)
        return services_list

