#!/usr/bin/env bats
#
# Tests for lb-functions and appgw-functions
#
# Run:  bats test/lb-appgw.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  # Stub `az` with canned output for lb and appgw commands
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB_BIN"
  cat > "$STUB_BIN/az" <<'EOF'
#!/bin/bash

# --- Load Balancer stubs ---
if [[ "$1" == "network" && "$2" == "lb" && "$3" == "list" ]]; then
  printf 'prod-rg/web-lb\tStandard\tPublic\teastus\tSucceeded\n'
  printf 'prod-rg/internal-lb\tStandard\tPrivate\teastus\tSucceeded\n'
  printf 'dev-rg/dev-lb\tBasic\tPublic\twestus2\tSucceeded\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "lb" && "$3" == "rule" && "$4" == "list" ]]; then
  printf 'http-rule\tTcp\t80\t8080\tprod-rg/web-lb\n'
  printf 'https-rule\tTcp\t443\t8443\tprod-rg/web-lb\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "lb" && "$3" == "probe" && "$4" == "list" ]]; then
  printf 'http-probe\tHttp\t80\t/healthz\t15\t2\tprod-rg/web-lb\n'
  printf 'tcp-probe\tTcp\t443\tnull\t30\t3\tprod-rg/web-lb\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "lb" && "$3" == "address-pool" && "$4" == "list" ]]; then
  printf 'web-backend-pool\t2\tprod-rg/web-lb\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "lb" && "$3" == "frontend-ip" && "$4" == "list" ]]; then
  printf 'frontend-ip-01\tPublic\t20.1.2.3\tprod-rg/web-lb\n'
  printf 'frontend-ip-02\tPrivate\t10.0.1.100\tprod-rg/web-lb\n'
  exit 0
fi

# --- Application Gateway stubs ---
if [[ "$1" == "network" && "$2" == "application-gateway" && "$3" == "list" ]]; then
  printf 'prod-rg/web-appgw\tStandard_v2\t2\tRunning\teastus\tSucceeded\n'
  printf 'prod-rg/api-appgw\tWAF_v2\t3\tRunning\teastus\tSucceeded\n'
  printf 'dev-rg/dev-appgw\tStandard_v2\t1\tRunning\twestus2\tSucceeded\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "application-gateway" && "$3" == "http-listener" && "$4" == "list" ]]; then
  printf 'https-listener\tHttps\t443\twww.example.com\tprod-rg/web-appgw\n'
  printf 'http-listener\tHttp\t80\twww.example.com\tprod-rg/web-appgw\n'
  printf 'api-listener\tHttps\t443\tapi.example.com\tprod-rg/web-appgw\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "application-gateway" && "$3" == "rule" && "$4" == "list" ]]; then
  printf 'https-rule\tBasic\t100\thttps-listener\tprod-rg/web-appgw\n'
  printf 'http-rule\tPathBased\t200\thttp-listener\tprod-rg/web-appgw\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "application-gateway" && "$3" == "address-pool" && "$4" == "list" ]]; then
  printf 'web-backend\t3\tprod-rg/web-appgw\n'
  printf 'api-backend\t2\tprod-rg/web-appgw\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "application-gateway" && "$3" == "ssl-cert" && "$4" == "list" ]]; then
  printf 'wildcard-cert\tKeyVault\tprod-rg/web-appgw\n'
  printf 'api-cert\tUploaded\tprod-rg/web-appgw\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "application-gateway" && "$3" == "ssl-profile" && "$4" == "list" ]]; then
  printf 'strict-profile\tAppGwSslPolicy20220101S\t1\tprod-rg/web-appgw\n'
  printf 'default-profile\tAppGwSslPolicy20220101\t0\tprod-rg/web-appgw\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "application-gateway" && "$3" == "probe" && "$4" == "list" ]]; then
  printf 'web-probe\tHttps\t/health\t30\t3\tprod-rg/web-appgw\n'
  printf 'api-probe\tHttp\t/readyz\t15\t2\tprod-rg/web-appgw\n'
  exit 0
fi

if [[ "$1" == "network" && "$2" == "application-gateway" && "$3" == "frontend-ip" && "$4" == "list" ]]; then
  printf 'appGwPublicFrontendIp\tPublic\t20.53.1.100\tprod-rg/web-appgw\n'
  printf 'appGwPrivateFrontendIp\tPrivate\t10.0.1.50\tprod-rg/web-appgw\n'
  exit 0
fi

exit 0
EOF
  chmod +x "$STUB_BIN/az"
  PATH="$STUB_BIN:$PATH"

  export BMAZ_COLUMNISE_ONLY_WHEN_TERMINAL_PRESENT=true
  export BMAZ_HOME="$REPO_ROOT"

  source "$REPO_ROOT/lib/shared-functions"
  source "$REPO_ROOT/lib/lb-functions"
  source "$REPO_ROOT/lib/appgw-functions"
}

# =============================================================================
# Load Balancer tests
# =============================================================================

# --- lbs ---------------------------------------------------------------------

@test "lbs lists and sorts by first column" {
  run lbs </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == dev-rg/dev-lb* ]]
  [[ "${lines[1]}" == prod-rg/internal-lb* ]]
  [[ "${lines[2]}" == prod-rg/web-lb* ]]
}

