#!/usr/bin/perl

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010 - 2012 by internet Multi Server Control Panel
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
# @category		i-MSCP
# @copyright	2010 - 2012 by i-MSCP | http://i-mscp.net
# @author		Daniel Andreca <sci2tech@gmail.com>
# @link			http://i-mscp.net i-MSCP Home Site
# @license		http://www.gnu.org/licenses/gpl-2.0.html GPL v2

package Servers::httpd::apache_fcgi::installer;

use strict;
use warnings;
use iMSCP::Debug;
use Data::Dumper;
use parent 'Common::SingletonClass';

sub _init
{
	my $self = shift;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdInitInstaller', $self, 'apache_fcgi');

	$self->{'cfgDir'} = "$main::imscpConfig{'CONF_DIR'}/apache";
	$self->{'bkpDir'} = "$self->{cfgDir}/backup";
	$self->{'wrkDir'} = "$self->{cfgDir}/working";

	my $conf = "$self->{cfgDir}/apache.data";
	my $oldConf = "$self->{cfgDir}/apache.old.data";

	tie %self::apacheConfig, 'iMSCP::Config','fileName' => $conf, noerrors => 1;

	if($oldConf) {
		tie %self::apacheOldConfig, 'iMSCP::Config','fileName' => $oldConf, noerrors => 1;
		%self::apacheConfig = (%self::apacheConfig, %self::apacheOldConfig);
	}

	iMSCP::HooksManager->getInstance()->trigger('afterHttpdInitInstaller', $self, 'apache_fcgi');

	$self;
}

sub registerSetupHooks
{
	my $self = shift;
	my $hooksManager = shift;

	iMSCP::HooksManager->getInstance()->trigger('beforeRegisterSetupHooks', 'apache_fcgi') and return 1;

	# Add installer dialog in setup dialog stack
	$hooksManager->register(
		'beforeSetupDialog',
		sub { my $dialogStack = shift; push(@$dialogStack, sub { $self->askCgiModule(@_) }); 0; }
	) and return 1;

	iMSCP::HooksManager->getInstance()->trigger('afterRegisterSetupHooks', 'apache_fcgi');
}

sub askCgiModule
{
	my $self = shift;
	my $dialog = shift;

	my $cgiModule = $main::preseed{'PHP_FASTCGI'} || $self::apacheConfig{'PHP_FASTCGI'} ||
		$self::apacheOldConfig{'PHP_FASTCGI'} || '';

	my $rs = 0;

	if($main::reconfigure || $cgiModule !~ /^fcgid|fastcgi$/i) {
		($rs, $cgiModule) = $dialog->radiolist(
			"\nPlease, select the cgi module you want use:",
			['fcgid', 'fastcgi'],
			$cgiModule ne 'fcgid' ? 'fastcgi' : 'fcgid'
		);
	}

	$self::apacheConfig{'PHP_FASTCGI'} = $cgiModule if $rs != 30;

	0;
}

sub install
{
	my $self = shift;
	my $rs = 0;

	$rs = iMSCP::HooksManager->getInstance()->trigger('beforeHttpdInstall', 'apache_fcgi');

	# Saving all system configuration files if they exists
	for ((
		"$main::imscpConfig{LOGROTATE_CONF_DIR}/apache2", "$main::imscpConfig{LOGROTATE_CONF_DIR}/apache",
		"$self::apacheConfig{APACHE_CONF_DIR}/ports.conf"
	)) {
		$rs |= $self->bkpConfFile($_);
	}

	$rs |= $self->addUsersAndGroups();
	$rs |= $self->makeDirs();
	$rs |= $self->buildFastCgiConfFiles();
	$rs |= $self->buildPhpConfFiles();
	$rs |= $self->buildMainVhostFile();
	$rs |= $self->buildMasterVhostFiles();
	$rs |= $self->installLogrotate();
	$rs |= $self->saveConf();
	$rs |= $self->setGuiPermissions();
	$rs |= $self->oldEngineCompatibility();

	$rs |= iMSCP::HooksManager->getInstance()->trigger('afterHttpdInstall', 'apache_fcgi');

	$rs;
}

