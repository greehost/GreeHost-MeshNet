# ABSTRACT: Configure, and deploy a Nebula mesh network.
package GreeHost::MeshNet;
use Moo;
use GreeHost::MeshNet::Network;

sub new_from_config {
    my ( $class, $config ) = @_;

    my $network = GreeHost::MeshNet->new(
        network => GreeHost::MeshNet::Network->new(%{$config->{config}}),
    );

    foreach my $node ( @{$config->{nodes}} ) {
        $network->network->add_node( { %{ $node || {} }, network => $network->network } );
    }

    return $network->network;
}

has network => (
    is       => 'ro',
    isa      => sub { $_[0]->isa('GreeHost::MeshNet::Network') },
    required => 1,
);


1;
