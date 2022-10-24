# puppet-setups-control

Instructions and template repository for efficient and secure configuration management of a computing infrastructure using *puppet* with the *puppet-setups* model.

    These instructions and source code is governed by an MIT-style license that can be found in the LICENSE file or at https://opensource.org/licenses/MIT.

    (c) Rickard Armiento, 2022

The main repository is located at: https://github.com/httk-system/puppet-setups-control

## At a glance

The configuration management system set up according to this README has the following highlights:

* Puppet-based git-repo-centric configuration management for your computing infrastructure, using GitHub or equivalent.
* Consistent security model based on public key ssh authentication and signatures with yubikeys hardware keys (recommended) or regular gpg keys (not recommended)
* Git submodules are used to track puppet module dependencies, giving a structure that is, arguably, easier to understand and review from security perspective than puppet-librarian, r10k, etc.
* Organization and abstraction of puppet manifests in a *puppet-setups* model that uses a Hiera *setup hierarchy* and puppet *setup modules* which, arguably, has some benefit over a more standard *roles and profiles* model.
* Enables configuration work to be carried out on the managed systems themselves without the management system getting too much in the way.

## Repository organization

The primary repository that declares a full software infrastructure is *puppet-control*.
It is mostly organized as usual for puppet control repositories:

* `bin/` contains some useful scripts / tools.

* `security/` contains some security-related data files.

* `manifests/` contains the primary puppet manifests that are run to provision new systems and `site.pp` which is called for puppet apply.

* `hiera` contains the Hiera configuration.
  This repository use what we will call the *puppet-setups* method to organize the puppet configuration manifests, which differs from the usual puppet *roles and profiles* method.
  The configuration is declared using a Hiera *setup hierarchy*, where the highest level is a list of software technologies, *setups*.
  Each *setup* specifies global configuration parameters and assignes specific nodes to *roles* of that software technology.
  For more details on this model, see [PUPPET_SETUPS.md](PUPPET_SETUPS.md).

  The `hiera/setup.yaml` is the *setup hierarchy*, i.e., the declaration of the computing infrastructure configuration.
  (Which can be divided up into more files if one prefers.)

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
A *control center* should be a machine where you (or other system administratos) are physically present at to perform system administration tasks, meaning that it is a physically secure place for encryption keys, etc.

Furthermore, for management on remote systems all system administrators need a *control user*.
It is a good idea to keep these separate from your regular login names, e.g., by adding a "sys" prefix or suffix to the regular usernames.
In the following we will refer to, e.g., the *control username*.

To follow these instructions, your intial control center must at least run Ubuntu 20.04.
It must also have puppet, git, and gpg installed; and tools for managing yubikeys if you are going to use them:
```
sudo apt install git gnupg gnupg-agent puppet
sudo apt install yubico-piv-tool ykcs11
```

NOTE: the yubico-piv-tool 2.2.0 on Ubuntu 22.04 is not working properly due to a mismatch with the openssl version. On this platform you have to download and build version yubico-piv-tool 2.3.0 manually.

### Security setup

The security infrastructure is completely centered on cryptograhic signatures handled by gpg, either (preferably) stored on hardware tokens (yubikeys) or (not recommended) as password protected files stored locally on your *control center* machines.

It is thus highly recommended to invest in at least three [yubikeys](https://www.yubico.com/se/store/).
These devices are hardware tokens that, when correctly setup and used, makes sure no one will be able to obtain a copy of your secret keys without you knowing.
I am not affiliated with Yubico, but the cost of these devices is highly motivated for the extra security it brings to managing your infrastructure

The motivation for getting three keys is a golden rule in software and hardware management: never plan to place yourself in a position where there is a single hardware failure between you and a disasterous conseuqence.
In our case, one day one of our keys will have to be replaced (e.g., due to breaking or missing).
If we only have two keys and one is gone, we are in a situation where, if the remaining key also fails, we are loced out of our infrastructure.
(If there is more than one system administrator, the requirement translates to a minimum of three keys in *total*, not per person. However, it is probably a good idea to provide two keys per administrator, since otherwise each key failure means a person is blocked from work until the replacement key is in place.)

For information on how to configure the yubikeys, see: [YUBIKEYS.md](YUBIKEYS.md).

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
   sudo puppet apply manifests/control_center.pp --modulepath modules
   ```
5. Create on your git host (e.g., GitHub) a repository `puppet-setups` for your setups (recommended to be private) and a repository `puppet-modules` (can probably be public) as a bulk repository for your own modules while you develop them.

7. Add your own repositories as git submodules to the module directory:
   ```
   cd modules
   git submodule add <url> local-setups
   git submodule add <url> local-modules
   ```

8. A small example infrastructure configuration is provided in `hiera/common.yaml`.
   This is primary file to edit to create your configuration.

9. Modify the dependency modules to include the external repositories you need,
   plus you likely want to have your own setup and module repositories.

10. Commit the changes with a signature (important!):
    ```
    git commit -S
    ```

11. Push your signed changes to the repository back to your remote.
    ```
    git push
    ```

## Set up management for a manually installed system

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
  At the very least you should create or copy access-token URLs for read access to your puppet-control and private puppet module directories into `puppet-control-token-url` and `puppet-private-token-url` in this directory.
  ```
  sudo mkdir -p /root/secrets
  ```

- Clone this repository into `/etc/puppet/code/environments/production` owned by your control user and validate the contents.
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

- Run the provision script.
  Note: `<system name>` can be left out, in which case it is set to mac-<mac address>.

  ```
  sudo bin/provision.sh "<system name>"
  ```

## Maintenance

(To be added)

  
