#!/bin/bash
#================================================================
# Let's Encrypt renewal script for Apache on CentOS
# @author Erika Heidi<erika@do.co>
# Mucked around by: Dave Fuller 
# Usage: ./le-renew.sh [base-domain-name]
# More info: http://do.co/1mbVihI
#================================================================
domain=$1
le_path='/home/ec2-user/letsencrypt'
le_conf='/etc/letsencrypt'
exp_limit=30;

do_log () {
        type=$1
        msg=$2
        TS=$(date --rfc-3339=seconds)
        echo "$TS [$1]: $msg"
}

error () {
        do_log ERROR "$1"
}

info () {
        do_log INFO "$1"
}
get_domain_list(){
        certdomain=$1
        config_file="$le_conf/renewal/${certdomain}.conf"
        
        if [ ! -f $config_file ] ; then
                error "The config file for the certificate ${certdomain} was not found."
                exit 1;
        fi
        sed -re '/domains.=/!d;s/(domains.=.|,(\s*)*$)//g' "${config_file}"
}

if [ -z "$domain" ] ; then
        error "you must provide the domain name for the certificate renewal."
        exit 1;
fi

cert_file="${le_conf}/live/${domain}/fullchain.pem"

if [ ! -f $cert_file ]; then
        error "certificate file not found for domain ${domain}."
        exit 1;
fi

cert_date=$(openssl x509 -in $cert_file -text -noout|sed -e '/Not After/!d ;s/.* : //g')
exp=$(date -d "${cert_date}" +%s)
datenow=$(date -d "now" +%s)
days_exp=$((( $exp - $datenow ) / 86400 ))

info "Checking expiration date for $domain..."

if [ "$days_exp" -gt "$exp_limit" ] ; then
        info "The certificate is up to date, no need for renewal ($days_exp days left)."
        exit 0;
else
        info "The certificate for $domain is about to expire soon. Starting renewal request..."
        domain_list=$( get_domain_list $domain )
        "$le_path"/letsencrypt-auto certonly --apache --renew-by-default --domains "${domain_list}"
        info "Restarting Apache..."
        service httpd restart
        info "Renewal process finished for domain $domain"
        exit 0;
fi
