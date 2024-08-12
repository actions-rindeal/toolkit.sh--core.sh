#!/usr/bin/env bash
#trunk-ignore-all(shellcheck/SC1083)  # This { is literal. Check expression (missing ;/\n?) or quote it.

source "${BACH_SH_PATH}"
source "${CORE_SH_PATH}"

@setup {
    @mock jq
    @mock cat
    @mock uuidgen
}

# Helper function to mock environment variables
mock_env() {
    for var in "$@"; do
        eval "export $var"
    done
}

# Helper function to unmock environment variables
unmock_env() {
    for var in "$@"; do
        unset "$var"
    done
}

test-exportVariable() {
    mock_env GITHUB_ENV
    core.exportVariable "MY_VAR" "my value"
}
test-exportVariable-assert() {
    @out MY_VAR<<ghadelimiter_$(uuidgen)
my value
ghadelimiter_$(uuidgen)
}

test-setSecret() {
    core.setSecret "my secret value"
}
test-setSecret-assert() {
    @out "::add-mask::my secret value"
}

test-addPath() {
    mock_env GITHUB_PATH
    core.addPath "/path/to/dir"
}
test-addPath-assert() {
    @out "/path/to/dir"
}

test-getInput() {
    mock_env INPUT_MYINPUT
    @mock bash -c 'echo "$INPUT_MYINPUT"' === @out "test value"
    result=$(core.getInput "MYINPUT")
    @assert-equals "test value" "$result"
}

test-getInput-required() {
    mock_env INPUT_MYINPUT
    @mock bash -c 'echo "$INPUT_MYINPUT"' === @out ""
    if ! core.getInput --required "MYINPUT"; then
        @echo "Input required"
    fi
}
test-getInput-required-assert() {
    @out "::error title=_getInput: Required input is empty.::Input 'INPUT_MYINPUT' was found empty, but its value was required to be non-empty."
    @out "Input required"
}

test-getMultilineInput() {
    mock_env INPUT_MULTILINE
    @mock bash -c 'echo "$INPUT_MULTILINE"' === @out $'line1\nline2\nline3'
    readarray -t lines < <(core.getMultilineInput "MULTILINE")
    @assert-equals 3 "${#lines[@]}"
    @assert-equals "line1" "${lines[0]}"
    @assert-equals "line2" "${lines[1]}"
    @assert-equals "line3" "${lines[2]}"
}

test-getBooleanInput-true() {
    mock_env INPUT_MYBOOL
    @mock bash -c 'echo "$INPUT_MYBOOL"' === @out "true"
    if core.getBooleanInput "MYBOOL"; then
        @echo "Input is true"
    else
        @echo "Input is false"
    fi
}
test-getBooleanInput-true-assert() {
    @out "Input is true"
}

test-getBooleanInput-false() {
    mock_env INPUT_MYBOOL
    @mock bash -c 'echo "$INPUT_MYBOOL"' === @out "false"
    if core.getBooleanInput "MYBOOL"; then
        @echo "Input is true"
    else
        @echo "Input is false"
    fi
}
test-getBooleanInput-false-assert() {
    @out "Input is false"
}

test-setOutput() {
    mock_env GITHUB_OUTPUT
    core.setOutput "MY_OUTPUT" "output value"
}
test-setOutput-assert() {
    @out MY_OUTPUT<<ghadelimiter_$(uuidgen)
output value
ghadelimiter_$(uuidgen)
}

test-setCommandEcho-on() {
    core.setCommandEcho true
}
test-setCommandEcho-on-assert() {
    @out "::echo::on"
}

test-setCommandEcho-off() {
    core.setCommandEcho false
}
test-setCommandEcho-off-assert() {
    @out "::echo::off"
}

test-setFailedAndExit() {
    core.setFailedAndExit "Error occurred" "Detailed error message"
}
test-setFailedAndExit-assert() {
    @out "::error title=Error occurred::Detailed error message"
}

test-isDebug-true() {
    mock_env RUNNER_DEBUG
    @mock bash -c 'echo "$RUNNER_DEBUG"' === @out "1"
    if core.isDebug; then
        @echo "Debug mode is on"
    else
        @echo "Debug mode is off"
    fi
}
test-isDebug-true-assert() {
    @out "Debug mode is on"
}

