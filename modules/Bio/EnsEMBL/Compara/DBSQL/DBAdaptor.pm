#
# BioPerl module for DBSQL::Obj
#
# Cared for by Ewan Birney <birney@sanger.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
        -user   => 'root',
        -dbname => 'pog',
        -host   => 'caldy',
        -driver => 'mysql',
        );


=head1 DESCRIPTION

This object represents the handle for a comparative DNA alignment database

=head1 CONTACT

Post questions the the EnsEMBL developer list: <ensembl-dev@ebi.ac.uk>

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

@ISA = qw( Bio::EnsEMBL::DBSQL::DBAdaptor );



=head2 new

  Arg [..]   : list of named arguments.  See Bio::EnsEMBL::DBConnection.
               [-CONF_FILE] optional name of a file containing configuration
               information for comparas genome databases.  If databases are
               not added in this way, then they should be added via the
               method add_DBAdaptor. An example of the conf file can be found
               in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example
  Example    :  $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
						    -user   => 'root',
						    -dbname => 'pog',
						    -host   => 'caldy',
						    -driver => 'mysql',
                                                    -conf_file => 'conf.pl');
  Description: Creates a new instance of a DBAdaptor for the compara database.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
  Exceptions : none
  Caller     : general

=cut

sub new {
  my ($class, @args) = @_;

  #call superclass constructor; this may actually return a container
  my $container = $class->SUPER::new(@args);

  my $self;
  if($container->isa('Bio::EnsEMBL::Container')) {
    $self = $container->_obj;
  } else {
    $self = $container;
  }

  my ($conf_file) = rearrange(['CONF_FILE'], @args);
#  my ($conf_file) = $self->_rearrange(['CONF_FILE'], @args);

  $self->{'genomes'} = {};

  if(defined($conf_file) and $conf_file ne "") {
    #read configuration file from disk
    my @conf = @{do $conf_file};

    foreach my $genome (@conf) {
      my ($species, $assembly, $db_hash) = @$genome;
      my $db;

      my $module = $db_hash->{'module'};
      my $mod = $module;

      eval {
	# require needs /'s rather than colons
	if ( $mod =~ /::/ ) {
	  $mod =~ s/::/\//g;
	}
	require "${mod}.pm";

	$db = $module->new(-dbname => $db_hash->{'dbname'},
			   -host   => $db_hash->{'host'},
			   -user   => $db_hash->{'user'},
			   -pass   => $db_hash->{'pass'},
			   -port   => $db_hash->{'port'},
			   -driver => $db_hash->{'driver'});
      };
      $db->disconnect_when_inactive(0);

      if($@) {
        $self->throw("could not load module specified in configuration file:$@");
      }

      unless($db && ref $db && $db->isa('Bio::EnsEMBL::DBSQL::DBConnection')) {
        $self->throw("[$db] specified in conf file is not a " .
             "Bio::EnsEMBL::DBSQL::DBConnection");
      }

      #compara should hold onto the actual container objects
      #if($db->isa('Bio::EnsEMBL::DBSQL::Container')) {
      #	$db = $db->_obj;
      #      }

      $self->{'genomes'}->{"$species:".uc($assembly)} = $db;
    }
  }

  #we want to return the container not the contained object
  return $container;
}



=head2 add_db_adaptor

  Arg [1]    : Bio::EnsEMBL::DBSQL::DBConnection
  Example    : $compara_db->add_db_adaptor($homo_sapiens_db);
  Description: Adds a genome-containing database to compara.  This database
               can be used by compara to obtain sequence for a genome on
               on which comparative analysis has been performed.  The database
               adaptor argument must define the get_MetaContainer argument
               so that species name and assembly type information can be
               extracted from the database.
  Returntype : none
  Exceptions : Thrown if the argument is not a Bio::EnsEMBL::DBConnection
               or if the argument does not implement a get_MetaContainer
               method.
  Caller     : general

=cut

sub add_db_adaptor {
  my ($self, $dba) = @_;

  unless($dba && ref $dba && $dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor')) {
    $self->throw("dba argument must be a Bio::EnsEMBL::DBSQL::DBAdaptor\n" .
		 "not a [$dba]");
  }

  #compara should hold onto the actual container objects...
  #  if($dba->isa('Bio::EnsEMBL::Container')) {
  #    $dba = $dba->_obj;
  #  }
  $dba->db->disconnect_when_inactive(0);
  my $mc = $dba->get_MetaContainer;
  my $csa = $dba->get_CoordSystemAdaptor;
  
  my $species = $mc->get_Species->binomial;
  my ($cs) = @{$csa->fetch_all};
  my $assembly = $cs ? $cs->version : '';

  #warn "ADDING GENOME DB $species $assembly $dba";
  $self->{'genomes'}->{"$species:".uc($assembly) } = $dba;
}



=head2 get_db_adaptor

  Arg [1]    : string $species
               the name of the species to obtain a genome DBAdaptor for.
  Arg [2]    : string $assembly
               the name of the assembly to obtain a genome DBAdaptor for.
  Example    : $hs_db = $db->get_db_adaptor('Homo sapiens','NCBI_30');
  Description: Obtains a DBAdaptor for the requested genome if it has been
               specified in the configuration file passed into this objects
               constructor, or subsequently added using the add_db_adaptor
               method.  If the DBAdaptor is not available (i.e. has not
               been specified by one of the abbove methods) undef is returned.
  Returntype : Bio::EnsEMBL::DBSQL::DBConnection
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::GenomeDBAdaptor

=cut

sub get_db_adaptor {
  my ($self, $species, $assembly) = @_;

  unless($species && $assembly) {
    $self->throw("species and assembly arguments are required\n");
  }

  return $self->{'genomes'}->{"$species:".uc($assembly)};
}






sub deleteObj {
  my $self = shift;

  if($self->{'genomes'}) {
    foreach my $db (keys %{$self->{'genomes'}}) {
      delete $self->{'genomes'}->{$db};
    }
  }

  $self->SUPER::deleteObj;
}

1;

