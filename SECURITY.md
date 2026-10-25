# Security policy / 安全政策

## Supported versions / 支持版本

Security fixes are provided for the latest official release of Hoopito (Chinese
name: 球豆), currently v2.0.1 / Android 2.0.1+5. Actual release provenance and
verification scope are recorded in the release record;
local Debug packages and unsigned artifacts do not establish a production release.

Hoopito · 球豆仅为最新正式版本提供安全修复，当前为 v2.0.1／Android 2.0.1+5。实际发行来源与验收范围见发行记录，
本地 Debug 包和未签名复现产物不代表正式发行。发行状态与已知范围见
[发行记录 / Release record](docs/release/v2.0.1-release-record.md)。

The signed v2.0.1 tag and APK retain application source commit
`4ecd960e5af1f6b12124a43e330d67efb628281b`; later documentation and promotional
asset commits do not change that provenance. Historical HoopTrace releases keep
their original names and verification records.

v2.0.1 签名 tag 与 APK 的应用来源固定为上述提交；后续文档与宣传素材提交不改变该来源。
历史 HoopTrace 发行保留原名与验收记录。

## Report privately / 私密报告

Do not open a public issue for vulnerabilities that could expose or destroy
local match data, bypass backup safeguards, escape the selected SAF directory,
or enable code execution. Use GitHub **Private vulnerability reporting** in the
repository Security tab. Include affected versions, reproduction steps, impact,
and a minimal proof of concept. Never include real player data or signing keys.

如问题可能泄露或破坏本地比赛数据、绕过备份保护、越出用户选择的 SAF
目录或造成代码执行，请不要创建公开 Issue；应使用仓库 Security 页面中的
**Private vulnerability reporting**。请提供受影响版本、复现步骤、影响范围和
最小化验证材料，且不要上传真实球员数据或签名密钥。

Maintainers will acknowledge a complete report within 7 days, aim to provide a
triage decision within 14 days, and coordinate disclosure after a fix is
available. These are best-effort targets for a volunteer project.

维护者会尽量在 7 天内确认完整报告、14 天内给出分级结论，并在修复可用后
协调披露；这些是志愿维护项目的尽力目标，并非服务等级承诺。

## Security boundaries / 安全边界

- Hoopito has no account system, cloud backend, telemetry, ads, or payment SDK.
- Match data is local SQLite data unless the user explicitly exports, shares, or
  enables an approved SAF backup directory.
- Android system backup is disabled; official releases request no broad storage
  permission.
- Candidate safety copies remain inside the app's private storage. They protect
  replacement mistakes and do not replace an external JSON backup.
- Third-party forks and repackaged APKs are outside the upstream trust boundary.
- Official APKs must trace to a signed Git tag, published checksums, and the
  maintainer certificate documented in the release record.
