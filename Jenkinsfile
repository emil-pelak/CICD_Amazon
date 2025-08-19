pipeline {
  agent any

  environment {
    ROBOT_DIR      = "robot_reports"
    PY_ENV         = "venv"
    HEADLESS       = "true"                 // run headless on Jenkins
    EMAIL_FROM     = "emil-pelak@wp.pl"
    EMAIL_TO       = "emil-pelak@outlook.com"
    MAX_ATTACH_MB  = "7"                    // cap email attachment size
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

    // (opcjonalnie) możesz zostawić puste miejsce na kolejne stage'e
  }

  post {
    // To wykona się ZAWSZE – także gdy testy padną.
    always {
      // 1) Snapshot + KPI + ZIP (w shellu, aby nie wchodzić w konflikt z sandboxem)
      sh '''
        set -e
        mkdir -p "${ROBOT_DIR}"

        HTML="$(readlink -f ${ROBOT_DIR}/report.html || true)"
        SNAP="${ROBOT_DIR}/report_snapshot.png"

        # --- Snapshot reportu ---
        if [ -n "$HTML" ] && [ -f "$HTML" ]; then
          okshot=0
          for B in google-chrome google-chrome-stable chromium chromium-browser; do
            if command -v "$B" >/dev/null 2>&1; then
              "$B" --headless=new --disable-gpu --no-sandbox \
                  --window-size=1600,1000 \
                  --screenshot="${SNAP}" "file://${HTML}" && okshot=1 && break
            fi
          done
          if [ "$okshot" -eq 1 ]; then
            echo "✅ Report snapshot created at ${SNAP}"
          else
            echo "⚠️  Could not create report snapshot (no Chrome/Chromium)."
          fi
        else
          echo "⚠️  ${ROBOT_DIR}/report.html not found – skipping snapshot."
        fi

        # --- KPI z output.xml przez Python (bez Groovy parsers) ---
        KPI_DIR="${ROBOT_DIR}"
        rm -f "${KPI_DIR}/total.txt" "${KPI_DIR}/passed.txt" "${KPI_DIR}/failed.txt" "${KPI_DIR}/duration.txt" >/dev/null 2>&1 || true

        if [ -f "${ROBOT_DIR}/output.xml" ]; then
          python3 - <<'PY'
import xml.etree.ElementTree as ET, sys, math
root = ET.parse("robot_reports/output.xml").getroot()
# total/passed/failed
stat = root.find("./statistics/total/stat")
tot  = int(stat.get("total","0")) if stat is not None else 0
pas  = int(stat.get("pass","0"))  if stat is not None else 0
fail = int(stat.get("fail","0"))  if stat is not None else 0
# elapsed ms -> mm:ss
ms   = int(root.get("elapsedtime","0") or 0)
s    = ms // 1000
mm   = s // 60
ss   = s % 60
mmss = f"{mm:02d}:{ss:02d}" if ms>0 else "n/a"

open("robot_reports/total.txt","w").write(str(tot))
open("robot_reports/passed.txt","w").write(str(pas))
open("robot_reports/failed.txt","w").write(str(fail))
open("robot_reports/duration.txt","w").write(mmss)
PY
        else
          echo "⚠️  ${ROBOT_DIR}/output.xml not found – KPIs unavailable."
        fi

        # --- ZIP artefaktów ---
        ( cd ${ROBOT_DIR} && zip -9qr ../${ROBOT_DIR}.zip . ) || true
      '''

      // 2) Publikacja (działa także przy FAIL – już po zakończeniu joba)
      publishHTML(target: [
        allowMissing: true,   // pozwól nawet gdy katalogu brak
        keepAll: true,
        reportDir: "${ROBOT_DIR}",
        reportFiles: "report.html",
        reportName: "Robot Report"
      ])
      archiveArtifacts artifacts: "${ROBOT_DIR}/**, ${ROBOT_DIR}.zip", fingerprint: true

      // 3) Budowa maila
      script {
        // --- Linki ---
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        // --- Git meta ---
        def branch = sh(
          script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev/main',
          returnStdout: true
        ).trim().replaceFirst(/^origin\\//,'')
        def shortSha = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo ???????', returnStdout: true).trim()
        def subject  = sh(script: 'git log -1 --pretty=%s 2>/dev/null || echo "-"', returnStdout: true).trim()
        def author   = sh(script: 'git log -1 --pretty="%an <%ae>" 2>/dev/null || echo "-"', returnStdout: true).trim()

        // --- KPI wczytane Z PLIKÓW (żadnych groovy parsers) ---
        def total    = fileExists("${ROBOT_DIR}/total.txt")    ? readFile("${ROBOT_DIR}/total.txt").trim()    : ""
        def passed   = fileExists("${ROBOT_DIR}/passed.txt")   ? readFile("${ROBOT_DIR}/passed.txt").trim()   : ""
        def failed   = fileExists("${ROBOT_DIR}/failed.txt")   ? readFile("${ROBOT_DIR}/failed.txt").trim()   : ""
        def duration = fileExists("${ROBOT_DIR}/duration.txt") ? readFile("${ROBOT_DIR}/duration.txt").trim() : "n/a"

        // Oblicz pass rate tylko gdy mamy sensowne total
        def passRate = "-"
        try {
          double t = (total ?: "0") as double
          double p = (passed ?: "0") as double
          passRate = t > 0 ? String.format("%.1f%%", (p*100.0)/t) : "-"
        } catch (ignore) {}

        // Pokaż sekcję KPI tylko gdy mamy jakieś dane (tu: pokazujemy zawsze, ale ALL/Duration będą "—"/"n/a" gdy brak)
        def showAll    = (total   && total   != "0") ? total    : "—"
        def showPassed = (passed)                    ? passed   : "—"
        def showFailed = (failed)                    ? failed   : "—"
        def showRate   = passRate
        def showTime   = (duration ?: "n/a")

        // --- Snapshot inline (jeśli istnieje) ---
        def imgTag = ''
        def shot   = "${env.WORKSPACE}/${ROBOT_DIR}/report_snapshot.png"
        if (fileExists(shot)) {
          def b64 = sh(script: "base64 -w0 '${shot}'", returnStdout: true).trim()
          imgTag = '<img class="thumb" src="data:image/png;base64,' + b64 + '" alt="Robot report snapshot"/>'
        } else {
          imgTag = '<div class="thumb" style="border:1px dashed #e5e7eb;border-radius:10px;padding:14px;color:#6b7280">Snapshot unavailable</div>'
        }

        // --- Email ---
        String buildStatus = currentBuild.currentResult ?: 'SUCCESS'
        String statusColor = (buildStatus == 'SUCCESS') ? '#16a34a' : '#dc2626'
        String statusIcon  = (buildStatus == 'SUCCESS') ? '✅' : '❌'
        String subj        = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Wikipedia - test report"

        String body = """
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${subj}</title>
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; background:#f8fafc; padding:20px }
  .card { background:#fff; border:1px solid #e5e7eb; border-radius:14px; max-width:900px; margin:auto; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,.06) }
  .status { background:${statusColor}; color:#fff; padding:16px 20px; font-size:18px; font-weight:700 }
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
  .box  { border:1px solid #eef2f7; border-radius:12px; padding:12px }
  .muted { color:#6b7280; font-size:12px }
  img.thumb { width:100%; max-width:880px; border:1px solid #eef2f7; border-radius:10px; display:block; }
</style>
</head>
<body>
  <div class="card">
    <div class="status">${statusIcon} ${buildStatus} <span class="sub">• ${env.JOB_NAME}</span> <span class="sub">• Build #${env.BUILD_NUMBER}</span></div>

    <div class="grid">
      <div class="kpi"><span class="label">All</span><span class="val">${showAll}</span></div>
      <div class="kpi"><span class="label">Passed</span><span class="val">${showPassed}</span></div>
      <div class="kpi"><span class="label">Failed</span><span class="val">${showFailed}</span></div>
      <div class="kpi"><span class="label">Pass rate</span><span class="val">${showRate}</span></div>
      <div class="kpi"><span class="label">Duration (mm:ss)</span><span class="val">${showTime}</span></div>
    </div>

    <div class="section">
      <div class="h">Commit</div>
      <div><b>Branch:</b> <span class="mono">${branch}</span></div>
      <div><b>SHA:</b> <span class="mono">${shortSha}</span></div>
      <div><b>Message:</b> ${subject}</div>
      <div><b>Author:</b> ${author}</div>
    </div>

    <div class="btns">
      <a class="btn primary"   href="${reportUrl}"  target="_blank">🔎 Open “Wikipedia - test report”</a>
      <a class="btn secondary" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
      <a class="btn zip"       href="${zipUrl}"     target="_blank">📦 Download results (ZIP)</a>
    </div>

    <div class="section">${imgTag}</div>
    <div class="section muted">
      If Chrome blocks direct HTML artifacts due to CSP, use the “Open “Wikipedia - test report” or “Console Output” link above (publisher view).
    </div>
  </div>
</body>
</html>
"""

        // Załącz ZIP jeśli mały
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
          emailext(subject: subj, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: body, mimeType: 'text/html', attachmentsPattern: zipPath)
        } else {
          emailext(subject: subj, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: body, mimeType: 'text/html')
        }

        echo "Pipeline finished: ${currentBuild.currentResult}"
      }
    }
  }
}
