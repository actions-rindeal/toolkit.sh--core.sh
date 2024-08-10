#!/usr/bin/env bash

# Set strict mode
set -euo pipefail

##
# @file      actions-core.sh
# @brief     Bash implementation of NPM @actions/core
# @description
#     This script provides a partial Bash implementation of the NPM @actions/core package
#     used in GitHub Actions. It includes functions for managing GitHub Actions
#     workflow commands, setting outputs, managing state, and handling inputs.
#     Note that not all functions are implemented; this is a best-effort implementation.
# @see       https://github.com/actions/toolkit/tree/main/packages/core
# @see       https://github.com/actions/toolkit/blob/main/packages/core/src/core.ts

##-----------------------------------------------------------------------
## @section  Variables
##-----------------------------------------------------------------------

##
# @description  Export a variable to the environment and issue a file command
# @arg  name    The name of the variable to export
# @arg  value   The value of the variable to export
# @example
#     core.exportVariable "MY_VAR" "my value"
##
core.exportVariable() {
    local name="$1" ; shift
    local value="$1" ; shift
    export "${name}=${value}"
    core._issueFileCommand 'ENV' "$(core._prepareKeyValueMessage "${name}" "${value}")"
}
export -f  core.exportVariable

##
# @description  Mask a secret from logs
# @arg  secret  The secret to mask
# @example
#     core.setSecret "my secret value"
##
core.setSecret() {
    local secret="$1" ; shift
    core._issue 'add-mask' "${secret}"
}
export -f  core.setSecret

##
# @description     Add a directory to the system PATH
# @arg  inputPath  The path to add
# @example
#     core.addPath "/path/to/dir"
##
core.addPath() {
    local inputPath="$1" ; shift
    export "PATH=${inputPath}:${PATH}"
    core._issueFileCommand 'PATH' "${inputPath}"
}
export -f  core.addPath

##
# @description  Get an input value
# @arg  name    The name of the input to get
# @option  --required  Whether the input is required
# @option  --no-trim   Whether to trim whitespace from both ends of the input
# @example
#     value=$(core.getInput "MY_INPUT")
#     required_value=$(core.getInput --required "REQUIRED_INPUT")
#     untrimmed_value=$(core.getInput --no-trim "UNTRIMMED_INPUT")
##
core.getInput() {
    local name  required=false  trim=true
    
    local opts
    opts=$(getopt --long required,no-trim -- '' "$@") || exit 1
    eval set -- "${opts}"
    while (( $# > 0 )) ; do
    case "$1" in
        --required) shift ; required=true ;                  ;;
        --no-trim ) shift ; trim=false ;                     ;;
        --        ) shift ; name="INPUT_${1^^}" ; shift 1 ;  ;;
        * ) core._getoptInvalidArgErrorAndExit "${@}" ;      ;;
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

    "${trim}" && val="$(core._trim "${val}")"
    printf "%s" "${val}"
}
export -f  core.getInput

##
# @description  Get a multiline input value
# @arg  name    The name of the input to get
# @option  --required       Whether the input is required
# @option  --no-trim        Whether to trim whitespace from both ends of each line
# @example
#     readarray -t lines < <(core.getMultilineInput "MY_MULTILINE_INPUT")
#     readarray -t required_lines < <(core.getMultilineInput --required "REQUIRED_MULTILINE_INPUT")
#     readarray -t untrimmed_lines < <(core.getMultilineInput --no-trim "UNTRIMMED_MULTILINE_INPUT")
##
core.getMultilineInput() {
    local name  required=false  trim=true
    
    local opts
    opts=$(getopt --long required,no-trim -- '' "$@") || exit 1
    eval set -- "${opts}"
    while (( $# > 0 )) ; do
    case "$1" in
        --required) shift ; required=true ;                  ;;
        --no-trim ) shift ; trim=false ;                     ;;
        --        ) shift ; name="INPUT_${1^^}" ; shift 1 ;  ;;
        * ) core._getoptInvalidArgErrorAndExit "${@}" ;      ;;
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

    local IFS=$'\n'
    local -a lines
    readarray -t lines <<< "${val}"

    for line in "${lines[@]}"; do
        if [[ -n "$line" ]]; then
            "$trim" && line="$(core._trim "${line}")"
            printf '%s\n' "$line"
        fi
    done
}
export -f  core.getMultilineInput

