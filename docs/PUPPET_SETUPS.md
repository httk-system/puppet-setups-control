# The puppet-setups method

## Puppet

Puppet is a software configuration management tool maintained by the company [Puppet, Inc.](https://puppet.com).
The tool uses a declarative language in *puppet manifests* expressed in *puppet modules* to specify the configuration of software accross a computing infrastructure comprised by *nodes* (essentially a more general term for "computer" that covers, e.g., containers and virtualized systems).

## The *roles and profiles* method

Puppet modules can be organized and abstracted in many different ways.
The current standard way is known as the *roles and profiles* method.
It is well documented both in the [puppet documentation](https://puppet.com/docs/puppet/6/the_roles_and_profiles_method.html) and broadly in various third-party tutorials and guides, e.g., [the Puppet enterprise guide](https://puppet-enterprise-guide.com/theory/roles-and-profiles-overview.html).

The typical application of *roles and profiles* prescribes an organization of three levels.
A node managed by puppet is assigned one (and only one) *role*, which is comprised by a set of *profiles*.
The profiles are in turn built up by puppet modules that are typically very oriented towards a specific software.
For example, one may have *main webserver* and *backup webserver* roles which invoke the same *webserver* profile; which then uses the *apache* puppet module for the specific management the configuration of the Apache web server software.
Hence, the *roles and profiles* model specify configuration in a "per-node" perspective, in analog to how we tend to think of computers in a computing infrastructure as file servers, web servers, etc.

## The *puppet-setups* method

In contrast to the *roles and profiles* method, the *puppet-setups* model uses as its highest level concept a *setup*, representing a complete software technology (that can possibly span many nodes).
A list of the *setups* invoked in a computing infrastructure is declared in a Hiera *setup hierarchy*.
The *setup hierarchy* specifies (i) the general parameters for the specific instance of the technology being configured; (ii) each node that participate in this *setup* with its respective *setup role* and role-specific parameters.

When puppet applies the configuration, the *setup hierarchy* is traversed and for each *setup* for each participating node, a puppet function on the format `setup_<setup name>::<role name>($config)` is called.
Hence, a *setup module* is a puppet module that provide a namespaced puppet function for each *setup role*.
The *setup role* function invokes regular *puppet modules* to manage specific software.
For example, one may have *setups* for, e.g., *big data analytics cluster*, *load balancing web server farm*, and *fileserver*.
In this example, the *big data analytics cluster* part of the Hiera *setup hierarchy* may specify that the *hadoop name server* role is assigned to node "n4711", the *hadoop backup name server* role is assinged to node "n4712" and the spark history server role is also assigned to node "n4711".
