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

    stage('Make snapshot & package') {
      steps {
        sh '''
          set -e
          HTML="$(readlink -f ${ROBOT_DIR}/report.html)"

          # unikalna nazwa pliku + usuń stare snapshoty
          SNAP="${ROBOT_DIR}/report_snapshot_${BUILD_NUMBER}.png"
          rm -f "${ROBOT_DIR}"/report_snapshot_*.png || true

          # poczekaj aż report.html przestanie się zmieniać
          for i in $(seq 1 30); do
            S1=$(stat -c%s "$HTML" 2>/dev/null || echo 0)
            sleep 0.3
            S2=$(stat -c%s "$HTML" 2>/dev/null || echo 0)
            if [ "$S1" = "$S2" ] && [ "$S2" -gt 0 ]; then break; fi
          done

          okshot=0
          for B in google-chrome-stable google-chrome chromium chromium-browser; do
            if command -v "$B" >/dev/null 2>&1; then
              "$B" --headless=new --disable-gpu --no-sandbox \
                  --user-data-dir="/tmp/snap-${BUILD_TAG}" \
                  --disk-cache-size=1 \
                  --window-size=1600,1000 \
                  --screenshot="${SNAP}" "file://${HTML}" && okshot=1 && break
            fi
          done

          if [ "$okshot" -eq 1 ]; then
            echo "SNAPSHOT_WRITTEN=${SNAP}" > .snapshot_env
            echo "✅ Report snapshot created at ${SNAP}"
          else
            : > .snapshot_env
            echo "⚠️  Could not create report snapshot (no Chrome/Chromium)."
          fi

          ( cd ${ROBOT_DIR} && zip -9qr ../${ROBOT_DIR}.zip . )
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
        // ----- Links -----
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        // ----- Git meta (safe fallbacks) -----
        def branch = sh(
          script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev/main',
          returnStdout: true
        ).trim().replaceFirst(/^origin\//,'')
        def shortSha = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo ???????', returnStdout: true).trim()
        def subject  = sh(script: 'git log -1 --pretty=%s 2>/dev/null || echo "-"', returnStdout: true).trim()
        def author   = sh(script: 'git log -1 --pretty="%an <%ae>" 2>/dev/null || echo "-"', returnStdout: true).trim()

        // ----- KPIs from output.xml -----
        def total='0', passed='0', failed='0', elapsed='n/a', startTime='-', endTime='-'
        try {
          def xml = new XmlSlurper().parse(new File("${env.WORKSPACE}/${ROBOT_DIR}/output.xml"))
          def stat = xml.statistics.total.stat[0]
          if (stat) {
            total  = (stat.@total?.toString() ?: '0')
            passed = (stat.@pass ?.toString() ?: '0')
            failed = (stat.@fail ?.toString() ?: '0')
          }
          def ms = (xml.@elapsedtime?.toString() ?: '')
          if (ms) {
            long s = (ms as long) / 1000L
            elapsed = String.format("%02d:%02d", (int)(s/60), (int)(s%60))
          }
          def suite = xml.suite[0]
          startTime = suite?.@starttime?.toString() ?: '-'
          endTime   = suite?.@endtime  ?.toString() ?: '-'
        } catch (e) {
          echo "WARN: Failed to parse output.xml: ${e}"
        }

        // ----- Decide what to render -----
        boolean hasStats  = !((total == '0' && passed == '0' && failed == '0') || total == null)
        boolean hasTiming = !((elapsed == 'n/a' || elapsed == null) && (startTime == '-' && endTime == '-'))

        String kpiSection = hasStats ? """
    <div class="grid">
      <div class="kpi"><span class="label">Total</span><span class="val">${total}</span></div>
      <div class="kpi"><span class="label">Passed</span><span class="val">${passed}</span></div>
      <div class="kpi"><span class="label">Failed</span><span class="val">${failed}</span></div>
      <div class="kpi"><span class="label">Pass rate</span><span class="val">${(total as Double) > 0 ? String.format("%.1f%%", (passed as Double)*100.0/(total as Double)) : "—"}</span></div>
      <div class="kpi"><span class="label">Duration (mm:ss)</span><span class="val">${elapsed}</span></div>
    </div>
""" : ""

        String execSection = hasTiming ? """
    <div class="section">
      <div class="h">Execution</div>
      <div><b>Start:</b> ${startTime}</div>
      <div><b>End:</b> ${endTime}</div>
      <div><b>Node:</b> ${env.NODE_NAME ?: 'built-in'}</div>
      <div><b>Browser:</b> Chrome (headless=${env.HEADLESS})</div>
    </div>
""" : ""

        // ----- read snapshot path created in stage -----
        if (fileExists('.snapshot_env')) {
          def txt = readFile('.snapshot_env').trim()
          if (txt?.startsWith('SNAPSHOT_WRITTEN=')) {
            env.SNAPSHOT_FILE = txt.split('=')[1]
          }
        }

        // ----- Inline snapshot (unique filename per build) -----
        def imgTag = ''
        def shot   = env.SNAPSHOT_FILE ?: "${env.WORKSPACE}/${ROBOT_DIR}/report_snapshot_${env.BUILD_NUMBER}.png"
        if (fileExists(shot)) {
          def b64 = sh(script: "base64 -w0 '${shot}'", returnStdout: true).trim()
          imgTag = '<img class="thumb" src="data:image/png;base64,' + b64 + '" alt="Robot report snapshot"/>'
        } else {
          imgTag = '<div style="padding:12px;border:1px dashed #ccc;border-radius:8px">Snapshot unavailable</div>'
        }

        // ----- Email -----
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

    <!-- KPIs (shown only when available) -->
    ${kpiSection}

    <div class="section">
      <div class="h">Commit</div>
      <div><b>Branch:</b> <span class="mono">${branch}</span></div>
      <div><b>SHA:</b> <span class="mono">${shortSha}</span></div>
      <div><b>Message:</b> ${subject}</div>
      <div><b>Author:</b> ${author}</div>
    </div>

    <!-- Execution (shown only when timing is available) -->
    ${execSection}

    <div class="btns">
      <a class="btn primary"   href="${reportUrl}"  target="_blank">🔎 Open “Wikipedia - test report”</a>
      <a class="btn secondary" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
      <a class="btn zip"       href="${zipUrl}"     target="_blank">📦 Download results (ZIP)</a>
    </div>

    <div class="section">${imgTag}</div>
    <div class="section muted">If Chrome blocks direct HTML artifacts due to CSP, use the “Robot Report” link above (publisher view).</div>
  </div>
</body>
</html>
"""

        // Attach ZIP if small enough
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
