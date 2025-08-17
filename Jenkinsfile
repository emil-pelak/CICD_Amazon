pipeline {
  agent any

  environment {
    ROBOT_DIR  = "robot_reports"
    PY_ENV     = "venv"
    HEADLESS   = "true"                   // na Jenkinsie testy w headless
    EMAIL_FROM = "emil-pelak@wp.pl"
    EMAIL_TO   = "emil-pelak@outlook.com"
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
          python3 -m venv ${PY_ENV} || true
          . ${PY_ENV}/bin/activate
          pip install --upgrade pip wheel
          pip install -r requirements.txt
        '''
      }
    }

    stage('Run tests') {
      steps {
        sh '''
          set -e
          echo "🧹 Cleaning old /tmp/robot-* profiles"
          find /tmp -maxdepth 1 -user "$(whoami)" -type d -name "robot-*" -exec rm -rf {} + || true

          . ${PY_ENV}/bin/activate
          mkdir -p ${ROBOT_DIR}

          robot \
            --outputdir ${ROBOT_DIR} \
            --reporttitle "Wikipedia - test report" \
            --logtitle    "Wikipedia - test log"  \
            --variable HEADLESS:${HEADLESS} \
            tests/
        '''
      }
    }

    stage('Make snapshot & KPIs') {
      steps {
        sh '''
          set -e
          . ${PY_ENV}/bin/activate

          # --- Parse output.xml -> KPIs + timing ---
          python3 - <<'PY'
import os, xml.etree.ElementTree as ET, json
p = os.path.join(os.environ.get('ROBOT_DIR','robot_reports'),'output.xml')
root = ET.parse(p).getroot()

stat = root.find('./statistics/total/stat')
total  = stat.get('total') if stat is not None else '0'
passed = stat.get('pass')  if stat is not None else '0'
failed = stat.get('fail')  if stat is not None else '0'

ms = root.get('elapsedtime') or ''
elapsed = 'n/a'
if ms.isdigit():
    s = int(ms)//1000
    elapsed = f"{s//60:02d}:{s%60:02d}"

suite = root.find('./suite')
start = suite.get('starttime') if suite is not None else '-'
end   = suite.get('endtime')   if suite is not None else '-'

data = {"total": total, "passed": passed, "failed": failed,
        "elapsed": elapsed, "start": start, "end": end}
open(os.path.join('robot_reports','kpis.json'),'w').write(json.dumps(data))
PY

          # --- Screenshot report.html (Chrome headless) ---
          HTML="$(readlink -f ${ROBOT_DIR}/report.html)"
          SNAP="${ROBOT_DIR}/report_snapshot.png"
          okshot=0
          for C in google-chrome google-chrome-stable chromium chromium-browser; do
            if command -v "$C" >/dev/null 2>&1; then
              "$C" --headless=new --disable-gpu --no-sandbox \
                   --window-size=1600,1000 \
                   --screenshot="${SNAP}" "file://${HTML}" && okshot=1 && break
            fi
          done

          # Fallback przez Selenium (gdy brak CLI screena)
          if [ "$okshot" -ne 1 ]; then
            python3 - <<'PY'
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
import time, os
html = os.path.abspath('robot_reports/report.html')
opts = Options()
opts.add_argument('--headless=new')
opts.add_argument('--no-sandbox')
opts.add_argument('--disable-gpu')
opts.add_argument('--window-size=1600,1100')
driver = webdriver.Chrome(options=opts)
driver.get('file://' + html)
time.sleep(1)
driver.save_screenshot('robot_reports/report_snapshot.png')
driver.quit()
PY
          fi

          # Base64 do inline <img>
          base64 < "${SNAP}" > "${ROBOT_DIR}/report_snapshot.b64" || true

          # Zrób ZIP pełnych wyników (w tym dużych screenshotów z testów)
          ( cd "${ROBOT_DIR}" && zip -qr ../${ROBOT_DIR}.zip . )
        '''
      }
    }

    stage('Publish report') {
      steps {
        publishHTML(target: [
          allowMissing: false,
          keepAll: true,
          reportDir: "${ROBOT_DIR}",
          reportFiles: "report.html",
          reportName: "Robot Report"
        ])
        archiveArtifacts artifacts: "${ROBOT_DIR}/**, ${ROBOT_DIR}.zip", fingerprint: true
      }
    }
  }

  post {
    always {
      script {
        // Linki (publisher view dla HTML)
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        // Gałąź/commit
        def branch = 'dev/main'
        try {
          branch = sh(script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
        } catch (ignored) {}
        def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        def subject  = sh(script: 'git log -1 --pretty=%s', returnStdout: true).trim()
        def author   = sh(script: 'git log -1 --pretty="%an <%ae>"', returnStdout: true).trim()

        // KPI z pliku (unikamy Groovy sandbox na XML)
        def total='0', passed='0', failed='0', elapsed='n/a', startTime='-', endTime='-'
        if (fileExists("${ROBOT_DIR}/kpis.json")) {
          def k = readJSON(file: "${ROBOT_DIR}/kpis.json")
          total    = k.total   ?: '0'
          passed   = k.passed  ?: '0'
          failed   = k.failed  ?: '0'
          elapsed  = k.elapsed ?: 'n/a'
          startTime= k.start   ?: '-'
          endTime  = k.end     ?: '-'
        }
        def passRate = "0.0%"
        try { double t = total as double; double p = passed as double; passRate = t>0 ? String.format("%.1f%%",(p*100.0)/t) : "0.0%"; } catch (ignored) {}

        // Snapshot inline (data URI)
        def imgTag = ''
        if (fileExists("${ROBOT_DIR}/report_snapshot.b64")) {
          def b64 = readFile("${ROBOT_DIR}/report_snapshot.b64").trim()
          imgTag = '<img class="thumb" src="data:image/png;base64,' + b64 + '" alt="Robot report snapshot"/>'
        }

        // Status UI
        def buildStatus   = currentBuild.result ?: 'SUCCESS'
        def statusBadgeBg = (buildStatus == 'SUCCESS') ? "#16a34a" : "#dc2626"
        def statusIcon    = (buildStatus == 'SUCCESS') ? "✅" : "❌"
        def nodeName      = env.NODE_NAME ?: 'agent'
        def browser       = "Chrome (headless=${env.HEADLESS})"

        def subj = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Wikipedia - test report"

        def body = """
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${subj}</title>
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; background:#f8fafc; padding:20px }
  .card { background:#fff; border:1px solid #e5e7eb; border-radius:14px; max-width:980px; margin:auto; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,.06) }
  .status { background:${statusBadgeBg}; color:#fff; padding:16px 20px; font-size:18px; font-weight:700 }
  .sub { color:#e5e7eb; font-weight:500 }
  .grid { display:grid; grid-template-columns: repeat(5, minmax(120px,1fr)); gap:12px; padding:16px 20px 8px 20px }
  .kpi { background:#f9fafb; border:1px solid #eef2f7; border-radius:12px; padding:12px; text-align:center }
  .kpi .label { font-size:12px; color:#6b7280; display:block }
  .kpi .val   { font-size:22px; font-weight:800; margin-top:2px }
  .section { padding:0 20px 16px 20px }
  .h { font-weight:700; margin:8px 0 10px 0; color:#111827 }
  .mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background:#f3f4f6; padding:2px 6px; border-radius:6px }
  .btns { padding:0 20px 20px 20px }
  a.btn { display:inline-block; margin-right:10px; margin-top:10px; padding:10px 14px; border-radius:10px; text-decoration:none; color:#fff }
  a.primary   { background:#111827 }
  a.secondary { background:#374151 }
  a.zip       { background:#0ea5e9 }
  .meta { display:grid; grid-template-columns: 1fr 1fr; gap:12px }
  .box  { border:1px solid #eef2f7; border-radius:12px; padding:12px }
  .muted { color:#6b7280; font-size:12px }
  img.thumb { width:100%; max-width:940px; border:1px solid #eef2f7; border-radius:10px; display:block; }
</style>
</head>
<body>
  <div class="card">
    <div class="status">${statusIcon} ${buildStatus} <span class="sub">• ${env.JOB_NAME}</span> <span class="sub">• Build #${env.BUILD_NUMBER}</span></div>

    ${imgTag}

    <div class="grid">
      <div class="kpi"><span class="label">Total</span><span class="val">${total}</span></div>
      <div class="kpi"><span class="label">Passed</span><span class="val">${passed}</span></div>
      <div class="kpi"><span class="label">Failed</span><span class="val">${failed}</span></div>
      <div class="kpi"><span class="label">Pass rate</span><span class="val">${passRate}</span></div>
      <div class="kpi"><span class="label">Duration (mm:ss)</span><span class="val">${elapsed}</span></div>
    </div>

    <div class="section meta">
      <div class="box">
        <div class="h">Commit</div>
        <div><b>Branch:</b> <span class="mono">${branch}</span></div>
        <div><b>SHA:</b> <span class="mono">${shortSha}</span></div>
        <div><b>Message:</b> ${subject}</div>
        <div><b>Author:</b> ${author}</div>
      </div>
      <div class="box">
        <div class="h">Execution</div>
        <div><b>Start:</b> ${startTime}</div>
        <div><b>End:</b> ${endTime}</div>
        <div><b>Node:</b> ${nodeName}</div>
        <div><b>Browser:</b> ${browser}</div>
      </div>
    </div>

    <div class="btns">
      <a class="btn primary"   href="${reportUrl}"  target="_blank">🔎 Open “Wikipedia - test report”</a>
      <a class="btn secondary" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
      <a class="btn zip"       href="${zipUrl}"     target="_blank">📦 Download results (ZIP)</a>
    </div>

    <div class="section muted">Attached: report.html, log.html (kept small). Full results & big screenshots are in the ZIP artifact.</div>
  </div>
</body>
</html>
"""

        // wyślij maila; małe załączniki (HTML), ZIP tylko jako link
        emailext(
          subject:  subj,
          from:     env.EMAIL_FROM,
          to:       env.EMAIL_TO,
          body:     body,
          mimeType: 'text/html',
          attachmentsPattern: "${ROBOT_DIR}/report.html, ${ROBOT_DIR}/log.html"
        )

        echo "Pipeline finished: ${currentBuild.currentResult}"
      }
    }
  }
}
