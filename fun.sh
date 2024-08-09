#!/usr/bin/env  bash

# Set strict mode
#set -euo pipefail

core.exportVariable() {
    local name="$1" ; shift
    local value="$1" ; shift
    export "${name}=${value}"
    core.issueFileCommand 'ENV' "$(core.issueFileCommand "${name}" "${value}")"
}
export -f  core.exportVariable

## Usage:
##     core.setFailedAndExit  "No 'repo' input provided."
##     core.setFailedAndExit  "Invalid 'repo' input."  "Check 'repo' format: '%s'" "${REPO}"
core.setFailedAndExit() { printf "::error title=$1::${2-$1}\n" "${@:3}" ; exit 1 ; }
export -f  core.setFailedAndExit

# Function to convert value to command value
core.toCommandValue() {
    local input="$1"
    if [[ -z "$input" ]]; then
        printf ''
    elif [[ "$input" == true || "$input" == false || "$input" =~ ^[0-9]+$ ]]; then
        printf '%s' "$input"
    else
        printf '%s' "$input" | jq -R -s '.'
    fi
}
export -f  core.toCommandValue

# Function to issue a file command
core.issueFileCommand() {
    local command="$1"
    local message="$2"
    local file_path_var="GITHUB_${command}"
    local file_path="${!file_path_var}"

    if [[ -z "$file_path" ]]; then
        printf 'Error: Unable to find environment variable for file command %s\n' "$command" >&2
        return 1
    fi

    if [[ ! -f "$file_path" ]]; then
        printf 'Error: Missing file at path: %s\n' "$file_path" >&2
        return 1
    fi

    printf '%s\n' "$(core.toCommandValue "$message")" >> "$file_path"
}
export -f  core.issueFileCommand

# Function to prepare key-value message
core.prepareKeyValueMessage() {
    local key="$1"
    local value="$2"
    local delimiter="ghadelimiter_$(cat /proc/sys/kernel/random/uuid)"
    local converted_value=$(core.toCommandValue "$value")

    printf '%s<<%s\n%s\n%s\n' "$key" "$delimiter" "$converted_value" "$delimiter"
}
export -f  core.prepareKeyValueMessage

##########  Context  ##########################

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
