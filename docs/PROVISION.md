# Manually provision a managed system

Note: you first need to have set up your puppet-control repository according to the instructions in [docs/BOOTSTRAP.md](BOOTSTRAP.md).

## Prepare the system

- Install Ubuntu (preferably server-minimal) with working networking and your control user account with sudo priviledges (examples below use "sysrar").
  Preferably configure networking using netplan with networkd as the renderer.
  This is an example `/etc/netplan/20-interfaces.yaml` for one static and one dhcp interface config (remove all other files from /etc/netplan):
  ```
  network:
    renderer: networkd
    ethernets:
      enp30s0:
        dhcp4: true
      enp31s0:
        dhcp4: false
        addresses: [192.168.0.42/24]
  ```
  You may need to start systemd-networkd for this to work (`sudo systemctl start systemd-networkd`) and then try applying the configuration with `sudo netplan apply

- You can clean out some unnecessary cruft from the Ubuntu install by:
  ```
  sudo apt update
  sudo apt remove ubuntu-desktop ubuntu-desktop-minimal
  sudo apt remove ubuntu-wallpapers
  sudo apt install ubuntu-server-minimal rsyslog less nano openssh-server --no-install-recommends
  sudo apt-get autoremove -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0
  sudo apt clean
  ```

- Install a few prerequistes
  ```
  sudo apt install git gpg bind9-dnsutils puppet
  ```

- Disable the default hiera config since it will not be used (and generates warnings from being in a deprecated format)
  ```
  sudo mv /etc/puppet/hiera.yaml   sudo mv /etc/puppet/hiera.yaml.disabled
  ```

## Setup secrets

- Place any "secrets" your configuration may need into a directory `/root/managed/secrets`.
  ```
  sudo mkdir -p /root/managed/secrets
  ```
  In this directory you should at least create or copy the following files: `puppet-control-pull-url`, `puppet-local-setups-pull-url` and `puppet-local-modules-pull-url`, `puppet-control-push-url`, `puppet-local-setups-push-url` and `puppet-local-modules-push-url`.
  For private repository pull-urls, create these using access-token URLs so that the repositories can be updated without authentication.

## Clone the control repo

- Clone your own forked puppet-control repository into `/etc/puppet/code/environments/production` owned by your control user and validate the contents.
Note - be attentive when running this, since you have to handle authentication when the private submodules are cloned:
  ```
  CONTROL_PULL_URL="$(sudo cat /root/managed/secrets/puppet-control-pull-url)"  
  CONTROL_PUSH_URL="$(sudo cat /root/managed/secrets/puppet-control-push-url)"  
  SETUPS_PULL_URL="$(sudo cat /root/managed/secrets/puppet-local-setups-pull-url)"
  SETUPS_PUSH_URL="$(sudo cat /root/managed/secrets/puppet-local-setups-push-url)"
  MODULES_PULL_URL="$(sudo cat /root/managed/secrets/puppet-local-modules-pull-url)"
  MODULES_PUSH_URL="$(sudo cat /root/managed/secrets/puppet-local-modules-push-url)"

  sudo mkdir -p /etc/puppet/code/environments
  sudo chown "root:sudo" /etc/puppet/code/environments
  sudo chmod g+srwx /etc/puppet/code/environments
  sudo chmod o-rwx /etc/puppet/code/environments
  umask "0002"
  git clone --recurse-submodules "$CONTROL_PULL_URL" /etc/puppet/code/environments/production

  cd /etc/puppet/code/environments/production
  git remote set-url origin "$CONTROL_PULL_URL"
  git remote set-url --push origin "$CONTROL_PUSH_URL"
  cd /etc/puppet/code/environments/production/modules/local-setups
  git remote set-url origin "$SETUPS_PULL_URL"
  git remote set-url --push origin "$SETUPS_PUSH_URL"
  git checkout main
  cd /etc/puppet/code/environments/production/modules/local-modules
  git remote set-url origin "$MODULES_PULL_URL"
  git remote set-url --push origin "$MODULES_PUSH_URL"
  git checkout main
  ```

- Do a self-consistency check of the downloaded files
  ```
  cd /etc/puppet/code/environments/production
  bin/validate.sh
  ```
  Check the output of the last command to make sure the repository is in a correct state.

## Apply system configuration

- Configure a system id
  Note: `<system name>` can be left out, in which case it is set to mac-<mac address>.

  ```
  sudo bin/set_system_id.sh "<system name>"
  ```

- Run the first `puppet apply`
  ```
  sudo puppet apply manifests/site.pp
  ```

Now go to [docs/MAINTENANCE.md](MAINTENANCE.md) for information about how to maintain this system.

## Automatic provision of new systems

You can continue to provision system manually by following the above instructions. However, once you have one managed system working, you can configure the bootserver setup to automatically install and configure new systems via network boot.
(This, of course, only works if the systems are physically connected in a way that allows this.)

(Info to be added)
