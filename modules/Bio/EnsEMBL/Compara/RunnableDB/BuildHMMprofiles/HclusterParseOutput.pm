=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HclusterParseOutput;

=head1 DESCRIPTION

RunnableDB that parses the output of Hcluster

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut
package Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HclusterParseOutput;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub param_defaults {
    return {
            'sort_clusters'         => 1,
            'immediate_dataflow'    => 1,
            'member_type'           => 'protein',
    };
}

sub run {
    my $self = shift @_;
    
    $self->parse_hclusteroutput;
}

sub write_output {
    my $self = shift @_;
}

####################
# internal methods
####################
sub parse_hclusteroutput {
    my $self = shift;

    $self->throw('cluster_dir is an obligatory parameter') unless (defined $self->param('cluster_dir'));
    my $filename            = $self->param('cluster_dir') . '/hcluster.out';
    my $hcluster_parse_file = $self->param('cluster_dir') . '/hcluster_parse.out'; 
    
    open(FILE_2, ">$hcluster_parse_file") or die "Could not open '$hcluster_parse_file' for writing : $!";
    print FILE_2 "cluster_id\tgenes_count\tcluster_list\n";   
 
    open(FILE, $filename) or die "Could not open '$filename' for reading : $!";
    while (<FILE>) {
        # 0       0       0       1.000   2       1       697136_68,
        # 1       0       39      1.000   3       5       1213317_31,1135561_22,288182_42,426893_62,941130_38,
        chomp $_;
        my ($cluster_id, $dummy1, $dummy2, $dummy3, $dummy4, $cluster_size, $cluster_list) = split("\t",$_);
        next if ($cluster_size < 2);
        $cluster_list =~ s/\,$//;
        $cluster_list =~ s/_[0-9]*//g;
        my @cluster_list = split(",", $cluster_list);
	my $genes_count  = scalar(@cluster_list);
	print FILE_2 "$cluster_id\t$genes_count\t$cluster_list\n";
    }
    close FILE;
    close FILE_2;
}

1;