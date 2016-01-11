package TableData::Object::Base;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

use Scalar::Util::Numeric qw(isint isfloat);

sub _array_is_numeric {
    my $self = shift;
    for (@{$_[0]}) {
        return 0 if defined($_) && !isint($_) && !isfloat($_);
    }
    return 1;
}

sub _list_is_numeric {
    my $self = shift;
    $self->_array_is_numeric(\@_);
}

sub cols_by_name {
    my $self = shift;
    $self->{cols_by_name};
}

sub cols_by_idx {
    my $self = shift;
    $self->{cols_by_idx};
}

sub col_exists {
    my ($self, $name_or_idx) = @_;
    if ($name_or_idx =~ /\A[0-9][1-9]*\z/) {
        return $name_or_idx <= @{ $self->{cols_by_idx} };
    } else {
        return exists $self->{cols_by_name}{$name_or_idx};
    }
}

sub col_name {
    my ($self, $name_or_idx) = @_;
    if ($name_or_idx =~ /\A[0-9][1-9]*\z/) {
        return $self->{cols_by_idx}[$name_or_idx];
    } else {
        return exists($self->{cols_by_name}{$name_or_idx}) ?
            $name_or_idx : undef;
    }
}

sub col_idx {
    my ($self, $name_or_idx) = @_;
    if ($name_or_idx =~ /\A[0-9][1-9]*\z/) {
        return $name_or_idx < @{ $self->{cols_by_idx} } ? $name_or_idx : undef;
    } else {
        return $self->{cols_by_name}{$name_or_idx};
    }
}

sub col_count {
    my $self = shift;
    scalar @{ $self->{cols_by_idx} };
}

