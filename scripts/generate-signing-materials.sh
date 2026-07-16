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

# 步骤5: 创建 Profile 模板 JSON
cat > signing/profile-template.json << 'EOF'
{
  "version": "1.0.0",
  "app-name": "md3music",
  "app-type": "release",
  "bundle-name": "com.md3music.harmonyos",
  "development-time": "2026-01-01 00:00:00",
  "distribution-type": "os_shared",
  "app-distribution-type": "app_gallery",
  "uuid": "00000000-0000-0000-0000-000000000000",
  "validity": {
    "not-before": "2026-01-01 00:00:00",
    "not-after": "2036-01-01 00:00:00"
  },
  "type": "release",
  "app-feature": "hos_app"
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
