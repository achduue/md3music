#!/bin/bash
set -euo pipefail
KEY_PWD="md3music_signing_password_20240101"
SIGN_TOOL=$(find / -name "hap-sign-tool.jar" 2>/dev/null | head -1)
if [ -z "$SIGN_TOOL" ]; then echo "ERROR: hap-sign-tool.jar not found"; exit 1; fi
mkdir -p signing
# 生成密钥对
java -jar "$SIGN_TOOL" generate-keypair -keyAlias "md3music-key" -keyAlg "ECC" -keySize "NIST-P-256" -keystoreFile "signing/md3music.p12" -keyPwd "$KEY_PWD" -keystorePwd "$KEY_PWD"
java -jar "$SIGN_TOOL" generate-keypair -keyAlias "md3music-ca" -keyAlg "ECC" -keySize "NIST-P-256" -keystoreFile "signing/md3music.p12" -keyPwd "$KEY_PWD" -keystorePwd "$KEY_PWD"
# 生成CA
java -jar "$SIGN_TOOL" generate-ca -keyAlias "md3music-ca" -keyAlg "ECC" -keySize "NIST-P-256" -signAlg "SHA256withECDSA" -subject "C=CN,O=MD3Music,OU=Dev,CN=MD3Music CA" -keystoreFile "signing/md3music.p12" -outFile "signing/rootCA.cer" -keyPwd "$KEY_PWD" -keystorePwd "$KEY_PWD" -validity "3650"
# 生成应用证书
java -jar "$SIGN_TOOL" generate-app-cert -keyAlias "md3music-key" -signAlg "SHA256withECDSA" -issuer "C=CN,O=MD3Music,OU=Dev,CN=MD3Music CA" -issuerKeyAlias "md3music-ca" -subject "C=CN,O=MD3Music,OU=Dev,CN=MD3Music App" -keystoreFile "signing/md3music.p12" -subCaCertFile "signing/rootCA.cer" -rootCaCertFile "signing/rootCA.cer" -outForm "certChain" -outFile "signing/md3music.pem" -keyPwd "$KEY_PWD" -keystorePwd "$KEY_PWD" -issuerKeyPwd "$KEY_PWD" -validity "3650"
# 生成profile证书
java -jar "$SIGN_TOOL" generate-keypair -keyAlias "md3music-profile-key" -keyAlg "ECC" -keySize "NIST-P-256" -keystoreFile "signing/md3music.p12" -keyPwd "$KEY_PWD" -keystorePwd "$KEY_PWD"
java -jar "$SIGN_TOOL" generate-profile-cert -keyAlias "md3music-profile-key" -signAlg "SHA256withECDSA" -issuer "C=CN,O=MD3Music,OU=Dev,CN=MD3Music CA" -issuerKeyAlias "md3music-ca" -subject "C=CN,O=MD3Music,OU=Dev,CN=MD3Music Profile" -keystoreFile "signing/md3music.p12" -subCaCertFile "signing/rootCA.cer" -rootCaCertFile "signing/rootCA.cer" -outForm "certChain" -outFile "signing/md3music-profile.pem" -keyPwd "$KEY_PWD" -keystorePwd "$KEY_PWD" -issuerKeyPwd "$KEY_PWD" -validity "3650"
# 提取证书用于profile
node -e "
const fs = require('fs');
const cert = fs.readFileSync('signing/md3music.pem', 'utf-8');
const first = cert.split('-----END CERTIFICATE-----')[0] + '-----END CERTIFICATE-----\n';
const profile = {
  'version-name': '1.0.0', 'version-code': 1, 'app-distribution-type': 'os_integration',
  'uuid': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'validity': { 'not-before': 1594865258, 'not-after': 1893456000 },
  'type': 'release',
  'bundle-info': { 'developer-id': 'MD3Music', 'distribution-certificate': first, 'bundle-name': 'com.md3music.harmonyos', 'apl': 'normal', 'app-feature': 'hos_app' },
  'acls': { 'allowed-acls': [''] },
  'permissions': { 'restricted-permissions': [] },
  'issuer': 'pki_internal'
};
fs.writeFileSync('signing/profile-template.json', JSON.stringify(profile, null, 2));
"
# 签名profile
java -jar "$SIGN_TOOL" sign-profile -keyAlias "md3music-profile-key" -signAlg "SHA256withECDSA" -mode "localSign" -profileCertFile "signing/md3music-profile.pem" -inFile "signing/profile-template.json" -keystoreFile "signing/md3music.p12" -outFile "signing/md3music.p7b" -keyPwd "$KEY_PWD" -keystorePwd "$KEY_PWD"
cp signing/md3music.pem signing/md3music.cer
echo "=== Signing materials generated ==="
ls -la signing/