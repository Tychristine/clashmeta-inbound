# VLESS-TLS-XHTTP-PinnedPeerCertSha256

## 入站

`xhttp-config` host保持留空字符，path随机可以把uuid字符串拼上去

## 出站

- servername: 自定义，因为Pin了子叶证书指纹不会校验
- fingerprint: 证书指纹 使用openssl x509 -noout -fingerprint -sha256 -inform pem -in yourcert.pem 获取
- xhttp-opts.host: 必填，值同servername
