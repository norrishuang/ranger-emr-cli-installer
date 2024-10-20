mkdir -p /mnt/demoCA && cd /mnt/demoCA
# get ip address
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
local_ipv4=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4) 
local_hostname=$(hostname)
local_hostname_long=$(hostname -f)

cat << EOF > openssl.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
countryName = US
countryName_default = US
stateOrProvinceName = California
stateOrProvinceName_default = California
localityName = San Francisco
localityName_default = San Francisco
organizationName = My Company
organizationName_default = My Company
organizationalUnitName = IT Department
organizationalUnitName_default = IT Department
commonName = ${local_hostname}
commonName_max = 64

[v3_req]
basicConstraints = CA:TRUE
subjectAltName = @alt_names

[alt_names]
IP.1 = ${local_ipv4}
DNS.1 = ${local_hostname}
DNS.2 = ${local_hostname_long}
EOF

#创建 CA 目录结构
mkdir -p /mnt/demoCA/{private,newcerts}
touch /mnt/demoCA/index.txt
echo 01 > /mnt/demoCA/serial
# 生成 CA 的 RSA 密钥对
PASSWORD="1234"
openssl genrsa -des3 -out /mnt/demoCA/private/cakey.pem -passout pass:"${PASSWORD}" 2048

# 自签发 CA 证书
PASSWORD="1234"
local_hostname=$(hostname)
SUBJECT="/C=US/ST=California/L=San Francisco/O=My Company/OU=IT/Department/CN=${local_hostname}"
openssl req -new -x509 -days 365 -key /mnt/demoCA/private/cakey.pem -passin pass:"${PASSWORD}" -out /mnt/demoCA/cacert.pem -extensions v3_req -config /mnt/demoCA/openssl.cnf -subj "${SUBJECT}"
# 查看证书内容
openssl x509 -in /mnt/demoCA/cacert.pem -noout -text
# 设置输入密码（cakey.pem的密码）
IN_PASSWORD="1234"
# 设置输出密码（生成的P12文件的密码）
OUT_PASSWORD="1234"
# 生成PKCS12文件
openssl pkcs12 -inkey /mnt/demoCA/private/cakey.pem -in /mnt/demoCA/cacert.pem -export -out /mnt/demoCA/certificate.p12 -passin pass:"${IN_PASSWORD}" -passout pass:"$OUT_PASSWORD"
# 默认密码通常为"changeit"
KEYSTORE_PASSWORD="changeit"
ALIAS="mytrinoserver3"
CERT_FILE="/mnt/demoCA/cacert.pem"
KEYSTORE_PATH="/etc/pki/ca-trust/extracted/java/cacerts"
# 导入证书到密钥库
sudo keytool -import -alias "${ALIAS}" -file "${CERT_FILE}" -keystore "${KEYSTORE_PATH}" -storepass "${KEYSTORE_PASSWORD}" -noprompt