sub setGuiPermissions
{
	my $self = shift;

	my $panelUName = $main::imscpConfig{'SYSTEM_USER_PREFIX'}.$main::imscpConfig{'SYSTEM_USER_MIN_UID'};
	my $panelGName = $main::imscpConfig{'SYSTEM_USER_PREFIX'}.$main::imscpConfig{'SYSTEM_USER_MIN_UID'};
	my $rootUName = $main::imscpConfig{'ROOT_USER'};
	my $rootGName = $main::imscpConfig{'ROOT_GROUP'};
	my $apacheUName = $self::apacheConfig{'APACHE_USER'};
	my $apacheGName = $self::apacheConfig{'APACHE_GROUP'};
	my $phpDir = $self::apacheConfig{'PHP_STARTER_DIR'};
	my $rootDir = $main::imscpConfig{'ROOT_DIR'};
	my $rs = 0;

	$rs = iMSCP::HooksManager->getInstance()->trigger('beforeHttpdSetGuiPermissions');

	use iMSCP::Rights;

	$rs |= setRights(
		"$rootDir/gui/public",
		{ user => $panelUName, group => $apacheGName, dirmode => '0550', filemode => '0440', recursive => 'yes' }
	);

	$rs |= setRights(
		"$rootDir/gui/themes",
		{ user => $panelUName, group => $apacheGName, dirmode => '0550', filemode => '0440', recursive => 'yes' }
	);

	$rs |= setRights(
		"$rootDir/gui/library",
		{ user => $panelUName, group => $panelGName, dirmode => '0500', filemode => '0400', recursive => 'yes' }
	);

	$rs |= setRights(
		"$rootDir/gui/data",
		{ user => $panelUName, group => $panelGName, dirmode => '0700', filemode => '0600', recursive => 'yes' }
	);

	$rs |= setRights(
		"$rootDir/gui/data",
		{ user => $panelUName, group => $apacheGName, mode => '0550' }
	);

	$rs |= setRights(
		"$rootDir/gui/data/ispLogos",
		{ user => $panelUName, group => $apacheGName, dirmode => '0750', filemode => '0640', recursive => 'yes' }
	);

	$rs |= setRights(
		"$rootDir/gui/i18n",
		{ user => $panelUName, group => $panelGName, dirmode => '0700', filemode => '0600', recursive => 'yes' }
	);

	$rs |= setRights(
		"$rootDir/gui/plugins",
		{ user => $panelUName, group => $panelGName, dirmode => '0700', filemode => '0600', recursive => 'yes' }
	);

	$rs |= setRights(
		"$rootDir/gui/plugins",
		{ user => $panelUName, group => $apacheGName, mode => '0550' }
	);

	$rs |= setRights(
		"$rootDir/gui/public/tools/filemanager/data",
		{ user => $panelUName, group => $panelGName, dirmode => '0700', filemode => '0600', recursive => 'yes' }
	);

	$rs |= setRights(
		"$rootDir/gui/public/tools/webmail/logs",
		{ user => $panelUName, group => $panelGName, dirmode => '0750', filemode => '0640', recursive => 'yes' }
	);

	$rs |= setRights(
		"$rootDir/gui",
		{ user => $panelUName, group => $apacheGName, mode => '0550' }
	);

	$rs |= setRights(
		$rootDir,
		{ user => $panelUName, group => $apacheGName, mode => '0555' }
	);

	$rs |= setRights(
		$phpDir,
		{ user => $rootUName, group => $rootGName, mode => '0555' }
	);

	$rs |= iMSCP::HooksManager->getInstance()->trigger('afterHttpdSetGuiPermissions');

	$rs;
}

