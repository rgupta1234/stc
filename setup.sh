#!/bin/bash

OCP_VERSION=3.9
CNS_NODES=3


cat << EOF
 ____ _____ ____ 
/ ___|_   _/ ___|
\___ \ | || |    
 ___) || || |___ 
|____/ |_| \____|
                 

EOF


echo
echo "Welcome to STC OpenShift Installation Validator"

if [ ! -f env.yml ]; then

echo "Defaults value are shown in []"
echo


echo "Are Hardware Requirements satisfied? Min. 16 GB RAM and 2 CPU"
echo "[y] n"
read req
[[ $req == "n" ]] && sed -Ei 's/sizing: (.*)/sizing: relaxed/' playbooks/group_vars/all

echo "Please select OCP Version to install: 3.10, 3.9 or 3.7"
echo "3.10 [3.9] 3.7"
read ocp_version

case "$ocp_version" in
3.10|3.9|3.7) OCP_VERSION=$ocp_version
;;
esac


sed -Ei "s/ocp_version: (.*)/ocp_version: \"$OCP_VERSION\"/" playbooks/group_vars/all 

echo "ocp_version: $OCP_VERSION" > env.yml

echo "*** selected $OCP_VERSION "
echo



while  [ -z $api_dns ]
do
  echo "Please insert Cluster hostname (API DNS):"
  read -r api_dns
done

echo "api_dns: $api_dns" >> env.yml

while  [ -z $apps_dns ]
do
  echo "Please insert Wilcard DNS for Apps:"
  read -r apps_dns
done

echo "apps_dns: $apps_dns" >> env.yml


echo
echo "Cluster Topology Setup"
echo


while  [ -z $bastion ]
do
  echo "Please insert Bastion Node hostname:"
  read -r bastion
done

echo "bastion: $bastion" >> env.yml

echo "Please insert a Load Balancer Node hostname (leave it blank if not needed or external Balancer is present, for e.g. pick bastion if needed):"
read -r lb

[[ -n $lb  ]] && echo "lb: $lb" >> env.yml

while  [ "$n_masters" != "1" -a  "$n_masters" != "3" ]
do
  echo "Please insert number of Masters (1 or 3):"
  echo "1 [3]"
  read -r n_masters
  if [ -z $n_masters ]; then
	n_masters=3
	break
  fi
done

echo "masters:" >> env.yml


for (( c=1; c<=$n_masters; c++ ))
do
	while  [ -z $master_i ]
	do
  		echo "Please insert Master $c hostname:"
  		read -r master_i
	done
	echo "- $master_i" >> env.yml
	master_i=""

done




echo "Please insert number of Infranodes (0 or 3, leave blank if App nodes are also Infranodes):"

read -r n_infranodes

if [ -n "$n_infranodes" ]; then
	echo "infranodes:" >> env.yml

	for (( c=1; c<=$n_infranodes; c++ ))
	do
        	while  [ -z $infranode_i ]
        	do
                	echo "Please insert Infranode $c hostname:"
                	read -r infranode_i
        	done
       		echo "- $infranode_i" >> env.yml
        	infranode_i=""

	done

fi



while  [ "$n_nodes" != "1" -a "$n_nodes" != "2" -a "$n_nodes" != "3" ]
do
  echo "Please insert number of Nodes (1, 2 or 3):"
  echo "1 2 [3]"
  read -r n_nodes
  if [ -z $n_nodes ]; then
        n_nodes=3
        break
  fi
done

echo "nodes:" >> env.yml


for (( c=1; c<=$n_nodes; c++ ))
do
        while  [ -z $node_i ]
        do
                echo "Please insert Node $c hostname:"
                read -r node_i
        done
        echo "- $node_i" >> env.yml
        node_i=""

done


echo "Is there any Proxy to use for OpenShift and Container Runtime?"
echo "y [n]"
read has_proxy

if [[ $has_proxy == "y"  ]]; then
	while  [ -z $proxy_http ]
	do
  		echo "Please insert HTTP Proxy:"
  		read -r proxy_http
	done

	echo "proxy_http: $proxy_http" >> env.yml


        while  [ -z $proxy_https ]
        do
                echo "Please insert HTTPS Proxy:"
                read -r proxy_https
        done

        echo "proxy_https: $proxy_https" >> env.yml

        echo "Please insert No Proxy (leave blank if any)"
        read -r proxy_no
	
	if [ -n "$proxy_no" ]; then
        	echo "proxy_no: $proxy_no" >> env.yml
	fi

        echo "Please insert Proxy Username (leave blank if any)"
        read -r proxy_username

        if [ -n "$proxy_username" ]; then
                echo "proxy_username: $proxy_username" >> env.yml
        fi

        echo "Please insert Proxy Password (leave blank if any)"
        read -r proxy_password

        if [ -n "$proxy_password" ]; then
                echo "proxy_password: $proxy_password" >> env.yml
        fi

fi

while  [ "$cns" != "y" -a "$cns" != "n" ];
do
	echo
	echo "Install OCS (formerly known as CNS)?"
	echo "[y] n"
	read -r cns
        [[ -z $cns ]] && break
done


if [ "$cns" != "n" ]; then

echo "cns:" >> env.yml

