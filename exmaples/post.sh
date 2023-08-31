#!/usr/bin/env bash
set -Eeuo pipefail

DEFAULT_BASE_URL=${DEFAULT_BASE_URL:-"http://localhost:3000"}
REQUEST_ID=${REQUEST_ID:-$(uuidgen | tr "[:upper:]" "[:lower:]")}

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-s server_uri] [-n name] [-j job]

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-s, --server    server base URI (by default ${DEFAULT_URL})
-n, --name      user name
-j, --job       user job

EOF
  exit
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  BASE_URL=${DEFAULT_BASE_URL}
  NAME="bob"
  JOB="leader"
  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -s | --server) # TUF server base URL
      TUF_REPO_URL="${2-}"
      shift
      ;;
    -n | --name)
      NAME="${2-}"
      shift
      ;;
    -j | --job) # TUF repository ID
      JOB="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  # check required params and arguments
  [[ -z "${BASE_URL-}" ]] && die "Missing required parameter: ${YELLOW}server${NOFORMAT}"


  return 0
}

parse_response() {
  local response=${1}
  local http_code
  http_code=$(tail -c4 <<< "$response")  # get the last line
  local content
  content1=$(tail -n1 <<< "$response")
  response_body=${content1:0:$((${#content1}-3))}
  content=$(sed '1d;$d' <<< "$response")  # get all except the first and last lines
  local head=true
  local header=""
  while read -r line; do
    if $head; then
      if [[ $line = $'\r' ]]; then
          head=false
      else
          header="$header"$'\n\t'"$line"
      fi
    else
      response_body="$response_body"$'\n'"$line"
    fi
  done < <(echo "$content")

  if [[ "${http_code}" -ne 201 ]] ; then
    msg "${RED}HTTP response code: ${NOFORMAT}${http_code}"
  else
    msg "${BLUE}HTTP response code: ${NOFORMAT}${http_code}"
  fi
  msg "${RED}Headers:${NOFORMAT}$header"
  echo "${response_body}"
}

setup_colors
parse_params "$@"

URL="${BASE_URL}/api/users"
msg "${GREEN}RequestID:${NOFORMAT} ${REQUEST_ID}"
msg "${GREEN}URL      :${NOFORMAT} ${URL}"

body="{\"name\":\"${NAME}\", \"job\":\"${JOB}\"}"
response=$(curl -si -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: ${REQUEST_ID}" \
  -X "POST" \
  --data "${body}" \
  "${URL}")

parse_response "${response}"
