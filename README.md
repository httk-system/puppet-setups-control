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

For more information on the organization of this repository see [docs/ORGANIZATION.md](docs/ORGANIZATION.md).

For information on how to bootstrap your own puppet-control repository from this repository, see [docs/SETUP.md](docs/SETUP.md).

For information on how to manually provision a new system, see [docs/PROVISION.md](docs/PROVISION.md).