for (( c=1; c<=$CNS_NODES; c++ ))
do
        while  [ -z $cns_i ]
        do
                echo "Please insert OCS Node $c hostname (e.g. pick masters, infra or nodes):"
                read -r cns_i
        done
        echo "- $cns_i" >> env.yml
        cns_i=""

done

else
		echo "Insert NFS Node hostname (leave it blank if not needed, for e.g. pick bastion if needed):"
		read -r nfs
		[[ -n $nfs ]] && echo "nfs: $nfs" >> env.yml

fi


while  [ -z $ssh_user ]
do
  echo "Please insert SSH username to be used by Ansible:"
  read -r ssh_user
done

echo "ssh_user: $ssh_user" >> env.yml


echo "Please select Subscription management: RHSM or Satellite"
echo "[rhsm] satellite"
read subscription

case "$subscription" in
rhsm|satellite);;
*) SUBSCRIPTION=${subscription:-rhsm}
;;
esac


if [ "$SUBSCRIPTION" = "rhsm" ]; then
        while  [ -z $rhsm_username ]
	do
  		echo "Please insert RHSM username:"
  		read -r rhsm_username
	done

	echo "rhn_username: $rhsm_username" >> env.yml

	echo '*** registering host to RHSM with username '$rhsm_username
	sudo subscription-manager register --username $rhsm_username
	if [ $? != 0 ]; then
		echo "Error while registering host, please verify credentials"
		exit 1
	fi
	echo 'Please insert pool id if any, leave blank to find out it automatically'
	read pool_id
        if [ -z "$pool_id" ]; then
        	echo '*** figuring out subscription pool id'
		SUBSCRIPTION_POOL_ID=`sudo subscription-manager list --available --matches=*Openshift* --pool-only | head -1 - ` && echo 'subscription_pool_id: '$SUBSCRIPTION_POOL_ID >> env.yml
	else
		echo '*** using subscription pool id ' $pool_id
		SUBSCRIPTION_POOL_ID=$pool_id
		echo 'subscription_pool_id: '$SUBSCRIPTION_POOL_ID >> env.yml
	fi
	#echo '*** attaching host to correct subscription '
	#sudo subscription-manager attach --pool=$SUBSCRIPTION_POOL_ID
	#echo '*** disable all repos'
	#sudo subscription-manager repos --disable='*'
else
	echo '*** registering host to Satellite'
	echo "Please insert Organization ID:"
	read org_id
	echo
	echo "Please insert Activation Key:"
	read ak
	echo
        if [ -z "$org_id" -o -z "$ak" ]; then
		echo "Error: Organization ID and Activation Key cannot be empty"
		exit 1
	fi
	echo "subscription_activationkey: $ak" >> env.yml
	echo "subscription_org_id: $org_id" >> env.yml
	#echo "*** using Organization ID $org_id and Activation Key $ask to register host"
	#sudo subscription-manager register --org="$org_id" --activationkey="$ak"
fi

echo
echo "Generated configuration:"
echo
echo '********************* STC Conf file *********************'
cat env.yml
echo '****************** End STC Conf file ********************'
echo

else
	echo
	echo "A env.yml file di already present"
	echo "These values will be used:"
	echo
	echo '********************* STC Conf file *********************'
	cat env.yml
	echo '****************** End STC Conf file ********************'
	echo
fi

while  [ "$install" != "y" -a "$install" != "n" ];
do
  echo "Do you want to proceed?"
  echo "y n"
  read -r install
done

if [ "$install" == "n" ]; then

        echo "Aborting installation, please restart"
        exit 1
fi

OCP_VERSION=`grep ocp_version env.yml | awk '{print $2;}';`

if grep subscription_pool_id env.yml >/dev/null; then 
	pool=`grep subscription_pool_id env.yml | awk '{print $2;}';`
        echo '*** attaching host to correct subscription '
        sudo subscription-manager attach --pool=$pool
        echo '*** disable all repos'
        sudo subscription-manager repos --disable='*'
elif grep subscription_org_id env.yml >/dev/null; then
	org_id=`grep subscription_org_id env.yml | awk '{print $2;}';`
	activation_key=`grep subscription_activationkey env.yml | awk '{print $2;}';`
	echo "*** using Organization ID $org_id and Activation Key $activation_key to register host"

        sudo subscription-manager register --org="$org_id" --activationkey="$activation_key"
fi


echo '*** enable repos needed for OCP'
sudo subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-ose-$OCP_VERSION-rpms --enable=rhel-7-fast-datapath-rpms
if [[ $OCP_VERSION != "3.7" ]]; then
       echo '*** enable ansible 2.4 repo for OCP '$OCP_VERSION
       sudo subscription-manager repos --enable=rhel-7-server-ansible-2.4-rpms
fi

echo '*** install git and ansible'
sudo yum install -y git ansible tmux nc screen
echo '*** validate given configuration (env.yml)'
ansible-playbook playbooks/validate_config.yml
echo '*** encrypt secrets file'
ansible-vault encrypt secrets.yml
echo '*** enable SSH authentication between hosts'
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i inventory -k --ask-vault-pass playbooks/prepare_ssh.yml
echo '*** copy created inventory as default inventory'
sudo cp inventory /etc/ansible/hosts
