#!/bin/bash
set -euo pipefail

# 密码（至少32字符）
KEY_PWD="md3music_signing_password_20240101"

# 查找 hap-sign-tool.jar
SIGN_TOOL=$(find / -name "hap-sign-tool.jar" 2>/dev/null | head -1)
if [ -z "$SIGN_TOOL" ]; then
    echo "ERROR: hap-sign-tool.jar not found"
    exit 1
fi
echo "Found hap-sign-tool: $SIGN_TOOL"

mkdir -p signing

# 步骤1: 生成密钥对到 .p12
java -jar "$SIGN_TOOL" generate-keypair \
  -keyAlias "md3music-key" \
  -keyAlg "ECC" \
  -keySize "NIST-P-256" \
  -keystoreFile "signing/md3music.p12" \
  -keyPwd "$KEY_PWD" \
  -keystorePwd "$KEY_PWD"

# 步骤2: 生成 CA 证书 (需要先为CA生成密钥对)
java -jar "$SIGN_TOOL" generate-keypair \
  -keyAlias "md3music-ca" \
  -keyAlg "ECC" \
  -keySize "NIST-P-256" \
  -keystoreFile "signing/md3music.p12" \
  -keyPwd "$KEY_PWD" \
  -keystorePwd "$KEY_PWD"

java -jar "$SIGN_TOOL" generate-ca \
  -keyAlias "md3music-ca" \
  -keyAlg "ECC" \
  -keySize "NIST-P-256" \
  -signAlg "SHA256withECDSA" \
  -subject "C=CN,O=MD3Music,OU=Dev,CN=MD3Music CA" \
  -keystoreFile "signing/md3music.p12" \
  -outFile "signing/rootCA.cer" \
  -keyPwd "$KEY_PWD" \
  -keystorePwd "$KEY_PWD" \
  -validity "3650"

# 步骤3: 生成应用签名证书
java -jar "$SIGN_TOOL" generate-app-cert \
  -keyAlias "md3music-key" \
  -signAlg "SHA256withECDSA" \
  -issuer "C=CN,O=MD3Music,OU=Dev,CN=MD3Music CA" \
  -issuerKeyAlias "md3music-ca" \
  -subject "C=CN,O=MD3Music,OU=Dev,CN=MD3Music App" \
  -keystoreFile "signing/md3music.p12" \
  -subCaCertFile "signing/rootCA.cer" \
  -rootCaCertFile "signing/rootCA.cer" \
  -outForm "certChain" \
  -outFile "signing/md3music.pem" \
  -keyPwd "$KEY_PWD" \
  -keystorePwd "$KEY_PWD" \
  -issuerKeyPwd "$KEY_PWD" \
  -validity "3650"

# 步骤4: 生成 Profile 签名证书 (需要先为profile生成密钥对)
java -jar "$SIGN_TOOL" generate-keypair \
  -keyAlias "md3music-profile-key" \
  -keyAlg "ECC" \
  -keySize "NIST-P-256" \
  -keystoreFile "signing/md3music.p12" \
  -keyPwd "$KEY_PWD" \
  -keystorePwd "$KEY_PWD"

java -jar "$SIGN_TOOL" generate-profile-cert \
  -keyAlias "md3music-profile-key" \
  -signAlg "SHA256withECDSA" \
  -issuer "C=CN,O=MD3Music,OU=Dev,CN=MD3Music CA" \
  -issuerKeyAlias "md3music-ca" \
  -subject "C=CN,O=MD3Music,OU=Dev,CN=MD3Music Profile" \
  -keystoreFile "signing/md3music.p12" \
  -subCaCertFile "signing/rootCA.cer" \
  -rootCaCertFile "signing/rootCA.cer" \
  -outForm "certChain" \
  -outFile "signing/md3music-profile.pem" \
  -keyPwd "$KEY_PWD" \
  -keystorePwd "$KEY_PWD" \
  -issuerKeyPwd "$KEY_PWD" \
  -validity "3650"

# 步骤5: 使用 Node.js 生成 Profile 模板 JSON
# 按照官方 autosign.py 的方式，distribution-certificate 使用完整 PEM 内容（含 BEGIN/END 标记）
node -e "
const fs = require('fs');

// 读取应用证书 PEM 文件
const certContent = fs.readFileSync('signing/md3music.pem', 'utf-8');

// 提取第一个证书块（包含 BEGIN/END 标记）
const firstCert = certContent.split('-----END CERTIFICATE-----')[0] + '-----END CERTIFICATE-----\n';

// 构建 profile 模板
const profile = {
  'version-name': '1.0.0',
  'version-code': 1,
  'app-distribution-type': 'os_integration',
  'uuid': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'validity': {
    'not-before': 1594865258,
    'not-after': 1893456000
  },
  'type': 'release',
  'bundle-info': {
    'developer-id': 'MD3Music',
    'distribution-certificate': firstCert,
    'bundle-name': 'com.md3music.harmonyos',
    'apl': 'normal',
    'app-feature': 'hos_app'
  },
  'acls': {
    'allowed-acls': ['']
  },
  'permissions': {
    'restricted-permissions': []
  },
  'issuer': 'pki_internal'
};

// 写入 JSON 文件
fs.writeFileSync('signing/profile-template.json', JSON.stringify(profile, null, 2));
console.log('Profile template created. distribution-certificate length: ' + firstCert.length);
"

# 步骤6: 签名 Profile 生成 .p7b
java -jar "$SIGN_TOOL" sign-profile \
  -keyAlias "md3music-profile-key" \
  -signAlg "SHA256withECDSA" \
  -mode "localSign" \
  -profileCertFile "signing/md3music-profile.pem" \
  -inFile "signing/profile-template.json" \
  -keystoreFile "signing/md3music.p12" \
  -outFile "signing/md3music.p7b" \
  -keyPwd "$KEY_PWD" \
  -keystorePwd "$KEY_PWD"

# 步骤7: 将 PEM 证书链复制为 .cer
cp signing/md3music.pem signing/md3music.cer

echo "=== Signing materials generated ==="
ls -la signing/
