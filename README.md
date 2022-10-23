# puppet-setups

A puppet-control-type repository for managing a software infrastructure using the "setups" paradigm.

The main repository is at: https://github.com/httk-system/puppet-setups-control

## Preface

Puppet is a software configuration management tool maintained by the company [Puppet, Inc.](https://puppet.com).
The tool uses a declarative language to specify the configuration of installed software accross a computer infrastructure comprised by *nodes* (which essentially is a more general term for "computer" which also covers, e.g., containers and virtualized systems).
The Puppet language allow many different ways of organizing the declarative configuration manifests.
One should seek a design that allows for a good overview of the nodes being managed, as well as allows for meaningful abstraction and reuse of configuration manifests.

A defacto standard, the *roles and profiles* method, has emerged for organizing puppet manufests to describe the configuration of more complex computer infrastructures.
This method is well documented both in the docs by [Puppet, inc.](https://puppet.com/docs/puppet/6/the_roles_and_profiles_method.html) and widely in various third-party tutorials and guides, e.g., [the Puppet enterprise guide](https://puppet-enterprise-guide.com/theory/roles-and-profiles-overview.html).
In the typical application of *roles and profiles*, an organization of three levels is prescribed.
A *node* is assigned one (and only one) role, which then specifies a set of *profiles* (which can be shared between multiple roles).
The profiles are built up by a set of modules that typically handles the configuration of a specific software.
For example, one may have *main webserver* and *backup webserver* roles, which both invoke the same *webserver* profile, which defers the details of the Apache web server configuration to an *apache* module.

Hence, in the *roles and profiles* scheme, the infrastructure configuration is planned with a "per-node" perspective.
This is analogous with how we often think of individual computers as file servers, web servers, etc.
Nevertheless, for software where the configuration spans multiple nodes, the "per-node" organization sometime appear less natural.

The present repository represents an opininated alternative method, *setups*.
The main idea is to use software technologies (possibly spanning many nodes) as the outermost level when planning an infrastructure configuration, e.g., "big data analytics cluster", "load balancing web server farm", and "fileserver farm".
The configuration of these technologies include various parameters to control their behavior and the assigment of "roles" to specific nodes.
For example, the configuration of an hadoop big data anlytics cluster would specify that the *hadoop name server* role is assigned to node "n4711", the *hadoop backup name server* role is assinged to node "n42" and the spark history server role is also assigned to node "n4711".

In practice, in the *setup* configuration method we declare Puppet functions called `setup_<technology>` that takes a single hash argument `config`.
Using Heira we declare separately global configuation parameters, a list of *systems* (here used with the same meaning as nodes), and a *setup* hierarchy that describe the infrastructure setup.

The present repository provides a practical implementation for recent Ubuntu systems. It is organized as follows:
- `bin` - some useful tools
- `hiera` - the hiera configuration
- `manifests` - the primary puppet manifests
- `modules` - modules that the repository depends on
- `securiry` - security-related data files

## Before you start

The infrastructure consists of managed machines and one or more *control centers*.
A control center should be a machine where you (or other system administratos) are physically present at to perform system administration tasks.
(A machine can be both managed and a control center.)

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

## Security infrastructure with gpg keys or yubikeys

Before we start, we need to prepare the security infrastructure.
It is completely centered on cryptograhic signatures handled by gpg.

Obviously, this makes the security of your cryptograhic keys extremely important.
Hence, it is highly recommended to invest in at least three [yubikeys](https://www.yubico.com/se/store/).
These devices are hardware tokens that, when correctly setup and used, makes sure no one will be able to obtain a copy of your secret keys without you knowing. 
I am not affiliated with Yubico, but the cost of these devices is highly motivated for the extra security it brings to managing your infrastructure.

The motivation for getting three keys is a golden rule in software and hardware management: never plan to place yourself in a position where there is a single hardware failure between you and a disasterous conseuqence.
In our case, one day one of our keys will have to be replaced (e.g., due to breaking or missing).
If we only have two keys and one is gone, we are in a situation where, if the remaining key also fails, we are loced out of our infrastructure. 
(If there is more than one system administrator, the requirement translates to a minimum of three keys in *total*, not per person. However, it is probably a good idea to provide two keys per administrator, since otherwise each key failure means a person is blocked from work until the replacement key is in place.)

## Setting up your yubikeys (if you do not have yubikeys, skip to next section)

For each yubikey you have, do steps 1-7:

1. Insert the yubikey and make sure gpg has access to it
   ```
   gpg --card-status
   ```
   You should see a dump of info about your yubikey here.
   If you do not, a few things you can try are:
   (i) re-insert the yubikey;
   (ii) kill the gpg-agent process;
   (iii) `systemctl restart pcscd`.

2. Secure the PINs and settings for the apps we will use.

   Note: *the default pin is 123456* and *the default puk is 123456768*.
   ```
   gpg --change-admin-pin
   gpg --change-pin
   yubico-piv-tool -a change-puk
   yubico-piv-tool -a change-pin
   ykman openpgp keys set-touch aut on
   ykman openpgp keys set-touch sig on
   ykman openpgp keys set-touch enc on
   ```

3. Create gpg keys on the device itself.
   (Note: I highly recommend *against* advice in other tutorials to generate the keys outside of the yubikey and then store them on the device.
   In my opinion, this leads to a significantly reduced overall security in your setup to allow the crytographic keys to exist outside of the hardware protection provided by the yubikey).
   ```
   gpg --edit-card
   ```
   In the promt that appear, write `admin`, `key-attr` and select "ECC" and "Curve 25519" for all three types of keys. Then generate keys with `generate`.
   Set expiry to 1 year.

4. Get the key id for the key you just generated:
   ```
   KEYID=$(gpg --card-status --with-colons | grep "^fpr:" | awk -F: '{print $2}')
   ```

5. Somewhere reasonably safe (and backed up),
   create a subdirectory for this specific yubikey and store
   a revokation certificate and the gpg and ssh-formatted
   versions of the public key:
   ```
   mkdir <yubikey id>
   cd <yubikey id>

   gpg --output yubikey-revoke.asc --gen-revoke "$KEYID"

   gpg --armor --export "$KEYID" > yubikey-public-gpg.asc
   gpg --export-ssh-key "$KEYID" > yubikey-public-ssh.pub
   ```

6. We also want to create two special ssh authentication piv keys.
   These keys will be setup to only require pin once per session and
   no touch, which makes them less secure, since a rogue process
   running on your machine could invoke their use unlimited.
   However, we will use these keys to identify us over ssh to
   be able to run commands on all managed systems and having to
   touch the yubikey for each such connection would be cumbersome.
   Hence, we will set things up so that the actions these key
   can peform are very limited.

   We will use slot 94 and 95 for this, which are the last of the
   "retired key management" slots.
   ```
   yubico-piv-tool -s 95 -A ECCP256 -a generate -o piv95-public.pem --pin-policy=once --touch-policy=never
   yubico-piv-tool -a verify-pin -a selfsign-certificate -s 95 -S "/CN=SSH key slot 95/" -i piv95-public.pem -o piv95-cert.pem
   yubico-piv-tool -a import-certificate -s 95 -i piv95-cert.pem

   yubico-piv-tool -s 94 -A ECCP256 -a generate -o piv94-public.pem --pin-policy=once --touch-policy=never
   yubico-piv-tool -a verify-pin -a selfsign-certificate -s 94 -S "/CN=SSH key slot 94/" -i piv94-public.pem -o piv94-cert.pem
   yubico-piv-tool -a import-certificate -s 94 -i piv94-cert.pem
   ```

7. Export the piv keys in ssh format
   ```
   ssh-keygen -D libykcs11.so -e | grep "Public key for Retired Key 20" > yubikey-public-ssh-piv95.pub
   ssh-keygen -D libykcs11.so -e | grep "Public key for Retired Key 19" > yubikey-public-ssh-piv94.pub
   ```
   
8. Repeat steps 1-7 for all yubikeys you have to set up.
   When finished, make sure your current working directory have all key directories as subdirectories.

9. Create files that collect all these public ssh keys, per user:
   ```
   cat */yubikey-public-ssh.pub > authorized_keys.<control username>
   cat */yubikey-public-ssh-piv95.pub | awk '{print "command=\"/usr/control/puppet-apply\"",$0}' > authorized_keys_apply.<control username>
   cat */yubikey-public-ssh-piv94.pub | awk '{print "command=\"/usr/control/system-update"}' > authorized_keys_update.<control username>
   ```

10. Create a file that collect all the gpg signature keys:
    ```
    cat */yubikey-public-gpg.asc > trusted_keys.asc
    ```

## Setting up gnupg keys (skip if using yubikeys)

(To be added)

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

  