package GreeHost::MeshNet::Network;
use Moo;
use GreeHost::MeshNet::Network::Node;
use IPC::Run3;

has name => (
    is      => 'ro',
    default => sub { 'GreeHost MeshNet' },
);

has cidr_block => (
    is      => 'ro',
    default => sub { '192.168.18.1/24' },
);

has _nodes => (
    is => 'ro',
    default => sub { return +{ } },
);

has lighthouses => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_lighthouses',
);

sub _build_lighthouses {
    my ( $self ) = @_;

    my @lighthouses;
    foreach my $hostname ( keys %{$self->_nodes} ) {
        next unless $self->_nodes->{$hostname}->is_lighthouse;
        push @lighthouses, $self->_nodes->{$hostname};
    }
    return [ @lighthouses ];
}


# TODO: ::Node cannot call network and get a copyt of this object.  It should.
# ALSO: This class needs a functyion, lighthouse_routes that iterates nodes and finds
#       all the lighthouse ones to fill in the nodes.

sub add_node {
    my ( $self, $node ) = @_;

    # Verify Things
    
    # Add The Node
    # TODO: The node should automatically get this network, update caller in 
    #       GreeHost::MeshNet before changing.
    $self->_nodes->{$node->{domain}} = GreeHost::MeshNet::Network::Node->new( $node );
}

sub install_nebula {
    return unless ! -d 'bin';

    run3( [qw( curl -LO https://github.com/slackhq/nebula/releases/download/v1.2.0/nebula-linux-amd64.tar.gz )] );
    mkdir 'bin';
    run3( [qw( tar -xzf nebula-linux-amd64.tar.gz -C bin )] );
    unlink 'nebula-linux-amd64.tar.gz';
}

sub install_nebula_cert_authority {
    my ( $self ) = @_;
    return unless ! -d 'certs';
    mkdir 'certs';
    run3([qw( ./bin/nebula-cert ca -out-crt certs/ca.crt -out-key certs/ca.key -name ), $self->name ] );
}

1;