sub addUsersAndGroups
{
	my $self = shift;
	my ($panelGName, $panelUName);
	my $rs = 0;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdAddUsersAndGroups') and return 1;

	# Panel group
	use Modules::SystemGroup;
	$panelGName = Modules::SystemGroup->new();
	$rs = $panelGName->addSystemGroup(
		$main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'}
	);
	return $rs if $rs;

	## Panel user
	use Modules::SystemUser;
	$panelUName = Modules::SystemUser->new();
	$panelUName->{'skipCreateHome'} = 'yes';
	$panelUName->{'comment'} = 'iMSCP master virtual user';
	$panelUName->{'home'} = "$self::apacheConfig{'PHP_STARTER_DIR'}/master";
	$panelUName->{'group'} = $main::imscpConfig{'SYSTEM_USER_PREFIX'}.$main::imscpConfig{'SYSTEM_USER_MIN_UID'};

	$rs = $panelUName->addSystemUser(
		$main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'}
	);
	return $rs if $rs;

	$rs = $panelUName->addToGroup($main::imscpConfig{'MASTER_GROUP'});
	return $rs if $rs;

	iMSCP::HooksManager->getInstance()->trigger('afterHttpdAddUsersAndGroups');
}

sub makeDirs
{
	my $self = shift;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdMakeDirs') and return 1;

	my $panelUName = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'};
	my $panelGName = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'};
	my $rootUName = $main::imscpConfig{'ROOT_USER'};
	my $rootGName = $main::imscpConfig{'ROOT_GROUP'};
	my $apacheUName = $self::apacheConfig{'APACHE_USER'};
	my $apacheGName = $self::apacheConfig{'APACHE_GROUP'};
	my $phpdir = $self::apacheConfig{'PHP_STARTER_DIR'};
	my $rs = 0;

	use iMSCP::Dir;

	for (
		[$self::apacheConfig{'APACHE_USERS_LOG_DIR'}, $apacheUName, $apacheGName, 0755],
		[$self::apacheConfig{'APACHE_BACKUP_LOG_DIR'}, $rootUName, $rootGName, 0755],
		[$phpdir, $rootUName, $rootGName, 0755],
		["$phpdir/master", $panelUName, $panelGName, 0755],
		["$phpdir/master/php5", $panelUName, $panelGName, 0755]
	) {
		$rs |= iMSCP::Dir->new(dirname => $_->[0])->make({ user => $_->[1], group => $_->[2], mode => $_->[3]});
	}

	$rs |= iMSCP::HooksManager->getInstance()->trigger('afterHttpdMakeDirs');

	$rs;
}

sub bkpConfFile
{
	my $self = shift;
	my $cfgFile = shift;
	my $timestamp = time;
	my $rs = 0;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdBkpConfFile', $cfgFile) and return 1;

	use File::Basename;

	if(-f $cfgFile){
		my $file = iMSCP::File->new( filename => $cfgFile );
		my ($filename, $directories, $suffix) = fileparse($cfgFile);

		if(! -f "$self->{bkpDir}/$filename$suffix.system") {
			$rs |= $file->copyFile("$self->{bkpDir}/$filename$suffix.system");
		} else {
			$rs |= $file->copyFile("$self->{bkpDir}/$filename$suffix.$timestamp");
		}
	}

	$rs |= iMSCP::HooksManager->getInstance()->trigger('afterHttpdBkpConfFile', $cfgFile);

	$rs;
}

sub saveConf
{
	my $self = shift;
	my $rs = 0;

	use iMSCP::File;

	my $file = iMSCP::File->new(filename => "$self->{cfgDir}/apache.data");
	my $cfg = $file->get() or return 1;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdBkpConfFile', \$cfg, 'apache.old.data') and return 1;

	$file = iMSCP::File->new(filename => "$self->{cfgDir}/apache.old.data");

	$rs |= $file->set($cfg);
	$rs |= $file->save();
	$rs |= $file->mode(0640);
	$rs |= $file->owner($main::imscpConfig{'ROOT_USER'}, $main::imscpConfig{'ROOT_GROUP'});

	$rs |= iMSCP::HooksManager->getInstance()->trigger('afterHttpdBkpConfFile', 'apache.old.data');

	$rs;
}


