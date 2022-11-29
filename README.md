# puppet-setups-control

This repository is a template repository with instructions to set up and operate efficient and secure configuration management of a computing infrastructure using *puppet* organized according a *"puppet-setups"* model.

*These instructions and source code is governed by an MIT-style license that can be found in the LICENSE file - (c) Rickard Armiento, 2022.*

The main repository is located at: https://github.com/httk-system/puppet-setups-control

## At a glance

The configuration management system described here has the following highlights:

* Puppet-based git-repo-centric configuration management to manage a computing infrastructure.

* Consistent security model using public key ssh authentication and signatures with yubikeys hardware keys (recommended) or regular gpg keys (not recommended).

* Puppet module dependencies handled using git submodules in a way that is, arguably, easier to understand and review from security perspective than puppet-librarian, r10k, etc.

* Puppet manifests organized in a *"puppet-setups"* model, centered around a Hiera *setup hierarchy* and puppet *setup functions* that, arguably, has some benefit over a more standard *roles and profiles* model. See [docs/PUPPET_SETUPS.md](docs/PUPPET_SETUPS.md) for more info.

* Enables configuration work to be carried out on the managed systems themselves without the management system getting too much in the way.

## Repository organization

The primary repository that declares a full software infrastructure is *puppet-control*.
It is mostly organized as usual for puppet control repositories:

* `bin/` contains some useful scripts / tools.

* `security/` contains some security-related data files.

* `manifests/` contains the primary puppet manifests that are run to provision new systems and `site.pp` which is called for puppet apply.

* `hiera` contains the Hiera configuration.

  The configuration data organized in a *"puppet-setups"* model (which differs from the usual puppet *roles and profiles* method).
  The file `hiera/setup.yaml` contains the *setup hierarchy*, i.e., the declaration of the computing infrastructure configuration.
  (Which can be divided up into more files if one prefers.)
  The setup hierarchy is a list of software technologies, *setups*.
  Each *setup* specifies global configuration parameters and assignes specific nodes to *roles* of that software technology.
  For more details on this model, see [docs/PUPPET_SETUPS.md](docs/PUPPET_SETUPS.md).

