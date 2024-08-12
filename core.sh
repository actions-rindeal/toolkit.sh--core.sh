#!/usr/bin/env bash

# Set strict mode
#set -euo pipefail

##
# @file      core.sh
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
    local name="${1}" ; shift
    local value="${1}" ; shift
    export "${name}=${value}"
    local kv_message
    kv_message="$(core._prepareKeyValueMessage "${name}" "${value}")"
    core._issueFileCommand 'ENV' "${kv_message}"
}
export -f  core.exportVariable

##
# @description  Mask a secret from logs
# @arg  secret  The secret to mask
# @example
#     core.setSecret "my secret value"
##
core.setSecret() {
    local secret="${1}" ; shift
    core._issueCommand 'add-mask' "${secret}"
}
export -f  core.setSecret

##
# @description     Add a directory to the system PATH
# @arg  inputPath  The path to add
# @example
#     core.addPath "/path/to/dir"
##
core.addPath() {
    local inputPath="${1}" ; shift
    export "PATH=${inputPath}:${PATH}"
    core._issueFileCommand 'PATH' "${inputPath}"
}
export -f  core.addPath

##
# @internal
# @description  Internal function to handle common input retrieval logic
# @arg  name    The name of the input to get
# @option  --required  Whether the input is required
# @option  --no-trim   Whether to trim whitespace from both ends of the input
# @option  --type      The type of input (string, multiline, boolean)
# @stdout  The value of the input
##
core._getInput() {
    local name required=false trim=true type="string"
    
    local opts
    opts=$(getopt --long required,no-trim,type: -- '' "$@") || exit 1
    eval set -- "${opts}"
    while (( $# > 0 )) ; do
    case "${1}" in
        --required) shift ; required=true ;                  ;;
        --no-trim ) shift ; trim=false ;                     ;;
        --type    ) shift ; type="${1}" ; shift 1 ;            ;;
        --        ) shift ; name="INPUT_${1^^}" ; shift 1 ;  ;;
        * ) core._getoptInvalidArgErrorAndExit "${@}" ;      ;;
    esac
    done

    if [[ ! -v "${name}" ]] ; then
        core.error "${FUNCNAME[0]}: Input not found." "Environment variable '${name}' does not exist."
        return 1
    fi

    local value="${!name}"

    if "${required}" && [[ -z "${value}" ]] ; then
        core.error "${FUNCNAME[0]}: Required input is empty." "Input '${name}' was found empty, but its value was required to be non-empty."
        return 1
    fi

    case "${type}" in
        string )
            "${trim}" && value="$(core._trim "${value}")"
            printf "%s" "${value}"
            ;;
        multiline )
            local -a lines
            IFS=$'\n' readarray -t lines <<< "${value}"
            local line
            for line in "${lines[@]}"; do
                if [[ -n "${line}" ]]; then
                    "${trim}" && line="$(core._trim "${line}")"
                    printf '%s\n' "${line}"
                fi
            done
            ;;
        boolean )
            value="$(core._trim "${value}")"
            value="${value,,}"
            case "${value}" in
                true  ) return 0 ;;
                false ) return 1 ;;
                *) core.error "Input '${name}' is not boolean." "The actual value is '${value}'" ; return 2 ;;
            esac
            ;;
        * )
            core.error "${FUNCNAME[0]}: Invalid input type '${type}'"
            exit 1
            ;;
    esac
}
export -f  core._getInput

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
core.getInput() { core._getInput "$@" --type string ; }
export -f core.getInput

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
core.getMultilineInput() { core._getInput "$@" --type multiline ; }
export -f core.getMultilineInput

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
core.getBooleanInput() { core._getInput "$@" --type boolean ; }
export -f core.getBooleanInput