sub oldEngineCompatibility
{
	my $self = shift;

	use iMSCP::File;
	use Servers::httpd::apache_fcgi;

	my $httpd = Servers::httpd::apache_fcgi->new();
	my $rs = 0;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdOldEngineCompatibility') and return 1;

	if(-f "$self::apacheConfig{APACHE_SITES_DIR}/imscp.conf"){
		$rs |= $httpd->disableSite('imscp.conf');
		$rs |= iMSCP::File->new(filename => "$self::apacheConfig{APACHE_SITES_DIR}/imscp.conf")->delFile();
	}

	$rs |= iMSCP::HooksManager->getInstance()->trigger('afterHttpdOldEngineCompatibility');

	$rs;
}

sub buildFastCgiConfFiles
{
	my $self = shift;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdBuildFastCgiConfFiles') and return 1;

	use iMSCP::File;
	use Servers::httpd::apache_fcgi;

	my $httpd = Servers::httpd::apache_fcgi->new();
	my $rs = 0;
	my ($cfgTpl, $err);

	# Saving the current production file if they exists
	for (qw/fastcgi_imscp.conf fastcgi_imscp.load fcgid_imscp.conf fcgid_imscp.load/) {
		$rs = $self->bkpConfFile("$self::apacheConfig{'APACHE_MODS_DIR'}/$_");
		return $rs if $rs;
	}

	# Building, storage and installation of new files

	# fastcgi_imscp.conf / fcgid_imscp.conf
	for (qw/fastcgi fcgid/) {
		# Loading the template from the /etc/imscp/apache directory
		$httpd->setData(
			{
				SYSTEM_USER_PREFIX => $main::imscpConfig{'SYSTEM_USER_PREFIX'},
				SYSTEM_USER_MIN_UID	=> $main::imscpConfig{'SYSTEM_USER_MIN_UID'},
				PHP_VERSION => $main::imscpConfig{'PHP_VERSION'}
			}
		);

		$httpd->buildConfFile("$self->{cfgDir}/${_}_imscp.conf");
		my $file = iMSCP::File->new(filename => "$self->{wrkDir}/${_}_imscp.conf");
		$file->copyFile($self::apacheConfig{'APACHE_MODS_DIR'}) and return 1;

		next if(! -f "$self::apacheConfig{'APACHE_MODS_DIR'}/$_.load");
		# Loading the system configuration file
		$file = iMSCP::File->new(filename => "$self::apacheConfig{'APACHE_MODS_DIR'}/$_.load");
		$cfgTpl = $file->get();
		return 1 if ! $cfgTpl;

		# Building the new configuration file
		$file = iMSCP::File->new(filename => "$self->{wrkDir}/${_}_imscp.load");
		$cfgTpl = "<IfModule !mod_$_.c>\n" . $cfgTpl . "</IfModule>\n";
		$file->set($cfgTpl);

		# Store the new file
		$file->save() and return 1;
		$file->mode(0644) and return 1;
		$file->owner($main::imscpConfig{'ROOT_USER'}, $main::imscpConfig{'ROOT_GROUP'}) and return 1;

		# Install the new file
		$file->copyFile($self::apacheConfig{'APACHE_MODS_DIR'}) and return 1;
	}

	# Ensures that the unused i-MSCP fcgid module loader is disabled
	my $enable = $self::apacheConfig{'PHP_FASTCGI'} eq 'fastcgi' ? 'fastcgi_imscp' : 'fcgid_imscp';
	my $disable = $self::apacheConfig{'PHP_FASTCGI'} eq 'fastcgi' ? 'fcgid_imscp' : 'fastcgi_imscp';

	## Enable required modules and disable unused

	# try to disable but do not fail if do not exists
	$httpd->disableMod('php4') if -e "$self::apacheConfig{'APACHE_MODS_DIR'}/php4.load";
	$httpd->disableMod('php5') if -e "$self::apacheConfig{'APACHE_MODS_DIR'}/php5.load";

	$rs = $httpd->disableMod("fastcgi fcgid $disable");
	return $rs if $rs;

	$rs = $httpd->enableMod("actions $enable");
	return $rs if $rs;

	iMSCP::HooksManager->getInstance()->trigger('afterHttpdBuildFastCgiConfFiles');
}