* `modules/` uses [Git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to include all puppet module dependencies.

  It is generally advisible to divide dependencies into *setup modules* and normal puppet modules that manage specific softwares.
  Hence, the standard organization of `modules/` is as follows:

  - `upstream-setups`: a git submodule pointing to the "upstream" repo for *setup modules* (i.e., those from the `httk-system` GitHub organization).
  - `upstream-modules`: a git submodule pointing to the upstream repo for puppet modules.
  - `local-setups`: a git submodule pointing to a repo for *setup modules* tailored for your own computing infrastructure.
  - `local-modules`: a git submodule pointing to a repo for normal puppet modules tailored for your own computing infrastructure.
  - `external`: every subdirectory is a git submodule pointing to an external module, e.g., this is how to include the standard `apache` and `firewall` modules provided by puppetlabs.

## Prerequisites

### Control center machine

The infrastructure consists of *managed nodes* and one or more *control centers* (one machine can be both.)
A *control center* should be a machine where a system administrator is physically present to perform system administrative tasks, meaning that it is a physically secure place for encryption keys, etc.

All system administrators need a *control user account*.
It is a good idea to keep these separate from your regular login names, e.g., by adding a "sys" prefix or suffix to the regular usernames.
In the following we will refer to, e.g., the *control username*.

To follow these instructions, your intial control center must at least run Ubuntu 20.04.
It must also have puppet, git, and gpg installed; and tools for managing yubikeys if you are going to use them:
```
sudo apt install git gpg gpg-agent puppet
sudo apt install yubico-piv-tool ykcs11
```

*NOTE: the yubico-piv-tool 2.2.0 on Ubuntu 22.04 is not working properly due to a mismatch with the openssl version. On this platform you have to download and build version yubico-piv-tool 2.3.0 manually.*

### Security setup

The security infrastructure is completely centered on cryptograhic signatures handled by gpg, either (preferably) stored on hardware tokens (yubikeys) or (not recommended) as password protected files stored locally on your *control center* machines.

It is thus highly recommended to invest in at least three [yubikeys](https://www.yubico.com/se/store/).
These devices are hardware tokens that, when correctly setup and used, makes sure no one will be able to obtain a copy of your secret keys without you knowing.
I am not affiliated with Yubico, but the cost of these devices is highly motivated for the extra security it brings to managing your infrastructure

The reason one needs three yubikeys is to adhere to a golden rule: never plan to be in a position where a single hardware failure comes with disasterous conseuqences.
In our case, it is certain that one day one of the keys has to be replaced (e.g., due to breaking or missing).
At that point, if we originally one kept two keys, we are a single hardware failure from being locked out of our infrastructure.
(If there are more than one system administrator, stricly speaking, they can cover for each other so the total minimum of three keys still apply. However, it is probably a good idea to provide two keys per administrator, since otherwise a key failure block that administrator from work until the replacement is in place.)

For information on how to setup the yubikeys, see: [docs/YUBIKEYS.md](docs/YUBIKEYS.md).

## Bootstrap setup

1. Fork this repository into a private repository for your organization and name it "puppet-control".

2. Clone it into your initial control center machine, e.g., into `~/Puppet`.
   ```
   mkdir ~/Puppet
   cd ~/Puppet
   git clone --recurse-submodules <your git repo remote>
   ```

3. Handle the security configuration.

   - Copy all `authorized_keys_*.<control username>` files for all system administrators into the `security` directory.

   - Merge all system administratos `trusted_keys.asc` into a single file and place it into the `security` directory.

4. Execute the contol center setup config:
   ```
   sudo puppet apply modules/upstream-setups/manifests/provision_control_center.pp --modulepath modules/external:modules/upstream-setups:modules/upstream-modules
   ```
   
5. Create on your git host (e.g., GitHub) a repository `puppet-setups` for your local setup functions (recommended to be private) and a repository `puppet-modules` (can probably be public) as a repository where to keep your own modules while you develop them.

6. Add your own repositories as git submodules to the module directory:
   ```
   cd modules
   git submodule add <url> local-setups
   git submodule add <url> local-modules
   ```

7. A small example infrastructure configuration is provided in `hiera/common.yaml`.
   This is primary file to edit to create your configuration.

8. Modify the dependency modules to include the external repositories you need.

9. Commit the changes with a signature (important!):
   ```
   git commit -S
   ```

10. Push your signed changes to the repository back to your remote.
    ```
    git push
    ```

## Set up management for a first manually installed system

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

- Place any "secrets" your configuration may need into a directory `/root/secrets`.
  At the very least you should create or copy access-token URLs for read access to your puppet-control, local-setups, and local-modules (if non-public) repositories into `puppet-control-token-url`, `puppet-local-setups-token-url` and `puppet-local-modules-token-url` in this directory.
  ```
  sudo mkdir -p /root/secrets
  ```

- Clone your own forked puppet-control repository into `/etc/puppet/code/environments/production` owned by your control user and validate the contents.
Note - be attentive when running this, since you have to handle authentication when the private submodules are cloned:
  ```
  CONTROL_USER="sysrar"
  CONTROL_PUSH_URL="git@github.com:example/puppet-control.git"
  CONTROL_TOKEN_URL="$(sudo cat /root/secrets/puppet-control-token-url)"  
  SETUPS_PUSH_URL="git@github.com:example/puppet-setups.git"
  SETUPS_TOKEN_URL="$(sudo cat /root/secrets/puppet-setups-token-url)"
  MODULES_PUSH_URL="git@github.com:example/puppet-modules.git"
  MODULES_TOKEN_URL="$(sudo cat /root/secrets/puppet-modules-token-url)"

  sudo mkdir -p /etc/puppet/code/environments
  sudo chown "$CONTROL_USER:$CONTROL_USER" /etc/puppet/code/environments
  git clone --recurse-submodules "$CONTROL_REPO" /etc/puppet/code/environments/production
  chmod go-rx /etc/puppet/code/environments

  cd /etc/puppet/code/environments/production
  git remote set-url origin "$CONTROL_TOKEN_URL"
  git remote set-url --push origin "$CONTROL_PUSH_URL"
  cd /etc/puppet/code/environments/modules/local-setups
  git remote set-url origin "$SETUPS_TOKEN_URL"
  git remote set-url --push origin "$SETUPS_PUSH_URL"
  git checkout main
  cd /etc/puppet/code/environments/modules/local-modules
  git remote set-url origin "$MODULES_TOKEN_URL"
  git remote set-url --push origin "$MODULES_PUSH_URL"
  git checkout main
  ```

- Do a self-consistency check of the downloaded files
  ```
  cd /etc/puppet/code/environments/production
  bin/validate.sh
  ```
  Check the output of the last command to make sure the repository is in a correct state.

- Set up your ssh keys:
  ```
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  cp -rp /etc/puppet/code/environments/production/security/authorized_keys.<control user> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  ```

- Configure a system id
  Note: `<system name>` can be left out, in which case it is set to mac-<mac address>.

  ```
  sudo bin/set_system_id.sh "<system name>"
  ```

- Run the provision script.
  Note: `<system name>` can be left out, in which case it is set to mac-<mac address>.

  ```
  sudo puppet apply modules/upstream-setups/manifests/provision_managed_node.pp --modulepath modules/external:modules/upstream-setups:modules/upstream-modules
  ```

## Auto-install systems

Once you have one managed system working, you can configure it to automatically install and configure the rest of the systems you manage via network boot.
(This, of course, only works if the systems are connected in a way that allows this.)

(Info to be added)

## Maintenance

(Info to be added)