##
# @description  Set an output value
# @arg  name    The name of the output to set
# @arg  value   The value of the output to set
# @example
#     core.setOutput "MY_OUTPUT" "output value"
##
core.setOutput() {
    local name="${1}" ; shift
    local value="${1}" ; shift
    local kv_message
    kv_message="$(core._prepareKeyValueMessage "${name}" "${value}")"
    core._issueFileCommand 'OUTPUT' "${kv_message}"
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
    local enabled="${1}" ; shift
    local state
    "${enabled}" && state='on' || state='off'
    core._issueCommand 'echo' "${state}"
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
# shellcheck disable=SC2059
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
core.isDebug() { (( RUNNER_DEBUG == 1 )) ; }
export -f  core.isDebug

##
# @description  Log a debug message
# @arg  message The debug message to log
# @example
#     core.debug "This is a debug message"
##
core.debug() { core._issueCommand 'debug' "${*}" ; }
export -f  core.debug

##
# @description  Log an error message
# @arg  message The error message to log
# @example
#     core.error "An error occurred"
##
core.error() { core._issueCommand 'error' "${@}" ; }
export -f  core.error

##
# @description  Log a warning message
# @arg  message The warning message to log
# @example
#     core.warning "This is a warning"
##
core.warning() { core._issueCommand 'warning' "${@}" ; }
export -f  core.warning

##
# @description  Log a notice message
# @arg  message The notice message to log
# @example
#     core.notice "This is a notice"
##
core.notice() { core._issueCommand 'notice' "${@}" ; }
export -f  core.notice

##
# @description  Log an info message
# @arg  message The info message to log
# @example
#     core.info "This is an info message"
##
core.info() { printf "%s\n" "${*}" ; }
export -f  core.info

##
# @description  Start a log group
# @arg  name    The name of the group
# @example
#     core.startGroup "My Group"
#     echo "This is inside the group"
#     core.endGroup
##
core.startGroup() { core._issueCommand 'group' "${*}" ; }
export -f  core.startGroup

##
# @description  End the current log group
# @example
#     core.startGroup "My Group"
#     echo "This is inside the group"
#     core.endGroup
##
core.endGroup() { core._issueCommand 'endgroup' ; }
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
    local name="${1}" ; shift
    local value="${1}" ; shift
    local kv_message
    kv_message="$(core._prepareKeyValueMessage "${name}" "${value}")"
    core._issueFileCommand 'STATE' "${kv_message}"
}
export -f  core.saveState

##
# @description  Get the value of a saved state
# @arg  name    The name of the state to retrieve
# @example
#     state_value=$(core.getState "MY_STATE")
##
core.getState() {
    local name="${1}" ; shift
    local var="STATE_${name}"
    [[ -v "${var}" ]] && printf "%s" "${!var}"
}
export -f  core.getState

## @internal
core.getIDToken() { core._NotImplementedErrorAndExit ; }
export -f  core.getIDToken

## -----------------------------------------------------------------------
## @section  Core Internal
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
    printf "::error title=%s%%3A Invalid options provided to getopt::%s\n" "${FUNCNAME[1]}" "${args}"
    exit 1
}
export -f  core._getoptInvalidArgErrorAndExit

## @internal
core._NotImplementedErrorAndExit() {
    printf "::error title=%s() is not implemented::\n" "${FUNCNAME[1]}"
    exit 1
}
export -f  core._NotImplementedErrorAndExit

## @internal
core._prepareKeyValueMessage() {
    local key="${1}"
    local value="${2}"
    local delimiter="" converted_value=""

    delimiter="ghadelimiter_$(uuidgen)"
    converted_value=$(core._toCommandValue "${value}")

    printf '%s<<%s\n%s\n%s\n' "${key}" "${delimiter}" "${converted_value}" "${delimiter}"
}
export -f  core._prepareKeyValueMessage

## @internal
core._toCommandValue() {
    local input="${1}"
    if [[ -z "${input}" ]]; then
        printf ''
    elif [[ "${input}" == true || "${input}" == false || "${input}" =~ ^[0-9]+$ ]]; then
        printf '%s' "${input}"
    else
        printf '%s' "${input}" | jq -R -s '.'
    fi
}
export -f  core._toCommandValue

## @internal
core._issueFileCommand() {
    local command="${1}" ; shift
    local message="${1}" ; shift
    local file_path_var="GITHUB_${command}"
    local file_path="${!file_path_var}"

    if [[ -z "${file_path}" ]]; then
        printf 'Error: Unable to find environment variable "%s"\n' "${file_path_var}" >&2
        return 1
    fi

    if [[ ! -f "${file_path}" ]]; then
        printf 'Error: Missing file at path: %s\n' "${file_path}" >&2
        return 1
    fi

    local command_value
    command_value="$(core._toCommandValue "${message}")"
    printf '%s\n' "${command_value}" >> "${file_path}"
}
export -f  core._issueFileCommand

