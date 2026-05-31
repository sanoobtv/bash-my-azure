#!/usr/bin/env bats
#
# Unit tests for bash-my-azure.
# Pure-logic functions are tested directly; az-dependent functions run against
# a stubbed `az` placed on PATH (no live Azure, no cost).
#
# Run:  bats test/bmaz.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  # Stub `az` on PATH with canned TSV output.
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB_BIN"
  cat > "$STUB_BIN/az" <<'EOF'
#!/bin/bash
if [[ "$1" == "vm" && "$2" == "list" ]]; then
  printf 'prod-rg/web02\tStandard_B2s\trunning\teastus\n'
  printf 'prod-rg/web01\tStandard_B2s\trunning\teastus\n'
  printf 'dev-rg/dev01\tStandard_B1s\tdeallocated\twestus2\n'
  exit 0
fi
exit 0
EOF
  chmod +x "$STUB_BIN/az"
  PATH="$STUB_BIN:$PATH"

  # columnise must be a no-op pass-through under test (no TTY)
  export BMAZ_COLUMNISE_ONLY_WHEN_TERMINAL_PRESENT=true

  # __bmaz_help reads doc comments from the lib files under BMAZ_HOME
  export BMAZ_HOME="$REPO_ROOT"

  source "$REPO_ROOT/lib/shared-functions"
  source "$REPO_ROOT/lib/vm-functions"
}

# --- __bmaz_read_filters -----------------------------------------------------

@test "read_filters joins args with pipe" {
  run __bmaz_read_filters foo bar baz
  [ "$status" -eq 0 ]
  [ "$output" = "foo|bar|baz" ]
}

@test "read_filters with no args is empty" {
  run __bmaz_read_filters
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "read_filters does not interpret % as printf format" {
  run __bmaz_read_filters '50%off'
  [ "$output" = '50%off' ]
}

# --- __bmaz_parse_resource ---------------------------------------------------

@test "parse_resource splits rg/name token" {
  __bmaz_parse_resource "prod-rg/web01"
  [ "$_bmaz_rg" = "prod-rg" ]
  [ "$_bmaz_name" = "web01" ]
}

@test "parse_resource uses BMAZ_DEFAULT_RG for bare name" {
  BMAZ_DEFAULT_RG=prod-rg __bmaz_parse_resource "web01"
  [ "$_bmaz_rg" = "prod-rg" ]
  [ "$_bmaz_name" = "web01" ]
}

@test "parse_resource errors on ambiguous bare name" {
  unset BMAZ_DEFAULT_RG
  run __bmaz_parse_resource "web01"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Ambiguous"* ]]
}

# --- skim-stdin --------------------------------------------------------------

@test "skim-stdin takes first column of each piped line" {
  run bash -c "source '$REPO_ROOT/lib/shared-functions'; printf 'prod-rg/web01\tFoo\nprod-rg/web02\tBar\n' | skim-stdin"
  [ "$output" = "prod-rg/web01 prod-rg/web02" ]
}

@test "skim-stdin appends piped tokens to args" {
  run bash -c "source '$REPO_ROOT/lib/shared-functions'; printf 'a/1\nb/2\n' | skim-stdin x y"
  [ "$output" = "x y a/1 b/2" ]
}

# --- vms (stubbed az) --------------------------------------------------------

@test "vms lists and sorts by first column" {
  run vms </dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == dev-rg/dev01* ]]
  [[ "${lines[1]}" == prod-rg/web01* ]]
  [[ "${lines[2]}" == prod-rg/web02* ]]
}

@test "vms applies built-in filter" {
  run vms web02 </dev/null
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == prod-rg/web02* ]]
}

# --- --help (doc-comment extraction) -----------------------------------------

@test "vms --help prints the doc block and skips az" {
  run vms --help
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "List Virtual Machines" ]
  [[ "$output" == *'$ vms web'* ]]
}

@test "--help strips comment markers and surfaces the USAGE line" {
  run vm-status --help
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" != \#* ]]                 # leading '#' stripped
  [[ "$output" == *"USAGE: vm-status"* ]]
}
