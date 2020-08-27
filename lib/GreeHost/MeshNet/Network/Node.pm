package GreeHost::MeshNet::Network::Node;
use Moo;
use Text::Xslate;
use IPC::Run3;
use Object::Remote;

has domain => (
    is => 'ro',
);

has address => (
    is => 'ro',
);

has network => (
    is       => 'ro',
    isa      => sub { $_[0]->isa( 'GreeHost::MeshNet::Network' ) },
    weak_ref => 1,
);

has deploy_address => (
    is => 'ro',
);

has is_lighthouse => (
    is => 'ro',
);

has ssh_opts => (
    is      => 'ro',
    default => sub { 
        return [ '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null' ];
    },
);

has remote_init_commands => (
    is      => 'ro',
    default => sub { [  ] },
);

has post_deploy_script => (
    is      => 'ro',
    default => sub { [  ] },
);

# For lighthouses, their public IPs/domains are required
# TODO: ensure that when is_lighthouse is true, public_address exists.
has public_address => (
    is => 'ro',
);

has groups => (
    is => 'ro',
);

my $default_nebula_config =<<'EOF';
pki:
  ca:   /etc/nebula/ca.crt
  cert: /etc/nebula/[% $node.domain %].crt
  key:  /etc/nebula/[% $node.domain %].key

static_host_map:
%% for $node.network.lighthouses -> $lighthouse_node {
  "[% $lighthouse_node.address %]": ["[% $lighthouse_node.public_address %]:4242"]
%% }

lighthouse:
  am_lighthouse: [% $node.is_lighthouse == 1 ? "true" : "false" %]
  serve_dns: [% $node.is_lighthouse == 1 ? "true" : "false" %]
  interval: 60
  hosts:
%%  if ( $node.is_lighthouse != 1 ) {
%%      for $node.network.lighthouses -> $lighthouse_node {
    - "[% $lighthouse_node.address %]"
%%      }
%%  }

listen:
  host: 0.0.0.0
  port: [% $node.is_lighthouse == 1 ? 4242 : 0 %]

punchy:
  punch: true
  respond: true

tun:
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000

  outbound:
    # Allow all outbound traffic from this node
    - port: any
      proto: any
      host: any

  inbound:
    # Allow icmp between any nebula hosts
    - port: any
      proto: any
      host: any
EOF

has nebula_config => (
    is      => 'ro',
    lazy    => 1,
    builder => sub { return "./certs/" . shift->domain . ".conf"  },
);

sub generate_nebula_config {
    my ( $self ) = @_;

    open my $sf, ">", $self->nebula_config
        or die "Failed to open " . $self->nebula_config . " for writing: $!";
    print $sf Text::Xslate->new( syntax => 'Metakolon' )
        ->render_string( $default_nebula_config, { node => $self } );
    close $sf;
}

has nebula_cert => (
    is      => 'ro',
    isa     => sub { -x $_[0] },
    default => sub { './bin/nebula-cert' },
);

has nebula_ca_cert => (
    is      => 'ro',
    default => sub { './certs/ca.crt' },
);

has nebula_ca_key => (
    is      => 'ro',
    default => sub { './certs/ca.key' },
);

has domain_cert => (
    is      => 'ro',
    lazy    => 1,
    builder => sub { return "./certs/" . shift->domain . ".crt" },
);

has domain_key => (
    is      => 'ro',
    lazy    => 1,
    builder => sub { return "./certs/" . shift->domain . ".key" },
);

sub generate_nebula_certs {
    my ( $self ) = @_;

    my @command = (
        $self->nebula_cert, 'sign',
        '-ca-crt', $self->nebula_ca_cert, '-ca-key', $self->nebula_ca_key,
        '-name', $self->domain, '-ip', $self->address . "/" . (split m|/|, $self->network->cidr_block)[1],
        '-out-crt', $self->domain_cert, '-out-key', $self->domain_key
    );

    run3( [ @command ] );
}

sub deploy {
    my ( $self ) = @_;


    # Move the files over....
    my $ssh_cmd = join( " ", "ssh", @{$self->ssh_opts} );
    run3([ 'rsync', '-e', $ssh_cmd, $self->nebula_ca_cert, $self->deploy_address . ":/etc/nebula/ca.crt" ] );
    run3([ 'rsync', '-e', $ssh_cmd, $self->nebula_config, $self->deploy_address . ":/etc/nebula/config.yml" ] );
    run3([ 'rsync', '-e', $ssh_cmd, $self->domain_cert, $self->deploy_address . ":/etc/nebula/" ] );
    run3([ 'rsync', '-e', $ssh_cmd, $self->domain_key, $self->deploy_address . ":/etc/nebula/" ] );
    
    my $conn = Object::Remote->connect( $self->deploy_address, ssh_options => $self->ssh_opts );
    GreeHost::MeshNet::RPC->can::on( $conn, 'install_nebula' )->();
    GreeHost::MeshNet::RPC->can::on( $conn, 'start_and_enable_nebula_service' )->();
    
    # Code taken from remote_init, consolidate next time.
    for my $block ( @{$self->post_deploy_script} ) {
        my $mode = shift @{$block};

        foreach my $command ( @{$block} ) {
            run3([($mode eq 'remote' ? ( 'ssh', @{$self->ssh_opts}, $self->deploy_address ) : () ), @{$command}]);
        }
    }

}

sub remote_init {
    my ( $self ) = @_;

    for my $block ( @{$self->remote_init_commands} ) {
        my $mode = shift @{$block};

        foreach my $command ( @{$block} ) {
            run3([($mode eq 'remote' ? ( 'ssh', @{$self->ssh_opts}, $self->deploy_address ) : () ), @{$command}]);
        }
    }
}



1;