## @internal
core._escapeData() {
    local str="${1}" ; shift
    str="${str//%/%25}"
    str="${str//$'\r'/%0D}"
    str="${str//$'\n'/%0A}"
    printf '%s' "${str}"
}
export -f  core._escapeData

## @internal
core._escapeProperty() {
    local str="${1}" ; shift
    str="${str//%/%25}"
    str="${str//$'\r'/%0D}"
    str="${str//$'\n'/%0A}"
    str="${str//:/%3A}"
    str="${str//,/%2C}"
    printf '%s' "${str}"
}
export -f  core._escapeProperty

## @internal
## @description
##     NOTE: Workflow command and parameter names are case insensitive.
## @arg $1 Command name
## @arg $2 Message (optional)
## @arg $@ Properties in the format `propName=propVal`
core._issueCommand() {
    local command="${1:-missing.command}" ; shift
    local message="${1:-}" ; shift
    local properties=( "$@" )

    local cmdStr="::${command}"

    if (( ${#properties[@]} > 0 )) ; then
        cmdStr+=" "
        local prop first=true
        for prop in "${properties[@]}" ; do
            "${first}" && first=false || cmdStr+=","
            local key="${prop%%=*}"
            local val="${prop#*=}"
            cmdStr+="${key}=$(core._escapeProperty "${val}")"
        done
    fi

    cmdStr+="::"
    [[ -n "${message}" ]] && cmdStr+="$(core._escapeData "${message}")"

    printf '%s' "${cmdStr}"
}
export -f  core._issueCommand

## @internal
## @description
##     NOTE: Workflow command and parameter names are case insensitive.
## @arg $1 Command name
## @arg $2 Message (optional)
## @arg $@ Properties in the format `propName=propVal`
##         Available properties:
##         - title - Title of the annotation block
##         - file - File path
##         - line | startLine - Line number, starting at 1
##         - endLine - End line number
##         - col | startColumn - Column number, starting at 1
##         - endColumn - End column number
core._issueLoggingCommand() {
    local command="${1}"        ; shift
    local message="${2}"        ; shift
    local properties=( "${@}" ) ; shift ${#@}
    
    local prop
    for prop in "${properties[@]}" ; do
        local key="${prop%%=*}"
        local value="${prop#*=}"
        case "${key}" in
            line | startLine  )  props+=( "line=${value}" )  ;;
            col | startColumn )  props+=( "col=${value}"  )  ;;
            title | file | endLine | endColumn ) props+=( "${key}=${value}" )  ;;
            * )
                printf "::error title=%s()%%3A Invalid property '%s'::The property '%s' is not a valid logging annotation property.\n" \
                    "${FUNCNAME[1]}" "${key}" "${key}"
                exit 1
            ;;
        esac
    done

    core._issueCommand "${command}" "${message}" "${props[@]}"
}
export -f  core._issueLoggingCommand

##-----------------------------------------------------------------------
# @section  Summary
# @see  https://github.com/actions/toolkit/blob/main/packages/core/src/summary.ts
##-----------------------------------------------------------------------

# Global variables with unique names
__ACTIONS_CORE_SUMMARY_BUFFER_X4K92=""

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
    eval set -- "${opts}"
    while (( $# > 0 )) ; do
        case "${1}" in
            --overwrite ) shift ; overwrite=true ;           ;;
            --          ) shift ;                            ;;
            * ) core._getoptInvalidArgErrorAndExit "${@}" ;  ;;
        esac
    done

    if [[ ! -v GITHUB_STEP_SUMMARY ]] || [[ -z "${GITHUB_STEP_SUMMARY}" ]] ; then
        core.error "Environment Variable Not Found" \
            "Unable to find environment variable for GITHUB_STEP_SUMMARY. Check if your runtime environment supports job summaries."
        exit 1
    fi

    if [[ ! -w "${GITHUB_STEP_SUMMARY}" ]] ; then
        core.error "Summary File Access Denied" \
            "Unable to access summary file: '${GITHUB_STEP_SUMMARY}'. Check if the file has correct read/write permissions."
        exit 1
    fi

    if "${overwrite}" ; then
        printf "%s" "${__ACTIONS_CORE_SUMMARY_BUFFER_X4K92}" > "${GITHUB_STEP_SUMMARY}"
    else
        printf "%s" "${__ACTIONS_CORE_SUMMARY_BUFFER_X4K92}" >> "${GITHUB_STEP_SUMMARY}"
    fi

    summary.emptyBuffer
}
export -f  summary.write

