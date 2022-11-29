# Organization of the puppet-setups-control repository

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