sub buildMainVhostFile
{
	my $self = shift;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdBuildMainVhostFile', '00_nameserver.conf') and return 1;

	use iMSCP::File;
	use version;
	use Servers::httpd::apache_fcgi;

	my $httpd = Servers::httpd::apache_fcgi->new();
	my ($rs, $cfgTpl, $err);

	if(-f "$self::apacheConfig{'APACHE_SITES_DIR'}/00_nameserver.conf") {
		iMSCP::File->new(
			filename => "$self::apacheConfig{'APACHE_SITES_DIR'}/00_nameserver.conf"
		)->copyFile("$self->{bkpDir}/00_nameserver.conf.". time) and return 1;
	}

	if(-f '/etc/apache2/ports.conf') {
		# Loading the file
		my $file = iMSCP::File->new(filename => '/etc/apache2/ports.conf');
		my $rdata = $file->get();
		return $rdata if ! $rdata;

		iMSCP::HooksManager->getInstance()->trigger('beforeHttpdBuildPortConfFile', \$rdata, 'port.conf') and return 1;

		$rdata =~ s/^NameVirtualHost \*:80/#NameVirtualHost \*:80/gmi;

		iMSCP::HooksManager->getInstance()->trigger('afterHttpdBuildPortConfFile', \$rdata, 'port.conf') and return 1;

		$file->set($rdata) and return 1;
		$file->save() and return 1;
	}

	# Using alternative syntax for piped logs scripts when possible
	# The alternative syntax does not involve the Shell (from Apache 2.2.12)
	my $pipeSyntax = '|';

	if(`$self::apacheConfig{'CMD_HTTPD_CTL'} -v` =~ m!Apache/([\d.]+)! && version->new($1) >= version->new('2.2.12')) {
		$pipeSyntax .= '|';
	}

	$httpd->setData(
		{
			APACHE_WWW_DIR => $main::imscpConfig{'USER_HOME_DIR'},
			ROOT_DIR => $main::imscpConfig{'ROOT_DIR'},
			PIPE => $pipeSyntax
		}
	);

	$cfgTpl = $httpd->buildConfFile(
		"$self->{cfgDir}/00_nameserver.conf",
		{ destination => "$self->{wrkDir}/00_nameserver.conf" }
	);

	# Installing the new file in production directory
	my $file = iMSCP::File->new(filename => "$self->{wrkDir}/00_nameserver.conf");
	$file->copyFile($self::apacheConfig{'APACHE_SITES_DIR'}) and return 1;

	# Enable required modules
	$rs = $httpd->enableMod('cgid rewrite suexec proxy proxy_http ssl');
	return $rs if $rs;

	$rs = $httpd->enableSite('00_nameserver.conf');
	return $rs if $rs;

	iMSCP::HooksManager->getInstance()->trigger('afterHttpdBuildMainVhostFile', '00_nameserver.conf');
}

