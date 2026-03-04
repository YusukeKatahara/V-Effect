---
description: Pulls the latest changes and summarizes the modifications and previous activities
model: gemini-2.0-flash
---

> **Model to use:** Gemini 2.0 Flash (Uses a lightweight model to save tokens)

// turbo
1. Get the latest code by executing `git pull`.
   `git pull`

2. Check the history with `git log -n 5 --stat` etc., and provide a summary of the changes introduced by the pull.

3. Provide a summary of "what work was done last time" based on the recent commit history or previous conversation history of the user who executed the pull (renn or yusuke).

