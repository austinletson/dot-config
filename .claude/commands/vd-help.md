---
description: Research VisiData docs and answer questions
argument-hint: [question about visidata]
model: sonnet
allowed-tools: WebSearch, WebFetch, Bash, Grep, Read
---

Answer this question about VisiData: $ARGUMENTS

Follow these steps systematically:

## 1. Search VisiData Documentation

First, search the official documentation at https://www.visidata.org/docs/

- Use WebFetch to read relevant documentation pages
- Look for the VisiData manual, API reference, or guides
- Focus on finding specific, authoritative answers to the question

## 2. Test with the vd Command (if applicable)

If the question relates to command-line usage or behavior:

- Run `vd --help` to see available options and flags
- Run `vd --help-all` for comprehensive command reference
- Try `man vd` if available for detailed manual pages
- If safe and relevant, test specific features with sample data

## 3. Search the GitHub Repository

If documentation is insufficient, search the VisiData GitHub repository:

- Use WebSearch with: "site:github.com/saulpw/visidata $ARGUMENTS"
- Look for:
  - README sections
  - Issues discussing the feature
  - Pull requests that implemented it
  - Code examples in the repository
  - Wiki pages if available

## 4. Provide Your Answer

Structure your response as follows:

**If you found the answer:**
- Provide a clear, specific answer to the question
- Include relevant code examples or command usage
- Cite your sources with URLs or command outputs
- If multiple approaches exist, explain the differences

**If you cannot find the answer:**
State explicitly: "I cannot find a definitive answer to this question in the VisiData documentation or repository."

Then explain:
- What you searched
- What related information you found (if any)
- Suggestions for where else the user might look

## Important Guidelines

- Do NOT guess or infer answers that aren't documented
- Always cite specific sources (URLs, file paths, command outputs)
- If documentation conflicts with command behavior, note the discrepancy
- Prefer official documentation over GitHub discussions when both exist
- Include version information when relevant to the answer
