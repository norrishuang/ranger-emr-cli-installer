#!/bin/bash

configCA() {
    printHeading "GENERATE CA FOR TRINO"
    if [[ "$AUTH_PROVIDER" = "openldap" ]]; then
        generateCAForTrino
    elif [[ "$AUTH_PROVIDER" = "ad" && "$SOLUTION" = "open-source" ]]; then
        # installSssdPackagesForAd
        # joinRealm
        print 'Not implement, wait.'
    fi
    # configSshdForSssd
    # restartSssdRelatedServices
}

generateCAForTrino() {
    for node in $(getEmrMasterNodes); do
        echo "send shell script to master nodes"
        scp -o StrictHostKeyChecking=no -i $SSH_KEY $APP_HOME/bin/set_trino_ldap.sh hadoop@"${node}":/home/hadoop/
        echo "set trino configuration of ldap"
        ssh -o StrictHostKeyChecking=no -i "${SSH_KEY}" -T hadoop@"${node}" <<EOSSH
sudo su - root
sh /home/hadoop/set_trino_ldap.sh
EOSSH
    done
}
