# higress

Sealos Cloud 的入口网关。

| | |
| --- | --- |
| chart | `higress.io/higress`，提交在 `charts/`，版本见 `charts/higress/Chart.yaml` |
| 镜像 | `ghcr.io/vlee0203/sealos-cloud-images/higress:<version>` |
| 命名空间 | `higress-system` |

| 文件 | |
| --- | --- |
| `Kubefile` | 镜像构建文件 |
| `charts/` | higress helm chart |
| `install.sh` | 运行期 CMD：建命名空间、apply chart 内 CRD、apply 三个额外资源、生成 values、helm 安装 |
| `README.md` | 本文件 |

## 构建

```bash
sudo sealos build -t <镜像名>:v2.2.4-amd64 --platform linux/amd64 -f Kubefile .
```

或 GitHub Actions：`Build Component Cluster Image`，component=higress，version=v2.2.4。

升级 chart：`helm pull higress.io/higress --version=<版本> --untar -d charts/` 后提交。

## 运行

```bash
sealos run ghcr.io/vlee0203/sealos-cloud-images/higress:v2.2.4 --env CLOUD_DOMAIN=<domain>
```

首次安装与升级同一条路径。

| env | 默认 | 说明 |
| --- | --- | --- |
| `CLOUD_DOMAIN` | 空 | 泛域名证书的域名 |
| `CLOUD_PORT` | `443` | 网关 https 端口 |
