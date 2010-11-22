#!/usr/bin/perl

# i-MSCP a internet Multi Server Control Panel
#
# Copyright (C) 2001-2006 by moleSoftware GmbH - http://www.molesoftware.com
# Copyright (C) 2006-2010 by isp Control Panel - http://ispcp.net
# Copyright (C) 2010 by internet Multi Server Control Panel - http://i-mscp.net
#
# Version: $Id$
#
# The contents of this file are subject to the Mozilla Public License
# Version 1.1 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
# License for the specific language governing rights and limitations
# under the License.
#
# The Original Code is "VHCS - Virtual Hosting Control System".
#
# The Initial Developer of the Original Code is moleSoftware GmbH.
# Portions created by Initial Developer are Copyright (C) 2001-2006
# by moleSoftware GmbH. All Rights Reserved.
#
# Portions created by the ispCP Team are Copyright (C) 2006-2010 by
# isp Control Panel. All Rights Reserved.
#
# Portions created by the i-MSCP Team are Copyright (C) 2010 by
# internet Multi Server Control Panel. All Rights Reserved.
#
# The i-MSCP Home Page is:
#
#    http://i-mscp.net
#

use strict;
use warnings;

# Hide the "used only once: possible typo" warnings
no warnings 'once';

$main::engine_debug = undef;

require 'imscp_common_methods.pl';
require 'imscp-db-keys.pl';

################################################################################
# Load i-MSCP configuration from the imscp.conf file

if(-e '/usr/local/etc/imscp/imscp.conf'){
	$main::cfg_file = '/usr/local/etc/imscp/imscp.conf';
} else {
	$main::cfg_file = '/etc/imscp/imscp.conf';
}

my $rs = get_conf($main::cfg_file);
die("FATAL: Can't load the imscp.conf file") if($rs != 0);

################################################################################
# Enable debug mode if needed
if ($main::cfg{'DEBUG'} != 0) {
	$main::engine_debug = '_on_';
}

################################################################################
# Generating i-MSCP Db key and initialization vector if needed
#
if ($main::db_pass_key eq '{KEY}' || $main::db_pass_iv eq '{IV}') {

	print STDOUT "\tGenerating database keys, it may take some time, please ".
		"wait...\n";

	print STDOUT "\tIf it takes to long, please check: ".
	 "http://i-mscp.net/documentation/frequently_asked_questions/what".
	 "_does_generating_database_keys_it_may_take_some_time_please_wait..._on_".
	 "setup_mean\n";

	$rs = sys_command(
		"perl $main::cfg{'ROOT_DIR'}/keys/rpl.pl " .
		"$main::cfg{'GUI_ROOT_DIR'}/include/imscp-db-keys.php " .
		"$main::cfg{'ROOT_DIR'}/engine/imscp-db-keys.pl " .
		"$main::cfg{'ROOT_DIR'}/engine/messenger/imscp-db-keys.pl"
	);

	die('FATAL: Error during database keys generation!') if ($rs != 0);

	do 'imscp-db-keys.pl';
}

################################################################################
# Lock file system variables
#
$main::lock_file = $main::cfg{'MR_LOCK_FILE'};
$main::fh_lock_file = undef;

$main::log_dir = $main::cfg{'LOG_DIR'};
$main::root_dir = $main::cfg{'ROOT_DIR'};

$main::imscp = "$main::log_dir/imscp-rqst-mngr.el";

################################################################################
# imscp_rqst_mngr variables
#
$main::imscp_rqst_mngr = "$main::root_dir/engine/imscp-rqst-mngr";
$main::imscp_rqst_mngr_el = "$main::log_dir/imscp-rqst-mngr.el";
$main::imscp_rqst_mngr_stdout = "$main::log_dir/imscp-rqst-mngr.stdout";
$main::imscp_rqst_mngr_stderr = "$main::log_dir/imscp-rqst-mngr.stderr";

################################################################################
# imscp_dmn_mngr variables
#
$main::imscp_dmn_mngr = "$main::root_dir/engine/imscp-dmn-mngr";
$main::imscp_dmn_mngr_el = "$main::log_dir/imscp-dmn-mngr.el";
$main::imscp_dmn_mngr_stdout = "$main::log_dir/imscp-dmn-mngr.stdout";
$main::imscp_dmn_mngr_stderr = "$main::log_dir/imscp-dmn-mngr.stderr";

################################################################################
# imscp_sub_mngr variables
#
$main::imscp_sub_mngr = "$main::root_dir/engine/imscp-sub-mngr";
$main::imscp_sub_mngr_el = "$main::log_dir/imscp-sub-mngr.el";
$main::imscp_sub_mngr_stdout = "$main::log_dir/imscp-sub-mngr.stdout";
$main::imscp_sub_mngr_stderr = "$main::log_dir/imscp-sub-mngr.stderr";

################################################################################
# imscp_alssub_mngr variables
#
$main::imscp_alssub_mngr = "$main::root_dir/engine/imscp-alssub-mngr";
$main::imscp_alssub_mngr_el = "$main::log_dir/imscp-alssub-mngr.el";
$main::imscp_alssub_mngr_stdout = "$main::log_dir/imscp-alssub-mngr.stdout";
$main::imscp_alssub_mngr_stderr = "$main::log_dir/imscp-alssub-mngr.stderr";

################################################################################
# imscp_als_mngr variables
#
$main::imscp_als_mngr = "$main::root_dir/engine/imscp-als-mngr";
$main::imscp_als_mngr_el = "$main::log_dir/imscp-als-mngr.el";
$main::imscp_als_mngr_stdout = "$main::log_dir/imscp-als-mngr.stdout";
$main::imscp_als_mngr_stderr = "$main::log_dir/imscp-als-mngr.stderr";

