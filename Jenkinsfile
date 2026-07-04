// Web/H5 构建与部署见 GitHub Actions（.github/workflows/web.yml）。
// 本 Jenkinsfile 保留作 Gitea webhook 备用；推荐 develop/v* 推送到 GitHub 触发 Actions 更新。
// Script Path: Jenkinsfile
// GWT token: zh-cloud-todo-flutter
// Jenkins test: https://jenkins.zh04.com/view/test/job/zh-cloud-test/job/zh-cloud-todo-flutter/
// Jenkins prod: https://jenkins.zh04.com/view/prod/job/zh-cloud-prod/job/zh-cloud-todo-flutter/
// 文档: docs/engineering/01-ci-jenkins.md

import groovy.json.JsonOutput

// ---- 通用工具 -----------------------------------------------------------

// 返回 GWT ref 过滤正则：test 仅 develop / release/*；prod 仅 vX.Y.Z tag。
// 之前版本将 refs/heads/main 也允许为 prod 触发，会误把发版 tag 之外的 hotfix 直推 prod，已收紧。
String giteaWebhookRefFilter() {
  String jobName = (env.JOB_NAME ?: '').toLowerCase()
  boolean prodJob = jobName.contains('/zh-cloud-prod/') || jobName.endsWith('-prod')
  return prodJob
    ? '^refs/tags/v[0-9]+\\.[0-9]+\\.[0-9]+(-.+)?$'
    : '^refs/heads/(develop|release/.+)$'
}

// 飞书 webhook 通知。配置 FEISHU_WEBHOOK_URL 后生效；失败仅 echo 不抛错。
void feishuBuildNotify(String statusEmoji, String title) {
  String webhook = (env.FEISHU_WEBHOOK_URL ?: '').trim()
  if (!webhook) {
    echo '⚠️ 未配置 FEISHU_WEBHOOK_URL，跳过飞书通知'
    return
  }
  String lineRef = (env.GIT_TAG ?: env.GIT_BRANCH ?: env.gitea_ref ?: '').toString().trim()
  String commit = (env.GIT_COMMIT ?: '').trim()
  String buildUrl = (env.BUILD_URL ?: '').trim()
  List<String> lines = [
    "${statusEmoji} ${title}",
    "Job: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
    (lineRef || commit) ? "Ref/提交: ${lineRef} ${commit}".trim() : null,
    buildUrl ? "URL: ${buildUrl}" : null,
  ].findAll { it != null }
  String payload = JsonOutput.toJson([msg_type: 'text', content: [text: lines.join('\n')]])
  try {
    httpRequest(
      httpMode: 'POST', url: webhook, contentType: 'APPLICATION_JSON',
      requestBody: payload, validResponseCodes: '200:299', timeout: 10, quiet: true,
    )
  } catch (Throwable t) {
    echo "⚠️ 飞书通知发送失败（已忽略）：${t.class.simpleName}"
  }
}

// 进入 Flutter 镜像执行闭包；统一 user 映射避免 root 写出 _netrc / .pub-cache 之类。
void flutterInside(String flutterImg, Closure body) {
  def img = docker.image(flutterImg)
  img.pull()
  String dockerUser = sh(script: 'echo "$(id -u):$(id -g)"', returnStdout: true).trim()
  img.inside("-u ${dockerUser}", body)
}

// 解析构建参数优先级：env > param > hard default。
String resolveApiBase(Map params, String resolvedEnv) {
  String e = (env.TODO_API_BASE_URL ?: '').trim()
  if (e) return e
  if (resolvedEnv == 'prod') return (params.TODO_API_BASE_URL_PROD ?: '').trim()
  return (params.TODO_API_BASE_URL_TEST ?: '').trim()
}

// 把单引号字符串转义进单引号 bash 字符串。
String sq(String v) {
  return "'" + (v ?: '').replace("'", "'\\''") + "'"
}

