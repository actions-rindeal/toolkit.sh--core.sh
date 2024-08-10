#!/usr/bin/env  bash

# Set strict mode
#set -euo pipefail

##-----------------------------------------------------------------------
## @section  Variables
##-----------------------------------------------------------------------

## @description  Export a variable to the environment and issue a file command
## @arg  name    The name of the variable to export
## @arg  value   The value of the variable to export
core.exportVariable() {
    local name="$1" ; shift
    local value="$1" ; shift
    export "${name}=${value}"
    core._issueFileCommand 'ENV' "$(core._prepareKeyValueMessage "${name}" "${value}")"
}
export -f  core.exportVariable

## @description  Mask a secret from logs
## @arg  secret  The secret to mask
core.setSecret() {
    local secret="$1" ; shift
    core._issue 'add-mask' "${secret}"
}

## @description     Add a directory to the system PATH
## @arg  inputPath  The path to add
core.addPath() {
    local inputPath="$1" ; shift
    export "PATH=${inputPath}:${PATH}"
    core._issueFileCommand 'PATH' "${inputPath}"
}
export -f  core.addPath

## @description  Get an input value
## @arg  name    The name of the input to get
## @option  --required  Whether the input is required
## @option  --no-trim   Whether to trim whitespace from both ends of the input
core.getInput() {
    local name  required=false  trim=true
    
    local opts
    opts=$(getopt --long required,no-trim -- '' "$@") || exit 1
    eval set -- "${opts}"
    while (( $# > 0 )) ; do
    case "$1" in
        --required) required=true; shift ;;
        --no-trim ) trim=false   ; shift ;;
        --        ) shift; name="INPUT_${1^^}" ; shift; break ;;
        *) printf "Invalid option: %s\n" "$1" >&2; exit 1 ;;
    esac
    done

    if [[ ! -v "${name}" ]] ; then
        printf "Variable '%s' does not exist.\n" "$name" >&2
        exit 1
    fi

    local val="${!name}"

    if "${required}" && [[ -z "${val}" ]] ; then
        printf "Input required and not supplied: %s\n" "$name" >&2
        exit 1
    fi

    if "${trim}" ; then
        val=${val##*([[:space:]])}
        val=${val%%*([[:space:]])}
    fi
    printf "%s" "${val}"
}
export -f  core.getInput

## @description  Get a multiline input value
core.getMultilineInput() { TODO; }
export -f  core.getMultilineInput

## @description  Get a boolean input value
## @arg  name  The name of the input to get
core.getBooleanInput() {
    local value
    value="$(core.getInput "${@}")"
    case "${value,,}" in
        true  ) printf 'true';  return 0 ;;
        false ) printf 'false'; return 1 ;;
        *) printf "%s" "Input is not boolean." >&2; return 1 ;;
    esac
}
export -f  core.getBooleanInput

## @description  Set an output value
## @arg  name   The name of the output to set
## @arg  value  The value of the output to set
core.setOutput() {
    local name="$1" ; shift
    local value="$1" ; shift
    core._issueFileCommand 'OUTPUT' "$(core._prepareKeyValueMessage "${name}" "${value}")"
}
export -f  core.setOutput

## @description   Enable or disable command echoing
## @arg  enabled  Whether to enable or disable command echoing
core.setCommandEcho() {
    local enabled="$1" ; shift
    local state
    "${enabled}" && state='on' || state='off'
    core._issue 'echo' "${state}"
}
export -f  core.setCommandEcho

##-----------------------------------------------------------------------
## @section Results
##-----------------------------------------------------------------------

##
## @decription  Print a failure message and exit
## @arg  title  The failure title (and message if none provided)
## @option  message  The failure message (may contain printf markup)
## @arg  ...  Additional arguments for printf
## @example
##     core.setFailedAndExit  "No 'repo' input provided."
##     core.setFailedAndExit  "Invalid 'repo' input."  "Check 'repo' format: '%s'" "${REPO}"
core.setFailedAndExit() { printf "::error title=$1::${2-$1}\n" "${@:3}" ; exit 1 ; }
export -f  core.setFailedAndExit

##-----------------------------------------------------------------------
## @section Logging Commands
## @description ...
##-----------------------------------------------------------------------

## @description  Check if debug mode is enabled
## @exitcode  0  Debug mode is on
## @exitcode  1  Debug mode is off
core.isDebug() { (( RUNNER_DEBUG == 1 )); }
export -f  core.isDebug

core.debug() { core._issue 'debug' "${*}"; }
export -f  core.debug

