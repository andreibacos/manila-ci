#!/bin/bash
set -e

source /usr/local/src/manila-ci/jobs/utils.sh
ensure_branch_supported || exit 0

# Deploy devstack vm
/usr/local/src/manila-ci/jobs/deploy_devstack_vm.sh

source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.manila.txt

# Update local.conf
run_ssh_cmd_with_retry ubuntu@$FIXED_IP $DEVSTACK_SSH_KEY  \
	"sed -i \"s/\(driver_handles_share_servers\).*/\1 = False/g\" /home/ubuntu/devstack/local.conf"
run_ssh_cmd_with_retry ubuntu@$FIXED_IP $DEVSTACK_SSH_KEY  \
    'sed -i "s/iniset \$TEMPEST_CONFIG share build_timeout 2400/iniset \$TEMPEST_CONFIG share build_timeout 2400 \niniset \$TEMPEST_CONFIG share multitenancy_enabled False/g" /home/ubuntu/bin/run_tests.sh'

# Run devstack
/usr/local/src/manila-ci/jobs/run_devstack.sh

run_ssh_cmd_with_retry ubuntu@$FIXED_IP $DEVSTACK_SSH_KEY \
    'source /home/ubuntu/keystonerc; NOVA_COUNT=$(nova service-list | grep nova-compute | grep -c -w up); if [ "$NOVA_COUNT" != 1 ];then nova service-list; exit 1;fi' 12

if [[ "$ZUUL_BRANCH" == "master" ]] || [[ "$ZUUL_BRANCH" == "stable/ocata" ]]; then
    run_ssh_cmd_with_retry ubuntu@$FIXED_IP $DEVSTACK_SSH_KEY \
        "url=\$(grep transport_url /etc/nova/nova-dhcpbridge.conf | awk '{print \$3}'); nova-manage cell_v2 simple_cell_setup --transport-url \$url >> /opt/stack/logs/screen/create_cell.log"
fi

# restart nova services to refresh cached cells (manila-share will not find the windows VM otherwise)
run_ssh_cmd_with_retry ubuntu@$FIXED_IP $DEVSTACK_SSH_KEY "/home/ubuntu/bin/restart_nova_services.sh" 

# Create the share server used by manila in this scenario
run_ssh_cmd_with_retry ubuntu@$FIXED_IP $DEVSTACK_SSH_KEY  \
    "source /home/ubuntu/keystonerc && /home/ubuntu/bin/create_share_server.sh" 6

# Ensure that the m-shr service is available or wait for it otherwise.
# Note that for this job type, the service becomes available only after
# the share server can be reached via WinRM.
run_ssh_cmd_with_retry ubuntu@$FIXED_IP $DEVSTACK_SSH_KEY  \
    "source /home/ubuntu/keystonerc && /home/ubuntu/bin/check_manila.sh" 1