pipeline {
  agent any

  triggers {
    GenericTrigger(
      genericVariables: [
        [key: 'gitea_ref', value: '$.ref'],
        [key: 'commit_after', value: '$.after'],
      ],
      token: 'zh-cloud-todo-flutter',
      regexpFilterText: '$gitea_ref',
      regexpFilterExpression: giteaWebhookRefFilter(),
      printContributedVariables: true,
      printPostContent: false,
      silentResponse: false,
      allowSeveralTriggersPerBuild: false,
      causeString: 'GWT: $gitea_ref',
    )
  }

  options {
    withFolderProperties()
    timestamps()
    disableConcurrentBuilds(abortPrevious: true)
    quietPeriod(20)
    buildDiscarder(logRotator(numToKeepStr: '3', artifactNumToKeepStr: '3'))
    timeout(time: 1, unit: 'HOURS')
    // 与 zh-cloud-service 一致：显式 checkout，避免 Declarative 默认检出与 GWT 竞态
    skipDefaultCheckout(true)
  }

  parameters {
    string(name: 'TAG_NAME', defaultValue: '', trim: true, description: 'prod 手工构建时填 vX.Y.Z；test 一般留空')
    booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: '为 true 时跳过 flutter test')
    booleanParam(name: 'SKIP_ANALYZE', defaultValue: false, description: '为 true 时跳过 flutter analyze')
    booleanParam(
      name: 'DEPLOY_TO_HOST',
      defaultValue: true,
      description: '为 true 时上传 Web 产物并重启远端 compose（PR 构建不部署）'
    )
    string(
      name: 'FLUTTER_DOCKER_IMAGE',
      defaultValue: 'ghcr.io/cirruslabs/flutter:stable',
      trim: true,
      description: 'CI 内执行 flutter 的 Docker 镜像（须 Dart ≥ 3.11，与 pubspec 一致）'
    )
    string(
      name: 'TODO_API_BASE_URL_TEST',
      defaultValue: 'https://todo-test.zh04.com',
      trim: true,
      description: 'test 构建 Web 时注入 TODO_API_BASE_URL（经 nginx 反代 /app-api）'
    )
    string(
      name: 'TODO_API_BASE_URL_PROD',
      defaultValue: 'https://todo.zh04.com',
      trim: true,
      description: 'prod 构建 Web 时注入 TODO_API_BASE_URL'
    )
    string(name: 'TODO_TENANT_ID', defaultValue: '1', trim: true, description: '构建时注入 TODO_TENANT_ID')
    string(
      name: 'DEPLOY_SSH_CONFIG',
      defaultValue: '',
      trim: true,
      description: 'Publish Over SSH 里 SSH Server 的 Name（必填，prod 不允许 host.docker.internal）'
    )
    string(
      name: 'DEPLOY_STAGING_DIR',
      defaultValue: '/tmp/zh-cloud-staging-todo-flutter',
      trim: true,
      description: '远端压缩包临时目录，必须是绝对路径'
    )
    string(
      name: 'COMPOSE_DEPLOY_SUBPATH',
      defaultValue: 'todo-flutter',
      trim: true,
      description: '相对 DEPLOY_TARGET_DIR 的部署目录（本仓 compose 权威路径，见 deploy/）'
    )
    string(
      name: 'REMOTE_COMPOSE_FILE',
      defaultValue: 'docker-compose.yml',
      trim: true,
      description: '远端 compose 文件名，位于 COMPOSE_DEPLOY_SUBPATH 下'
    )
    string(
      name: 'REMOTE_COMPOSE_PROJECT',
      defaultValue: '',
      trim: true,
      description: 'docker compose -p 项目名；留空则 test=todo-flutter-test、prod=todo-flutter'
    )
    booleanParam(
      name: 'RESTART_COMPOSE',
      defaultValue: true,
      description: '部署后是否 docker compose up -d todo-flutter'
    )
    string(
      name: 'APPROVED_DEPLOY_USERS',
      defaultValue: 'izhaong',
      trim: true,
      description: 'prod approve 阶段可点确认的 Jenkins 用户名列表（逗号分隔）'
    )
  }

  stages {
    stage('拉取代码') {
      steps {
        deleteDir()
        checkout scm
        sh 'test -f pubspec.yaml && test -f .metadata'
      }
    }

    stage('解析触发上下文') {
      steps {
        script {
          String zeroSha = '0000000000000000000000000000000000000000'
          String after = (env.commit_after ?: '').trim()
          if (after == zeroSha) {
            error('Gitea 分支删除事件（commit_after 全 0），跳过构建')
          }

          String fromFolder = (env.DEPLOY_ENV ?: '').toString().trim()
          String dep = fromFolder
          if (!dep) {
            String jn = (env.JOB_NAME ?: '').toLowerCase()
            dep = (jn.contains('prod') || jn.contains('zh-cloud-prod')) ? 'prod' : 'test'
          }
          dep = dep.toLowerCase()
          if (dep != 'test' && dep != 'prod') {
            error("DEPLOY_ENV 仅支持 test 或 prod，当前: ${dep}")
          }
          env.RESOLVED_ENV = dep
          boolean isProd = (dep == 'prod')

          String refFromGwt = (env.gitea_ref ?: '').toString()
          String ref = (env.GIT_BRANCH ?: env.BRANCH_NAME ?: refFromGwt).toString()

          if (isProd) {
            if (refFromGwt && !(refFromGwt ==~ /^refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+(-.+)?$/)) {
              error("prod 仅允许 vX.Y.Z tag 触发，当前 ref=${refFromGwt}")
            }
            String tag = (env.TAG_NAME ?: params.TAG_NAME ?: '').trim()
            if (!tag && ref.startsWith('refs/tags/')) {
              tag = ref.replace('refs/tags/', '').trim()
            }
            env.TRIGGER_TAG = tag
            if (!env.TRIGGER_TAG) {
              error('prod 未解析到 tag；需由 v* tag 触发，或手工构建在 TAG_NAME 填 vX.Y.Z')
            }
          } else {
            if (refFromGwt && !(refFromGwt ==~ /^refs\/heads\/(develop|release\/.+)$/)) {
              error("test 仅允许 develop / release/* push 触发，当前 ref=${refFromGwt}")
            }
            env.TRIGGER_TAG = ''
          }
          echo "[ci] RESOLVED_ENV=${env.RESOLVED_ENV} ref=${refFromGwt} TRIGGER_TAG=${env.TRIGGER_TAG ?: '—'}"
        }
      }
    }

    stage('环境检查') {
      steps {
        sh 'docker --version'
        script {
          // 密钥类变量走 mask，避免日志全量打印。
          String maskValue = { String key, Object value ->
            String text = value == null ? '' : value.toString()
            return (key ==~ /(?i).*(TOKEN|PASSWORD|PASS|SECRET|COOKIE|CREDENTIAL|ACCESS_KEY|SECRET_KEY|WEBHOOK|PRIVATE_KEY).*/) ? '****' : text
          }
          Map envMap = [:]
          String rawEnv = sh(script: 'printenv | sort', returnStdout: true).trim()
          rawEnv.split('\n').findAll { it && it.contains('=') }.each { line ->
            int idx = line.indexOf('=')
            String key = line.substring(0, idx)
            envMap[key] = maskValue(key, line.substring(idx + 1))
          }
          Map paramsMap = [:]
          params.each { key, value -> paramsMap[key.toString()] = maskValue(key.toString(), value) }
          echo "ENV_JSON=${JsonOutput.toJson(envMap)}"
          echo "PARAMS_JSON=${JsonOutput.toJson(paramsMap)}"
        }
      }
    }

    stage('Flutter 依赖与质量 + 构建 Web') {
      steps {
        script {
          String flutterImg = (params.FLUTTER_DOCKER_IMAGE ?: 'ghcr.io/cirruslabs/flutter:stable').trim()
          String apiBase = resolveApiBase(params, env.RESOLVED_ENV ?: 'test')
          if (!apiBase) {
            error('TODO_API_BASE_URL 未解析到，请检查 DEPLOY_ENV 或显式设置 TODO_API_BASE_URL')
          }
          String tenantId = (env.TODO_TENANT_ID ?: params.TODO_TENANT_ID ?: '1').trim()
          env.BUILD_API_BASE_URL = apiBase
          env.BUILD_TENANT_ID = tenantId
          echo "[ci] flutter image=${flutterImg} TODO_API_BASE_URL=${apiBase} TODO_TENANT_ID=${tenantId}"

          flutterInside(flutterImg) {
            sh 'flutter --version'
            sh 'flutter pub get'
            if (!params.SKIP_ANALYZE) {
              sh 'flutter analyze'
            }
            if (!params.SKIP_TESTS) {
              sh 'flutter test'
            }
            sh """
set -e
flutter build web --release \\
  --dart-define=TODO_API_BASE_URL=${sq(apiBase)} \\
  --dart-define=TODO_TENANT_ID=${sq(tenantId)}
test -d build/web
test -f build/web/index.html
"""
          }

          String composeSrc = (env.RESOLVED_ENV == 'prod') ? 'deploy/docker-compose.prod.yml' : 'deploy/docker-compose.test.yml'
          String envSrc = (env.RESOLVED_ENV == 'prod') ? 'deploy/env.prod.example' : 'deploy/env.test.example'
          sh """
set -e
test -f '${composeSrc}'
test -f '${envSrc}'
test -f deploy/nginx/client.nginx.conf
rm -rf .jenkins-dist/deploy .jenkins-dist/todo-flutter-web.tar.gz
mkdir -p .jenkins-dist/deploy/nginx
tar -C build/web -czf .jenkins-dist/todo-flutter-web.tar.gz .
cp '${composeSrc}' .jenkins-dist/deploy/docker-compose.yml
cp '${envSrc}' .jenkins-dist/deploy/env.example
cp deploy/nginx/client.nginx.conf .jenkins-dist/deploy/nginx/client.nginx.conf
test -s .jenkins-dist/todo-flutter-web.tar.gz
"""
        }
      }
    }

    stage('确认部署生产') {
      when {
        allOf {
          expression { return params.DEPLOY_TO_HOST == null || params.DEPLOY_TO_HOST }
          expression { return env.RESOLVED_ENV == 'prod' }
          not { changeRequest() }
        }
      }
      options {
        // 收紧到 2 小时；与 pipeline 顶层 1h timeout 矛盾修复见 issue:
        // 生产发版前人在岗可以马上放行，卡 24h 无意义。
        timeout(time: 2, unit: 'HOURS')
      }
      steps {
        input message: '确认将 todo-flutter Web 部署到生产宿主机？',
              ok: '确认部署',
              submitter: (params.APPROVED_DEPLOY_USERS ?: 'izhaong').split(',')*.trim().join(',')
      }
    }

    stage('部署到宿主机（SSH Publisher）') {
      when {
        allOf {
          expression { return params.DEPLOY_TO_HOST == null || params.DEPLOY_TO_HOST }
          not { changeRequest() }
        }
      }
      steps {
        script {
          String sshCfg = (params.DEPLOY_SSH_CONFIG ?: '').trim()
          String staging = (params.DEPLOY_STAGING_DIR ?: '').trim()
          String deployRoot = (env.DEPLOY_TARGET_DIR ?: '').trim()
          String composeSub = (params.COMPOSE_DEPLOY_SUBPATH ?: 'todo-flutter').trim()
          String composeFile = (params.REMOTE_COMPOSE_FILE ?: 'docker-compose.yml').trim()
          String projectOverride = (params.REMOTE_COMPOSE_PROJECT ?: '').trim()
          boolean restart = (params.RESTART_COMPOSE == null) || params.RESTART_COMPOSE
          boolean isTest = (env.RESOLVED_ENV == 'test')

          if (!sshCfg) error('DEPLOY_SSH_CONFIG 不能为空')
          if (!deployRoot) error('DEPLOY_TARGET_DIR 不能为空；请通过 Folder 环境变量传入，例如 /izhaong/zh-cloud-test')
          if (!staging || !composeSub || !composeFile) {
            error('DEPLOY_SSH_CONFIG / DEPLOY_STAGING_DIR / COMPOSE_DEPLOY_SUBPATH / REMOTE_COMPOSE_FILE 不能为空')
          }
          if (!deployRoot.startsWith('/') || !staging.startsWith('/')) {
            error('DEPLOY_TARGET_DIR 与 DEPLOY_STAGING_DIR 必须使用绝对路径')
          }
          if (!isTest && sshCfg == 'host.docker.internal') {
            error('prod 部署禁止使用 DEPLOY_SSH_CONFIG=host.docker.internal，避免误将生产部署到本机')
          }

          echo "[deploy] ssh=${sshCfg} DEPLOY_TARGET_DIR=${deployRoot} subpath=${composeSub}"
          String deployExec = """
set -e
STAGING_DIR=${sq(staging)}
DEPLOY_ROOT=${sq(deployRoot)}
COMPOSE_SUB=${sq(composeSub)}
COMPOSE_F=${sq(composeFile)}
PROJECT_OVERRIDE=${sq(projectOverride)}
RESTART=${restart ? 'true' : 'false'}
IS_TEST=${isTest ? 'true' : 'false'}
PKG=todo-flutter-web.tar.gz
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:\$PATH"

TARGET_DIR="\$DEPLOY_ROOT/\$COMPOSE_SUB"
mkdir -p "\$TARGET_DIR/dist" "\$TARGET_DIR/nginx"

SRC_COMPOSE="\$STAGING_DIR/deploy/docker-compose.yml"
DST_COMPOSE="\$TARGET_DIR/\$COMPOSE_F"
test -f "\$SRC_COMPOSE"
COMPOSE_CHANGED=0
if [ ! -f "\$DST_COMPOSE" ] || ! cmp -s "\$SRC_COMPOSE" "\$DST_COMPOSE"; then
  [ -f "\$DST_COMPOSE" ] && cp -a "\$DST_COMPOSE" "\$DST_COMPOSE.bak-\$(date +%Y%m%d%H%M%S)"
  cp -a "\$SRC_COMPOSE" "\$DST_COMPOSE"
  COMPOSE_CHANGED=1
  echo "[deploy] compose 已更新"
fi

# 静态 conf 不再走 envsubst；test 与 prod 同步挂此文件。
SRC_NGINX="\$STAGING_DIR/deploy/nginx/client.nginx.conf"
DST_NGINX="\$TARGET_DIR/nginx/client.nginx.conf"
test -f "\$SRC_NGINX"
NGINX_CHANGED=0
if [ ! -f "\$DST_NGINX" ] || ! cmp -s "\$SRC_NGINX" "\$DST_NGINX"; then
  [ -f "\$DST_NGINX" ] && cp -a "\$DST_NGINX" "\$DST_NGINX.bak-\$(date +%Y%m%d%H%M%S)"
  cp -a "\$SRC_NGINX" "\$DST_NGINX"
  NGINX_CHANGED=1
  echo "[deploy] nginx conf 已更新"
fi

SRC_ENV="\$STAGING_DIR/deploy/env.example"
DST_ENV="\$TARGET_DIR/env"
test -f "\$SRC_ENV"
ENV_CHANGED=0
if [ ! -f "\$DST_ENV" ]; then
  cp -a "\$SRC_ENV" "\$DST_ENV"
  chmod 600 "\$DST_ENV" 2>/dev/null || true
  ENV_CHANGED=1
  echo "[deploy] env 已按示例初始化"
else
  # 仅补缺行，不覆盖业务密钥。env.example 中新增的 KEY 会追加到宿主 env 末尾；
  # 已存在的 KEY（包括被业务密钥覆盖的）保持宿主机原值不动。
  TMP_ADD="\$(mktemp -t env-add.XXXXXX)"
  APPENDED=0
  while IFS= read -r line || [ -n "\$line" ]; do
    case "\$line" in ''|\#*) continue ;; esac
    key="\${line%%=*}"
    [ -z "\$key" ] && continue
    if ! grep -qE "^\${key}=" "\$DST_ENV"; then
      echo "\$line" >> "\$TMP_ADD"
      APPENDED=\$((APPENDED+1))
    fi
  done < "\$SRC_ENV"
  if [ "\$APPENDED" -gt 0 ]; then
    cp -a "\$DST_ENV" "\$DST_ENV.bak-\$(date +%Y%m%d%H%M%S)"
    {
      echo
      echo "# appended by jenkins \$(date +%Y-%m-%d)"
      cat "\$TMP_ADD"
    } >> "\$DST_ENV"
    chmod 600 "\$DST_ENV" 2>/dev/null || true
    ENV_CHANGED=1
    echo "[deploy] env 已追加 \${APPENDED} 条缺失 key（宿主机的原值未动）"
  fi
  rm -f "\$TMP_ADD"
fi

PKG_PATH="\$STAGING_DIR/\$PKG"
DEST_DIR="\$TARGET_DIR/dist"
NEXT_DIR="\$TARGET_DIR/.todo-flutter-dist-next-\$\$"
test -f "\$PKG_PATH"
rm -rf "\$NEXT_DIR"
mkdir -p "\$NEXT_DIR"
tar -xzf "\$PKG_PATH" -C "\$NEXT_DIR"
mkdir -p "\$DEST_DIR"
# dist 始终 --delete 同步；rsync 不写保护名单。
rsync -a --delete "\$NEXT_DIR"/ "\$DEST_DIR"/
rm -rf "\$NEXT_DIR"
rm -f "\$PKG_PATH"
rm -rf "\$STAGING_DIR"

if [ "\$RESTART" = "true" ]; then
  if [ -n "\$PROJECT_OVERRIDE" ]; then
    COMPOSE_PROJECT="\$PROJECT_OVERRIDE"
  elif [ "\$IS_TEST" = "true" ]; then
    COMPOSE_PROJECT="todo-flutter-test"
  else
    COMPOSE_PROJECT="todo-flutter"
  fi
  COMPOSE_SVC="todo-flutter"
  cd "\$TARGET_DIR"
  # 任何 dist 重同步都视为内容变化，强制 recreate 避免旧容器复用缓存。
  RECREATE_FLAG="--force-recreate"
  if [ "\$COMPOSE_CHANGED" = "1" ] || [ "\$NGINX_CHANGED" = "1" ] || [ "\$ENV_CHANGED" = "1" ]; then
    echo "[deploy] compose/nginx/env 有变更，使用 --force-recreate"
  else
    echo "[deploy] 配置未变但 dist 已重同步，使用 --force-recreate 确保新产物生效"
  fi
  docker compose -p "\$COMPOSE_PROJECT" -f "\$COMPOSE_F" --env-file env up -d \$RECREATE_FLAG "\$COMPOSE_SVC"
  docker compose -p "\$COMPOSE_PROJECT" -f "\$COMPOSE_F" ps
else
  echo "[deploy] 跳过 compose 重启（RESTART=false）"
fi
""".stripIndent()

          sshPublisher(
            publishers: [
              sshPublisherDesc(
                configName: sshCfg,
                verbose: true,
                transfers: [
                  sshTransfer(
                    sourceFiles: '.jenkins-dist/**',
                    remoteDirectory: staging,
                    removePrefix: '.jenkins-dist',
                    execCommand: deployExec
                  )
                ]
              )
            ]
          )
        }
      }
    }
  }

  post {
    success {
      echo '✅ Jenkins 流水线执行成功（todo-flutter 构建/部署完成）'
      script { feishuBuildNotify('✅', "Jenkins 构建成功（todo-flutter）[${env.RESOLVED_ENV ?: 'n/a'}]") }
    }
    failure {
      echo '❌ Jenkins 流水线执行失败（请查看上方日志定位失败阶段）'
      script { feishuBuildNotify('❌', "Jenkins 构建失败（todo-flutter）[${env.RESOLVED_ENV ?: 'n/a'}]") }
    }
    always {
      sh 'rm -rf .jenkins-dist || true'
      echo "结束状态：${currentBuild.currentResult}"
    }
  }
}