test-isDebug-false() {
    mock_env RUNNER_DEBUG
    @mock bash -c 'echo "$RUNNER_DEBUG"' === @out "0"
    if core.isDebug; then
        @echo "Debug mode is on"
    else
        @echo "Debug mode is off"
    fi
}
test-isDebug-false-assert() {
    @out "Debug mode is off"
}

test-debug() {
    core.debug "This is a debug message"
}
test-debug-assert() {
    @out "::debug::This is a debug message"
}

test-error() {
    core.error "An error occurred"
}
test-error-assert() {
    @out "::error::An error occurred"
}

test-warning() {
    core.warning "This is a warning"
}
test-warning-assert() {
    @out "::warning::This is a warning"
}

test-notice() {
    core.notice "This is a notice"
}
test-notice-assert() {
    @out "::notice::This is a notice"
}

test-info() {
    core.info "This is an info message"
}
test-info-assert() {
    @out "This is an info message"
}

test-startGroup() {
    core.startGroup "My Group"
}
test-startGroup-assert() {
    @out "::group::My Group"
}

test-endGroup() {
    core.endGroup
}
test-endGroup-assert() {
    @out "::endgroup::"
}

test-saveState() {
    mock_env GITHUB_STATE
    core.saveState "MY_STATE" "state value"
}
test-saveState-assert() {
    @out MY_STATE<<ghadelimiter_$(uuidgen)
state value
ghadelimiter_$(uuidgen)
}

test-getState() {
    mock_env STATE_MY_STATE
    @mock bash -c 'echo "$STATE_MY_STATE"' === @out "state value"
    result=$(core.getState "MY_STATE")
    @assert-equals "state value" "$result"
}

# Summary tests

test-summary-init() {
    summary.init
    @assert-equals "" "$(summary.stringify)"
}

test-summary-addRaw() {
    summary.init
    summary.addRaw "Raw text"
    @assert-equals "Raw text" "$(summary.stringify)"
}

test-summary-addEOL() {
    summary.init
    summary.addRaw "Line 1"
    summary.addEOL
    summary.addRaw "Line 2"
    @assert-equals $'Line 1\nLine 2' "$(summary.stringify)"
}

test-summary-addCodeBlock() {
    summary.init
    summary.addCodeBlock "print('Hello')" -l python
    expected=$'<pre><code lang="python">print(\'Hello\')</code></pre>\n'
    @assert-equals "$expected" "$(summary.stringify)"
}

test-summary-addList() {
    summary.init
    summary.addList "Item 1" "Item 2" "Item 3"
    expected=$'<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>\n'
    @assert-equals "$expected" "$(summary.stringify)"
}

test-summary-addTable() {
    summary.init
    summary.startTable "Header1" "Header2"
    summary.addTableRow "Value1" "Value2"
    summary.endTable
    expected=$'<table>\n<thead><tr><th>Header1</th><th>Header2</th></tr></thead>\n<tbody>\n<tr><td>Value1</td><td>Value2</td></tr>\n</tbody></table>\n'
    @assert-equals "$expected" "$(summary.stringify)"
}

test-summary-addDetails() {
    summary.init
    summary.addDetails "Click to expand" "Hidden content"
    expected=$'<details><summary>Click to expand</summary>Hidden content</details>\n'
    @assert-equals "$expected" "$(summary.stringify)"
}

test-summary-addImage() {
    summary.init
    summary.addImage "image.png" "Alt text" -w 100 -h 100
    expected=$'<img src="image.png" alt="Alt text" width="100" height="100">\n'
    @assert-equals "$expected" "$(summary.stringify)"
}

test-summary-addHeading() {
    summary.init
    summary.addHeading "Title" -h 2
    expected=$'<h2>Title</h2>\n'
    @assert-equals "$expected" "$(summary.stringify)"
}

test-summary-addSeparator() {
    summary.init
    summary.addSeparator
    expected=$'<hr>\n'
    @assert-equals "$expected" "$(summary.stringify)"
}

test-summary-addBreak() {
    summary.init
    summary.addBreak
    expected=$'<br>\n'
    @assert-equals "$expected" "$(summary.stringify)"
}

test-summary-addQuote() {
    summary.init
    summary.addQuote "To be or not to be" "https://example.com/hamlet"
    expected=$'<blockquote cite="https://example.com/hamlet">To be or not to be</blockquote>\n'
    @assert-equals "$expected" "$(summary.stringify)"
}

test-summary-addLink() {
    summary.init
    summary.addLink "Visit our website" "https://example.com"
    expected=$'<a href="https://example.com">Visit our website</a>\n'
    @assert-equals "$expected" "$(summary.stringify)"
}

