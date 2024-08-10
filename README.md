# Bash Actions Core

A Bash reimplementation of the [`@actions/core`](https://www.npmjs.com/package/@actions/core) package.

Use familiar syntax and functions in your GitHub workflows and actions now in BASH, too!

## Usage

The API mimicks the original one as closely as possible, while still sticking to BASH style.

```bash
core.exportVariable "MY_VAR" "my value"

core.setSecret "my secret value"

core.addPath "/path/to/dir"

value=$(core.getInput "MY_INPUT")
required_value=$(core.getInput --required "REQUIRED")
untrimmed_value=$(core.getInput --no-trim "UNTRIMMED")

core.setOutput "MY_OUTPUT" "output value"

core.isDebug && echo "Debug mode on" || echo "Debug mode off"
core.debug    "This is a debug message"
core.error    "An error occurred"
core.warning  "This is a warning" line=235
core.notice   "This is a notice"
core.info     "This is an info message"

core.saveState "MY_STATE" "state value"
state_value=$(core.getState "MY_STATE")

event_name=$(context.eventName)
sha=$(context.sha)
ref=$(context.ref)
workflow=$(context.workflow)
actor=$(context.actor)
job=$(context.job)
run_attempt=$(context.runAttempt)
run_number=$(context.runNumber)
run_id=$(context.runId)
context.payload | jq .
read -r user repo << $(context.repo)
read -r user repo issue << $(context.issue)
```

## Installation

Clone the repository and source the script in your GitHub Actions workflow.

```bash
wget -O  ~/core.sh  https://github.com/actions-rindeal/core.sh/raw/master/core.sh
source   ~/core.sh
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
