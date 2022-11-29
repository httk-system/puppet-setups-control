# Bootstrap your own puppet-control repository from puppet-setups-control

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

## Bootstrap your own puppet-control repository

1. Fork this repository into a private repository for your organization and name it "puppet-control".

2. Clone it into your initial control center machine, e.g., into `~/Puppet`.
   ```
   mkdir ~/Puppet
   cd ~/Puppet
   git clone --recurse-submodules <your git repo remote>
   cd <your git repo name>
   ```

3. Setup a connection to upstream so you can merge updates from this template repository
   ```
   git remote set upstream https://github.com/httk-system/puppet-setups-control.git
   ```

4. Edit README.md to fit your own control repository.

5. Handle the security configuration.

   - Copy all `authorized_keys_*.<control username>` files for all system administrators into the `security` directory.

   - Merge all system administratos `trusted_keys.asc` into a single file and place it into the `security` directory.

6. Execute the contol center setup config:
   ```
   sudo puppet apply modules/upstream-setups/manifests/provision_control_center.pp --modulepath modules/external:modules/upstream-setups:modules/upstream-modules
   ```
   
7. Create on your git host (e.g., GitHub) a repository `puppet-setups` for your local setup functions (recommended to be private) and a repository `puppet-modules` (can probably be public) as a repository where to keep your own modules while you develop them.

8. Add your own repositories as git submodules to the module directory:
   ```
   cd modules
   git submodule add <url> local-setups
   git submodule add <url> local-modules
   ```

9. A small example infrastructure configuration is provided in `hiera/common.yaml`.
   This is primary file to edit to create your configuration.

10. Modify the dependency modules to include the external repositories you need.

11. Commit the changes with a signature (important!):
    ```
    git commit -S
    ```

12. Push your signed changes to the repository back to your remote.
    ```
    git push
    ```

To provision your first managed system, now jump to [docs/PROVISION.md](PROVISION.md)
