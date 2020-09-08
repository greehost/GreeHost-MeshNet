# GreeHost::MeshNet

## GreeHost-Origin

`greehost-origin` initializes the manager server and creates the `greehost-network.json` configuration file that `GreeHost::MeshNet` requires.

The script is written with the expectation that it will be forked, modified, and then run on a minimal install of CentOS 7.

Specifically, the structure `$network` must be modified to match the actual network that is being configured.  The block of `system()` calls under `init-system` should be modified to run commands you want to run when `init-system` is used to configure the manager server.

Once initialized, the manager server is expected to have GreeHost::MeshNet installed and have the `/opt/greehost/meshnet/greehost-network.json` file written out.

### Commands

`perl greehost-origin init-system YourHostname` will run through all of the `system()` calls invoked in `init-system` and is intended to be used to bootstrap the manager server.

`perl greehost-origin write-config` will write or overwrite `greehost-network.json` in the current working directory.

### $network Structure

The `$network` structure has a couple of jobs to do:

1. Define each node in the network, and metadata about that node including:
    1. Domain name
    2. IP Address for Nebula
    3. SSH connection information for remote configuration/deployment
    4. Various meta data for Nebula configuration (lighthouse/public address)
    5. Commands for remote bootstrapping
    6. Commands to run after deploying Nebula configuration to a node
2. Define global configuration like:
    1. The network name for the CA
    2. Defaults for SSH options used by the nodes
    3. Defaults for remote bootstrapping and post-deployment commands.


```perl
my @ssh_opts = ( '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null' );
my $network = {
    config => {
        name               => 'GreeHost Network',
        ssh_opts           => [ @ssh_opts ],
        post_deploy_script => [
            [ 'remote',
                [qw(service nebula start)],
                [qw(sleep 3)],
                [qw(firewall-cmd --permanent --zone=internal --add-interface=nebula1)],
                [qw(firewall-cmd --zone=internal --add-interface=nebula1)],
                [qw(firewall-cmd --permanent --zone=internal --add-port=22/tcp)],
                [qw(firewall-cmd  --zone=internal --add-port=22/tcp)],
                [qw(service sshd restart)],

            ],
        ],
        remote_init_script => [
            [ 'local',
                ['scp', @ssh_opts, 'GreeHost-MeshNet-0.001.tar.gz', '[% deploy_address %]' . ":" ],
            ], [ 'remote',
                [qw(hostnamectl set-hostname), '[% domain %]' ],
                [qw(yum -y install epel-release)],
                [qw(yum -y update)],
                [qw(yum -y upgrade)],
                [qw(yum install -y yum-utils perl-App-cpanminus perl-core rsync)],
                [qw(yum groupinstall -y), "Development Tools"],
                [qw(cpanm install GreeHost-MeshNet-0.001.tar.gz)],
                [qw(mkdir /etc/nebula )],
            ],
        ],
    },
    nodes => [
        {
            domain         => "mn.greehost.com",
            address        => "192.168.18.1",
            deploy_address => 'root@104.237.159.204',
            is_lighthouse  => "1",
            public_address => "104.237.159.204",
            post_deploy_script_append => [
                [ 'remote',
                    [qw(firewall-cmd --permanent --zone=public --add-port=4242/udp)],
                    [qw(firewall-cmd --zone=public --add-port=4242/udp)],
                ],
            ],
        }, {
            domain         => "manager.mn.greehost.com",
            address        => "192.168.18.4",
            deploy_address => 'root@192.168.87.22',
            is_lighthouse  => "0",
        },
    ],
};
```

#### Node Options

| Name                      | Description                                                      |
|---------------------------|------------------------------------------------------------------|
| domain                    | Domain name, used for Nebula cert, and remote configuration      |
| address                   | Nebula IP address, encoded into the Nebula cert                  |
| deploy_address            | SSH connection string for greehost-meshnet --deploy and --remote |
| is_lighthouse             | Boolean, when true this node will be a Nebula lighthouse         |
| public_address            | Public IP for Nebula Lighthouse (used in nebula config files)    |
| post_deploy_script_append | Run these commands after --deploy                                |

#### Config Options

| Name               | Description                                                |
|--------------------|------------------------------------------------------------|
| name               | Network name, used for the Nebula CA                       |
| ssh_opts           | SSH Options to use for connecting to nodes on this network |
| post_deploy_script | A script to run after --deploy on all nodes by default     |
| remote_init_script | A script to run for --remote_init for all nodes by default |


#### Script Syntax

The syntax for a script is `[ 'tag', [ @command ], [ @command ], ... ]`

| Tag    | Description                               |
|--------|-------------------------------------------|
| local  | Run commands locally with run3()          |
| remote | Run commands on the remote server via ssh |


