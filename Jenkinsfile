pipeline {
  agent { label 'built-in' }                 // wszystko na Built-In Node
  options { skipDefaultCheckout(true) }      // usuń automatyczny „Declarative: Checkout SCM”

  environment {
    ROBOT_DIR     = 'robot_reports'
    PY_ENV        = 'venv'
    HEADLESS      = 'true'
    EMAIL_FROM    = 'emil-pelak@wp.pl'
    MAX_ATTACH_MB = '7'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: '*/dev/main']],
          userRemoteConfigs: [[
            url: 'git@github.com:emil-pelak/CICD_Wikipedia.git',
            credentialsId: 'local_github-ssh'
          ]]
        ])
      }
    }

    stage('Install dependencies') {
      steps {
        sh '''
          set -e
          python3 -m venv "$PY_ENV" || true
          . "$PY_ENV/bin/activate"
          pip install --upgrade pip wheel
          pip install -r requirements.txt
        '''
      }
    }

    stage('Run tests') {
      steps {
        sh '''
          set -e
          echo "Cleaning old /tmp/robot-* profiles"
          find /tmp -maxdepth 1 -user "$(whoami)" -type d -name "robot-*" -exec rm -rf {} + || true

          . "$PY_ENV/bin/activate"
          mkdir -p "$ROBOT_DIR"

          robot \
            --outputdir "$ROBOT_DIR" \
            --reporttitle "Wikipedia - test report" \
            --logtitle    "Wikipedia - test log"  \
            --variable HEADLESS:${HEADLESS} \
            tests/
        '''
      }
    }
  }

  post {
    always {
      sh '''
        set -e
        if [ -d "$ROBOT_DIR" ]; then
          (cd "$ROBOT_DIR" && zip -9qr ../${ROBOT_DIR}.zip .) || true
        fi
      '''

      publishHTML(target: [
        allowMissing: true,
        keepAll: true,
        reportDir: "${ROBOT_DIR}",
        reportFiles: "report.html",
        reportName: "Robot Report"
      ])

      archiveArtifacts artifacts: "${ROBOT_DIR}/**, ${ROBOT_DIR}.zip", fingerprint: true

      script {
        // Links
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        // Git meta
        def branch      = sh(script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev/main', returnStdout: true).trim().replaceFirst(/^origin\\//,'')
        def shortSha    = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo ???????', returnStdout: true).trim()
        def commitTitle = sh(script: 'git log -1 --pretty=%s 2>/dev/null || echo "-"', returnStdout: true).trim()
        def author      = sh(script: 'git log -1 --pretty=%an 2>/dev/null || echo "-"', returnStdout: true).trim()

        // Passed/Failed z output.xml
        def xmlPath = "${ROBOT_DIR}/output.xml"
        def pfLine = fileExists(xmlPath)
          ? sh(returnStdout: true, script: """python3 - "${xmlPath}" <<'PY'
import sys, xml.etree.ElementTree as ET
p=f=0
try:
    root = ET.parse(sys.argv[1]).getroot()
    for s in root.findall('.//statistics/total/stat'):
        if (s.text or '').strip().lower() == 'all tests':
            p = int(s.get('pass') or 0)
            f = int(s.get('fail') or 0)
            break
except Exception:
    pass
print(f"{p},{f}")
PY
""").trim()
          : "0,0"

        def parts  = pfLine.split(',')
        def passed = (parts.length>0 && parts[0]) ? parts[0].toInteger() : 0
        def failed = (parts.length>1 && parts[1]) ? parts[1].toInteger() : 0

        String buildStatus = currentBuild.currentResult ?: 'SUCCESS'
        String subj        = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} - Robot Report"

        String body = """
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${subj}</title>
<style>
  body{font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;background:#f6f7fb;padding:18px}
  .card{max-width:960px;margin:auto;background:#fff;border:1px solid #e5e7eb;border-radius:14px;overflow:hidden}
  .hdr{padding:14px 18px;font-weight:700;background:${buildStatus=='SUCCESS' ? '#22c55e' : '#ef4444'};color:#fff}
  .grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;padding:16px 18px}
  .box{border:1px solid #eef2f7;border-radius:12px;padding:12px}
  .lbl{color:#6b7280;font-size:12px}
  .chip{display:inline-flex;align-items:center;gap:6px;padding:4px 10px;border:1px solid #e5e7eb;border-radius:999px;background:#f9fafb;font-family:ui-monospace,Menlo,Consolas,monospace}
  .branch{background:#eef2ff;border-color:#e0e7ff;color:#1e3a8a}
  .sha{background:#ecfeff;border-color:#cffafe;color:#155e75}
  .stats{display:grid;grid-template-columns:1fr 1fr;gap:12px;padding:0 18px 14px}
  .stat{border:1px solid #eef2f7;border-radius:12px;padding:14px;text-align:center}
  .stat h3{margin:0 0 6px 0;color:#6b7280;font-weight:600;font-size:13px}
  .stat .n{font-size:28px;font-weight:800;color:#111827}
  .btns{padding:0 18px 18px;display:flex;gap:10px;flex-wrap:wrap}
  a.btn{flex:1 1 240px;text-align:center;display:inline-block;box-sizing:border-box;padding:12px 16px;border-radius:10px;text-decoration:none;color:#fff;white-space:nowrap}
  .b1{background:#111827}.b2{background:#374151}.b3{background:#0ea5e9}
</style>
</head>
<body>
  <div class="card">
    <div class="hdr">${buildStatus} • ${env.JOB_NAME} • Build #${env.BUILD_NUMBER}</div>
    <div class="grid">
      <div class="box">
        <div class="lbl">Branch</div>
        <div class="chip branch">${branch}</div>
        <div style="height:8px"></div>
        <div class="lbl">SHA</div>
        <div class="chip sha">${shortSha}</div>
      </div>
      <div class="box">
        <div class="lbl">Commit title</div>
        <div style="font-weight:700">${commitTitle}</div>
        <div style="height:8px"></div>
        <div class="lbl">Author</div>
        <div>${author}</div>
      </div>
    </div>
    <div class="stats">
      <div class="stat"><h3>Passed</h3><div class="n">${passed}</div></div>
      <div class="stat"><h3>Failed</h3><div class="n">${failed}</div></div>
    </div>
    <div class="btns">
      <a class="btn b1" href="${reportUrl}"  target="_blank">Open "Wikipedia - test report"</a>
      <a class="btn b2" href="${consoleUrl}" target="_blank">Console Output</a>
      <a class="btn b3" href="${zipUrl}"     target="_blank">Download results (ZIP)</a>
    </div>
  </div>
</body>
</html>
"""
        def zipPath   = "${ROBOT_DIR}.zip"
        def attachZip = false
        if (fileExists(zipPath)) {
          try {
            long bytes   = (sh(script: "stat -c%s '${zipPath}' || echo 0", returnStdout: true).trim() as long)
            long maxByte = (env.MAX_ATTACH_MB as Integer) * 1024L * 1024L
            attachZip = (bytes > 0 && bytes <= maxByte)
            echo "ZIP size: ${bytes} bytes (attach <= ${maxByte}) -> attachZip=${attachZip}"
          } catch (ignored) {}
        }
        if (attachZip) {
          emailext(
            subject: subj,
            from: env.EMAIL_FROM,
            body: body,
            mimeType: 'text/html',
            attachmentsPattern: zipPath
          )
        } else {
          emailext(
            subject: subj,
            from: env.EMAIL_FROM,
            body: body,
            mimeType: 'text/html'
          )
        }
      }
    }
  }
}
