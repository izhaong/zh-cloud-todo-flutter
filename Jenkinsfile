// zh-cloud-todo-flutter — 单个根级 Gitea Multibranch Job。
// develop/main/SemVer tag 由 BRANCH_NAME/TAG_NAME 路由，触发由 Jenkins Gitea SCM Source 维护。
// Script Path: Jenkinsfile；本仓只维护 Todo Flutter Web 构建与部署。
// 文档: docs/engineering/01-ci-jenkins.md

// ---- 通用工具 -----------------------------------------------------------

// 飞书 webhook 通知。配置 FEISHU_WEBHOOK_URL 后生效；失败仅 echo 不抛错。
void feishuBuildNotify(String statusEmoji, String title) {
  String webhook = (env.FEISHU_WEBHOOK_URL ?: '').trim()
  if (!webhook) {
    echo '⚠️ 未配置 FEISHU_WEBHOOK_URL，跳过飞书通知'
    return
  }
  String lineRef = (env.GIT_TAG ?: env.GIT_BRANCH ?: env.BRANCH_NAME ?: '').toString().trim()
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
  boolean cachedImage = sh(
    script: "docker image inspect '${flutterImg}' >/dev/null 2>&1",
    returnStatus: true
  ) == 0
  if (!cachedImage) {
    retry(3) {
      img.pull()
    }
  } else {
    echo "[ci] 复用本地 Flutter 构建镜像：${flutterImg}"
  }
  sh "docker image inspect '${flutterImg}' >/dev/null"
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
  agent { label 'built-in' }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
    timeout(time: 10, unit: 'MINUTES')
    // 显式 checkout，避免 Declarative 默认检出与 Multibranch 上下文解析竞态。
    skipDefaultCheckout(true)
  }

  parameters {
    string(name: 'TAG_NAME', defaultValue: '', trim: true, description: 'Multibranch tag 兼容字段；正常由 TAG_NAME/BRANCH_NAME 自动解析')
    booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: '为 true 时跳过 flutter test')
    booleanParam(name: 'SKIP_ANALYZE', defaultValue: false, description: '为 true 时跳过 flutter analyze')
    booleanParam(
      name: 'DEPLOY_TO_HOST',
      defaultValue: true,
      description: '为 true 时上传 Web 产物并重启远端 compose（PR 构建不部署）'
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
      defaultValue: '192.168.3.94',
      trim: true,
      description: 'Publish Over SSH 里 test 部署 Server 的已登记 Name'
    )
    string(
      name: 'DEPLOY_STAGING_DIR',
      defaultValue: '/tmp/zh-cloud-staging-todo-flutter',
      trim: true,
      description: '远端压缩包临时目录，必须是绝对路径'
    )
    string(name: 'DEPLOY_TARGET_DIR_TEST', defaultValue: '/izhaong/zh-cloud-test', trim: true, description: 'test 宿主机部署根目录')
    string(name: 'DEPLOY_TARGET_DIR_PROD', defaultValue: '/izhaong/zh-cloud-prod', trim: true, description: 'prod 宿主机部署根目录；promotion 接通前不使用')
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
        sh 'test -f pubspec.yaml && test -f .metadata'
      }
    }

    stage('解析触发上下文') {
      steps {
        script {
          String branchName = (env.BRANCH_NAME ?: '').trim()
          String tagName = (env.TAG_NAME ?: params.TAG_NAME ?: '').trim()
          String candidateTag = tagName ?: branchName
          if (branchName == 'develop') {
            env.DELIVERY_MODE = 'test'
            env.RESOLVED_ENV = 'test'
            env.TRIGGER_TAG = ''
          } else if (branchName == 'main') {
            env.DELIVERY_MODE = 'candidate'
            env.RESOLVED_ENV = 'prod'
            env.TRIGGER_TAG = ''
          } else if (candidateTag ==~ /^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$/) {
            env.DELIVERY_MODE = 'production'
            env.RESOLVED_ENV = 'prod'
            env.TRIGGER_TAG = candidateTag
          } else {
            error("不受信任的 Multibranch ref: BRANCH_NAME=${branchName}, TAG_NAME=${tagName}")
          }
          echo "[ci] DELIVERY_MODE=${env.DELIVERY_MODE} RESOLVED_ENV=${env.RESOLVED_ENV} BRANCH_NAME=${branchName} TRIGGER_TAG=${env.TRIGGER_TAG ?: '—'}"
        }
      }
    }

    stage('生产提升保护') {
      when { expression { return env.DELIVERY_MODE == 'production' } }
      steps {
        error('production 必须读取 main 的 release-ready manifest 并提升同一 digest；当前仓库尚未完成 promotion 实现')
      }
    }

    stage('环境检查') {
      steps {
        sh 'docker --version'
        sh 'tool/test_jenkinsfile_runtime_contract.sh'
        echo "[ci] ref=${env.BRANCH_NAME ?: '—'} mode=${env.DELIVERY_MODE ?: '—'} env=${env.RESOLVED_ENV ?: '—'}"
      }
    }

    stage('Flutter 依赖与质量 + 构建 Web') {
      steps {
        script {
          String flutterImg = 'ghcr.io/cirruslabs/flutter:3.44.0'
          String apiBase = resolveApiBase(params, env.RESOLVED_ENV ?: 'test')
          if (!apiBase) {
            error('TODO_API_BASE_URL 未解析到，请检查 Multibranch ref 路由或显式设置 TODO_API_BASE_URL')
          }
          String tenantId = (env.TODO_TENANT_ID ?: params.TODO_TENANT_ID ?: '1').trim()
          env.BUILD_API_BASE_URL = apiBase
          env.BUILD_TENANT_ID = tenantId
          echo "[ci] flutter image=${flutterImg} TODO_API_BASE_URL=${apiBase} TODO_TENANT_ID=${tenantId}"

          flutterInside(flutterImg) {
            sh 'flutter --version'
            sh 'flutter pub get'
            if (!params.SKIP_ANALYZE) {
              sh 'flutter analyze --no-fatal-infos'
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

    stage('归档 Web 制品') {
      steps {
        archiveArtifacts artifacts: '.jenkins-dist/*.tar.gz', fingerprint: true, onlyIfSuccessful: true
      }
    }

    stage('部署测试环境') {
      when {
        allOf {
          expression { return env.DELIVERY_MODE == 'test' && params.DEPLOY_TO_HOST }
          not { changeRequest() }
        }
      }
      steps {
        script {
          String sshCfg = (params.DEPLOY_SSH_CONFIG ?: '').trim()
          String staging = (params.DEPLOY_STAGING_DIR ?: '').trim()
          String deployRoot = (params.DEPLOY_TARGET_DIR_TEST ?: '').trim()
          String composeSub = (params.COMPOSE_DEPLOY_SUBPATH ?: 'todo-flutter').trim()
          String composeFile = (params.REMOTE_COMPOSE_FILE ?: 'docker-compose.yml').trim()
          String projectOverride = (params.REMOTE_COMPOSE_PROJECT ?: '').trim()
          boolean restart = (params.RESTART_COMPOSE == null) || params.RESTART_COMPOSE
          boolean isTest = true

          if (!sshCfg) error('DEPLOY_SSH_CONFIG 不能为空')
          if (!deployRoot) error('DEPLOY_TARGET_DIR_TEST 不能为空')
          if (!staging || !composeSub || !composeFile) {
            error('DEPLOY_SSH_CONFIG / DEPLOY_STAGING_DIR / COMPOSE_DEPLOY_SUBPATH / REMOTE_COMPOSE_FILE 不能为空')
          }
          if (!deployRoot.startsWith('/') || !staging.startsWith('/')) {
            error('DEPLOY_TARGET_DIR 与 DEPLOY_STAGING_DIR 必须使用绝对路径')
          }
          echo "[deploy] ssh=${sshCfg} DEPLOY_TARGET_DIR_TEST=${deployRoot} subpath=${composeSub}"
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
    case "\$line" in ''|#*) continue ;; esac
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
