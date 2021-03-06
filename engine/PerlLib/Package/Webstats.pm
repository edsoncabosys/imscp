=head1 NAME

Package::Webstats - i-MSCP Webstats package

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2015 by internet Multi Server Control Panel
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# @category    i-MSCP
# @copyright   2010-2015 by i-MSCP | http://i-mscp.net
# @author      Laurent Declercq <l.declercq@nuxwin.com>
# @link        http://i-mscp.net i-MSCP Home Site
# @license     http://www.gnu.org/licenses/gpl-2.0.html GPL v2

package Package::Webstats;

use strict;
use warnings;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use iMSCP::Debug;
use iMSCP::Dialog;
use iMSCP::Dir;
use iMSCP::Execute;
use iMSCP::Getopt;
use iMSCP::ProgramFinder;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 Webstats package for i-MSCP.

 i-MSCP Webstats package. This is a wrapper that handle all available Webstats packages found in the Webstats directory.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners(\%eventManager)

 Register setup event listeners

 Param iMSCP::EventManager \%eventManager
 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
	my ($self, $eventManager) = @_;

	$eventManager->register('beforeSetupDialog', sub { push @{$_[0]}, sub { $self->showDialog(@_) }; 0; });
}

=item showDialog(\%dialog)

 Show dialog

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub showDialog
{
	my ($self, $dialog) = @_;

	my $packages = [split ',', main::setupGetQuestion('WEBSTATS_PACKAGES')];
	my $rs = 0;

	if(
		$main::reconfigure ~~ ['webstats', 'all', 'forced'] || ! @{$packages} ||
		grep { not $_ ~~ [$self->{'PACKAGES'}, 'No'] } @{$packages}
	) {
		($rs, $packages) = $dialog->checkbox(
			"\nPlease select the Webstats packages you want to install:",
			$self->{'PACKAGES'},
			(@{$packages} ~~ 'No') ? () : (@{$packages} ? @{$packages} : @{$self->{'PACKAGES'}})
		);
	}

	if($rs != 30) {
		main::setupSetQuestion('WEBSTATS_PACKAGES', @{$packages} ? join ',', @{$packages} : 'No');

		if(not 'No' ~~ @{$packages}) {
			for(@{$packages}) {
				my $package = "Package::Webstats::${_}::${_}";
				eval "require $package";

				unless($@) {
					$package = $package->getInstance();
					$rs = $package->showDialog($dialog) if $package->can('showDialog');
					last if $rs;
				} else {
					error($@);
					return 1;
				}
			}
		}
	}

	$rs;
}

=item preinstall()

 Process preinstall tasks

 /!\ This method also trigger uninstallation of unselected Webstats packages.

 Return int 0 on success, other on failure

=cut

sub preinstall
{
	my $self = $_[0];

	my $rs = 0;
	my @packages = split ',', main::setupGetQuestion('WEBSTATS_PACKAGES');
	my $packagesToInstall = [grep { $_ ne 'No'} @packages];
	my $packagesToUninstall = [grep { not $_ ~~  @{$packagesToInstall}} @{$self->{'PACKAGES'}}];

	if(@{$packagesToUninstall}) {
		my $packages = [];

		for(@{$packagesToUninstall}) {
			my $package = "Package::Webstats::${_}::${_}";
			eval "require $package";

			unless($@) {
				$package = $package->getInstance();
				$rs = $package->uninstall(); # Mandatory method
				return $rs if $rs;

				@{$packages} = (@{$packages}, @{$package->getDistroPackages()}) if $package->can('getDistroPackages');
			} else {
				error($@);
				return 1;
			}
		}

		if(defined $main::skippackages && !$main::skippackages && @{$packages}) {
			$rs = $self->_removePackages($packages);
			return $rs if $rs;
		}
	}

	if(@{$packagesToInstall}) {
		my $packages = [];

		for(@{$packagesToInstall}) {
			my $package = "Package::Webstats::${_}::${_}";
			eval "require $package";

			unless($@) {
				$package = $package->getInstance();
				$rs = $package->preinstall() if $package->can('preinstall');
				return $rs if $rs;

				@{$packages} = (@{$packages}, @{$package->getDistroPackages()}) if $package->can('getDistroPackages');
			} else {
				error($@);
				return 1;
			}
		}

		if(defined $main::skippackages && !$main::skippackages && @{$packages}) {
			$rs = $self->_installPackages($packages);
			return $rs if $rs;
		}
	}

	$rs;
}