##
# @description  Get a boolean input value
# @arg  name    The name of the input to get
# @example
#     if core.getBooleanInput "MY_BOOLEAN_INPUT"; then
#         echo "Input is true"
#     else
#         echo "Input is false"
#     fi
##
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

##
# @description  Set an output value
# @arg  name    The name of the output to set
# @arg  value   The value of the output to set
# @example
#     core.setOutput "MY_OUTPUT" "output value"
##
core.setOutput() {
    local name="$1" ; shift
    local value="$1" ; shift
    core._issueFileCommand 'OUTPUT' "$(core._prepareKeyValueMessage "${name}" "${value}")"
}
export -f  core.setOutput

##
# @description   Enable or disable command echoing
# @arg  enabled  Whether to enable or disable command echoing
# @example
#     core.setCommandEcho true
#     core.setCommandEcho false
##
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
# @description  Print a failure message and exit
# @arg  title   The failure title (and message if none provided)
# @option  message  The failure message (may contain printf markup)
# @arg  ...     Additional arguments for printf
# @example
#     core.setFailedAndExit "No 'repo' input provided."
#     core.setFailedAndExit "Invalid 'repo' input."  "Check 'repo' format: '%s'" "${REPO}"
##
core.setFailedAndExit() { printf "::error title=$1::${2-$1}\n" "${@:3}" ; exit 1 ; }
export -f  core.setFailedAndExit

##-----------------------------------------------------------------------
## @section Logging Commands
##-----------------------------------------------------------------------

##
# @description  Check if debug mode is enabled
# @exitcode  0  Debug mode is on
# @exitcode  1  Debug mode is off
# @example
#     if core.isDebug; then
#         echo "Debug mode is enabled"
#     fi
##
core.isDebug() { (( RUNNER_DEBUG == 1 )); }
export -f  core.isDebug

##
# @description  Log a debug message
# @arg  message The debug message to log
# @example
#     core.debug "This is a debug message"
##
core.debug() { core._issue 'debug' "${*}"; }
export -f  core.debug

##
# @description  Log an error message
# @arg  message The error message to log
# @example
#     core.error "An error occurred"
##
core.error() { core._issueCommand 'error' "${@}"; }
export -f  core.error

##
# @description  Log a warning message
# @arg  message The warning message to log
# @example
#     core.warning "This is a warning"
##
core.warning() { core._issueCommand 'warning' "${@}"; }
export -f  core.warning

##
# @description  Log a notice message
# @arg  message The notice message to log
# @example
#     core.notice "This is a notice"
##
core.notice() { core._issueCommand 'notice' "${@}"; }
export -f  core.notice

##
# @description  Log an info message
# @arg  message The info message to log
# @example
#     core.info "This is an info message"
##
core.info() { printf "%s\n" "${*}"; }
export -f  core.info

##
# @description  Start a log group
# @arg  name    The name of the group
# @example
#     core.startGroup "My Group"
#     echo "This is inside the group"
#     core.endGroup
##
core.startGroup() { core._issue 'group' "${*}"; }
export -f  core.startGroup

##
# @description  End the current log group
# @example
#     core.startGroup "My Group"
#     echo "This is inside the group"
#     core.endGroup
##
core.endGroup() { core._issue 'endgroup'; }
export -f  core.endGroup

##-----------------------------------------------------------------------
## @section Wrapper action state
##-----------------------------------------------------------------------

