#!/bin/bash
set -euo pipefail

# 密码（至少32字符，hvigorw 签名要求）
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

# 步骤5: 从应用证书中提取 distribution-certificate (base64编码 DER格式)
# 使用 openssl 将 PEM 证书转为 DER 格式，再 base64 编码
# 先提取 PEM 文件中的第一个证书（叶子证书）
awk '/-----BEGIN CERTIFICATE-----/{c++} c==1{print} /-----END CERTIFICATE-----/{if(c==1)exit}' \
  signing/md3music.pem > signing/leaf-cert.pem

# 使用 openssl 转为 DER 格式并 base64 编码（确保输出是纯净的 base64）
if command -v openssl &> /dev/null; then
    DIST_CERT=$(openssl x509 -in signing/leaf-cert.pem -outform DER | base64 | tr -d '\n')
    echo "Used openssl for cert conversion"
else
    # 回退方案：直接提取 PEM 中的 base64 内容
    DIST_CERT=$(sed '/-----BEGIN/d;/-----END/d;/^$/d' signing/leaf-cert.pem | tr -d '\n\r ')
    echo "Used fallback PEM extraction (openssl not found)"
fi
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
  -keyPwd "$KEY_PWD" \
  -keystorePwd "$KEY_PWD"

# 步骤7: 将 PEM 证书链复制为 .cer
cp signing/md3music.pem signing/md3music.cer

echo "=== Signing materials generated ==="
ls -la signing/