=item install()

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
	my @packages = split ',', main::setupGetQuestion('WEBSTATS_PACKAGES');

	if(not 'No' ~~ @packages) {
		for(@packages) {
			my $package = "Package::Webstats::${_}::${_}";
			eval "require $package";

			unless($@) {
				$package = $package->getInstance();
				my $rs = $package->install() if $package->can('install');
				return $rs if $rs;
			} else {
				error($@);
				return 1;
			}
		}
	}

	0;
}

=item uninstall()

 Process uninstall tasks

 Return int 0 on success, other on failure

=cut

sub uninstall
{
	my $self = $_[0];

	my @packages = split ',', $main::imscpConfig{'WEBSTATS_PACKAGES'};

	my $packages = [];
	my $rs = 0;

	for(@packages) {
		if($_ ~~ @{$self->{'PACKAGES'}}) {
			my $package = "Package::Webstats::${_}::${_}";
			eval "require $package";

			unless($@) {
				$package = $package->getInstance();
				$rs = $package->uninstall(); # Mandatory method;
				return $rs if $rs;

				@{$packages} = (@{$packages}, @{$package->getDistroPackages()}) if $package->can('getDistroPackages');
			} else {
				error($@);
				return 1;
			}
		}
	}

	if(defined $main::skippackages && !$main::skippackages && @{$packages}) {
		$rs = $self->_removePackages($packages);
	}

	$rs;
}

=item setEnginePermissions()

 Set engine permissions

 Return int 0 on success, other on failure

=cut

sub setEnginePermissions
{
	my $self = $_[0];

	my @packages = split ',', $main::imscpConfig{'WEBSTATS_PACKAGES'};

	for(@packages) {
		if($_ ~~ @{$self->{'PACKAGES'}}) {
			my $package = "Package::Webstats::${_}::${_}";
			eval "require $package";

			unless($@) {
				$package = $package->getInstance();
				my $rs = $package->setEnginePermissions() if $package->can('setEnginePermissions');
				return $rs if $rs;
			} else {
				error($@);
				return 1;
			}
		}
	}

	0;
}

=item preaddDmn(\%data)

 Process preAddDmn tasks

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub preaddDmn
{
	my ($self, $data) = @_;

	if($data->{'FORWARD'} eq 'no') {
		my @packages = split ',', $main::imscpConfig{'WEBSTATS_PACKAGES'};

		for(@packages) {
			if($_ ~~ @{$self->{'PACKAGES'}}) {
				my $package = "Package::Webstats::${_}::${_}";
				eval "require $package";

				unless($@) {
					$package = $package->getInstance();
					my $rs = $package->preaddDmn($data) if $package->can('preaddDmn');
					return $rs if $rs;
				} else {
					error($@);
					return 1;
				}
			}
		}
	}

	0;
}

=item addDmn(\%data)

 Process addDmn tasks

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub addDmn
{
	my ($self, $data) = @_;

	if($data->{'FORWARD'} eq 'no') {
		my @packages = split ',', $main::imscpConfig{'WEBSTATS_PACKAGES'};

		for(@packages) {
			if($_ ~~ @{$self->{'PACKAGES'}}) {
				my $package = "Package::Webstats::${_}::${_}";
				eval "require $package";

				unless($@) {
					$package = $package->getInstance();
					my $rs = $package->addDmn($data) if $package->can('addDmn');
					return $rs if $rs;
				} else {
					error($@);
					return 1;
				}
			}
		}
	}

	0;
}

=item deleteDmn(\%data)

 Process deleteDmn tasks

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub deleteDmn
{
	my ($self, $data) = @_;

	if($data->{'FORWARD'} eq 'no') {
		my @packages = split ',', $main::imscpConfig{'WEBSTATS_PACKAGES'};

		for(@packages) {
			if($_ ~~ @{$self->{'PACKAGES'}}) {
				my $package = "Package::Webstats::${_}::${_}";
				eval "require $package";

				unless($@) {
					$package = $package->getInstance();
					my $rs = $package->deleteDmn($data) if $package->can('deleteDmn');
					return $rs if $rs;
				} else {
					error($@);
					return 1;
				}
			}
		}
	}

	0;
}

