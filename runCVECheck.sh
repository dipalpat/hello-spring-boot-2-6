function runCVECheck {

  # Extract the CycloneDX SBOM that advisor wrote into build-config.json to a
  # standalone file for Trivy to scan.
  jq '.sbom' target/.advisor/build-config.json > sbom-cdx.json

  echo "Scanning advisor's CycloneDX SBOM with Trivy..."
  trivy sbom --skip-db-update --quiet --format json --scanners vuln sbom-cdx.json > trivy-report.json 2> trivy-check.log
  local cve_count
  cve_count=$(jq '[.Results[]?.Vulnerabilities[]?] | length' trivy-report.json)
  echo "Found ${cve_count} known CVEs"
}

runCVECheck
