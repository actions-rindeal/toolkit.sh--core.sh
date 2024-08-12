# 🚀 Bash Actions Core: Supercharge Your GitHub Workflows!

[![GitHub stars](https://img.shields.io/github/stars/actions-rindeal/core.sh?style=social)](https://github.com/actions-rindeal/core.sh/stargazers)
[![GitHub license](https://img.shields.io/github/license/actions-rindeal/core.sh)](https://github.com/actions-rindeal/core.sh/blob/master/LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/actions-rindeal/core.sh)](https://github.com/actions-rindeal/core.sh/issues)

Unleash the power of Bash in your GitHub Actions! 💪 Bash Actions Core is a lightning-fast, feature-rich reimplementation of the popular [`@actions/core`](https://www.npmjs.com/package/@actions/core) package, bringing familiar syntax and functions to your Bash scripts.

## 🎭 Journey Through an Action: A Guided Tour

Let's embark on an exciting journey through a GitHub Action, showcasing the incredible features of Bash Actions Core along the way!

```bash
#!/usr/bin/env bash

# 📥 Step 1: Install Bash Actions Core
wget -O ~/core.sh https://github.com/actions-rindeal/core.sh/raw/master/core.sh
source ~/core.sh

# 🏁 Step 2: Set up our action
core.info "🚀 Starting our awesome action!"

# 🔐 Step 3: Handle secrets and variables
core.exportVariable "RELEASE_VERSION" "v1.0.0"
core.setSecret "SUPER_SECRET_KEY"

# 🛠️ Step 4: Prepare the environment
core.addPath "/usr/local/bin"

# 👂 Step 5: Listen to user input
repo_name=$(core.getInput --required "repo_name")
is_draft=$(core.getBooleanInput "is_draft")

# 🔍 Step 6: Debug mode check
if core.isDebug; then
    core.debug "🔍 Debug mode activated!"
fi

# 📊 Step 7: Start creating a summary
summary.addHeading "🎉 Release Summary"
summary.addList "Repository: ${repo_name}" "Version: ${RELEASE_VERSION}" "Draft: ${is_draft}"

# 🌟 Step 8: Perform the main action
core.startGroup "📦 Creating release"
    # ... release creation logic here ...
    core.info "📦 Release created successfully!"
core.endGroup

# ⚠️ Step 9: Handle warnings or notices
if [[ "${is_draft}" == "true" ]]; then
    core.warning "⚠️ This is a draft release" file="release.yml" startLine=10 endLine=15
else
    core.notice "✅ This is a public release"
fi

# 🎨 Step 10: Enhance the summary
summary.addCodeBlock "echo 'Release ${RELEASE_VERSION} created for ${repo_name}'" --lang "bash"
summary.addLink "View Release" "https://github.com/${repo_name}/releases"

# 💾 Step 11: Save state for other actions
core.saveState "RELEASE_CREATED" "true"

# 🏷️ Step 12: Set output for other steps
core.setOutput "release_url" "https://github.com/${repo_name}/releases/tag/${RELEASE_VERSION}"

# 📝 Step 13: Write the summary
summary.write

# 🎭 Step 14: Use GitHub context
actor=$(context.actor)
core.info "🙌 Action completed by ${actor}!"

# 🏁 Step 15: Finish up
core.info "✨ Action completed successfully!"
```

## 🌟 Key Features

- 🚀 **Fast & Lightweight**: Pure Bash implementation for speedy execution
- 🔄 **API Compatibility**: Mimics the `@actions/core` package for easy migration
- 🛠️ **Powerful Toolkit**: From variable management to creating rich summaries
- 🔒 **Secure**: Built-in secret handling and masking
- 📊 **Rich Logging**: Debug, info, warning, and error logging with annotations
- 🌍 **Context Aware**: Access GitHub context information effortlessly

## 🚀 Quick Start

1. Download the script in your GitHub Actions workflow:
   ```bash
   wget -O ~/core.sh https://github.com/actions-rindeal/core.sh/raw/master/core.sh
   ```

2. Source the script in your workflow:
   ```bash
   source ~/core.sh
   ```

3. Start using the powerful features of Bash Actions Core!

## 📚 Documentation

For detailed documentation and advanced usage, check out our [Wiki](https://github.com/actions-rindeal/core.sh/wiki).

## 🤝 Contributing

We love contributions! Whether it's bug reports, feature requests, or pull requests, all contributions are welcome.

## 📜 License

This project is licensed under the GPL 3.0 License - see the [LICENSE](LICENSE) file for details.

## 💖 Support

If you find this project helpful, please consider giving it a star ⭐ on GitHub. It helps others discover the project and motivates us to keep improving!
