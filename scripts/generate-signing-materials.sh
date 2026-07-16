#!/bin/bash
set -euo pipefail

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
  -keyPwd "123456" \
  -keystorePwd "123456"

# 步骤2: 生成 CA 证书 (需要先为CA生成密钥对)
java -jar "$SIGN_TOOL" generate-keypair \
  -keyAlias "md3music-ca" \
  -keyAlg "ECC" \
  -keySize "NIST-P-256" \
  -keystoreFile "signing/md3music.p12" \
  -keyPwd "123456" \
  -keystorePwd "123456"

java -jar "$SIGN_TOOL" generate-ca \
  -keyAlias "md3music-ca" \
  -keyAlg "ECC" \
  -keySize "NIST-P-256" \
  -signAlg "SHA256withECDSA" \
  -subject "C=CN,O=MD3Music,OU=Dev,CN=MD3Music CA" \
  -keystoreFile "signing/md3music.p12" \
  -outFile "signing/rootCA.cer" \
  -keyPwd "123456" \
  -keystorePwd "123456" \
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
  -keyPwd "123456" \
  -keystorePwd "123456" \
  -issuerKeyPwd "123456" \
  -validity "3650"

# 步骤4: 生成 Profile 签名证书 (需要先为profile生成密钥对)
java -jar "$SIGN_TOOL" generate-keypair \
  -keyAlias "md3music-profile-key" \
  -keyAlg "ECC" \
  -keySize "NIST-P-256" \
  -keystoreFile "signing/md3music.p12" \
  -keyPwd "123456" \
  -keystorePwd "123456"

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
  -keyPwd "123456" \
  -keystorePwd "123456" \
  -issuerKeyPwd "123456" \
  -validity "3650"

# 步骤5: 从应用证书中提取 distribution-certificate (base64编码)
# PEM 文件中第一个证书的 base64 内容（去掉 BEGIN/END 标记）
DIST_CERT=$(awk '/-----BEGIN CERTIFICATE-----/{c++} c==1{print} /-----END CERTIFICATE-----/{if(c==1)exit}' signing/md3music.pem \
  | sed '/-----BEGIN/d;/-----END/d' | tr -d '\n')
echo "Distribution cert length: ${#DIST_CERT}"

# 创建 Profile 模板 JSON (使用官方 OpenHarmony 格式: kebab-case)
# 注意: 使用不带引号的 EOF 以便变量展开
cat > signing/profile-template.json << EOF
{
  "version-name": "1.0.0",
  "version-code": 1,
  "app-distribution-type": "os_integration",
  "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "validity": {
    "not-before": 1594865258,
    "not-after": 1893456000
  },
  "type": "release",
  "bundle-info": {
    "developer-id": "MD3Music",
    "distribution-certificate": "${DIST_CERT}",
    "bundle-name": "com.md3music.harmonyos",
    "apl": "normal",
    "app-feature": "hos_app"
  },
  "acls": {
    "allowed-acls": [""]
  },
  "permissions": {
    "restricted-permissions": []
  },
  "issuer": "pki_internal"
}
EOF

# 步骤6: 签名 Profile 生成 .p7b
java -jar "$SIGN_TOOL" sign-profile \
  -keyAlias "md3music-profile-key" \
  -signAlg "SHA256withECDSA" \
  -mode "localSign" \
  -profileCertFile "signing/md3music-profile.pem" \
  -inFile "signing/profile-template.json" \
  -keystoreFile "signing/md3music.p12" \
  -outFile "signing/md3music.p7b" \
  -keyPwd "123456" \
  -keystorePwd "123456"

# 步骤7: 将 PEM 证书链转为 .cer (取第一个证书)
# 实际上 hap-sign-tool 的 generate-app-cert 输出的 pem 就是证书链
# build-profile.json5 的 certPath 可以指向 .pem 文件
cp signing/md3music.pem signing/md3music.cer

echo "=== Signing materials generated ==="
ls -la signing/
