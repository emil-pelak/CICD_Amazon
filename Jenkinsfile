pipeline {
  agent any

  environment {
    ROBOT_DIR     = "robot_reports"
    PY_ENV        = "venv"
    HEADLESS      = "true"

    EMAIL_FROM    = "emil-pelak@wp.pl"
    EMAIL_TO      = "emil-pelak@outlook.com"
    MAX_ATTACH_MB = "7"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: "*/dev/main"]],
          userRemoteConfigs: [[
            url: "git@github.com:emil-pelak/CICD_Wikipedia.git",
            credentialsId: "local_github-ssh"
          ]]
        ])
      }
    }

    stage('Install dependencies') {
      steps {
        sh '''
          set -e
          python3 -m venv "${PY_ENV}" || true
          . "${PY_ENV}/bin/activate"
          pip install --upgrade pip wheel
          pip install -r requirements.txt
        '''
      }
    }

    stage('Run tests') {
      steps {
        // użyj bash, żeby działał pipefail, a Groovy nic nie interpolował
        sh(script: '''bash -lc '
set -Eeuo pipefail
echo "Cleaning old /tmp/robot-* profiles"
find /tmp -maxdepth 1 -user "$(whoami)" -type d -name "robot-*" -exec rm -rf {} + || true

. "${PY_ENV}/bin/activate"
mkdir -p "${ROBOT_DIR}"

robot \
  --outputdir "${ROBOT_DIR}" \
  --reporttitle "Wikipedia - test report" \
  --logtitle    "Wikipedia - test log"  \
  --variable HEADLESS:${HEADLESS} \
  tests/ 2>&1 | tee "${ROBOT_DIR}/robot_console.txt"
' ''')
      }
    }
  }

  post {
    always {
      // ZIP + publikacja raportu
      sh '''
        set -e
        if [ -d "${ROBOT_DIR}" ]; then
          ( cd "${ROBOT_DIR}" && zip -9qr "../${ROBOT_DIR}.zip" . ) || true
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
        // ----- Linki -----
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${env.ROBOT_DIR}.zip"

        // ----- Git meta -----
        def branch = sh(
          script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev/main',
          returnStdout: true
        ).trim().replaceFirst(/^origin\\//,'')
        def shortSha    = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo ???????', returnStdout: true).trim()
        def commitTitle = sh(script: 'git log -1 --pretty=%s 2>/dev/null || echo "-"', returnStdout: true).trim()
        def author      = sh(script: 'git log -1 --pretty=%an 2>/dev/null || echo "-"', returnStdout: true).trim()

        // ----- KPIs: spróbuj z output.xml; fallback: konsola Robota -----
        int passed = 0, failed = 0

        def kv = sh(
          script: '''python3 - <<'PY'
import os, xml.etree.ElementTree as ET
ws = os.environ.get('WORKSPACE','.')
rd = os.environ.get('ROBOT_DIR','robot_reports')
p  = os.path.join(ws, rd, 'output.xml')
passed = failed = 0
try:
    if os.path.isfile(p):
        r=ET.parse(p).getroot()
        s=r.find('./statistics/total/stat')
        if s is not None:
            passed=int(s.get('pass') or 0)
            failed=int(s.get('fail') or 0)
except Exception:
    pass
print(f"PASSED={passed}\\nFAILED={failed}")
PY
''',
          returnStdout: true
        ).trim()

        def m = (kv =~ /PASSED=(\\d+)\\s+FAILED=(\\d+)/)
        if (m.find()) {
          passed = (m.group(1) as int)
          failed = (m.group(2) as int)
        }

        if (passed == 0 && failed == 0 && fileExists("${env.ROBOT_DIR}/robot_console.txt")) {
          def line = sh(
            script: "grep -E '[0-9]+ tests, [0-9]+ passed, [0-9]+ failed' '${env.ROBOT_DIR}/robot_console.txt' | tail -1 || true",
            returnStdout: true
          ).trim()
          def mr = (line =~ /(\\d+)\\s+tests,\\s+(\\d+)\\s+passed,\\s+(\\d+)\\s+failed/)
          if (mr.find()) {
            passed = (mr.group(2) as int)
            failed = (mr.group(3) as int)
          }
        }

        // ----- Mail (bez screena) -----
        String buildStatus = currentBuild.currentResult ?: 'SUCCESS'
        String statusColor = (buildStatus == 'SUCCESS') ? '#16a34a' : '#dc2626'
        String statusIcon  = (buildStatus == 'SUCCESS') ? '✅' : '❌'
        String mailSubject = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} - Wikipedia - test report"

        String body = """
<!doctype html>
<html>
<head>
<meta charset='utf-8'/>
<title>${mailSubject}</title>
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; background:#f8fafc; padding:20px }
  .card { background:#fff; border:1px solid #e5e7eb; border-radius:14px; max-width:900px; margin:auto; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,.06) }
  .status { background:${statusColor}; color:#fff; padding:16px 20px; font-size:18px; font-weight:700 }
  .sub { color:#e5e7eb; font-weight:500 }
  .section { padding:16px 20px }
  .meta { display:grid; grid-template-columns: 1fr 1fr; gap:12px }
  .box  { border:1px solid #eef2f7; border-radius:12px; padding:12px }
  .row  { margin:6px 0; display:flex; align-items:center; gap:8px; flex-wrap:wrap }
  .label{ color:#6b7280; font-size:12px }
  .chip { display:inline-flex; align-items:center; gap:6px; padding:4px 10px; border-radius:999px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; border:1px solid #e5e7eb; background:#f9fafb }
  .chip.branch { background:#eef2ff; border-color:#e0e7ff; color:#1e3a8a }
  .chip.sha    { background:#ecfeff; border-color:#cffafe; color:#155e75 }
  .grid2 { display:grid; grid-template-columns: repeat(2, minmax(120px,1fr)); gap:12px; padding:4px 20px 8px 20px }
  .kpi { background:#f9fafb; border:1px solid #eef2f7; border-radius:12px; padding:12px; text-align:center }
  .kpi .label { font-size:12px; color:#6b7280; display:block }
  .kpi .val   { font-size:22px; font-weight:800; margin-top:2px }
  .btns { padding:0 20px 20px 20px }
  a.btn { display:inline-block; margin-right:10px; margin-top:10px; padding:10px 14px; border-radius:10px; text-decoration:none; color:#fff }
  a.primary   { background:#111827 }
  a.secondary { background:#374151 }
  a.zip       { background:#0ea5e9 }
</style>
</head>
<body>
  <div class='card'>
    <div class='status'>${statusIcon} ${buildStatus} <span class='sub'>• ${env.JOB_NAME}</span> <span class='sub'>• Build #${env.BUILD_NUMBER}</span></div>

    <div class='section'>
      <div class='meta'>
        <div class='box'>
          <div class='row'><span class='label'>Branch</span> <span class='chip branch'>${branch}</span></div>
          <div class='row'><span class='label'>SHA</span>    <span class='chip sha'>${shortSha}</span></div>
        </div>
        <div class='box'>
          <div class='row'><span class='label'>Commit title:</span> <span style='font-weight:700'>${commitTitle}</span></div>
          <div class='row'><span class='label'>Author:</span> <span>${author}</span></div>
        </div>
      </div>
    </div>

    <div class='grid2'>
      <div class='kpi'><span class='label'>Passed</span><span class='val'>${passed}</span></div>
      <div class='kpi'><span class='label'>Failed</span><span class='val'>${failed}</span></div>
    </div>

    <div class='btns'>
      <a class='btn primary'   href='${reportUrl}'  target='_blank'>🔎 Open "Wikipedia - test report"</a>
      <a class='btn secondary' href='${consoleUrl}' target='_blank'>🖥 Console Output</a>
      <a class='btn zip'       href='${zipUrl}'     target='_blank'>📦 Download results (ZIP)</a>
    </div>
  </div>
</body>
</html>
"""

        // Załącz ZIP jeśli nie jest za duży
        def zipPath   = "${env.ROBOT_DIR}.zip"
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
          emailext(subject: mailSubject, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: body, mimeType: 'text/html', attachmentsPattern: zipPath)
        } else {
          emailext(subject: mailSubject, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: body, mimeType: 'text/html')
        }
      }
    }
  }
}
