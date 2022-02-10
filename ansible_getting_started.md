# After you have installed ansible

apt update
apt install software-properties-common
add-apt-repository ppa:ansible/ansible
apt update
apt install ansible

# and downloaded ansible playground with
git clone https://github.com/owncloud-ansible/playground
cd playground

# and installed ansible collections
ansible-galaxy collection install community.mysql
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix

# and installed the roles
ansible-galaxy install -r roles/requirements.yml

# You have the setup locally. Congratulations.
# Now, let's say you have to do a deployment. How to proceed?

# First we have to make sure we can get to the server => keys.

# Copy your public key over to the new server and enter it in to the .ssh/authorized_keys file

`scp ~.ssh/id_rsa.pub username@server:~.ssh/owncloud_deployment_key.pub`

cat owncloud_deployment_key.pub >> authorized_keys

# Make sure to set the correct permissions

chmod 700 .ssh/
chmod 600 .ssh/*

# Allright, now you can connect to your server you have to deploy with your keys. Great!

# Now let's go to ansible and test our connections with the ping module

ansible -i playground/inventories/ubuntu-minimal/hosts owncloud -u username -m "ping"


1. key authentication: chmod go-rwx ~/.ssh{,/authorized_keys}
2. sudo ohne password: visudo /etc/sudoers.d/<username> # add the following line: ALL=(ALL) NOPASSWD:ALL
3. ansible inventory is the hosts file: in there set [all:vars] ansible_host=<ip.ad.dre.ss>; ansible_user=<ssh login user>; ansible_become=yes; ansible_become_user=root
