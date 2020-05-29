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

sub row {
    my ($self, $idx) = @_;
    $self->{data}[$idx];
}

sub row_as_aos {
    my ($self, $idx) = @_;
    my $row_hos = $self->{data}[$idx];
    return undef unless $row_hos;
    my $cols = $self->{cols_by_idx};
    my $row_aos = [];
    for my $i (0..$#{$cols}) {
        $row_aos->[$i] = $row_hos->{$cols->[$i]};
    }
    $row_aos;
}

sub row_as_hos {
    my ($self, $idx) = @_;
    $self->{data}[$idx];
}

sub rows {
    my $self = shift;
    $self->{data};
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

sub uniq_col_names {
    my $self = shift;

    my @res;
  COL:
    for my $col (sort keys %{$self->{cols_by_name}}) {
        my %mem;
        for my $row (@{$self->{data}}) {
            next COL unless defined $row->{$col};
            next COL if $mem{ $row->{$col} }++;
        }
        push @res, $col;
    }
    @res;
}

sub const_col_names {
    my $self = shift;

    my @res;
  COL:
    for my $col (sort keys %{$self->{cols_by_name}}) {
        my $i = -1;
        my $val;
        my $val_undef;
        for my $row (@{$self->{data}}) {
            next COL unless exists $row->{$col};
            $i++;
            if ($i == 0) {
                $val = $row->{$col};
                $val_undef = 1 unless defined $val;
            } else {
                if ($val_undef) {
                    next COL if defined $row->{$col};
                } else {
                    next COL unless defined $row->{$col};
                    next COL unless $val eq $row->{$col};
                }
            }
        }
        push @res, $col;
    }
    @res;
}

sub del_col {
    my ($self, $name_or_idx) = @_;

    my $idx = $self->col_idx($name_or_idx);
    return undef unless defined $idx;

    my $name = $self->{cols_by_idx}[$idx];

    for my $row (@{$self->{data}}) {
        delete $row->{$name};
    }

    # adjust cols_by_{name,idx}
    for my $i (reverse 0..$#{$self->{cols_by_idx}}) {
        my $name = $self->{cols_by_idx}[$i];
        if ($i > $idx) {
            $self->{cols_by_name}{$name}--;
        } elsif ($i == $idx) {
            splice @{ $self->{cols_by_idx} }, $i, 1;
            delete $self->{cols_by_name}{$name};
        }
    }

    # adjust spec
    if ($self->{spec}) {
        my $ff = $self->{spec}{fields};
        for my $name (keys %$ff) {
            if (!exists $self->{cols_by_name}{$name}) {
                delete $ff->{$name};
            } else {
                $ff->{$name}{pos} = $self->{cols_by_name}{$name};
            }
        }
    }

    $name;
}

sub rename_col {
    my ($self, $old_name_or_idx, $new_name) = @_;

    my $idx = $self->col_idx($old_name_or_idx);
    die "Unknown column '$old_name_or_idx'" unless defined($idx);
    my $old_name = $self->{cols_by_idx}[$idx];
    die "Please specify new column name" unless length($new_name);
    return if $new_name eq $old_name;
    die "New column name must not be a number" if $new_name =~ /\A\d+\z/;

    # adjust data
    for my $row (@{$self->{data}}) {
        $row->{$new_name} = delete($row->{$old_name});
    }

    $self->{cols_by_idx}[$idx] = $new_name;
    $self->{cols_by_name}{$new_name} = delete($self->{cols_by_name}{$old_name});
    if ($self->{spec}) {
        my $ff = $self->{spec}{fields};
        $ff->{$new_name} = delete($ff->{$old_name});
    }
}

sub switch_cols {
    my ($self, $name_or_idx1, $name_or_idx2) = @_;

    my $idx1 = $self->col_idx($name_or_idx1);
    die "Unknown first column '$name_or_idx1'" unless defined($idx1);
    my $idx2 = $self->col_idx($name_or_idx2);
    die "Unknown second column '$name_or_idx2'" unless defined($idx2);
    return if $idx1 == $idx2;

    my $name1 = $self->col_name($name_or_idx1);
    my $name2 = $self->col_name($name_or_idx2);

    # adjust data
    for my $row (@{$self->{data}}) {
        ($row->{$name1}, $row->{$name2}) = ($row->{$name2}, $row->{$name1});
    }

    ($self->{cols_by_idx}[$idx1], $self->{cols_by_idx}[$idx2]) =
        ($self->{cols_by_idx}[$idx2], $self->{cols_by_idx}[$idx1]);
    ($self->{cols_by_name}{$name1}, $self->{cols_by_name}{$name2}) =
        ($self->{cols_by_name}{$name2}, $self->{cols_by_name}{$name1});
    if ($self->{spec}) {
        my $ff = $self->{spec}{fields};
        ($ff->{$name1}, $ff->{$name2}) = ($ff->{$name2}, $ff->{$name1});
    }
}

sub add_col {
    my ($self, $name, $idx, $spec) = @_;

    # XXX BEGIN CODE dupe with aoaos
    die "Column '$name' already exists" if defined $self->col_name($name);
    my $col_count = $self->col_count;
    if (defined $idx) {
        die "Index must be between 0..$col_count"
            unless $idx >= 0 && $idx <= $col_count;
    } else {
        $idx = $col_count;
    }

    for (keys %{ $self->{cols_by_name} }) {
        $self->{cols_by_name}{$_}++ if $self->{cols_by_name}{$_} >= $idx;
    }
    $self->{cols_by_name}{$name} = $idx;
    splice @{ $self->{cols_by_idx} }, $idx, 0, $name;
    if ($self->{spec}) {
        my $ff = $self->{spec}{fields};
        for my $f (values %$ff) {
            $f->{pos}++ if defined($f->{pos}) && $f->{pos} >= $idx;
        }
        $ff->{$name} = defined($spec) ? {%$spec} : {};
        $ff->{$name}{pos} = $idx;
    }
    # XXX BEGIN CODE dupe with aoaos

    for my $row (@{ $self->{data} }) {
        $row->{$name} = undef;
    }
}

sub set_col_val {
    my ($self, $name_or_idx, $value_sub) = @_;

    my $col_name = $self->col_name($name_or_idx);
    my $col_idx  = $self->col_idx($name_or_idx);

    die "Column '$name_or_idx' does not exist" unless defined $col_name;

    for my $i (0..$#{ $self->{data} }) {
        my $row = $self->{data}[$i];
        $row->{$col_name} = $value_sub->(
            table    => $self,
            row_idx  => $i,
            col_name => $col_name,
            col_idx  => $col_idx,
            value    => $row->{$col_name},
        );
    }
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


=head1 DESCRIPTION

This class lets you manipulate an array of hashes-of-scalars as a table object.
The table will have columns from all the hashes' keys.


=head1 METHODS

See L<TableData::Object::Base>.