##
# @description  Clear the summary buffer and summary file
# @example
#     summary.clear
##
summary.clear() {
    __ACTIONS_CORE_SUMMARY_BUFFER_X4K92=""
    summary.write --overwrite
}
export -f  summary.clear

##
# @description  Get the current summary buffer as a string
# @stdout  The current summary buffer content
# @example
#     content=$(summary.stringify)
##
summary.stringify() { printf "%s" "${__ACTIONS_CORE_SUMMARY_BUFFER_X4K92}" ; }
export -f  summary.stringify

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
export -f  summary.isEmptyBuffer

##
# @description  Reset the summary buffer without writing to the summary file
# @example
#     summary.emptyBuffer
##
summary.emptyBuffer() { __ACTIONS_CORE_SUMMARY_BUFFER_X4K92="" ; }
export -f  summary.emptyBuffer

##
# @description  Add raw text to the summary buffer
# @arg  text  The text to add
# @option  --eol  If set, append an end-of-line character
# @example
#     summary.addRaw "Some raw text"
#     summary.addRaw "Text with EOL" --eol
##
summary.addRaw() {
    local text="" eol=false
    
    local opts=""
    opts=$(getopt -o '' -l 'eol' -- '' "${@}") || exit 1
    eval set -- "${opts}"
    while (( $# > 0 )) ; do
        case "${1}" in
            --eol ) shift ; eol=true ;                       ;;
            --    ) shift ; text="${1}" ; shift 1 ;            ;;
            * ) core._getoptInvalidArgErrorAndExit "${@}" ;  ;;
        esac
    done

    __ACTIONS_CORE_SUMMARY_BUFFER_X4K92+="${text}"
    "${eol}" && summary.addEOL
}
export -f  summary.addRaw

##
# @description  Add an end-of-line character to the summary buffer
# @example
#     summary.addEOL
##
summary.addEOL() { __ACTIONS_CORE_SUMMARY_BUFFER_X4K92+=$'\n' ; }
export -f  summary.addEOL

##
# @description  Add a code block to the summary buffer
# @arg  code  The code to add
# @option  -l | --lang | --language  The language for syntax highlighting
# @example
#     summary.addCodeBlock -l "python" "print('Hello, World!')"
##
summary.addCodeBlock() {
    local code="" lang="" attrs=("")

    local opts=""
    opts=$(getopt -o 'l' -l 'lang,language' -- '' "${@}") || exit 1
    eval set -- "${opts}"
    while (( $# > 0 )) ; do
        case "${1}" in
            -l | --lang | --language ) shift ; lang="${1}" ; shift 1 ;  ;;
            --                       ) shift ; code="${1}"   ; shift 1 ;  ;;
            * ) core._getoptInvalidArgErrorAndExit "${@}" ;  ;;
        esac
    done

    [[ -n "${lang}" ]] && attrs+=( "lang=\"${lang}\"" )

    summary.addRaw "<pre><code${attrs[*]}>${code}</code></pre>" --eol
}
export -f  summary.addCodeBlock

