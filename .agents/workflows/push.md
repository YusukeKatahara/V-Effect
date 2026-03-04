---
description: Stages changes, commits with an auto-generated message, and pushes
model: gemini-2.0-flash
---

> **Model to use:** Gemini 2.0 Flash (Uses a lightweight model to save tokens)

// turbo
1. Check the current changes (`git diff`) and create a commit message that concisely summarizes the modifications.

2. Stage all changes and commit them with the created message.
   `git add .`
   `git commit -m "[Auto-generated message]"`

3. Push to the remote repository.
   `git push`

4. Upon completion, report a summary of the committed contents.
