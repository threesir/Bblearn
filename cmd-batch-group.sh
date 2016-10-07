#######################################################################
#!/bin/bash
## cmd-batch-group.sh 
## --------------------------------------------------------------------
## A script to run batch group (group manager application) for the
## purpose of (a) create/update groups, (b) remove groups, (c) create/
## update group memberships and (d) remove group memberships.
##
## Note the internal dependencies orders:
## a. Delete Group Memberships
## b. Delete Groups
## c. Create/Update Group Memberships
## d. Create/Update Groups
## --------------------------------------------------------------------
## History:
## 12-07-30 (Raymond): Creation of script for Ramesh java program.
#######################################################################


## Check parameter passing and set email list.
case "$1" in
  "prd")
    v_env="prd"
    v_email_smtp="mail.nyp.edu.sg"
    v_email_from="bblearn@nyp.edu.sg"
    # v_email_to="nyp_bbmain@nyp.edu.sg, sharad_vhosur@nyp.gov.sg, chewray.beenet@gmail.com"
    v_email_to="NYP-CNC-bbmain@nyp.edu.sg, sharad_vhosur@nyp.gov.sg, chewray.beenet@gmail.com"
    v_email_cc="joey_lee@nyp.gov.sg, son_wei_meng@nyp.gov.sg, arockiarajsavarinathan@bee-net.com"
    # v_email_to="chewray.beenet@gmail.com"
    # v_email_cc="rameshshanmugam@bee-net.com"
    ;;
  "uat")
    v_env="uat"
    v_email_smtp="mail.nyp.edu.sg"
    v_email_from="bblearn@nyp.edu.sg"
    v_email_to="NYP-CNC-bbmain@nyp.edu.sg"
    v_email_cc="chewray.beenet@gmail.com, arockiarajsavarinathan@bee-net.com"
    ;;
  "stg")
    v_env="stg"
    v_email_smtp="mail.nyp.edu.sg"
    v_email_from="bblearn@nyp.edu.sg"
    v_email_to="NYP-CNC-bbmain@nyp.edu.sg"
    v_email_cc="chewray.beenet@gmail.com"
    ;;
  "dev")
    v_env="dev"
    v_email_smtp="mail.nyp.edu.sg"
    v_email_from="bblearn@nyp.edu.sg"
    v_email_to="NYP-CNC-bbmain@nyp.edu.sg"
    v_email_cc="chewray.beenet@gmail.com"
    ;;
  "vm")
    v_env="vm"
    v_email_smtp=""
    v_email_from="chewray.beenet@gmail.com"
    v_email_to="chewray.beenet@gmail.com"
    v_email_cc=""
    ;;
  *)
    echo "Use the correct input 1 parameter as in:"
    echo "  [command]# $0 input1"
    echo "    input1 = prd, uat, stg, dev, vm"
   exit
esac

## Determine program controlled variables.
v_mntpt=`echo "/bb$v_env""_custom"`
v_uname=`uname -n`
v_host="$v_uname.nyp.edu.sg"
if [ $1 == "vm" ]; then
  v_mntpt="/bbprd_custom"
  v_uname="bbprd01"
  v_host="bbprd01.nyp.edu.sg"
fi
if [ ! -d $v_mntpt ]; then
  echo "Use the correct environment instead of [$1], exit script ..."
  exit
fi
v_today=`eval date +%Y%m%d`
v_time_stamp=`eval date +%H%M`
v_send_mail="$v_mntpt/util/sendEmail/sendEmail.pl"
v_bb_dir="/usr/local/blackboard"
v_bb_cfg="$v_bb_dir/config/bb-config.properties"
v_ftp_dir="$v_mntpt/bbftp/batch_group"
v_cfg_dir="$v_mntpt/batch_group/config"
v_cfg_file="$v_cfg_dir/$v_env-batch-group.properties"
v_dat_dir="$v_mntpt/batch_group/data"
v_log_base_dir="$v_dat_dir/$v_today"
v_log_dir="$v_log_base_dir/$v_time_stamp"
v_log="$v_log_dir/batch_group_runtime.log"
v_run_log="$v_dat_dir/$v_env-batch-group-run.log"
v_prefix="$v_today-$v_time_stamp-"
v_run_html="$v_log_dir/batch-group-report.html"
v_run_xls="$v_log_dir/batch-group-run.xls"
v_jar_prg="$v_mntpt/batch_group/bin/groupmanager.jar"
v_max_log=31


## Function to get Blackboard config property.
function f_get_bbconfig_property {
  v_property=$1
  grep "^$v_property=" $v_bb_cfg | cut -d= -f2 | tr -d "\r"
}

## Get required Blackboard config properties.
v_bbadmin=`f_get_bbconfig_property bbconfig.database.admin.name`
v_bbadmin_pwd=`f_get_bbconfig_property bbconfig.database.admin.password`

## Setting up the common Blackboard environment settings.
source /usr/local/blackboard/apps/snapshot/config/env.sh

## Extra program link for creating XLS file.
CP=$CP:$BBLIB/poi/poi-3.7-20101029.jar