sub _select {
    my ($self, $_as, $cols0, $func_filter_row, $sorts) = @_;

    # determine result's columns & spec
    my $spec;
    my %newcols_to_origcols;
    my @newcols;
    if ($cols0) {
        $spec = {fields=>{}};
        my $i = 0;
        for my $col0 (@$cols0) {
            die "Column '$col0' does not exist" unless $self->col_exists($col0);

            my $col = $col0;
            my $j = 1;
            while (defined $newcols_to_origcols{$col}) {
                $j++;
                $col = "${col0}_$j";
            }
            $newcols_to_origcols{$col} = $col0;
            push @newcols, $col;

            $spec->{fields}{$col} = {
                %{$self->{spec}{fields}{$col0} // {}},
                pos=>$i,
            };
            $i++;
        }
    } else {
        $spec = $self->{spec};
        $cols0 = $self->{cols_by_idx};
        @newcols = @{ $self->{cols_by_idx} };
        for (@newcols) { $newcols_to_origcols{$_} = $_ }
    }

    my $rows = [];

    # filter rows
    for my $row (@{ $self->rows_as_aohos }) {
        next unless !$func_filter_row || $func_filter_row->($self, $row);
        push @$rows, $row;
    }

    # sort rows
    if ($sorts && @$sorts) {
        # determine whether each column mentioned in $sorts is numeric, to
        # decide whether to use <=> or cmp.
        my %col_is_numeric;
        for my $sortcol (@$sorts) {
            my ($reverse, $col) = $sortcol =~ /\A(-?)(.+)/
                or die "Invalid sort column specification '$sortcol'";
            next if defined $col_is_numeric{$col};
            my $sch = $self->{spec}{fields}{$col}{schema};
            if ($sch) {
                require Data::Sah::Util::Type;
                $col_is_numeric{$col} = Data::Sah::Util::Type::is_numeric($sch);
            } else {
                my $col_name = $self->col_name($col);
                defined($col_name) or die "Unknown sort column '$col'";
                $col_is_numeric{$col} = $self->_array_is_numeric(
                    [map {$_->{$col_name}} @$rows]);
            }
        }

        $rows = [sort {
            for my $sortcol (@$sorts) {
                my ($reverse, $col) = $sortcol =~ /\A(-?)(.+)/;
                my $name = $self->col_name($col);
                my $cmp = ($reverse ? -1:1) *
                    ($col_is_numeric{$col} ?
                     ($a->{$name} <=> $b->{$name}) :
                     ($a->{$name} cmp $b->{$name}));
                return $cmp if $cmp;
            }
            0;
        } @$rows];
    } # sort rows

    # select columns & convert back to aoaos if that's the requested form
    {
        my $rows2 = [];
        for my $row0 (@$rows) {
            my $row;
            if ($_as eq 'aoaos') {
                $row = [];
                for my $i (0..$#{$cols0}) {
                    $row->[$i] = $row0->{$cols0->[$i]};
                }
            } else {
                $row = {};
                for my $i (0..$#newcols) {
                    $row->{$newcols[$i]} =
                        $row0->{$newcols_to_origcols{$newcols[$i]}};
                }
            }
            push @$rows2, $row;
        }
        $rows = $rows2;
    }

    # return result as object
    if ($_as eq 'aoaos') {
        require TableData::Object::aoaos;
        return TableData::Object::aoaos->new($rows, $spec);
    } else {
        require TableData::Object::aohos;
        return TableData::Object::aohos->new($rows, $spec);
    }
}

sub select_as_aoaos {
    my ($self, $cols, $func_filter_row, $sorts) = @_;
    $self->_select('aoaos', $cols, $func_filter_row, $sorts);
}

sub select_as_aohos {
    my ($self, $cols, $func_filter_row, $sorts) = @_;
    $self->_select('aohos', $cols, $func_filter_row, $sorts);
}

sub uniq_col_names { die "Must be implemented by subclass" }

sub const_col_names { die "Must be implemented by subclass" }

1;
# ABSTRACT: Base class for TableData::Object::*

=head1 METHODS

=head2 new($data[ , $spec]) => obj

Constructor. C<$spec> is optional, a specification hash as described by
L<TableDef>.

=head2 $td->cols_by_name => hash

Return the columns as a hash with name as keys and index as values.

Example:

 {name=>0, gender=>1, age=>2}

=head2 $td->cols_by_idx => array

Return the columns as an array where the element will correspond to the column's
position.

Example:

 ["name", "gender", "age"]

=head2 $td->row_count() => int

Return the number of rows.

See also: C<col_count()>.

=head2 $td->col_count() => int

Return the number of columns.

See also: C<row_count()>.

=head2 $td->col_exists($name_or_idx) => bool

Check whether a column exists. Column can be referred to using its name or
index/position (0, 1, ...).

=head2 $td->col_name($idx) => str

Return the name of column referred to by its index/position. Undef if column is
unknown.

See also: C<col_idx()>.

=head2 $td->col_idx($name) => int

Return the index/position of column referred to by its name. Undef if column is
unknown.

See also: C<col_name()>.

=head2 $td->rows_as_aoaos() => aoaos

Return rows as array of array-of-scalars.

See also: C<rows_as_aohos()>.

=head2 $td->rows_as_aohos() => aohos

Return rows as array of hash-of-scalars.

See also: C<rows_as_aoaos()>.

=head2 $td->select_as_aoaos([ \@cols[ , $func_filter_row[ , \@sorts] ] ]) => aoaos

Like C<rows_as_aoaos()>, but allow selecting columns, filtering rows, sorting.

C<\@cols> is an optional array of column specification to return in the
resultset. Currently only column names are allowed. You can mention the same
column name more than once.

C<$func_filter_row> is an optional coderef that will be passed C<< ($td,
$row_as_hos) >> and should return true/false depending on whether the row should
be included in the resultset. If unspecified, all rows will be returned.

C<\@sorts> is an optional array of column specification for sorting. For each
specification, you can use COLUMN_NAME or -COLUMN_NAME (note the dash prefix) to
express descending order instead of the default ascending. If unspecified, no
sorting will be performed.

See also: C<select_as_aohos()>.

=head2 $td->select_as_aohos([ \@cols[ , $func_filter_row[ , \@sorts ] ] ]) => aohos

Like C<select_as_aoaos()>, but will return aohos (array of hashes-of-scalars)
instead of aoaos (array of arrays-of-scalars).

See also: C<select_as_aoaos()>.

=head2 $td->uniq_col_names => list

Return a list of names of columns that are unique. A unique column exists in all
rows and has a defined and unique value across all rows. Example:

 my $td = table([
     {a=>1, b=>2, c=>undef, d=>1},
     {      b=>2, c=>3,     d=>2},
     {a=>1, b=>3, c=>4,     d=>3},
 ]); # -> ('d')

In the above example, C<a> does not exist in the second hash, <b> is not unique,
and C<c> has an undef value in the the first hash.

=head2 $td->const_col_names => list

Return a list of names of columns that are constant. A constant column ehas a
defined single value for all rows (a column that contains all undef's counts).
Example:

 my $td = table([
     {a=>1, b=>2, c=>undef, d=>2},
     {      b=>2, c=>undef, d=>2},
     {a=>2, b=>3, c=>undef, d=>2},
 ]); # -> ('c', 'd')

In the above example, C<a> does not exist in the second hash, <b> has two
different values.
