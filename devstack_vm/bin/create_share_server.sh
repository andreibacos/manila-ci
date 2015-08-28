#!/bin/bash

# TODO(lpetrut): remove hardcoded stuff
NET_ID=$(neutron net-list | grep private | awk '{print $2}')
nova boot ws2012r2 --image=ws2012r2_kvm \
                   --flavor=100 \
                   --nic net-id=$NET_ID \
                   --user-data=/home/ubuntu/ssl/winrm_client_cert.pem