## Forming the execution strings.
CP=$CP:$v_jar_prg
OPTS=""
OPTS="$OPTS -Dblackboard.home=$BBDIR"
OPTS="$OPTS -Dfile.encoding=UTF8"
OPTS="$OPTS -cp $CP"
OPTS="$OPTS -Djava.security.egd=file:///dev/urandom"
## OPTS="$OPTS gm.BbCourseGroupMemberManagement $v_env $v_bbadmin $v_bbadmin_pwd $v_prefix $v_host $v_cfg_file $v_dat_dir $v_log_dir"
OPTS="$OPTS gm.BbCourseGroupMemberManagement $v_env $v_bbadmin $v_bbadmin_pwd $v_prefix $v_host $v_cfg_file $v_dat_dir"


### Perform base checks -----------------------------------------------
function f_base_check {
  ## Check if log base directory exist and create one if not.
  if [ ! -e $v_log_base_dir ]; then
    mkdir $v_log_base_dir
  fi

  ## Check if log directory exist and create one if not.
  if [ ! -e $v_log_dir ]; then
    mkdir $v_log_dir
  fi

  ## Check if run log file exist.
  if [ ! -e $v_run_log ]; then
    echo $v_today > "$v_run_log"
  fi

  ## Move batch group files to the target directory.
  # cp $v_ftp_dir/grp*.txt $v_log_dir/.
  mv $v_ftp_dir/grp*.txt $v_log_dir/.
}


### Perform house-keeping ---------------------------------------------
function f_hs_keep {
  v_line_cnt=0
  v_run_already="false"

  ## Check if current batch group run already captured and number of logs.
  while read v_line_in ; do
    v_line_cnt=$((v_line_cnt+1))
    if [ $v_line_in -eq $v_today ]; then
      v_run_already="true"
    fi
  done < $v_run_log

  ## Check if need to continue with house-keeping.
  if [ $v_run_already == "false" ]; then
    ## Append today into log to identify run.
    echo "$v_today" >> $v_run_log

    ## Check if reach max log.
    if [ $v_line_cnt -ge $v_max_log ]; then
      v_line_cnt=0
      v_discard="false"

      ## Remove the 1st line from log.
      while read v_line_in ; do
        v_line_cnt=$((v_line_cnt+1))
        if [ $v_line_cnt -eq 1 ]; then
          v_discard="true"
          rm -rf $v_dat_dir/$v_line_in
        else
          echo "$v_line_in" >> $v_run_log.tmp
        fi
      done < $v_run_log

      ## Swap with temp file.
      if [ $v_discard == "true" ]; then
        mv $v_run_log.tmp $v_run_log
      fi
    fi
  fi
}


### Email Result ------------------------------------------------------
function f_email_result {
  ## Email batch group run result.
  if [ $v_env == "vm" ]; then
    $v_send_mail -f $v_email_from -t "$v_email_to" -cc "$v_email_cc" -u "[Bb-NYP] Batch Group Run@$v_env-$v_uname" -o message-file="$v_run_html" -a "$v_run_xls"
  else
    $v_send_mail -f $v_email_from -t "$v_email_to" -cc "$v_email_cc" -u "[Bb-NYP] Batch Group Run@$v_env-$v_uname" -s $v_email_smtp -o message-file="$v_run_html" -a "$v_run_xls"
  fi
}


### Main program ------------------------------------------------------
## Perform base checks.
f_base_check

## Capture the main start time.
v_main_hr1=`eval date +%H`
v_main_min1=`eval date +%M`
v_main_sec1=`eval date +%S`
echo "Start time = $v_main_hr1:$v_main_min1:$v_main_sec1" > $v_log

## Execute the batch group application program.
$JAVA_EXEC $OPTS

## Perform house-keeping.
f_hs_keep

## Capture the main end time.
v_main_hr2=`eval date +%H`
v_main_min2=`eval date +%M`
v_main_sec2=`eval date +%S`
echo "End time   = $v_main_hr2:$v_main_min2:$v_main_sec2" >> $v_log

v_main_secs=$(echo "$v_main_hr2 * 3600 + $v_main_min2 * 60 + $v_main_sec2 - ($v_main_hr1 * 3600 + $v_main_min1 * 60 + $v_main_sec1)" | bc)

if [ "$v_main_secs" -lt 0 ] ; then
  ((v_main_secs=v_main_secs+86400))
fi

## Determine the lapse time.
v_main_hr3=$(expr $v_main_secs / 3600)
v_main_min3=$(expr \( $v_main_secs - $v_main_hr3 \* 3600 \) / 60)
v_main_sec3=$(expr $v_main_secs - $v_main_hr3 \* 3600 - $v_main_min3 \* 60)
echo "Lapse time = $v_main_hr3:$v_main_min3:$v_main_sec3 or [$v_main_secs] secs" >> $v_log

## Append runtime log to html file.
cat $v_log >> $v_run_html

## Email Result.
f_email_result

#######################################################################
## End of script.
#######################################################################
