package TableData::Object::aohos;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use parent 'TableData::Object::Base';

sub new {
    my ($class, $data, $spec) = @_;
    my $self = bless {
        data     => $data,
        spec     => $spec,
    }, $class;
    if ($spec) {
        $self->{cols_by_idx}  = [];
        my $ff = $spec->{fields};
        for (keys %$ff) {
            $self->{cols_by_idx}[ $ff->{$_}{pos} ] = $_;
        }
        $self->{cols_by_name} = {
            map { $_ => $ff->{$_}{pos} }
                keys %$ff
        };
    } else {
        my %cols;
        for my $row (@$data) {
            $cols{$_}++ for keys %$row;
        }
        my $i = 0;
        $self->{cols_by_name} = {};
        $self->{cols_by_idx}  = [];
        for my $k (sort keys %cols) {
            $self->{cols_by_name}{$k} = $i;
            $self->{cols_by_idx}[$i] = $k;
            $i++;
        }
    }
    $self;
}

sub row_count {
    my $self = shift;
    scalar @{ $self->{data} };
}

sub rows_as_aoaos {
    my $self = shift;
    my $data = $self->{data};

    my $cols = $self->{cols_by_idx};
    my $rows = [];
    for my $hos (@{$self->{data}}) {
        my $row = [];
        for my $i (0..$#{$cols}) {
            $row->[$i] = $hos->{$cols->[$i]};
        }
        push @$rows, $row;
    }
    $rows;
}

sub rows_as_aohos {
    my $self = shift;
    $self->{data};
}

sub const_col_names {
    my $self = shift;

    my $res = [];
  COL:
    for my $col (sort keys %{$self->{cols_by_name}}) {
        my $i = -1;
        my $val;
        for my $row (@{$self->{data}}) {
            next COL unless exists $row->{$col};
            $i++;
            if ($i == 0) {
                $val = $row->{$col};
            } else {
                next COL unless
                    (!defined($val) && !defined($row->{$col})) ||
                    ( defined($val) &&  defined($row->{$col}) && $val eq $row->{$col});
            }
        }
        push @$res, $col;
    }
    $res;
}

1;
# ABSTRACT: Manipulate array of hashes-of-scalars via table object

=for Pod::Coverage .+

=head1 SYNOPSIS

To create:

 use TableData::Object qw(table);

 my $td = table([{foo=>10, bar=>10}, {bar=>20, baz=>20}]);

or:

 use TableData::Object::aohos;

 my $td = TableData::Object::aohos->new([{foo=>10, bar=>10}, {bar=>20, baz=>20}]);

To manipulate:

 $td->cols_by_name; # {foo=>0, bar=>1, baz=>2}
 $td->cols_by_idx;  # ['foo', 'bar', 'baz']


=head1 DESCRIPTION

This class lets you manipulate an array of hashes-of-scalars as a table object.
The table will have columns from all the hashes' keys.


=head1 METHODS

See L<TableData::Object::Base>. Additional methods include:

=head2 const_col_names => arrayref

Return names of columns that exist in all hashes with the same value. Example:

 # data: [{a=>1, b=>2}, {a=>2, b=>2, c=>3}, {a=>1, b=>2, c=>3}]
 $td->const_col_names; # ['b'], 'a' has a different value in 2nd hash, 'c' doesn't exist in all hashes
