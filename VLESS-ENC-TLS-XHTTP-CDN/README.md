# 优选CDN+Reality偷流量配置

## 前置条件

1. 域名在CloudFlare上解析DNS记录(小黄云代理流量关闭)
2. 1个有效的TLS/SSL证书，包含ACME申请的。CloudFlare Origin证书(15年)也可以
3. 代理端口监听443

## 客户端

将server修改为前置机器，端口随前置，sni为落地机器
此时流量导向为 [用户] -> [前置] -> (前置将认证失败流量转发到CloudFlare) -> (CloudFlare CDN根据SNI回源) -> [落地]
