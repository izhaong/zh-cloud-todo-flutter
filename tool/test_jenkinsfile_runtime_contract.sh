#!/usr/bin/env bash
set -euo pipefail

jenkinsfile="${1:-Jenkinsfile}"

grep -Fq "ghcr.io/cirruslabs/flutter:3.44.0" "$jenkinsfile"
grep -Fq 'retry(3)' "$jenkinsfile"
grep -Fq 'img.pull()' "$jenkinsfile"
if grep -Fq 'params.FLUTTER_DOCKER_IMAGE' "$jenkinsfile"; then
  echo 'ERROR: Flutter 构建镜像不得由历史 Job 参数覆盖' >&2
  exit 1
fi

if grep -Fq 'GenericTrigger(' "$jenkinsfile" || grep -Fq 'withFolderProperties()' "$jenkinsfile"; then
  echo "ERROR: Jenkinsfile 仍依赖 Generic Webhook Trigger 或 Folder Properties 插件" >&2
  exit 1
fi

grep -Fq 'disableConcurrentBuilds()' "$jenkinsfile"
if grep -Fq 'abortPrevious: true' "$jenkinsfile"; then
  echo 'ERROR: 新构建必须排队，不能中止仍在运行的构建' >&2
  exit 1
fi
if ! grep -Fq "agent { label 'built-in' }" "$jenkinsfile"; then
  echo 'ERROR: Jenkins agent 必须显式使用已登记的 built-in 节点' >&2
  exit 1
fi
if ! grep -Fq "timeout(time: 10, unit: 'MINUTES')" "$jenkinsfile"; then
  echo 'ERROR: Pipeline 总超时必须固定为 10 分钟' >&2
  exit 1
fi
if ! grep -Fq "buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))" "$jenkinsfile"; then
  echo 'ERROR: Pipeline 必须保留最近 10 次构建与制品' >&2
  exit 1
fi
if grep -Fq 'quietPeriod(' "$jenkinsfile"; then
  echo 'ERROR: Webhook 触发不应叠加 Jenkinsfile quietPeriod' >&2
  exit 1
fi
if grep -Fq "defaultValue: 'host.docker.internal'" "$jenkinsfile"; then
  echo 'ERROR: 当前 Jenkins agent 无法解析 host.docker.internal，不能作为默认 Publisher' >&2
  exit 1
fi
if grep -Eq 'printenv|ENV_JSON=|PARAMS_JSON=' "$jenkinsfile"; then
  echo 'ERROR: Jenkins 日志不得枚举全部环境变量或参数' >&2
  exit 1
fi
grep -Fq "name: 'DEPLOY_TARGET_DIR_TEST'" "$jenkinsfile"
grep -Fq "name: 'DEPLOY_TARGET_DIR_PROD'" "$jenkinsfile"
if grep -Eq 'giteaWebhookRefFilter|gitea_ref|commit_after|DEPLOY_ENV' "$jenkinsfile"; then
  echo 'ERROR: Jenkinsfile 仍依赖旧 GWT/Folder 环境路由' >&2
  exit 1
fi
if grep -Eq "jobName|JOB_NAME.*(prod|test)|endsWith\\('-prod'\\)|endsWith\\('-test'\\)" "$jenkinsfile"; then
  echo 'ERROR: 环境不得再由旧 Job 名后缀推断' >&2
  exit 1
fi
grep -Fq "branchName == 'develop'" "$jenkinsfile"
grep -Fq "branchName == 'main'" "$jenkinsfile"
grep -Fq "env.DELIVERY_MODE = 'production'" "$jenkinsfile"
grep -Fq 'production 必须读取 main 的 release-ready manifest 并提升同一 digest' "$jenkinsfile"
grep -Fq "expression { return env.DELIVERY_MODE == 'test' && params.DEPLOY_TO_HOST }" "$jenkinsfile"
grep -Fq 'tool/test_jenkinsfile_runtime_contract.sh' "$jenkinsfile"
if grep -Fq 'input message:' "$jenkinsfile"; then
  echo 'ERROR: 受保护 tag 已是发布授权，不重复增加 Jenkins input' >&2
  exit 1
fi

echo 'PASS: Jenkinsfile 使用仓库声明的 Flutter 运行时与原生 Multibranch 触发'