##
# @description  Add a list to the summary buffer
# @arg  ...  List items
# @option  --ul | --unordered  If set, create an unordered list. This is the default.
# @option  --ol | --ordered    If set, create an ordered list instead of unordered
# @example
#     summary.addList "Item 1" "Item 2" "Item 3"
#     summary.addList --ordered "First" "Second" "Third"
##
summary.addList() {
    local tag='ul' items=() itemArgs=()

    local opts
    opts=$(getopt -o '' -l 'unordered,ul,ordered,ol' -- '' "${@}") || exit 1
    eval set -- "${opts}"
    while (( $# > 0 )) ; do
        case "${1}" in
            --ol | --ordered   ) shift ; tag='ol' ;                           ;;
            --ul | --unordered ) shift ; tag='ul' ;                           ;;
            --                 ) shift ; itemArgs=( "${@}" ) ; shift ${#@} ;  ;;
            * ) core._getoptInvalidArgErrorAndExit "${@}" ;                   ;;
        esac
    done

    local item
    for item in "${itemArgs[@]}" ; do
        items+=( "<li>${item}</li>" )
    done

    summary.addRaw "<${tag}>${items[*]}</${tag}>" --eol
}
export -f  summary.addList

## @internal
summary.addTable() { core._NotImplementedErrorAndExit ; }
export -f  summary.addTable

##
# @description  Start a table in the summary buffer and optionally add a header row
# @arg  ...  Optional header cells
# @example
#     summary.startTable "Header1" "Header2" "Header3"
##
summary.startTable() {
    summary.addRaw "<table>" --eol
    local cell cells=""
    for cell in "${@}" ; do
        cells+="<th>${cell}</th>"
    done
    [[ -n "${cells}" ]] && \
        summary.addRaw "<thead><tr>${cells}</tr></thead>" --eol
    summary.addRaw "<tbody>" --eol
}
export -f summary.startTable

##
# @description  Add a row to the table in the summary buffer
# @arg  ...  Table cells for the row
# @example
#     summary.addTableRow "Value1" "Value2" "Value3"
##
summary.addTableRow() {
    local row_cells=""
    if (( $# <= 0 )) ; then
        core.error "${FUNCNAME[0]}: No cells provided" "Function called with no arguments."
        exit 1
    fi
    local cell
    for cell in "${@}" ; do
        row_cells+="<td>${cell}</td>"
    done
    summary.addRaw "<tr>${row_cells}</tr>" --eol
}
export -f summary.addTableRow

##
# @description  End the table in the summary buffer
# @example
#     summary.endTable
##
summary.endTable() {
    summary.addRaw "</tbody></table>" --eol
}
export -f summary.endTable

##
# @description  Add a collapsible details element to the summary buffer
# @arg  label  The text for the closed state
# @arg  content  The collapsible content
# @example
#     summary.addDetails "Click to expand" "Hidden content here"
##
summary.addDetails() {
    local label="${1}"
    local content="${2}"

    summary.addRaw "<details><summary>${label}</summary>${content}</details>" --eol
}
export -f  summary.addDetails

##
# @description  Add an image to the summary buffer
# @arg  src  The path to the image
# @arg  alt  The alt text for the image
# @option  [-w | --width]  The width of the image
# @option  [-h | --height]  The height of the image
# @example
#     summary.addImage "path/to/image.png" "Description of image" --width 100 --height 100
##
summary.addImage() {
    local src="" alt="" width="" height="" attrs=("")
    
    local opts
    opts=$(getopt -o 'w:h:' -l 'width:,height:' -- '' "${@}") || exit 1
    eval set -- "${opts}"
    while (( $# > 0 )) ; do
        case "${1}" in
            -w | --width  ) shift ; width="${1}"  ; shift 1 ;          ;;
            -h | --height ) shift ; height="${1}" ; shift 1 ;          ;;
            --       ) shift ; src="${1}" ; alt="${2}" ; shift 2 ;  ;;
            * ) core._getoptInvalidArgErrorAndExit "${@}" ;     ;;
        esac
    done

    if [[ -z "${src}" ]] ; then
        core.error "${FUNCNAME[0]}: missing 'src'"
        exit 1
    fi

    attrs+=( "src=\"${src}\"" )
    [[ -n "${alt}"    ]] && attrs+=( "alt=\"${alt}\"" )
    [[ -n "${width}"  ]] && attrs+=( "width=\"${width}\"" )
    [[ -n "${height}" ]] && attrs+=( "height=\"${height}\"" )

    summary.addRaw "<img${attrs[*]}>" --eol
}
export -f  summary.addImage