@test "lbs applies filter" {
  run lbs web </dev/null
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == prod-rg/web-lb* ]]
}

@test "lbs --help prints doc block" {
  run lbs --help
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "List Load Balancers" ]
}

# --- lb-rules ----------------------------------------------------------------

@test "lb-rules lists rules for a given LB" {
  run lb-rules prod-rg/web-lb </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == http-rule* ]]
  [[ "${lines[1]}" == https-rule* ]]
}

@test "lb-rules reads from stdin" {
  run bash -c "source '$REPO_ROOT/lib/shared-functions'; source '$REPO_ROOT/lib/lb-functions'; echo 'prod-rg/web-lb' | lb-rules"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == http-rule* ]]
}

@test "lb-rules errors without args or stdin" {
  run lb-rules </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "lb-rules --help prints doc block" {
  run lb-rules --help
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"load balancing rules"* ]]
}

# --- lb-probes ---------------------------------------------------------------

@test "lb-probes lists probes for a given LB" {
  run lb-probes prod-rg/web-lb </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == http-probe* ]]
  [[ "${lines[1]}" == tcp-probe* ]]
}

@test "lb-probes errors without args" {
  run lb-probes </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"USAGE"* ]]
}

# --- lb-backends -------------------------------------------------------------

@test "lb-backends lists backend pools" {
  run lb-backends prod-rg/web-lb </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == web-backend-pool* ]]
}

# --- lb-frontend-ips ---------------------------------------------------------

@test "lb-frontend-ips lists frontend IPs" {
  run lb-frontend-ips prod-rg/web-lb </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == frontend-ip-01* ]]
  [[ "${lines[1]}" == frontend-ip-02* ]]
}

# =============================================================================
# Application Gateway tests
# =============================================================================

# --- appgws ------------------------------------------------------------------

@test "appgws lists and sorts by first column" {
  run appgws </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == dev-rg/dev-appgw* ]]
  [[ "${lines[1]}" == prod-rg/api-appgw* ]]
  [[ "${lines[2]}" == prod-rg/web-appgw* ]]
}

@test "appgws applies filter" {
  run appgws web </dev/null
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == prod-rg/web-appgw* ]]
}

@test "appgws --help prints doc block" {
  run appgws --help
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "List Application Gateways" ]
}

# --- appgw-listeners ---------------------------------------------------------

@test "appgw-listeners lists listeners for a given AppGW" {
  run appgw-listeners prod-rg/web-appgw </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == https-listener* ]]
  [[ "${lines[1]}" == http-listener* ]]
  [[ "${lines[2]}" == api-listener* ]]
}

@test "appgw-listeners reads from stdin" {
  run bash -c "source '$REPO_ROOT/lib/shared-functions'; source '$REPO_ROOT/lib/appgw-functions'; echo 'prod-rg/web-appgw' | appgw-listeners"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == https-listener* ]]
}

@test "appgw-listeners errors without args" {
  run appgw-listeners </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "appgw-listeners --help prints doc block" {
  run appgw-listeners --help
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"HTTP listeners"* ]]
}

# --- appgw-rules -------------------------------------------------------------

@test "appgw-rules lists routing rules" {
  run appgw-rules prod-rg/web-appgw </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == https-rule* ]]
  [[ "${lines[1]}" == http-rule* ]]
}

@test "appgw-rules errors without args" {
  run appgw-rules </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"USAGE"* ]]
}

# --- appgw-backends ----------------------------------------------------------

@test "appgw-backends lists backend pools" {
  run appgw-backends prod-rg/web-appgw </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == web-backend* ]]
  [[ "${lines[1]}" == api-backend* ]]
}

# --- appgw-ssl-certs ---------------------------------------------------------

@test "appgw-ssl-certs lists SSL certificates" {
  run appgw-ssl-certs prod-rg/web-appgw </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == wildcard-cert* ]]
  [[ "${lines[1]}" == api-cert* ]]
}

@test "appgw-ssl-certs --help prints doc block" {
  run appgw-ssl-certs --help
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"SSL certificates"* ]]
}

# --- appgw-ssl-profiles ------------------------------------------------------

@test "appgw-ssl-profiles lists SSL profiles" {
  run appgw-ssl-profiles prod-rg/web-appgw </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == strict-profile* ]]
  [[ "${lines[1]}" == default-profile* ]]
}

@test "appgw-ssl-profiles --help prints doc block" {
  run appgw-ssl-profiles --help
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"SSL profiles"* ]]
}

# --- appgw-probes ------------------------------------------------------------

@test "appgw-probes lists health probes" {
  run appgw-probes prod-rg/web-appgw </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == web-probe* ]]
  [[ "${lines[1]}" == api-probe* ]]
}

# --- appgw-frontend-ips ------------------------------------------------------

@test "appgw-frontend-ips lists frontend IPs" {
  run appgw-frontend-ips prod-rg/web-appgw </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == appGwPublicFrontendIp* ]]
  [[ "${lines[1]}" == appGwPrivateFrontendIp* ]]
}