core.error() { core._issueCommand 'error' "${@}"; }
export -f  core.error

core.warning() { core._issueCommand 'warning' "${@}"; }
export -f  core.warning

core.notice() { core._issueCommand 'notice' "${@}"; }
export -f  core.notice

core.info() { printf "%s\n" "${*}"; }
export -f  core.info

core.startGroup() { core._issue 'group' "${*}"; }
export -f  core.startGroup

core.endGroup() { core._issue 'endgroup'; }
export -f  core.endGroup

##-----------------------------------------------------------------------
## @section Wrapper action state
##-----------------------------------------------------------------------

core.saveState() {
    local name="$1" ; shift
    local value="$1" ; shift
    core._issueFileCommand 'STATE' "$(core._prepareKeyValueMessage "${name}" "${value}")"
}
export -f  core.saveState

core.getState() {
    local name="$1" ; shift
    local var="STATE_${name}"
    [[ -v "${var}" ]] && { printf "%s" "${!var}"; } || { printf ""; }
}
export -f  core.getState

## @internal
core.getIDToken() { printf "Error: '%s' not implemented!" "${FUNCNAME}" >&2; exit 1; }
export -f  core.getIDToken

## -----------------------------------------------------------------------
## ------------------  Core Internal  ------------------------------------
## -----------------------------------------------------------------------

# Function to convert value to command value
## @internal
core._toCommandValue() {
    local input="$1"
    if [[ -z "$input" ]]; then
        printf ''
    elif [[ "$input" == true || "$input" == false || "$input" =~ ^[0-9]+$ ]]; then
        printf '%s' "$input"
    else
        printf '%s' "$input" | jq -R -s '.'
    fi
}
export -f  core._toCommandValue

# Function to issue a file command
## @internal
core._issueFileCommand() {
    local command="$1" ; shift
    local message="$1" ; shift
    local file_path_var="GITHUB_${command}"
    local file_path="${!file_path_var}"

    if [[ -z "$file_path" ]]; then
        printf 'Error: Unable to find environment variable "%s"\n' "${file_path_var}" >&2
        return 1
    fi

    if [[ ! -f "$file_path" ]]; then
        printf 'Error: Missing file at path: %s\n' "$file_path" >&2
        return 1
    fi

    printf '%s\n' "$(core._toCommandValue "$message")" >> "$file_path"
}
export -f  core._issueFileCommand

## @internal
core._prepareKeyValueMessage() {
    local key="$1"
    local value="$2"
    local delimiter="ghadelimiter_$(uuidgen)"
    local converted_value=$(core._toCommandValue "$value")

    printf '%s<<%s\n%s\n%s\n' "$key" "$delimiter" "$converted_value" "$delimiter"
}
export -f  core._prepareKeyValueMessage