test-summary-write() {
    summary.init
    summary.addRaw "Test content"
    mock_env GITHUB_STEP_SUMMARY
    @mock cat === @out ""
    summary.write
}
test-summary-write-assert() {
    @out "Test content"
}

test-summary-clear() {
    summary.init
    summary.addRaw "Test content"
    mock_env GITHUB_STEP_SUMMARY
    @mock cat === @out ""
    summary.clear
    @assert-equals "" "$(summary.stringify)"
}

# Context tests

test-context-eventName() {
    mock_env GITHUB_EVENT_NAME
    @mock bash -c 'echo "$GITHUB_EVENT_NAME"' === @out "push"
    result=$(context.eventName)
    @assert-equals "push" "$result"
}

test-context-sha() {
    mock_env GITHUB_SHA
    @mock bash -c 'echo "$GITHUB_SHA"' === @out "abcdef1234567890"
    result=$(context.sha)
    @assert-equals "abcdef1234567890" "$result"
}

test-context-ref() {
    mock_env GITHUB_REF
    @mock bash -c 'echo "$GITHUB_REF"' === @out "refs/heads/main"
    result=$(context.ref)
    @assert-equals "refs/heads/main" "$result"
}

test-context-workflow() {
    mock_env GITHUB_WORKFLOW
    @mock bash -c 'echo "$GITHUB_WORKFLOW"' === @out "CI"
    result=$(context.workflow)
    @assert-equals "CI" "$result"
}

test-context-action() {
    mock_env GITHUB_ACTION
    @mock bash -c 'echo "$GITHUB_ACTION"' === @out "run-tests"
    result=$(context.action)
    @assert-equals "run-tests" "$result"
}

test-context-actor() {
    mock_env GITHUB_ACTOR
    @mock bash -c 'echo "$GITHUB_ACTOR"' === @out "octocat"
    result=$(context.actor)
    @assert-equals "octocat" "$result"
}

test-context-job() {
    mock_env GITHUB_JOB
    @mock bash -c 'echo "$GITHUB_JOB"' === @out "build"
    result=$(context.job)
    @assert-equals "build" "$result"
}

test-context-runNumber() {
    mock_env GITHUB_RUN_NUMBER
    @mock bash -c 'echo "$GITHUB_RUN_NUMBER"' === @out "42"
    result=$(context.runNumber)
    @assert-equals "42" "$result"
}

test-context-runId() {
    mock_env GITHUB_RUN_ID
    @mock bash -c 'echo "$GITHUB_RUN_ID"' === @out "12345"
    result=$(context.runId)
    @assert-equals "12345" "$result"
}

test-context-apiUrl() {
    mock_env GITHUB_API_URL
    @mock bash -c 'echo "$GITHUB_API_URL"' === @out "https://api.github.com"
    result=$(context.apiUrl)
    @assert-equals "https://api.github.com" "$result"
}

test-context-serverUrl() {
    mock_env GITHUB_SERVER_URL
    @mock bash -c 'echo "$GITHUB_SERVER_URL"' === @out "https://github.com"
    result=$(context.serverUrl)
    @assert-equals "https://github.com" "$result"
}

test-context-graphqlUrl() {
    mock_env GITHUB_GRAPHQL_URL
    @mock bash -c 'echo "$GITHUB_GRAPHQL_URL"' === @out "https://api.github.com/graphql"
    result=$(context.graphqlUrl)
    @assert-equals "https://api.github.com/graphql" "$result"
}

test-context-payload() {
    mock_env GITHUB_EVENT_PATH
    @mock cat === @out '{"key": "value"}'
    @mock jq '.' === @out '{"key": "value"}'
    result=$(context.payload)
    @assert-equals '{"key": "value"}' "$result"
}

test-context-repo() {
    mock_env GITHUB_REPOSITORY
    @mock bash -c 'echo "$GITHUB_REPOSITORY"' === @out "owner/repo"
    result=$(context.repo)
    @assert-equals "owner repo" "$result"
}

test-context-issue() {
    mock_env GITHUB_REPOSITORY
    @mock bash -c 'echo "$GITHUB_REPOSITORY"' === @out "owner/repo"
    @mock jq -r '(.issue.number // .pull_request.number // .number) // empty' === @out "42"
    result=$(context.issue)
    @assert-equals "owner repo 42" "$result"
}

# Clean up mocked environment variables
#@teardown {