##
# @description  Save state for sharing across actions
# @arg  name    The name of the state to save
# @arg  value   The value of the state to save
# @example
#     core.saveState "MY_STATE" "state value"
##
core.saveState() {
    local name="$1" ; shift
    local value="$1" ; shift
    core._issueFileCommand 'STATE' "$(core._prepareKeyValueMessage "${name}" "${value}")"
}
export -f  core.saveState

##
# @description  Get the value of a saved state
# @arg  name    The name of the state to retrieve
# @example
#     state_value=$(core.getState "MY_STATE")
##
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

## @internal
core._trim() {
    local str="${*}"
    str="${str#"${str%%[![:space:]]*}"}"
    str="${str%"${str##*[![:space:]]}"}"
    printf "%s" "${str}"
}
export -f  core._trim

## @internal
core._getoptInvalidArgErrorAndExit() {
    local args
    args="$(printf "'%s' " "${@}")"
    printf "::error title=${FUNCNAME[1]}%3A Invalid options provided to getopt::%s\n" "${args}"
    exit 1
}

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
## @description
##     NOTE: Workflow command and parameter names are case insensitive.
## @arg $1 Command name
## @arg $2 Message (optional)
## @arg $@ Properties in the format `propName=propVal`
##         Available properties:
##         - title - Title of the annotation block
##         - file - File path
##         - line - Line number, starting at 1
##         - endLine - End line number
##         - col - Column number, starting at 1
##         - endColumn - End column number
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

##-----------------------------------------------------------------------
# @section  Summary
# @see  https://github.com/actions/toolkit/blob/main/packages/core/src/summary.ts
##-----------------------------------------------------------------------

# Global variables with unique names
__ACTIONS_CORE_SUMMARY_BUFFER_X4K92=""
__ACTIONS_CORE_SUMMARY_FILE_PATH_X4K92=""

##
# @description  Initialize the summary buffer
# @example
#     summary.init
##
summary.init() {
    __ACTIONS_CORE_SUMMARY_BUFFER_X4K92=""
    __ACTIONS_CORE_SUMMARY_FILE_PATH_X4K92="${GITHUB_STEP_SUMMARY:-}"
}
export -f summary.init

##
# @description  Write the summary buffer to the summary file
# @option  --overwrite  If set, overwrite the existing summary file instead of appending
# @example
#     summary.write
#     summary.write --overwrite
##
summary.write() {
    local overwrite=false
    
    local opts
    opts=$(getopt -o '' -l 'overwrite' -- '' "$@") || exit 1
    eval set -- "$opts"
    while (( $# > 0 )) ; do
        case "$1" in
            --overwrite ) shift ; overwrite=true ;           ;;
            --          ) shift ;                            ;;
            * ) core._getoptInvalidArgErrorAndExit "${@}" ;  ;;
        esac
    done

    if [[ -z "${__ACTIONS_CORE_SUMMARY_FILE_PATH_X4K92}" ]] ; then
        core.error "Environment Variable Not Found" \
            "Unable to find environment variable for GITHUB_STEP_SUMMARY. Check if your runtime environment supports job summaries."
        exit 1
    fi

    if [[ ! -w "${__ACTIONS_CORE_SUMMARY_FILE_PATH_X4K92}" ]] ; then
        core.error "Summary File Access Denied" \
            "Unable to access summary file: '${__ACTIONS_CORE_SUMMARY_FILE_PATH_X4K92}'. Check if the file has correct read/write permissions."
        exit 1
    fi

    if $overwrite ; then
        printf "%s" "${__ACTIONS_CORE_SUMMARY_BUFFER_X4K92}" > "${__ACTIONS_CORE_SUMMARY_FILE_PATH_X4K92}"
    else
        printf "%s" "${__ACTIONS_CORE_SUMMARY_BUFFER_X4K92}" >> "${__ACTIONS_CORE_SUMMARY_FILE_PATH_X4K92}"
    fi

    summary.emptyBuffer
}
export -f summary.write

##
# @description  Clear the summary buffer and summary file
# @example
#     summary.clear
##
summary.clear() {
    __ACTIONS_CORE_SUMMARY_BUFFER_X4K92=""
    summary.write --overwrite
}
export -f summary.clear