##
# @description  Add a heading to the summary buffer
# @arg  text  The heading text
# @option  [-h | -l | --lvl | --level]  The heading level (1-6, default: 1)
# @example
#     summary.addHeading "Main Title"
#     summary.addHeading -h 2 "Subtitle"
##
summary.addHeading() {
    local text="" level=""

    local opts
    opts=$(getopt -o 'h:l:' -l 'lvl:,level:' -- '' "${@}") || exit 1
    eval set -- "${opts}"
    while (( $# > 0 )) ; do
        case "${1}" in
            -h | -l | --lvl | --level ) shift ; level="${1}" ; shift 1 ;  ;;
            --                        ) shift ; text="${1}"  ; shift 1 ;  ;;
            * ) core._getoptInvalidArgErrorAndExit "${@}" ;               ;;
        esac
    done

    (( level < 1 )) && level=1
    (( level > 6 )) && level=6

    summary.addRaw "<h${level}>${text}</h${level}>" --eol
}
export -f  summary.addHeading

##
# @description  Add a separator to the summary buffer
# @example
#     summary.addSeparator
##
summary.addSeparator() { summary.addRaw "<hr>" --eol ; }
export -f  summary.addSeparator

##
# @description  Add a line break to the summary buffer
# @example
#     summary.addBreak
##
summary.addBreak() { summary.addRaw "<br>" --eol ; }
export -f  summary.addBreak

##
# @description  Add a quote to the summary buffer
# @arg  text  The quote text
# @arg  [cite]  The citation URL
# @example
#     summary.addQuote "To be or not to be" "https://example.com/hamlet"
##
summary.addQuote() {
    local text="${1}"
    local cite="${2:-}"
    local attrs=("")

    [[ -n "${cite}" ]] && attrs+=( "cite=\"${cite}\"" )

    summary.addRaw "<blockquote${attrs[*]}>${text}</blockquote>" --eol
}
export -f  summary.addQuote

##
# @description  Add a link to the summary buffer
# @arg  text  The link text
# @arg  href  The hyperlink URL
# @example
#     summary.addLink "Visit our website" "https://example.com"
##
summary.addLink() {
    local text="${1}"
    local href="${2}"
    local attrs=("")

    attrs+=( "href=\"${href}\"" )

    summary.addRaw "<a${attrs[*]}>${text}</a>" --eol
}
export -f  summary.addLink

## -------------------------------------------
# @section  Context
# @brief Provides a GitHub Actions context similar to the TypeScript version
# @description
#     This script mimics the functionality of the TypeScript Context class
#     for GitHub Actions. It provides functions to access GitHub Actions
#     context information, closely mimicking the original API.
# @see  https://github.com/actions/toolkit/blob/f003268b3250d192cf66f306694b34a278011d9b/packages/github/src/context.ts
## -------------------------------------------

##
# @description Get the name of the event that triggered the workflow
# @stdout The name of the event
# @see GITHUB_EVENT_NAME
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.eventName() { printf "%s" "${GITHUB_EVENT_NAME:-}" ; }
export -f  context.eventName

##
# @description Get the SHA of the commit that triggered the workflow
# @stdout The full SHA of the commit
# @see GITHUB_SHA
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.sha() { printf "%s" "${GITHUB_SHA:-}" ; }
export -f  context.sha

##
# @description Get the reference of the commit that triggered the workflow
# @stdout The Git ref of the commit (e.g., refs/heads/main)
# @see GITHUB_REF
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.ref() { printf "%s" "${GITHUB_REF:-}" ; }
export -f  context.ref

##
# @description Get the name of the workflow
# @stdout The name of the workflow
# @see GITHUB_WORKFLOW
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.workflow() { printf "%s" "${GITHUB_WORKFLOW:-}" ; }
export -f  context.workflow

##
# @description The name of the currently running action or the ID of a step.
#              GitHub removes special characters and uses __run for steps that
#              run scripts without an ID. If you reuse the same script or
#              action within a job, the name includes a suffix with the
#              sequence number (e.g., __run_2 or actionscheckout2 for the
#              second invocation of actions/checkout).
# @stdout The name of the current action
# @see GITHUB_ACTION
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.action() { printf "%s" "${GITHUB_ACTION:-}" ; }
export -f  context.action