################################################################################
# imscp_mbox_mngr variables
#
$main::imscp_mbox_mngr = "$main::root_dir/engine/imscp-mbox-mngr";
$main::imscp_mbox_mngr_el = "$main::log_dir/imscp-mbox-mngr.el";
$main::imscp_mbox_mngr_stdout = "$main::log_dir/imscp-mbox-mngr.stdout";
$main::imscp_mbox_mngr_stderr = "$main::log_dir/imscp-mbox-mngr.stderr";

################################################################################
# imscp_serv_mngr variables
#
$main::imscp_serv_mngr = "$main::root_dir/engine/imscp-serv-mngr";
$main::imscp_serv_mngr_el = "$main::log_dir/imscp-serv-mngr.el";
$main::imscp_serv_mngr_stdout = "$main::log_dir/imscp-serv-mngr.stdout";
$main::imscp_serv_mngr_stderr = "$main::log_dir/imscp-serv-mngr.stderr";

################################################################################
# imscp_net_interfaces_mngr variables
#
$main::imscp_net_interfaces_mngr = "$main::root_dir/engine/tools/imscp-net-interfaces-mngr";
$main::imccp_net_interfaces_mngr_el = "$main::log_dir/imscp-net-interfaces-mngr.el";
$main::imscp_net_interfaces_mngr_stdout = "$main::log_dir/imscp-net-interfaces-mngr.log";

################################################################################
# imscp_htaccess_mngr variables
#
$main::imscp_htaccess_mngr = "$main::root_dir/engine/imscp-htaccess-mngr";
$main::imscp_htaccess_mngr_el = "$main::log_dir/imscp-htaccess-mngr.el";
$main::imscp_htaccess_mngr_stdout = "$main::log_dir/imscp-htaccess-mngr.stdout";
$main::imscp_htaccess_mngr_stderr = "$main::log_dir/imscp-htaccess-mngr.stderr";

################################################################################
# imscp_htusers_mngr variables
#
$main::imscp_htusers_mngr = "$main::root_dir/engine/imscp-htusers-mngr";
$main::imscp_htusers_mngr_el = "$main::log_dir/imscp-htusers-mngr.el";
$main::imscp_htusers_mngr_stdout = "$main::log_dir/imscp-htusers-mngr.stdout";
$main::imscp_htusers_mngr_stderr = "$main::log_dir/imscp-htusers-mngr.stderr";

################################################################################
# imscp_htgroups_mngr variables
#
$main::imscp_htgroups_mngr = "$main::root_dir/engine/imscp-htgroups-mngr";
$main::imscp_htgroups_mngr_el = "$main::log_dir/imscp-htgroups-mngr.el";
$main::imscp_htgroups_mngr_stdout = "$main::log_dir/imscp-htgroups-mngr.stdout";
$main::imscp_htgroups_mngr_stderr = "$main::log_dir/imscp-htgroups-mngr.stderr";


################################################################################
# imscp_vrl_traff variables
#
$main::imscp_vrl_traff = "$main::root_dir/engine/messenger/imscp-vrl-traff";
$main::imscp_vrl_traff_el = "$main::log_dir/imscp-vrl-traff.el";
$main::imscp_vrl_traff_stdout = "$main::log_dir/imscp-vrl-traff.stdout";
$main::imscp_vrl_traff_stderr = "$main::log_dir/imscp-vrl-traff.stderr";

################################################################################
# imscp_httpd_logs variables
#
$main::imscp_httpd_logs_mngr_el = "$main::log_dir/imscp-httpd-logs-mngr.el";
$main::imscp_httpd_logs_mngr_stdout = "$main::log_dir/imscp-httpd-logs-mngr.stdout";
$main::imscp_httpd_logs_mngr_stderr = "$main::log_dir/imscp-httpd-logs-mngr.stderr";

################################################################################
# imscp_ftp_acc_mngr variables
#
$main::imscp_ftp_acc_mngr_el = "$main::log_dir/imscp-ftp-acc-mngr.el";
$main::imscp_ftp_acc_mngr_stdout = "$main::log_dir/imscp-ftp-acc-mngr.stdout";
$main::imscp_ftp_acc_mngr_stderr = "$main::log_dir/imscp-ftp-acc-mngr.stderr";

$main::imscp_bk_task_el = "$main::log_dir/imscp-bk-task.el";
$main::imscp_srv_traff_el = "$main::log_dir/imscp-srv-traff.el";
$main::imscp_dsk_quota_el = "$main::log_dir/imscp-dsk-quota.el";

################################################################################
# imscp_apps-installer_logs variables
#
$main::imscp_sw_mngr = "$main::root_dir/engine/imscp-sw-mngr";
$main::imscp_sw_mngr_el = "$main::log_dir/imscp-sw-mngr.el";
$main::imscp_sw_mngr_stdout = "$main::log_dir/imscp-sw-mngr.stdout";
$main::imscp_sw_mngr_stderr = "$main::log_dir/imscp-sw-mngr.stderr";

$main::imscp_pkt_mngr = "$main::root_dir/engine/imscp-pkt-mngr";
$main::imscp_pkt_mngr_el = "$main::log_dir/imscp-pkt-mngr.el";
$main::imscp_pkt_mngr_stdout = "$main::log_dir/imscp-pkt-mngr.stdout";
$main::imscp_pkt_mngr_stderr = "$main::log_dir/imscp-pkt-mngr.stderr";

1;
