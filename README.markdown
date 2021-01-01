# Utility shell scripts for personal use.

A (currently small) collection of shell scripts that I have developed
for my own use.

* `git_search.sh`
  * Searches an indicated directory subtree for Git repositories which need
    attention. The repositories which were found are sent to standard output.
  * A Git repository "needs attention" if `git status --porcelain=v1` produces
    a non-empty output.
  * An optional directory path argument may be provided. When no argument is
    provided, the current working directory is used as the directory subtree
    root.
  * The logic which inspects Git repositories may easily be changed without
    altering the rest of the script.
