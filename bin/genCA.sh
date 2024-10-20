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
        # shellcheck disable=SC2087
        ssh -o StrictHostKeyChecking=no -i "${SSH_KEY}" -T hadoop@"${node}" <<EOSSH
        mkdir -p /mnt/demoCA && cd /mnt/demoCA
        # get ip address
        local_ipv4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) 
        local_hostname=$(hostname)
        local_hostname_long=$(hostname -f)

        cat << EOF > openssl.cnf
        [req]
        distinguished_name = req_distinguished_name
        req_extensions = v3_req

        [req_distinguished_name]
        countryName=China
        countryName_default=CN
        stateOrProvinceName=guangdong
        stateOrProvinceName_default=gd
        localityName=shenzhen
        localityName_default=sz
        organizationName=amazon
        organizationName_default=amazon
        organizationalUnitName=aws
        organizationalUnitName_default=aws
        commonName=${local_hostname}
        commonName_max=64
        [v3_req]
        basicConstraints = CA:TRUE
        subjectAltName = @alt_names
        [alt_names]
        IP.1 = ${local_ipv4}
        DNS.1 = ${local_hostname}
        DNS.2 = ${local_hostname_long}
        EOF

        # craete CA dir
        mkdir -p /mnt/demoCA/{private,newcerts} touch /mnt/demoCA/index.txt
        echo 01 > /mnt/demoCA/serial
        # generate keypair for RSA of CA
        PASSWORD="1234"

        openssl genrsa -des3 -out /mnt/demoCA/private/cakey.pem -passout pass:"$PASSWORD" 2048
        # CA 
        PASSWORD="1234"
        local_hostname=$(hostname)
        SUBJECT="/C=US/ST=California/L=San Francisco/O=My Company/OU=IT Department/CN=${local_hostname}"
        openssl req -new -x509 -days 365 -key /mnt/demoCA/private/cakey.pem -passin pass:"$PASSWORD" -out /mnt/demoCA/cacert.pem -extensions v3_req -config /mnt/demoCA/openssl.cnf -subj "$SUBJECT"
        # 
        openssl x509 -in /mnt/demoCA/cacert.pem -noout -text # 设置输入密码(cakey.pem的密码)
        IN_PASSWORD="1234"
        # 
        OUT_PASSWORD="1234"
        # 
        openssl pkcs12 -inkey /mnt/demoCA/private/cakey.pem -in /mnt/demoCA/cacert.pem -export -out /mnt/demoCA/certificate.p12 -passin pass:"$IN_PASSWORD" -passout pass:"$OUT_PASSWORD"
        # default password -> changeit
        KEYSTORE_PASSWORD="changeit"
        ALIAS="myTrinoserver2"
        CERT_FILE="/mnt/demoCA/cacert.pem" KEYSTORE_PATH="/usr/lib/jvm/java-1.8.0/jre/lib/security/cacerts"
        # import CA cert to java keystore
        sudo keytool -import -alias "$ALIAS" -file "$CERT_FILE" -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASSWORD" -noprompt
EOSSH
    done
}
