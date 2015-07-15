#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Env qw(HOME);
use Cwd;

my $filename = 'liquibase.properties';

my $basePath = cwd();

my %opts=(
    filename        => \$filename,
    driver          => 'com.mysql.jdbc.Driver',
    classpath       => "${basePath}/mysql-connector-java-5.1.35-bin.jar",
    url             => 'jdbc:mysql://127.0.0.1/my_db',
    username        => 'root',
    password        => '',
    changeLogFile   => 'schema.xml',
    help            => 0
);

GetOptions(\%opts, 'filename=s', 'driver=s', 'classpath=s', 'url|server=s', 'username=s', 'password=s', 'changeLogFile=s', 'help|?')
    or pod2usage(-existval => 1, -verbose => 99);

pod2usage(-exitval => 0, -verbose => 1) if $opts{help};

open(my $fh, '>:encoding(UTF-8)', $filename)
    or die "Failed to open '$filename': $!\n";

for my $key (keys %opts) {
    if ($key ne 'filename' && $key ne 'help') {
        if ($key eq 'classpath') {
            my $baseLen = length $basePath;
            if (substr($opts{$key}, 0, $baseLen) ne $basePath) {
                $opts{$key} = "$basePath/$opts{$key}";
            }
        }
        print $fh "$key: $opts{$key}\n";
    }
}

close $fh;

print "Check environment variable for LIQUIBASE_HOME\n";
if (!defined $ENV{LIQUIBASE_HOME}) {
    #get pwd (of file)
    my $basePath = cwd();
    open(my $fh, '>>:encoding(UTF-8)', "$HOME/.bashrc")
        or die "Failed to append to $HOME/.bashrc: $!\n";
    print $fh "\nexport LIQUIBASE_HOME='$basePath'\n";
    close $fh;
}

print "Done\n";

__END__

=head1 NAME

setup - Usage

=head1 SYNOPSIS

setup [options] - Generate liquibase properties file

=head1 OPTIONS

    Options:
        --help                                              : Display help message
        --filename=liquibase.properties                     : The output file (default is liquibase.properties in current directory)
        --driver=com.mysql.jdbc.Driver                      : The DB driver used by liquibase (class)
        --classpath=./mysql-connector-java-5.1.35-bin.jar   : The location of the DB driver jar
        --url=jdbc:mysql://127.0.0.1/my_db                  : The DB to connect to
        --username=root                                     : user (DB credentials)
        --password=''                                       : password (DB credentials)
        --changeLogFile=schema.xml                          : Default changelog file


=over 8

Enjoy

=back

=head1 DESCRIPTION

B<this program> will generate the liquibase.properties file with the params given. Default is to create it in the current directory under the liquibase.properties name

=cut
