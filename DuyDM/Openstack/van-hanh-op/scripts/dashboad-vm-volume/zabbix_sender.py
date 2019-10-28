#!/usr/bin/python3.5
from pyzabbix import ZabbixMetric, ZabbixSender
from utils import Token, ListServices
from client import OpenstackClient

packet = []
zserver = '192.168.70.110'
port = 10051
hostId = 'OP_CTL2'
key_volumes_available = 'volumes[available]'
key_volumes_in_use = 'volumes[inuse]'
key_volumes_other = 'volumes[other]'
key_volumes_total = 'volumes[total]'
key_volumes_backup_total = 'volumes[backup]'
key_volumes_attached = 'volumes[attached]'
key_volumes_error = 'volumes[error]'
key_vms_total = 'vms[total]'
key_vms_running = 'vms[running]'
key_vms_stop = 'vms[stop]'
key_projects_total = 'projects[total]'
key_users_total = 'users[total]'
key_ips_total = 'ips[total]'
keys_ips_used = 'ips[used]'
keys_ips_availabity = 'ips[availabity]'
network_name = 'VLAN_192'


def check_volumes(client):
    volumes = client.cinder_api.volumes.list(search_opts={'all_tenants':1})
    total_volumes_backup = len(client.cinder_api.backups.list(search_opts={'all_tenants':1}))
    total_volumes = len(volumes)
    total_volumes_available = 0
    total_volumes_other = 0
    total_volumes_in_use = 0
    total_volumes_attached = 0
    total_volumes_error = 0
    for volume in volumes:
        if volume.status == 'available':
            total_volumes_available += 1
        elif volume.status == 'in-use':
            total_volumes_in_use += 1
        elif volume.status == 'error':
            total_volumes_error += 1
        elif volume.attachments:
            total_volumes_attached += 1
        else:
            total_volumes_other += 1
    packet_volumes = [ZabbixMetric(hostId, key_volumes_total, total_volumes),
                      ZabbixMetric(hostId, key_volumes_available, total_volumes_available),
                      ZabbixMetric(hostId, key_volumes_other, total_volumes_other),
                      ZabbixMetric(hostId, key_volumes_in_use, total_volumes_in_use),
                      ZabbixMetric(hostId, key_volumes_backup_total, total_volumes_backup),
                      ZabbixMetric(hostId, key_volumes_error, total_volumes_error),
                      ZabbixMetric(hostId, key_volumes_attached, total_volumes_attached)]
    return packet_volumes
    

def check_vms(client):
    vms = client.nova_api.servers.list(search_opts={'all_tenants':1})
    total_vms = len(vms)
    total_vms_running = 0
    total_vms_stop = 0
    for vm in vms:
        if vm.status == 'ACTIVE':
            total_vms_running += 1
        else:
            total_vms_stop += 1
    packet_vms = [ZabbixMetric(hostId, key_vms_total, total_vms),
                  ZabbixMetric(hostId, key_vms_running, total_vms_running),
                  ZabbixMetric(hostId, key_vms_stop, total_vms_stop)]
    return packet_vms


def check_projects(client):
    total_projects = len(client.keystone_api.projects.list())
    total_users = len(client.keystone_api.users.list())
    packet_projects = [ZabbixMetric(hostId, key_projects_total, total_projects),
                       ZabbixMetric(hostId, key_users_total, total_users)]
    return packet_projects


def check_ip_availabilities(client):
    subnets = client.neutron_api.list_network_ip_availabilities()
#    for subnet in subnets['network_ip_availabilities']:
#        if subnet['network_name'] == network_name:
#            total_ips = subnet['total_ips']
#            total_ips_used = subnet['used_ips']
#            total_ips_availabity = total_ips - total_ips_used
    networks = ['VLAN_192', 'VLAN_193', 'VLAN_183']
    total_ips = 0
    total_ips_used = 0
    for subnet in subnets['network_ip_availabilities']:
        if subnet['network_name'] in networks:
            total_ips += int(subnet['total_ips'])
            total_ips_used += int(subnet['used_ips'])
    total_ips_availabity = total_ips - total_ips_used
    packet_ips = [ZabbixMetric(hostId, key_ips_total, total_ips),
                  ZabbixMetric(hostId, keys_ips_used, total_ips_used),
                  ZabbixMetric(hostId, keys_ips_availabity, total_ips_availabity)]
    return packet_ips


def main():
    token = Token()
    client = OpenstackClient(session_auth=token.session_auth)
    packet_vms = check_vms(client)
    packet_volumes = check_volumes(client)
    packet_projects = check_projects(client)
    packet_ips = check_ip_availabilities(client)
    packet.extend(packet_vms)
    packet.extend(packet_volumes)
    packet.extend(packet_projects)
    packet.extend(packet_ips)
    result = ZabbixSender(zserver,port,use_config=None).send(packet)
    return result


if __name__ == '__main__':
    main()
