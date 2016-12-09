=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::LoadMembersFromFiles

=head1 DESCRIPTION

This Runnable loads one entry into 'genome_db' table and passes on the genome_db_id.

The format of the input_id follows the format of a Perl hash reference.
Examples:
    { 'species_name' => 'Homo sapiens', 'assembly_name' => 'GRCh37' }
    { 'species_name' => 'Mus musculus' }

supported keys:
    'locator'       => <string>
        one of the ways to specify the connection parameters to the core database (overrides 'species_name' and 'assembly_name')

    'species_name'  => <string>
        mandatory, but what would you expect?

    'assembly_name' => <string>
        optional: in most cases it should be possible to find the species just by using 'species_name'

    'genome_db_id'  => <integer>
        optional, in case you want to specify it (otherwise it will be generated by the adaptor when storing)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadMembersFromFiles;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::SeqMember;
use Bio::EnsEMBL::Compara::GeneMember;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults()},
        'need_cds_seq'  => 0,
    }
}

sub fetch_input {
	my $self = shift @_;

	# Loads the genome
      $self->param('genome_db', $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($self->param('genome_db_id')));
      $self->param('genome_content', $self->param('genome_db')->db_adaptor);

}

sub write_output {
	my $self = shift @_;

	my $genome_db_id = $self->param('genome_db_id');
	
      my $compara_dba = $self->compara_dba();
      my $sequence_adaptor = $compara_dba->get_SequenceAdaptor();
      my $gene_member_adaptor = $compara_dba->get_GeneMemberAdaptor();
      my $seq_member_adaptor = $compara_dba->get_SeqMemberAdaptor();

      print Dumper($self->param('genome_content')) if $self->debug;
      my ($prot_seq,$cds_seq) = $self->param('genome_content')->get_sequences;

      my $prot_count = keys(%{$prot_seq});
      my $cds_count  = keys(%{$cds_seq});

      print "PROT:$prot_count\tCDS:$cds_count\n";

      my ($gene_coordinates,$cds_coordinates) = $self->param('genome_content')->get_coordinates();

      my $taxon_id = $self->param('genome_content')->get_taxonomy_id;

      my %cached_dnafrags = ();

	  my $count = 0;

      foreach my $prot_id (keys %$prot_seq) {

		$count++;
        my $sequence = $prot_seq->{$prot_id}->{'seq_obj'};
        my $display_name = $prot_seq->{$prot_id}->{'display_name'};

		print "sequence $count: name ", $prot_id, "\n" if ($self->debug > 1);
		print "sequence $count: description ", $sequence->desc, "\n" if ($self->debug > 1);
		print "sequence $count: length ", $sequence->length, "\n" if ($self->debug > 1);

		my $gene_member = Bio::EnsEMBL::Compara::GeneMember->new(
                -stable_id      => $prot_id,
                -source_name    => 'EXTERNALGENE',
                -taxon_id       => $taxon_id,
                -description    => $sequence->desc,
                -genome_db_id   => $genome_db_id,
            );

		$gene_member->display_label($display_name);
            if (exists $gene_coordinates->{$prot_id}) {
               my $coord = $gene_coordinates->{$prot_id};
                if (not $cached_dnafrags{$coord->[0]}) {
                    $cached_dnafrags{$coord->[0]} = Bio::EnsEMBL::Compara::DnaFrag->new(-GENOME_DB => $self->param('genome_db'), -NAME => $coord->[0]);
                    my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();
		            $dnafrag_adaptor->store($cached_dnafrags{$coord->[0]}) || die "Could not store dnafrags";
                }
                $gene_member->dnafrag($cached_dnafrags{$coord->[0]});
                $gene_member->dnafrag_start($coord->[1]);
                $gene_member->dnafrag_end($coord->[2]);
                $gene_member->dnafrag_strand($coord->[3]);
            } else {
                warn $prot_id, " does not have gene coordinates\n";
                die $prot_id, " does not have gene coordinates\n";
            }

		$gene_member_adaptor->store($gene_member);

		my $pep_member = Bio::EnsEMBL::Compara::SeqMember->new(
                -stable_id      => $prot_id,
                -source_name    => 'EXTERNALPEP',
                -taxon_id       => $taxon_id,
                -description    => $sequence->desc,
                -genome_db_id   => $genome_db_id,
            );
		$pep_member->display_label($prot_id);
            $pep_member->gene_member_id($gene_member->dbID);
            if (exists $cds_coordinates->{$prot_id}) {
                my $coord = $cds_coordinates->{$prot_id};
                if (not $cached_dnafrags{$coord->[0]}) {
                    $cached_dnafrags{$coord->[0]} = Bio::EnsEMBL::Compara::DnaFrag->new(-GENOME_DB => $self->param('genome_db'), -NAME => $coord->[0]);
                    my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();
		            $dnafrag_adaptor->store($cached_dnafrags{$coord->[0]}) || die "Could not store dnafrag";
                }
                $pep_member->dnafrag($cached_dnafrags{$coord->[0]});
                $pep_member->dnafrag_start($coord->[1]);
                $pep_member->dnafrag_end($coord->[2]);
                $pep_member->dnafrag_strand($coord->[3]);
            } else {
                warn $prot_id, " does not have cds coordinates\n";
                die $prot_id, " does not have cds coordinates\n";
            }
		my $seq = $sequence->seq;
		$seq =~ s/O/X/g;
		$pep_member->sequence($seq);
		$seq_member_adaptor->store($pep_member);
            $seq_member_adaptor->_set_member_as_canonical($pep_member);

            if (exists $cds_seq->{ $prot_id }) {
                $sequence_adaptor->store_other_sequence($pep_member, $cds_seq->{ $prot_id }->{'seq_obj'}->seq, 'cds');
            } elsif ($self->param('need_cds_seq')) {
                die $prot_id, " does not have cds sequence\n";
            } else {
                warn $prot_id, " does not have cds sequence\n";
            } 
      };

	print "$count genes and peptides loaded\n" if ($self->debug);
}

1;