=item preaddSub(\%data)

 Process preaddSub tasks

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

=cut

sub preaddSub
{
	my ($self, $data) = @_;

	$self->preaddDmn($data);
}

=item addSub(\%data)

 Process addSub tasks

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

=cut

sub addSub
{
	my ($self, $data) = @_;

	$self->addDmn($data);
}

=item deleteSub(\%data)

 Process deleteSub tasks

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

=cut

sub deleteSub
{
	my ($self, $data) = @_;

	$self->deleteDmn($data);
}

=back

=head1 PRIVATE METHODS

=over 4

=item init()

 Initialize instance

 Return Package::Webstats

=cut

sub _init
{
	my $self = $_[0];

	# Find list of available Webstats packages
	@{$self->{'PACKAGES'}} = iMSCP::Dir->new(
		dirname => "$main::imscpConfig{'ENGINE_ROOT_DIR'}/PerlLib/Package/Webstats"
	)->getDirs();

	$self;
}

=item _installPackages(\@packages)

 Install packages

 Param array \@packages Packages to install
 Return int 0 on success, other on failure

=cut

sub _installPackages
{
	my ($self, $packages) = @_;

	my $preseed = iMSCP::Getopt->preseed;
	my @command = ();

	unless ($preseed || $main::noprompt || !iMSCP::ProgramFinder::find('debconf-apt-progress')) {
		iMSCP::Dialog->getInstance()->endGauge();
		push @command, 'debconf-apt-progress --logstderr --';
	}

	unshift @command, 'UCF_FORCE_CONFFMISS=1 '; # Force installation of missing conffiles which are managed by UCF

	if($main::forcereinstall) {
		push @command, "apt-get -y -o DPkg::Options::='--force-confnew' -o DPkg::Options::='--force-confmiss' " .
			"--reinstall --auto-remove --purge --no-install-recommends install @{$packages}";
	} else {
		push @command, "apt-get -y -o DPkg::Options::='--force-confnew' -o DPkg::Options::='--force-confmiss' " .
			"--auto-remove --purge --no-install-recommends install @{$packages}";
	}

	my ($stdout, $stderr);
	my $rs = execute("@command", ($preseed || $main::noprompt) ? \$stdout : undef, \$stderr);
	debug($stdout) if $stdout;
	error($stderr) if $stderr && $rs;
	error('Unable to install anti-rootkits distro packages') if $rs && !$stderr;

	$rs;
}

=item _removePackages(\@packages)

 Remove packages

 Param array \@packages Packages to remove
 Return int 0 on success, other on failure

=cut

sub _removePackages
{
	my ($self, $packages) = @_;

	# Do not try to remove packages which are no longer available on the system or not installed
	my ($stdout, $stderr);
	my $rs = execute("LANG=C dpkg-query -W -f='\${Package}/\${Status}\n' @{$packages}", \$stdout, \$stderr);
	error($stderr) if $stderr && $rs > 1;
	return $rs if $rs > 1;

	@{$packages} = grep { m%^(.*?)/install% && ($_ =  $1) } split /\n/, $stdout;

	if(@{$packages}) {
		my $preseed = iMSCP::Getopt->preseed;
		my @command = ();

		unless ($preseed || $main::noprompt || !iMSCP::ProgramFinder::find('debconf-apt-progress')) {
			iMSCP::Dialog->getInstance()->endGauge();
			push @command, 'debconf-apt-progress --logstderr -- ';
		}

		push @command, "apt-get -y --auto-remove --purge --no-install-recommends remove @{$packages}";

		my $rs = execute("@command", ($preseed || $main::noprompt) ? \$stdout : undef, \$stderr);
		debug($stdout) if $stdout;
		error($stderr) if $stderr && $rs;
		error('Unable to remove anti-rootkits distro packages') if $rs && !$stderr;
		return $rs if $rs;
	}

	0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
