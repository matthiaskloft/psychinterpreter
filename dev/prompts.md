
# analyze package
analyze the package for consistency using subagents where feasible: 1. code with intended structure and logic as
documented in /dev. 2. documentation in /dev and in roxygen with actual implemented
code. 3. abstraction level of package with regards to the planned extendion to new
classes. 4. tests with the actual code implemented. note everything down in a single doc in /dev


# history clean up
clean up package history in developer guide by integrating necessary info into the guide and then removing the history 

# wsl: update claude-code package
cd ~/.claude/local && npm update @anthropic-ai/claude-code
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
