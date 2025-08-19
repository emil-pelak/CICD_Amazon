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

  options {
    timestamps()
    ansiColor('xterm')
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
        // Nie przerywaj całego pipeline przy błędzie – ale ustaw wynik na FAILURE
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
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
    }

    stage('Make snapshot & package') {
      when {
        expression { fileExists("${ROBOT_DIR}/report.html") }
      }
      steps {
        // Snapshot z report.html + spakowanie artefaktów
        sh '''
          set -e
          HTML="$(readlink -f ${ROBOT_DIR}/report.html)"
          SNAP="${ROBOT_DIR}/report_snapshot.png"

          okshot=0
          for B in google-chrome google-chrome-stable chromium chromium-browser; do
            if command -v "$B" >/dev/null 2>&1; then
              "$B" --headless=new --disable-gpu --no-sandbox \
                  --window-size=1920,1200 \
                  --screenshot="${SNAP}" "file://${HTML}" && okshot=1 && break
            fi
          done
          if [ "$okshot" -eq 1 ]; then
            echo "✅ Report snapshot created at ${SNAP}"
          else
            echo "⚠️  Could not create report snapshot (no Chrome/Chromium)."
          fi

          ( cd ${ROBOT_DIR} && zip -9qr ../${ROBOT_DIR}.zip . )
        '''
      }
    }

    stage('Publish report') {
      when {
        expression { fileExists("${ROBOT_DIR}/report.html") }
      }
      steps {
        script {
          try {
            publishHTML(target: [
              allowMissing: false,
              keepAll: true,
              reportDir: "${ROBOT_DIR}",
              reportFiles: "report.html",
              reportName: "Robot Report"
            ])
          } catch (e) {
            echo "WARN publishHTML: ${e}"
          }
        }
        archiveArtifacts artifacts: "${ROBOT_DIR}/**, ${ROBOT_DIR}.zip", fingerprint: true
      }
    }
  }

  post {
    always {
      script {
        // ----- Linki -----
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        // ----- Git meta (z bezpiecznymi fallbackami) -----
        def branch = sh(
          script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev/main',
          returnStdout: true
        ).trim().replaceFirst(/^origin\\//,'')
        def shortSha = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo ???????', returnStdout: true).trim()
        def subject  = sh(script: 'git log -1 --pretty=%s 2>/dev/null || echo "-"', returnStdout: true).trim()
        def author   = sh(script: 'git log -1 --pretty="%an <%ae>" 2>/dev/null || echo "-"', returnStdout: true).trim()

        // ----- Spróbuj utworzyć snapshot, jeśli nie powstał w etapie -----
        def shotPath = "${env.WORKSPACE}/${ROBOT_DIR}/report_snapshot.png"
        if (!fileExists(shotPath) && fileExists("${env.WORKSPACE}/${ROBOT_DIR}/report.html")) {
          sh '''
            set -e
            HTML="$(readlink -f ${ROBOT_DIR}/report.html)"
            SNAP="${ROBOT_DIR}/report_snapshot.png"
            for B in google-chrome google-chrome-stable chromium chromium-browser; do
              if command -v "$B" >/dev/null 2>&1; then
                "$B" --headless=new --disable-gpu --no-sandbox --window-size=1920,1200 \
                    --screenshot="${SNAP}" "file://${HTML}" && break
              fi
            done
          '''
        }

        // ----- KPI z output.xml – bez XmlSlurper (Python -> env file) -----
        sh '''
          set -e
          OUT="${ROBOT_DIR}/output.xml"
          [ -f "$OUT" ] || { : > "${ROBOT_DIR}/metrics.env"; exit 0; }
          python3 - "$OUT" > "${ROBOT_DIR}/metrics.env" << 'PY'
import sys, xml.etree.ElementTree as ET
p = sys.argv[1]
try:
    root = ET.parse(p).getroot()
    ms = root.attrib.get("elapsedtime","")
    if ms:
        s = int(ms)//1000
        dur = f"{s//60:02d}:{s%60:02d}"
    else:
        dur = "n/a"
    stat = root.find("./statistics/total/stat")
    total  = stat.get("total","0") if stat is not None else "0"
    passed = stat.get("pass","0")  if stat is not None else "0"
    failed = stat.get("fail","0")  if stat is not None else "0"
    print(f"TOTAL={total}")
    print(f"PASSED={passed}")
    print(f"FAILED={failed}")
    print(f"DURATION={dur}")
except Exception:
    pass
PY
        '''

        def total='0', passed='0', failed='0', elapsed='n/a'
        if (fileExists("${ROBOT_DIR}/metrics.env")) {
          def lines = readFile("${ROBOT_DIR}/metrics.env").trim().split("\\n")
          def M = [:]
          lines.each { l ->
            def kv = l.tokenize('=')
            if (kv.size()==2) M[kv[0]] = kv[1]
          }
          total   = M['TOTAL']   ?: '0'
          passed  = M['PASSED']  ?: '0'
          failed  = M['FAILED']  ?: '0'
          elapsed = M['DURATION']?: 'n/a'
        }

        // Pokaż KPI tylko jeśli sensownie policzone
        boolean hasStats  = !(total == '0' && passed == '0' && failed == '0')
        boolean hasTiming = !(elapsed == 'n/a')

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
      <div><b>Node:</b> ${env.NODE_NAME ?: 'built-in'}</div>
      <div><b>Browser:</b> Chrome (headless=${env.HEADLESS})</div>
    </div>
""" : ""

        // ----- Inline snapshot (albo placeholder) -----
        def imgTag = '<div class="placeholder">Snapshot unavailable</div>'
        if (fileExists(shotPath)) {
          def b64 = sh(script: "base64 -w0 '${shotPath}'", returnStdout: true).trim()
          imgTag = '<img class="thumb" src="data:image/png;base64,' + b64 + '" alt="Robot report snapshot"/>'
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
  .placeholder { border:1px dashed #cbd5e1; background:#fff; border-radius:10px; color:#64748b; padding:24px; text-align:center }
</style>
</head>
<body>
  <div class="card">
    <div class="status">${statusIcon} ${buildStatus} <span class="sub">• ${env.JOB_NAME}</span> <span class="sub">• Build #${env.BUILD_NUMBER}</span></div>

    ${kpiSection}

    <div class="section">
      <div class="h">Commit</div>
      <div><b>Branch:</b> <span class="mono">${branch}</span></div>
      <div><b>SHA:</b> <span class="mono">${shortSha}</span></div>
      <div><b>Message:</b> ${subject}</div>
      <div><b>Author:</b> ${author}</div>
    </div>

    ${execSection}

    <div class="btns">
      <a class="btn primary"   href="${reportUrl}"  target="_blank">🔎 Open “Wikipedia - test report”</a>
      <a class="btn secondary" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
      <a class="btn zip"       href="${zipUrl}"     target="_blank">📦 Download r_
