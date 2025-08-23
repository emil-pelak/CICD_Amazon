      // --- E-mail (KPI + screenshot) ---
      script {
        // Linki
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        // Git meta
        def branch = sh(
          script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev/main',
          returnStdout: true
        ).trim().replaceFirst(/^origin\\//,'')
        def shortSha    = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo ???????', returnStdout: true).trim()
        def commitTitle = sh(script: 'git log -1 --pretty=%s 2>/dev/null || echo "-"',   returnStdout: true).trim()
        def author      = sh(script: 'git log -1 --pretty="%an" 2>/dev/null || echo "-"', returnStdout: true).trim()

        // ── KPI z output.xml (Python; bez XmlSlurper) ──────────────────────────────
        def kpiOut = sh(
          script: '''
python3 - <<'PY'
import xml.etree.ElementTree as ET, sys
try:
    root = ET.parse('robot_reports/output.xml').getroot()
    stat = root.find('./statistics/total/stat')
    total  = (stat.get('total') if stat is not None else '0')
    passed = (stat.get('pass')  if stat is not None else '0')
    failed = (stat.get('fail')  if stat is not None else '0')
    ms = int(root.get('elapsedtime') or 0)
    dur = f"{ms//60000:02d}:{(ms//1000)%60:02d}"
    suite = root.find('suite')
    start = suite.get('starttime','-') if suite is not None else '-'
    end   = suite.get('endtime','-')   if suite is not None else '-'
    print("TOTAL="+total)
    print("PASSED="+passed)
    print("FAILED="+failed)
    print("DURATION="+dur)
    print("START="+start)
    print("END="+end)
except Exception:
    print("TOTAL=-\\nPASSED=-\\nFAILED=-\\nDURATION=-\\nSTART=-\\nEND=-")
PY
''',
          returnStdout: true
        ).trim()

        def total='-', passed='-', failed='-', duration='-', start='-', end='-'
        kpiOut.split('\\n').each { l ->
          def p = l.split('=',2); if (p.size()==2) {
            switch(p[0]) {
              case 'TOTAL':    total    = p[1]; break
              case 'PASSED':   passed   = p[1]; break
              case 'FAILED':   failed   = p[1]; break
              case 'DURATION': duration = p[1]; break
              case 'START':    start    = p[1]; break
              case 'END':      end      = p[1]; break
            }
          }
        }
        def passRate = '-'
        try {
          def t = total as Integer; def p = passed as Integer
          if (t > 0) { passRate = String.format('%.0f%%', (p*100.0)/t) }
        } catch (ignored) {}

        // Zrzut raportu (base64)
        def imgTag = ''
        def shot   = "${env.WORKSPACE}/${ROBOT_DIR}/report_snapshot.png"
        if (fileExists(shot)) {
          def b64 = sh(script: "base64 -w0 '${shot}'", returnStdout: true).trim()
          imgTag = '<img class="snap" src="data:image/png;base64,' + b64 + '" alt="Robot report" />'
        } else {
          imgTag = '<div class="snap-missing">Snapshot unavailable</div>'
        }

        // Status & tytuł
        def buildStatus = currentBuild.currentResult ?: 'SUCCESS'
        def statusColor = (buildStatus == 'SUCCESS') ? '#16a34a' : '#dc2626'
        def subj = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Robot Report"

        // Treść e-maila (z KPI)
        String body = """
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${subj}</title>
<style>
  body{font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;background:#f8fafc;margin:0;padding:20px}
  .card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;max-width:950px;margin:auto;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.06)}
  .status{background:${statusColor};color:#fff;padding:16px 20px;font-size:18px;font-weight:700}
  .section{padding:14px 20px}
  .grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
  .box{border:1px solid #eef2f7;border-radius:12px;padding:12px}
  .chip{display:inline-flex;align-items:center;gap:6px;padding:4px 10px;border-radius:999px;border:1px solid #e5e7eb;background:#f9fafb;font-family:ui-monospace,Menlo,monospace}
  .chip.branch{background:#eef2ff;border-color:#e0e7ff;color:#1e3a8a}
  .chip.sha{background:#ecfeff;border-color:#cffafe;color:#155e75}
  .lbl{color:#6b7280;font-size:12px;margin-right:6px}
  /* KPI row */
  .kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:10px}
  .kpi{background:#f9fafb;border:1px solid #eef2f7;border-radius:12px;padding:10px;text-align:center}
  .kpi .lab{font-size:12px;color:#6b7280}
  .kpi .val{font-size:22px;font-weight:800;margin-top:2px}
  .kpi.good .val{color:#16a34a}
  .kpi.bad  .val{color:#dc2626}
  /* przyciski */
  .btns{padding:0 20px 16px}
  a.btn{display:inline-block;margin-right:10px;margin-top:10px;padding:10px 14px;border-radius:10px;text-decoration:none;color:#fff}
  a.primary{background:#111827} a.secondary{background:#374151} a.zip{background:#0ea5e9}
  /* screenshot */
  img.snap{max-width:860px;width:100%;height:auto;border:1px solid #eef2f7;border-radius:10px;display:block}
  .snap-missing{border:1px dashed #e5e7eb;border-radius:10px;padding:14px;color:#6b7280}
</style>
</head>
<body>
  <div class="card">
    <div class="status">${buildStatus} • ${env.JOB_NAME} • Build #${env.BUILD_NUMBER}</div>

    <!-- Commit -->
    <div class="section">
      <div class="grid">
        <div class="box">
          <div><span class="lbl">Branch</span><span class="chip branch">${branch}</span></div>
          <div style="margin-top:8px"><span class="lbl">SHA</span><span class="chip sha">${shortSha}</span></div>
        </div>
        <div class="box">
          <div><span class="lbl">Commit title:</span><b>${commitTitle}</b></div>
          <div style="margin-top:6px"><span class="lbl">Author:</span>${author}</div>
        </div>
      </div>
    </div>

    <!-- KPI -->
    <div class="section">
      <div class="kpis">
        <div class="kpi"><div class="lab">All</div><div class="val">${total}</div></div>
        <div class="kpi good"><div class="lab">Passed</div><div class="val">${passed}</div></div>
        <div class="kpi bad"><div class="lab">Failed</div><div class="val">${failed}</div></div>
        <div class="kpi"><div class="lab">Pass rate</div><div class="val">${passRate}</div></div>
        <div class="kpi"><div class="lab">Duration</div><div class="val">${duration}</div></div>
      </div>
      <div style="margin-top:8px;color:#6b7280;font-size:12px">
        <span class="lbl">Start</span>${start} &nbsp;•&nbsp; <span class="lbl">End</span>${end}
      </div>
    </div>

    <!-- Linki -->
    <div class="btns">
      <a class="btn primary"   href="${reportUrl}"  target="_blank">🔎 Open "Wikipedia - test report"</a>
      <a class="btn secondary" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
      <a class="btn zip"       href="${zipUrl}"     target="_blank">📦 Download results (ZIP)</a>
    </div>

    <!-- Zrzut -->
    <div class="section">${imgTag}</div>
  </div>
</body>
</html>
"""
        // Wysyłka (ZIP tylko jeśli mały)
        def zipPath   = "${ROBOT_DIR}.zip"
        def attachZip = false
        if (fileExists(zipPath)) {
          try {
            long bytes   = (sh(script: "stat -c%s '${zipPath}' || echo 0", returnStdout: true).trim() as long)
            long maxByte = (env.MAX_ATTACH_MB as Integer) * 1024L * 1024L
            attachZip = (bytes > 0 && bytes <= maxByte)
          } catch (ignored) {}
        }
        if (attachZip) {
          emailext(subject: subj, from: env.EMAIL_FROM, to: env.EMAIL_TO, body: body, mimeType: 'text/html', attachmentsPattern: zipPath)
        } else {
          emailext(subject: subj, from: env.EMAIL_FROM, to: env.EMAIL_TO, body: body, mimeType: 'text/html')
        }
      }
