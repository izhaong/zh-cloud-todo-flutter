# Web/H5 构建与部署见 GitHub Actions（.github/workflows/web.yml）。
# 本 Jenkinsfile 保留作 Gitea webhook 备用；推荐 develop/v* 推送到 GitHub 触发 Actions 更新。
// Script Path: Jenkinsfile
// GWT token: zh-cloud-todo-flutter
// Jenkins test: https://jenkins.zh04.com/view/test/job/zh-cloud-test/job/zh-cloud-todo-flutter/
// Jenkins prod: https://jenkins.zh04.com/view/prod/job/zh-cloud-prod/job/zh-cloud-todo-flutter/
// 文档: docs/engineering/01-ci-jenkins.md

def giteaWebhookRefFilter() {
  def jobName = (env.JOB_NAME ?: '').toLowerCase()
  return (jobName.contains('/zh-cloud-prod/') || jobName.endsWith('-prod'))
    ? '^(refs/heads/main|refs/tags/v[0-9].*)$'
    : '^refs/heads/develop$'
}

def feishuBuildNotify(String statusEmoji, String title) {
  def webhook = (env.FEISHU_WEBHOOK_URL ?: '').trim()
  if (!webhook) {
    echo '⚠️ 未配置 FEISHU_WEBHOOK_URL，跳过飞书通知'
    return
  }

  def lineRef = (env.GIT_TAG ?: env.GIT_BRANCH ?: env.gitea_ref ?: '').toString().trim()
  def commit = (env.GIT_COMMIT ?: '').trim()
  def buildUrl = (env.BUILD_URL ?: '').trim()

  def lines = [
    "${statusEmoji} ${title}",
    "Job: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
    (lineRef || commit) ? "Ref/提交: ${lineRef} ${commit}".trim() : null,
    buildUrl ? "URL: ${buildUrl}" : null,
  ].findAll { it }

  def payload = groovy.json.JsonOutput.toJson([msg_type: 'text', content: [text: lines.join('\n')]])
  try {
    httpRequest(
      httpMode: 'POST',
      url: webhook,
      contentType: 'APPLICATION_JSON',
      requestBody: payload,
      validResponseCodes: '200:299',
      timeout: 10,
      quiet: true
    )
  } catch (Throwable t) {
    echo "⚠️ 飞书通知发送失败（已忽略）：${t.class.simpleName}"
  }
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
      defaultValue: 'host.docker.internal',
      trim: true,
      description: 'Publish Over SSH 里 SSH Server 的 Name'
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
  }

  stages {
    stage('拉取代码') {
      steps {
        deleteDir()
        checkout scm
        sh 'test -f pubspec.yaml && test -f .metadata && ls -la pubspec.yaml .metadata web/index.html'
      }
    }

    stage('解析触发上下文') {
      steps {
        script {
          def zeroSha = '0000000000000000000000000000000000000000'
          def after = (env.commit_after ?: '').trim()
          if (after == zeroSha) {
            error('Gitea 分支删除事件（commit_after 全 0），跳过构建')
          }

          def fromFolder = (env.DEPLOY_ENV ?: '').toString().trim()
          def dep = fromFolder
          if (!dep) {
            def jn = (env.JOB_NAME ?: '').toLowerCase()
            dep = (jn.contains('prod') || jn.contains('zh-cloud-prod')) ? 'prod' : 'test'
          }
          dep = dep.toLowerCase()
          if (dep != 'test' && dep != 'prod') {
            error("DEPLOY_ENV 仅支持 test 或 prod，当前: ${dep}")
          }
          env.RESOLVED_ENV = dep
          def isProd = (dep == 'prod')

          def refFromGwt = (env.gitea_ref ?: '').toString()
          def ref = (env.GIT_BRANCH ?: env.BRANCH_NAME ?: refFromGwt).toString()

          if (isProd) {
            if (refFromGwt && !(refFromGwt ==~ /^refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+(-.+)?$/)) {
              error("prod 仅允许 vX.Y.Z tag 触发，当前 ref=${refFromGwt}")
            }
            def tag = (env.TAG_NAME ?: params.TAG_NAME ?: '').trim()
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
          def maskValue = { String key, Object value ->
            def text = value == null ? '' : value.toString()
            return (key ==~ /(?i).*(TOKEN|PASSWORD|PASS|SECRET|COOKIE|CREDENTIAL|ACCESS_KEY|SECRET_KEY|WEBHOOK|PRIVATE_KEY).*/) ? '****' : text
          }
          def envMap = [:]
          def rawEnv = sh(script: 'printenv | sort', returnStdout: true).trim()
          rawEnv.split('\n').findAll { it && it.contains('=') }.each { line ->
            def idx = line.indexOf('=')
            def key = line.substring(0, idx)
            envMap[key] = maskValue(key, line.substring(idx + 1))
          }
          def paramsMap = [:]
          params.each { key, value ->
            paramsMap[key.toString()] = maskValue(key.toString(), value)
          }
          echo "ENV_JSON=${groovy.json.JsonOutput.toJson(envMap)}"
          echo "PARAMS_JSON=${groovy.json.JsonOutput.toJson(paramsMap)}"
        }
      }
    }

    stage('Flutter 依赖与质量') {
      steps {
        script {
          def flutterImg = (params.FLUTTER_DOCKER_IMAGE ?: 'ghcr.io/cirruslabs/flutter:stable').trim()
          def apiBase = (env.TODO_API_BASE_URL ?: '').trim()
          if (!apiBase) {
            apiBase = (env.RESOLVED_ENV == 'prod')
              ? (params.TODO_API_BASE_URL_PROD ?: 'https://todo.zh04.com').trim()
              : (params.TODO_API_BASE_URL_TEST ?: 'https://todo-test.zh04.com').trim()
          }
          def tenantId = (env.TODO_TENANT_ID ?: params.TODO_TENANT_ID ?: '1').trim()
          env.BUILD_API_BASE_URL = apiBase
          env.BUILD_TENANT_ID = tenantId
          echo "[ci] flutter image=${flutterImg} TODO_API_BASE_URL=${apiBase} TODO_TENANT_ID=${tenantId}"

          def img = docker.image(flutterImg)
          img.pull()
          def dockerUser = sh(script: 'echo "$(id -u):$(id -g)"', returnStdout: true).trim()
          img.inside("-u ${dockerUser}") {
            sh 'flutter --version'
            sh 'test -f pubspec.yaml'
            sh 'flutter pub get'
            if (!params.SKIP_ANALYZE) {
              sh 'flutter analyze'
            }
            if (!params.SKIP_TESTS) {
              sh 'flutter test'
            }
          }
        }
      }
    }

    stage('Flutter 构建 Web') {
      steps {
        script {
          def flutterImg = (params.FLUTTER_DOCKER_IMAGE ?: 'ghcr.io/cirruslabs/flutter:stable').trim()
          def apiBase = (env.BUILD_API_BASE_URL ?: '').trim()
          def tenantId = (env.BUILD_TENANT_ID ?: '1').trim()
          def img = docker.image(flutterImg)
          def dockerUser = sh(script: 'echo "$(id -u):$(id -g)"', returnStdout: true).trim()
          img.inside("-u ${dockerUser}") {
            sh """
set -e
flutter build web --release \\
  --dart-define=TODO_API_BASE_URL='${apiBase.replace("'", "'\\''")}' \\
  --dart-define=TODO_TENANT_ID='${tenantId.replace("'", "'\\''")}'
test -d build/web
test -f build/web/index.html
"""
          }
          def composeSrc = (env.RESOLVED_ENV == 'prod') ? 'deploy/docker-compose.prod.yml' : 'deploy/docker-compose.test.yml'
          def envSrc = (env.RESOLVED_ENV == 'prod') ? 'deploy/env.prod.example' : 'deploy/env.test.example'
          sh """
set -e
test -f '${composeSrc}'
test -f '${envSrc}'
test -f deploy/nginx/client.nginx.conf.template
rm -rf .jenkins-dist/deploy .jenkins-dist/todo-flutter-web.tar.gz
mkdir -p .jenkins-dist/deploy/nginx
tar -C build/web -czf .jenkins-dist/todo-flutter-web.tar.gz .
cp '${composeSrc}' .jenkins-dist/deploy/docker-compose.yml
cp '${envSrc}' .jenkins-dist/deploy/env.example
cp deploy/nginx/client.nginx.conf.template .jenkins-dist/deploy/nginx/client.nginx.conf.template
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
      steps {
        timeout(time: 24, unit: 'HOURS') {
          input message: '确认将 todo-flutter Web 部署到生产宿主机？', ok: '确认部署', submitter: 'authenticated'
        }
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
          def sshCfg = (params.DEPLOY_SSH_CONFIG ?: 'host.docker.internal').trim()
          def staging = (params.DEPLOY_STAGING_DIR ?: '/tmp/zh-cloud-staging-todo-flutter').trim()
          def deployRoot = (env.DEPLOY_TARGET_DIR ?: '').trim()
          def composeSub = (params.COMPOSE_DEPLOY_SUBPATH ?: 'todo-flutter').trim()
          def composeFile = (params.REMOTE_COMPOSE_FILE ?: 'docker-compose.yml').trim()
          def projectOverride = (params.REMOTE_COMPOSE_PROJECT ?: '').trim()
          def restart = (params.RESTART_COMPOSE == null) ? true : params.RESTART_COMPOSE
          def isTest = (env.RESOLVED_ENV == 'test')

          if (!deployRoot) {
            error('DEPLOY_TARGET_DIR 不能为空；请通过 Folder 环境变量传入，例如 /izhaong/zh-cloud-test')
          }
          if (!sshCfg || !staging || !composeSub || !composeFile) {
            error('DEPLOY_SSH_CONFIG / DEPLOY_STAGING_DIR / COMPOSE_DEPLOY_SUBPATH / REMOTE_COMPOSE_FILE 不能为空')
          }
          if (!deployRoot.startsWith('/') || !staging.startsWith('/')) {
            error('DEPLOY_TARGET_DIR 与 DEPLOY_STAGING_DIR 必须使用绝对路径')
          }

          echo "[deploy] ssh=${sshCfg} DEPLOY_TARGET_DIR=${deployRoot} subpath=${composeSub}"
          def sq = { String v -> "'" + v.replace("'", "'\\''") + "'" }
          def deployExec = """
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

SRC_NGINX="\$STAGING_DIR/deploy/nginx/client.nginx.conf.template"
DST_NGINX="\$TARGET_DIR/nginx/client.nginx.conf.template"
test -f "\$SRC_NGINX"
NGINX_CHANGED=0
if [ ! -f "\$DST_NGINX" ] || ! cmp -s "\$SRC_NGINX" "\$DST_NGINX"; then
  [ -f "\$DST_NGINX" ] && cp -a "\$DST_NGINX" "\$DST_NGINX.bak-\$(date +%Y%m%d%H%M%S)"
  cp -a "\$SRC_NGINX" "\$DST_NGINX"
  NGINX_CHANGED=1
  echo "[deploy] nginx 模板已更新"
fi

SRC_ENV="\$STAGING_DIR/deploy/env.example"
DST_ENV="\$TARGET_DIR/env"
test -f "\$SRC_ENV"
ENV_CHANGED=0
if [ ! -f "\$DST_ENV" ]; then
  cp -a "\$SRC_ENV" "\$DST_ENV"
  chmod 600 "\$DST_ENV"
  ENV_CHANGED=1
  echo "[deploy] env 已按示例初始化"
elif ! cmp -s "\$SRC_ENV" "\$DST_ENV"; then
  cp -a "\$DST_ENV" "\$DST_ENV.bak-\$(date +%Y%m%d%H%M%S)"
  cp -a "\$SRC_ENV" "\$DST_ENV"
  chmod 600 "\$DST_ENV"
  ENV_CHANGED=1
  echo "[deploy] env 已按仓库示例更新（宿主机原 env 已备份）"
fi

PKG_PATH="\$STAGING_DIR/\$PKG"
DEST_DIR="\$TARGET_DIR/dist"
NEXT_DIR="\$TARGET_DIR/.todo-flutter-dist-next-\$\$"
test -f "\$PKG_PATH"
rm -rf "\$NEXT_DIR"
mkdir -p "\$NEXT_DIR"
tar -xzf "\$PKG_PATH" -C "\$NEXT_DIR"
mkdir -p "\$DEST_DIR"
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
  RECREATE_FLAG=""
  if [ "\$COMPOSE_CHANGED" = "1" ] || [ "\$NGINX_CHANGED" = "1" ] || [ "\$ENV_CHANGED" = "1" ]; then
    RECREATE_FLAG="--force-recreate"
    echo "[deploy] compose/nginx/env 有变更，使用 --force-recreate"
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
      script {
        feishuBuildNotify('✅', "Jenkins 构建成功（todo-flutter）[${env.RESOLVED_ENV ?: 'n/a'}]")
      }
    }
    failure {
      echo '❌ Jenkins 流水线执行失败（请查看上方日志定位失败阶段）'
      script {
        feishuBuildNotify('❌', "Jenkins 构建失败（todo-flutter）[${env.RESOLVED_ENV ?: 'n/a'}]")
      }
    }
    always {
      sh 'rm -rf .jenkins-dist || true'
      echo "结束状态：${currentBuild.currentResult}"
    }
  }
}
