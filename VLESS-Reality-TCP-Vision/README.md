# VLESS-Reality-Vision

> [!IMPORTANT]
> `xtls-rprx-vision` 仅在搭配["TLS+TCP"、"Reality+TCP"、"VLESS encryption"]时有效

## 配置

- uuid：通过uuid -v 4 生成随机UUID
- private key：运行mihomo generate reality-keypair生成 取Privatekey
- public key:(客户端)密码，同上取PublicKey
- short-id: 16位16进制字符串

## UUID

可安装uuid进行生成

```shell
# 安装uuid
apt install uuid -y
# 命令
uuid -v 4
```
