Commit work organized by task.

read the uncommited changes and organize them by task worked on.
Each task should have a very fine intent, do not group intents even if they're moving towards the same task.
You might have to commit specific hunks in a file instead of the whole file.
ask for approval per commit, if not approved, go to the next.
show a code changes diff preview of what you're trying to commit.

Be on the lookout for dangerous commits and warn me.


IMPORTANT: never use git commit without the specific files as an argument.
BAD: git add test.md && git commit -m "message"
GOOD: git commit test.md -m "message"

Do not run risky git operations.