sub buildPhpConfFiles
{
	my $self = shift;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdBuildPhpConfFiles') and return 1;

	use Servers::httpd::apache_fcgi;
	use iMSCP::File;

	my $httpd = Servers::httpd::apache_fcgi->new();
	my ($rs, $cfgTpl, $file);
	my $cfgDir = "$main::imscpConfig{'CONF_DIR'}/fcgi";
	my $bkpDir = "$cfgDir/backup";
	my $wrkDir = "$cfgDir/working";

	my $timestamp = time;

	# Saving files if they exists
	for ('php5-fcgid-starter', 'php5-fastcgi-starter', 'php5/php.ini', 'php5/browscap.ini') {
		if(-f "$self::apacheConfig{'PHP_STARTER_DIR'}/master/$_") {
			my (undef, $name) = split('/');
			$name = $_ if !defined $name;
			my $file = iMSCP::File->new(filename => "$self::apacheConfig{'PHP_STARTER_DIR'}/master/$_");
			$file->copyFile("$bkpDir/master.$name.$timestamp") and return 1;
		}
	}

	## PHP5 Starter script (fcgid)

	# Loading the template from /etc/imscp/fcgi/parts/master
	$httpd->setData(
		{
			HOME_DIR => $main::imscpConfig{'GUI_ROOT_DIR'},
			DMN_NAME => 'master'
		}
	);

	my $panelUname = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'};
	my $panelGName = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'};

	$httpd->buildConfFile(
		"$cfgDir/parts/master/php5-fcgid-starter.tpl",
		{
			destination	=> "$wrkDir/master.php5-fcgid-starter",
			mode => 0755,
			user => $panelUname,
			group => $panelGName
		}
	);

	# Install the new file
	$file = iMSCP::File->new(filename => "$wrkDir/master.php5-fcgid-starter");
	$file->copyFile("$self::apacheConfig{'PHP_STARTER_DIR'}/master/php5-fcgid-starter") and return 1;

	## PHP5 Starter script (fastcgi)

	# Loading the template from /etc/imscp/fcgi/parts/master
	$httpd->setData(
		{
			HOME_DIR => $main::imscpConfig{'GUI_ROOT_DIR'},
			DMN_NAME => 'master'
		}
	);

	my $panelUname = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'};
	my $panelGName = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'};

	$httpd->buildConfFile(
		"$cfgDir/parts/master/php5-fastcgi-starter.tpl",
		{
			destination => "$wrkDir/master.php5-fastcgi-starter",
			mode => 0755,
			user => $panelUname,
			group => $panelGName
		}
	);

	# Install the new file
	$file = iMSCP::File->new(filename => "$wrkDir/master.php5-fastcgi-starter");
	$file->copyFile("$self::apacheConfig{'PHP_STARTER_DIR'}/master/php5-fastcgi-starter") and return 1;

	## PHP5 php.ini file

	# Loading the template from /etc/imscp/fcgi/parts/master/php5
	$httpd->setData(
		{
			WWW_DIR	 => $main::imscpConfig{'ROOT_DIR'},
			DMN_NAME => 'gui',
			MAIL_DMN => $main::imscpConfig{'BASE_SERVER_VHOST'},
			CONF_DIR => $main::imscpConfig{'CONF_DIR'},
			MR_LOCK_FILE => $main::imscpConfig{'MR_LOCK_FILE'},
			PEAR_DIR => $main::imscpConfig{'PEAR_DIR'},
			RKHUNTER_LOG => $main::imscpConfig{'RKHUNTER_LOG'},
			CHKROOTKIT_LOG => $main::imscpConfig{'CHKROOTKIT_LOG'},
			OTHER_ROOTKIT_LOG => ($main::imscpConfig{'OTHER_ROOTKIT_LOG'} ne '')
				? ":$main::imscpConfig{'OTHER_ROOTKIT_LOG'}" : '',
			PHP_TIMEZONE => $main::imscpConfig{'PHP_TIMEZONE'}
		}
	);

	$httpd->buildConfFile(
		"$cfgDir/parts/master/php5/php.ini",
		{
			destination	=> "$wrkDir/master.php.ini",
			mode => 0644,
			user => $panelUname,
			group => $panelGName
		}
	);

	# Install the new file in production directory
	$file = iMSCP::File->new(filename => "$wrkDir/master.php.ini");
	$file->copyFile("$self::apacheConfig{'PHP_STARTER_DIR'}/master/php5/php.ini") and return 1;


	# PHP Browser Capabilities support file

	# Store the new file in working directory
	iMSCP::File->new(filename => "$cfgDir/parts/master/php5/browscap.ini")->copyFile("$wrkDir/browscap.ini") and return 1;

	$file = iMSCP::File->new(filename => "$wrkDir/browscap.ini");
	$file->mode(0644) and return 1;
	$file->owner($panelUname, $panelGName) and return 1;

	# Install the new file
	$file->copyFile("$self::apacheConfig{'PHP_STARTER_DIR'}/master/php5/browscap.ini") and return 1;

	iMSCP::HooksManager->getInstance()->trigger('afterHttpdBuildPhpConfFiles');
}