## @internal
core._issueCommand() {
    local command="${1:-missing.command}" ; shift
    local message="${1:-}" ; shift
    local properties=( "$@" )

    local cmdStr="::${command}"
    if (( ${#properties[@]} > 0 )) ; then
        cmdStr+=" "
        local first=true
        for prop in "${properties[@]}"; do
            "$first" && first=false || cmdStr+=","
            local key="${prop%%=*}"
            local val="${prop#*=}"
            cmdStr+="${key}=$(core._escapeProperty "$val")"
        done
    fi
    [[ -n "${message}" ]] && cmdStr+="::$(core._escapeData "$message")" || cmdStr+="::"
    printf '%s' "${cmdStr}"
}
export -f core._issueCommand

## @internal
core._issue() {
    local command="$1"
    local message="${2:-}"
    core._issueCommand "${command}" "${message}"
}
export -f core._issue

## @internal
core._escapeData() {
    local str="$1" ; shift
    str="${str//%/%25}"
    str="${str//$'\r'/%0D}"
    str="${str//$'\n'/%0A}"
    printf '%s' "$str"
}
export -f core._escapeData

## @internal
core._escapeProperty() {
    local str="$1" ; shift
    str="${str//%/%25}"
    str="${str//$'\r'/%0D}"
    str="${str//$'\n'/%0A}"
    str="${str//:/%3A}"
    str="${str//,/%2C}"
    printf '%s' "$str"
}
export -f core._escapeProperty

## -------------------------------------------
## @section Context
## -------------------------------------------

##
# @file github-context.sh
# @brief Provides a GitHub Actions context similar to the TypeScript version
# @description
#     This script mimics the functionality of the TypeScript Context class
#     for GitHub Actions. It provides functions to access GitHub Actions
#     context information, closely mimicking the original API.
##

##
# @description Get the name of the event that triggered the workflow
# @stdout The name of the event
##
context.eventName() { printf "%s" "${GITHUB_EVENT_NAME:-}"; }
export -f  context.eventName

##
# @description Get the SHA of the commit that triggered the workflow
# @stdout The full SHA of the commit
##
context.sha() { printf "%s" "${GITHUB_SHA:-}"; }
export -f  context.sha

##
# @description Get the reference of the commit that triggered the workflow
# @stdout The Git ref of the commit (e.g., refs/heads/main)
##
context.ref() { printf "%s" "${GITHUB_REF:-}"; }
export -f  context.ref

##
# @description Get the name of the workflow
# @stdout The name of the workflow
##
context.workflow() { printf "%s" "${GITHUB_WORKFLOW:-}"; }
export -f  context.workflow

##
# @description Get the name of the current action
# @stdout The name of the current action
##
context.action() { printf "%s" "${GITHUB_ACTION:-}"; }
export -f  context.action

##
# @description Get the name of the actor that triggered the workflow
# @stdout The name of the actor (usually a GitHub username)
##
context.actor() { printf "%s" "${GITHUB_ACTOR:-}"; }
export -f  context.actor

##
# @description Get the name of the current job
# @stdout The name of the job
##
context.job() { printf "%s" "${GITHUB_JOB:-}"; }
export -f  context.job

##
# @description Get the current attempt number of the job
# @stdout The attempt number (as a string)
##
context.runAttempt() { printf "%s" "${GITHUB_RUN_ATTEMPT:-0}"; }
export -f  context.runAttempt

##
# @description Get the current run number of the workflow
# @stdout The run number (as a string)
##
context.runNumber() { printf "%s" "${GITHUB_RUN_NUMBER:-0}"; }
export -f  context.runNumber

##
# @description Get the unique identifier for the current workflow run
# @stdout The run ID (as a string)
##
context.runId() { printf "%s" "${GITHUB_RUN_ID:-0}"; }
export -f  context.runId

##
# @description Get the API URL for the current GitHub instance
# @stdout The API URL (defaults to https://api.github.com)
##
context.apiUrl() { printf "%s" "${GITHUB_API_URL:-https://api.github.com}"; }
export -f  context.apiUrl

##
# @description Get the URL for the current GitHub instance
# @stdout The server URL (defaults to https://github.com)
##
context.serverUrl() { printf "%s" "${GITHUB_SERVER_URL:-https://github.com}"; }
export -f  context.serverUrl

##
# @description Get the GraphQL API URL for the current GitHub instance
# @stdout The GraphQL API URL (defaults to https://api.github.com/graphql)
##
context.graphqlUrl() { printf "%s" "${GITHUB_GRAPHQL_URL:-https://api.github.com/graphql}"; }
export -f  context.graphqlUrl

##
# @description Get the full event payload that triggered the workflow
# @stdout The event payload as a JSON string
##
context.payload() {
    local event_path="${GITHUB_EVENT_PATH:-}"
    if [[ -n "$event_path" && -f "$event_path" ]]; then
        jq '.' "$event_path"
    else
        if [[ -n "$event_path" ]]; then
            printf "GITHUB_EVENT_PATH %s does not exist" "$event_path" >&2
        fi
        echo "{}"
    fi
}
export -f  context.payload

##
# @description Get the owner and repository name
# @stdout The owner and repository name separated by a space
# @error If GITHUB_REPOSITORY is not set and can't be derived from the payload
##
context.repo() {
    local repo_info=""
    if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
        repo_info=$(awk -F'/' '{printf "%s %s", $1, $2}' <<< "$GITHUB_REPOSITORY")
    else
        repo_info=$(context.payload | jq -r '(.repository.owner.login + " " + .repository.name) // empty')
    fi

    if [[ -z "$repo_info" ]]; then
        printf "Error: Unable to determine repository information. Ensure GITHUB_REPOSITORY is set or the payload contains repository data." >&2
        return 1
    fi

    printf "%s" "$repo_info"
}
export -f  context.repo

##
# @description Get the issue or pull request information
# @stdout The owner, repository name, and issue/PR number separated by spaces
##
context.issue() {
    read -r owner repo <<< "$(context.repo)"
    number=$(context.payload | jq -r '(.issue.number // .pull_request.number // .number) // empty')
    printf "%s %s %s" "$owner" "$repo" "$number"
}
export -f  context.issue
