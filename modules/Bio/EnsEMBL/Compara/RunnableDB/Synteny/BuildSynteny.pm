=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Synteny::BuildSynteny

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This module runs the java program BuildSynteny.jar. This can fail if the input file is already sorted on position. If such a failure is detected, the input will be sorted on a different field in an attempt to sufficiently un-sort it and the command is automatically rerun.

Supported keys:
      'program' => <path>
         Path to executable

      'gff_file' => <path>
          Location of input gff file

      'maxDist1' => <number>
          Maximum gap allowed between alignments within a syntenic block

      'minSize1' => <number>
          Minimum length a syntenic block must have, shorter blocks are discarded

      'maxDist2' => <number>
          Maximum gap allowed between alignments within a syntenic block for second genome. Only maxDist1 needs to be defined if maxDist1 equals maxDist2

      'minSize2' => <number>
          Minimum length a syntenic block must have, shorter blocks are discarded for the second genome. Only minSize1 needs to be defined in minSize1 equals minSize2

      'orient' => <false>
           "false" is only needed for human/mouse, human/rat and mouse/rat NOT for elegans/briggsae (it can be ommitted).

      'output_file' => <path>
           output file

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Synteny::BuildSynteny;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::RunCommand', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;
  return 1;
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my( $self) = @_;

  my $cmd = _create_cmd($self->param('program'), $self->param('gff_file'), $self->param('maxDist1'), $self->param('minSize1'), $self->param('maxDist2'), $self->param('minSize2'), $self->param('orient'), $self->param('output_file'));

  my $command = $self->run_command($cmd);

  #Check error output 
  if ($command->err =~ /QuickSort/) {

      #Need to re-sort gff_file and rerun
      my $gff_file = $self->param('gff_file');
      my $gff_sort = $gff_file . ".sort";
      `sort -n -k 6,6 $gff_file > $gff_sort`;

      $self->warning("Needed to sort $gff_file");
      my $sort_cmd =  _create_cmd($self->param('program'), $gff_sort, $self->param('maxDist1'), $self->param('minSize1'), $self->param('maxDist2'), $self->param('minSize2'), $self->param('orient'), $self->param('output_file'));
      my $command = $self->run_command($sort_cmd);

      #recheck err file
      if ($command->err) {
          die "Error even after sorting gff_file";
      }
  }

  return 1;
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut

sub write_output {
  my( $self) = @_;
  return 1;
}

sub _create_cmd {
    my ($program, $gff_file, $maxDist1, $minSize1, $maxDist2, $minSize2, $orient, $output_file) = @_;

    my $cmd = $program;
    $cmd .= " $gff_file";
    $cmd .= " $maxDist1";
    $cmd .= " $minSize1";
    $cmd .= " $maxDist2" if (defined $maxDist2);
    $cmd .= " $minSize2" if (defined $minSize2);
    $cmd .= " $orient";
    $cmd .= " > $output_file";

    return $cmd;
}

1;