##
# @description  Get the current summary buffer as a string
# @stdout  The current summary buffer content
# @example
#     content=$(summary.stringify)
##
summary.stringify() {
    printf "%s" "${__ACTIONS_CORE_SUMMARY_BUFFER_X4K92}"
}
export -f summary.stringify

##
# @description  Check if the summary buffer is empty
# @exitcode  0  If the buffer is empty
# @exitcode  1  If the buffer is not empty
# @example
#     if summary.isEmptyBuffer; then
#         printf "Buffer is empty\n"
#     fi
##
summary.isEmptyBuffer() { (( ${#__ACTIONS_CORE_SUMMARY_BUFFER_X4K92} == 0 )) ; }
export -f summary.isEmptyBuffer

##
# @description  Reset the summary buffer without writing to the summary file
# @example
#     summary.emptyBuffer
##
summary.emptyBuffer() { __ACTIONS_CORE_SUMMARY_BUFFER_X4K92="" ; }
export -f summary.emptyBuffer

##
# @description  Add raw text to the summary buffer
# @arg  text  The text to add
# @option  --eol  If set, append an end-of-line character
# @example
#     summary.addRaw "Some raw text"
#     summary.addRaw "Text with EOL" --eol
##
summary.addRaw() {
    local text eol=false
    
    local opts
    opts=$(getopt -o '' -l 'eol' -- '' "$@") || exit 1
    eval set -- "$opts"
    while (( $# > 0 )) ; do
        case "$1" in
            --eol ) shift ; eol=true ;                       ;;
            --    ) shift ; text="$1" ; shift 1 ;            ;;
            * ) core._getoptInvalidArgErrorAndExit "${@}" ;  ;;
        esac
    done

    __ACTIONS_CORE_SUMMARY_BUFFER_X4K92+="${text}"
    $eol && summary.addEOL
}
export -f summary.addRaw

##
# @description  Add an end-of-line character to the summary buffer
# @example
#     summary.addEOL
##
summary.addEOL() {
    __ACTIONS_CORE_SUMMARY_BUFFER_X4K92+=$'\n'
}
export -f summary.addEOL

##
# @description  Add a code block to the summary buffer
# @arg  code  The code to add
# @arg  [lang]  The language for syntax highlighting
# @example
#     summary.addCodeBlock "print('Hello, World!')" "python"
##
summary.addCodeBlock() {
    local code="$1"
    local lang="${2:-}"
    local attrs=""
    [[ -n "${lang}" ]] && attrs=" lang=\"${lang}\""

    summary.addRaw "<pre><code${attrs}>${code}</code></pre>" --eol
}
export -f summary.addCodeBlock

##
# @description  Add a list to the summary buffer
# @arg  ...  List items
# @option  --ordered  If set, create an ordered list instead of unordered
# @example
#     summary.addList "Item 1" "Item 2" "Item 3"
#     summary.addList --ordered "First" "Second" "Third"
##
summary.addList() {
    local ordered=false tag='ul' items=""
    
    local opts
    opts=$(getopt -o '' -l 'ordered' -- '' "$@") || exit 1
    eval set -- "$opts"
    while (( $# > 0 )) ; do
        case "$1" in
            --ordered ) shift ; ordered=true ; tag='ol' ;    ;;
            --        ) shift ;                              ;;
            * ) core._getoptInvalidArgErrorAndExit "${@}" ;  ;;
        esac
    done

    for item in "$@"; do
        items+="<li>${item}</li>"
    done

    summary.addRaw "<${tag}>${items}</${tag}>" --eol
}
export -f summary.addList

##
# @description  Add a table to the summary buffer
# @arg  ...  Table rows, where each row is a space-separated list of cells
# @example
#     summary.addTable "Header1 Header2" "Value1 Value2" "Value3 Value4"
##
summary.addTable() {
    local rows=""
    for row in "$@"; do
        local cells=""
        for cell in ${row}; do
            cells+="<td>${cell}</td>"
        done
        rows+="<tr>${cells}</tr>"
    done

    summary.addRaw "<table>${rows}</table>" --eol
}
export -f summary.addTable

##
# @description  Add a collapsible details element to the summary buffer
# @arg  label  The text for the closed state
# @arg  content  The collapsible content
# @example
#     summary.addDetails "Click to expand" "Hidden content here"
##
summary.addDetails() {
    local label="$1"
    local content="$2"

    summary.addRaw "<details><summary>${label}</summary>${content}</details>" --eol
}
export -f summary.addDetails

##
# @description  Add an image to the summary buffer
# @arg  src  The path to the image
# @arg  alt  The alt text for the image
# @option  --width  The width of the image
# @option  --height  The height of the image
# @example
#     summary.addImage "path/to/image.png" "Description of image" --width 100 --height 100
##
summary.addImage() {
    local src alt width height attrs
    
    local opts
    opts=$(getopt -o '' -l 'width:,height:' -- '' "$@") || exit 1
    eval set -- "$opts"
    while (( $# > 0 )) ; do
        case "$1" in
            --width  ) shift ; width="$1"  ; shift 1 ;          ;;
            --height ) shift ; height="$1" ; shift 1 ;          ;;
            --       ) shift ; src="$1" ; alt="$2" ; shift 2 ;  ;;
            * ) core._getoptInvalidArgErrorAndExit "${@}" ;     ;;
        esac
    done

    if [[ -z "${src}" ]] ; then
        core.error "${FUNCNAME}: missing 'src'"
        exit 1
    fi
    attrs="src=\"${src}\""
    [[ -n "${alt}"    ]] && attrs+=" alt=\"${alt}\""
    [[ -n "${width}"  ]] && attrs+=" width=\"${width}\""
    [[ -n "${height}" ]] && attrs+=" height=\"${height}\""

    summary.addRaw "<img ${attrs}>" --eol
}
export -f summary.addImage