##
# @description Get the name of the actor that triggered the workflow
# @stdout The name of the actor (usually a GitHub username)
# @see GITHUB_ACTOR
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.actor() { printf "%s" "${GITHUB_ACTOR:-}" ; }
export -f  context.actor

##
# @description Get the name of the current job
# @stdout The name of the job
# @see GITHUB_JOB
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.job() { printf "%s" "${GITHUB_JOB:-}" ; }
export -f  context.job

##
# @description Get the current attempt number of the job
# @stdout The attempt number (as a string)
# @see GITHUB_RUN_ATTEMPT
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.runAttempt() { printf "%s" "${GITHUB_RUN_ATTEMPT:-0}" ; }
export -f  context.runAttempt

##
# @description Get the current run number of the workflow
# @stdout The run number (as a string)
# @see GITHUB_RUN_NUMBER
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.runNumber() { printf "%s" "${GITHUB_RUN_NUMBER:-0}" ; }
export -f  context.runNumber

##
# @description Get the unique identifier for the current workflow run
# @stdout The run ID (as a string)
# @see GITHUB_RUN_ID
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.runId() { printf "%s" "${GITHUB_RUN_ID:-0}" ; }
export -f  context.runId

##
# @description Get the API URL for the current GitHub instance
# @stdout The API URL (defaults to https://api.github.com)
# @see GITHUB_API_URL
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.apiUrl() { printf "%s" "${GITHUB_API_URL:-https://api.github.com}" ; }
export -f  context.apiUrl

##
# @description Get the URL for the current GitHub instance
# @stdout The server URL (defaults to https://github.com)
# @see GITHUB_SERVER_URL
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.serverUrl() { printf "%s" "${GITHUB_SERVER_URL:-https://github.com}" ; }
export -f  context.serverUrl

##
# @description Get the GraphQL API URL for the current GitHub instance
# @stdout The GraphQL API URL (defaults to https://api.github.com/graphql)
# @see GITHUB_GRAPHQL_URL
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.graphqlUrl() { printf "%s" "${GITHUB_GRAPHQL_URL:-https://api.github.com/graphql}" ; }
export -f  context.graphqlUrl

##
# @description Get the full event payload that triggered the workflow
# @arg  $1  jq query, defaults to `.`
# @stdout The event payload as a JSON string
##
context.payload() {
    local query="${1:-.}"
    local event_path="${GITHUB_EVENT_PATH:-}"
    if [[ -n "${event_path}" && -f "${event_path}" ]]; then
        jq -r "${query}" "${event_path}"
    else
        if [[ -n "${event_path}" ]]; then
            core.error "${FUNCNAME[0]}: GITHUB_EVENT_PATH does not exist" "The path '${event_path}' is unavailable."
        fi
        printf "{}"
    fi
}
export -f  context.payload

##
# @description Get the owner and repository name
# @stdout The owner and repository name separated by a space
# @error If GITHUB_REPOSITORY is not set and can't be derived from the payload
# @see GITHUB_REPOSITORY
# @see https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/variables#default-environment-variables
##
context.repo() {
    local repo_info=""
    if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
        repo_info=$(awk -F'/' '{printf "%s %s", $1, $2}' <<< "${GITHUB_REPOSITORY}")
    else
        repo_info=$(context.payload '(.repository.owner.login + " " + .repository.name) // empty')
    fi

    if [[ -z "${repo_info}" ]]; then
        core.error "${FUNCNAME[0]}: Unable to determine repository information" "Ensure GITHUB_REPOSITORY is set or the payload contains repository data."
        return 1
    fi

    printf "%s" "${repo_info}"
}
export -f  context.repo

##
# @description Get the issue or pull request information
# @stdout The owner, repository name, and issue/PR number separated by spaces
##
context.issue() {
    # shellcheck disable=SC2312
    read -r owner repo <<< "$(context.repo)"
    number="$(context.payload '(.issue.number // .pull_request.number // .number) // empty')"
    printf "%s %s %s" "${owner}" "${repo}" "${number}"
}
export -f  context.issue
