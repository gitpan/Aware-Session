#
#
# Copyright (c) 2004 Thiago Rondon. <thiago@aware.com.br>
# Copyright (c) 2004 Aware.
#

package Aware::Session;

use strict;
use vars qw($VERSION);
use Storable qw(nfreeze thaw);
use MD5;

our $VERSION = '1.0';
my $session = "/tmp/";

# TODO: Remove!
sub rand_n () {
	my ($r, $loop); 
	for ($loop = 0 ; $loop < 32 ; $loop++) {
		$r .= int(rand(9));
	}
	return $r;
}

sub new {
    my $class = shift;
    my $opt   = shift;

    ${$opt}{TMP_DIR} = "$session" if (!${$opt}{TMP_DIR});
    return bless { TMP_DIR => ${$opt}{TMP_DIR}, opened => 0, started => 0, _session_id => '' }, $class;
}

sub session_id {
    my $self = shift;
    my $sid  = shift;

    # Limpa as sessoes antigas
    my $now = time();
    opendir(SDIR, $self->{TMP_DIR});
        my @sFiles = readdir(SDIR);
        foreach my $sFile(@sFiles) {
            if ($sFile =~ /\.db$/) {
                if (($now - (stat($self->{TMP_DIR} . $sFile))[8]) >= 3600) {
                    unlink($self->{TMP_DIR} . $sFile);
                }
            }
        }
    closedir(SDIR);
    #-->

    if ($sid) {
        return 0 if (!(-e "$self->{TMP_DIR}$sid.db"));
    } else {
        $sid = substr(MD5->hexhash(MD5->hexhash(time(). {}. rand(). $$)), 0, 32);
	#$sid = &rand_n(); 
    }
    $self->{_session_id} = $sid;
    $self->{opened} = 1;
    return 1;
}

sub session_start {
    my $self = shift;
    my %content;    
    
    return 0 if (!$self->{opened});
    
    if (-e "$self->{TMP_DIR}$self->{_session_id}.db") {
        $self->{serialized} = '';
        open(sFile, "< $self->{TMP_DIR}$self->{_session_id}.db");
            while (<sFile>) {
                $self->{serialized} .= $_;
            }
            %content = %{thaw($self->{serialized})};
        close(sFile);

        $self->{VARS} = {};
        while (my ($key,$value) = each(%content)) {
            $self->{VARS}{$key} = $value;
        }
    }
    $self->{started} = 1;
    return 1;
}

sub session_destroy {
    my $self = shift;

    return 0 if (!$self->{started});
    
    if (-e "$self->{TMP_DIR}$self->{_session_id}.db") {
        unlink("$self->{TMP_DIR}$self->{_session_id}.db");
    }
    $self->{_session_id}   = '';
    $self->{VARS}          = {};
    $self->{opened}        = 0;
    $self->{started}       = 0;
    return 1;
}

sub session_register {
    my $self = shift;
    my ($key,$value) = @_;
    my %content;
    
    return 0 if (!$self->{started});

    $self->{VARS}{$key} = $value;
    while (my ($key,$value) = each(%{$self->{VARS}})) {
        $content{$key} = $value;
    }

    open(sFile, "> $self->{TMP_DIR}$self->{_session_id}.db");
    print sFile nfreeze(\%content);
    #syswrite(STDOUT,nfreeze(\%content));
    close(sFile);
    return 1;
}

sub session_is_registered {
    my $self = shift;
    my ($key) = @_;

    return 0 if (!$self->{started});

    if ($self->{VARS}{$key}) {
        return 1;
    } else {
        return 0;
    }
}

sub session_unregister {
    my $self = shift;
    my ($key) = @_;
    my %content;
    
    return 0 if (!$self->{started});
    
    if ($self->{VARS}{$key}) {
        delete($self->{VARS}{$key});
        while (my ($key,$value) = each(%{$self->{VARS}})) {
            $content{$key} = $value;
        }
        open(sFile, ">$self->{TMP_DIR}$self->{_session_id}.db");
            print sFile nfreeze(\%content);
        close(sFile);        
    }
    return 1;
}
