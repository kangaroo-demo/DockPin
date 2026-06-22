# 签名与公证

DockPin 可以用两种方式发布：

- 社区构建：ad-hoc 签名，开源，任何人都可以构建。用户从 GitHub 下载后，macOS Gatekeeper 可能会提示无法验证。
- Developer ID 构建：使用 Apple Developer 账号签名并公证。要让大多数用户不再看到“Apple 无法验证 DockPin”的提示，需要这种方式。

## 所需 Apple 账号

你需要有效的 Apple Developer Program 会员资格。

创建 Developer ID Application 证书，导出为 `.p12`，并为公证创建 app-specific password。

## GitHub Secrets

在仓库里配置这些 secrets：

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`：`.p12` 证书的 base64 内容。
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`：`.p12` 证书密码。
- `APPLE_KEYCHAIN_PASSWORD`：CI 临时 keychain 密码。填一个强随机值即可。
- `APPLE_ID`：用于公证的 Apple ID 邮箱。
- `APPLE_TEAM_ID`：Apple Developer Team ID。
- `APPLE_APP_SPECIFIC_PASSWORD`：用于公证的 app-specific password。
- `CODE_SIGN_IDENTITY`：可选，默认是 `Developer ID Application`。

编码证书：

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

## 发布

配置 secrets 后，推送版本 tag：

```sh
git tag -a v0.1.1 -m "DockPin 0.1.1"
git push origin v0.1.1
```

Release workflow 会：

1. 导入 Developer ID 证书。
2. 构建 `DockPin.app`。
3. 使用 hardened runtime 签名。
4. 提交 Apple 公证。
5. staple 公证票据。
6. 上传 `DockPin.zip` 到 GitHub Releases。

如果没有配置这些 secrets，workflow 仍会创建社区构建版本。