sub buildMasterVhostFiles
{
	my $self = shift;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdBuildMasterVhostFiles') and return 1;

	use iMSCP::File;
	use Servers::httpd;

	my $httpd = Servers::httpd::apache_fcgi->new();
	my $rs = 0;

	$rs = $httpd->disableSite('default default-ssl');
	return $rs if $rs;

	my $adminEmailAddress = $main::imscpConfig{'DEFAULT_ADMIN_ADDRESS'};
	my ($user, $domain) = split /@/, $adminEmailAddress;
	use Net::LibIDN qw/idn_to_ascii/;
	$adminEmailAddress = "$user@" . idn_to_ascii($domain, 'utf-8');

	$httpd->setData(
		{
			DEFAULT_ADMIN_ADDRESS => $adminEmailAddress,
			SYSTEM_USER_PREFIX => $main::imscpConfig{'SYSTEM_USER_PREFIX'},
			SYSTEM_USER_MIN_UID => $main::imscpConfig{'SYSTEM_USER_MIN_UID'},
			GUI_CERT_DIR => $main::imscpConfig{'GUI_CERT_DIR'},
			SERVER_HOSTNAME => $main::imscpConfig{'SERVER_HOSTNAME'},
			WWW_DIR => $main::imscpConfig{'ROOT_DIR'},
			DMN_NAME => 'gui',
			ROOT_DIR => $main::imscpConfig{'ROOT_DIR'},
			BASE_SERVER_IP => $main::imscpConfig{'BASE_SERVER_IP'},
			BASE_SERVER_VHOST => $main::imscpConfig{'BASE_SERVER_VHOST'},
			PHP_VERSION => $main::imscpConfig{'PHP_VERSION'},
			CONF_DIR => $main::imscpConfig{'CONF_DIR'},
			MR_LOCK_FILE => $main::imscpConfig{'MR_LOCK_FILE'},
			RKHUNTER_LOG => $main::imscpConfig{'RKHUNTER_LOG'},
			CHKROOTKIT_LOG => $main::imscpConfig{'CHKROOTKIT_LOG'},
			PEAR_DIR => $main::imscpConfig{'PEAR_DIR'},
			OTHER_ROOTKIT_LOG => ($main::imscpConfig{'OTHER_ROOTKIT_LOG'} ne '')
				? ":$main::imscpConfig{'OTHER_ROOTKIT_LOG'}" : ''
		}
	);

	# Build 00_master.conf file
	$rs = $httpd->buildConfFile("$self->{cfgDir}/00_master.conf");
	return $rs if $rs;

	iMSCP::File->new(
		filename => "$self->{wrkDir}/00_master.conf"
	)->copyFile(
		"$self::apacheConfig{'APACHE_SITES_DIR'}/00_master.conf"
	) and return 1;

	# Build 00_master_ssl.conf file
	$rs = $httpd->buildConfFile("$self->{cfgDir}/00_master_ssl.conf");
	return $rs if $rs;

	iMSCP::File->new(
		filename => "$self->{wrkDir}/00_master_ssl.conf"
	)->copyFile(
		"$self::apacheConfig{'APACHE_SITES_DIR'}/00_master_ssl.conf"
	) and return 1;

	# Enable and disable vhost files
	if($main::imscpConfig{'SSL_ENABLED'} eq 'yes') {
		$rs = $httpd->enableSite('00_master.conf 00_master_ssl.conf');
		return $rs if $rs;
	} else {
		$rs = $httpd->enableSite('00_master.conf');
        return $rs if $rs;

		$rs = $httpd->disableSite('00_master_ssl.conf');
		return $rs if $rs;
	}

	iMSCP::HooksManager->getInstance()->trigger('afterHttpdBuildMasterVhostFiles');
}

sub installLogrotate
{
	my $self = shift;

	iMSCP::HooksManager->getInstance()->trigger('beforeHttpdInstallLogrotate') and return 1;

	use Servers::httpd;

	my $httpd = Servers::httpd::apache_fcgi->new();

	my $rs = $httpd->buildConfFile('logrotate.conf');
	return $rs if $rs;

	$rs = $httpd->installConfFile(
		'logrotate.conf',
		{ destination => "$main::imscpConfig{LOGROTATE_CONF_DIR}/apache2" }
	);
	return $rs if $rs;

	iMSCP::HooksManager->getInstance()->trigger('afterHttpdInstallLogrotate');
}

1;
