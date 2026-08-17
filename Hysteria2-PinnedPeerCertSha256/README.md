# Hysteria2-PinnedPeerCertSha256

**Hysteria2+PinnedPeerCertSha256**搭配，适用于自签证书

## 客户端

客户端字段`fingerprint`与**xray**的`PinnedPeerCertSha256`同作用；可使用`openssl x509 -noout -fingerprint -sha256 -inform pem -in yourcert.pem`获取，也可以通过 Chrome 浏览器的“证书查看器”中“SHA256 指纹”的“证书”项获取。