##
# @description  Add a heading to the summary buffer
# @arg  text  The heading text
# @arg  [level]  The heading level (1-6, default: 1)
# @example
#     summary.addHeading "Main Title"
#     summary.addHeading "Subtitle" 2
##
summary.addHeading() {
    local text="$1"
    local level="${2:-1}"

    (( level < 1 )) && level=1
    (( level > 6 )) && level=6
    summary.addRaw "<h${level}>${text}</h${level}>" --eol
}
export -f summary.addHeading

##
# @description  Add a separator to the summary buffer
# @example
#     summary.addSeparator
##
summary.addSeparator() { summary.addRaw "<hr>" --eol ; }
export -f summary.addSeparator

##
# @description  Add a line break to the summary buffer
# @example
#     summary.addBreak
##
summary.addBreak() { summary.addRaw "<br>" --eol ; }
export -f summary.addBreak

##
# @description  Add a quote to the summary buffer
# @arg  text  The quote text
# @arg  [cite]  The citation URL
# @example
#     summary.addQuote "To be or not to be" "https://example.com/hamlet"
##
summary.addQuote() {
    local text="$1"
    local cite="${2:-}"

    local attrs=""
    [[ -n "${cite}" ]] && attrs=" cite=\"${cite}\""

    summary.addRaw "<blockquote${attrs}>${text}</blockquote>" --eol
}
export -f summary.addQuote

##
# @description  Add a link to the summary buffer
# @arg  text  The link text
# @arg  href  The hyperlink URL
# @example
#     summary.addLink "Visit our website" "https://example.com"
##
summary.addLink() {
    local text="$1"
    local href="$2"

    summary.addRaw "<a href=\"${href}\">${text}</a>" --eol
}
export -f summary.addLink

# Initialize the summary buffer
summary.init

## -------------------------------------------
# @section  Context
# @see  https://github.com/actions/toolkit/blob/main/packages/github/src/context.ts
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
