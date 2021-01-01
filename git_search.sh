#!/bin/bash

# This script recursively inspects directories and returns a list of git
# repositories which were found to be in a "non-trivial" state. A repository is
# in such a state if git status --porcelain=v1 produces a non-empty output.
#
# Parameters:
# (optional) 1) A path to a directory which will serve as the root of the
#               directory subtree which will be searched by the script.
#
# Preconditions: none.
#
# Effects:
# 1) If a malformed directory path argument was provided, then an error message
#    was printed. The script returned.
# 2) If a malformed directory path argument was not present, then:
#    a) If a directory path argument was not provided, then the current working
#       directory was used as the root of the directory subtree which was
#       searched.
#    b) The list of git repositories in a non-trivial state which were in the
#       selected directory subtree was sent to standard output.


# Script definitions

# If the name of a defined, non-positional shell parameter is present as the
# first argument, then a terminal slash / is added to the value of the
# referenced parameter if one is not already present.
#
# Parameters:
# 1) The name of a defined, non-positional shell parameter.
#
# Preconditions: none
#
# Effects:
# 1) The referenced parameter may be modified as described above.
function ConditionalTerminalSlashAddition ()
{
  if [[ -v ${1} ]] && [[ ${1##+([:digit:])} ]]; then
    local -n arg_ref=${1};
    if [[ ${arg_ref: -1} != "/" ]]; then
      arg_ref=${arg_ref}"/";
    fi
  else
    return 1;
  fi
}

# If the name of a defined, non-positional shell parameter is present as the
# first argument and the value of the referenced parameter is the path of an
# existing directory, then the directory path is made absolute if it is not
# already. A terminal slash is not added.
#
# Parameters:
# 1) The name of a defined, non-positional shell parameter.
#
# Preconditions: none
#
# Effects:
# 1) The referenced parameter may be modified as described above.
function ConvertDirectoryPathToAbsolutePath ()
{
  if [[ -v ${1} ]] && [[ ${1##+([:digit:])} ]]; then
    local -n arg_ref=${1} ;
    if [[ -d ${arg_ref} ]]; then
      local current_directory=${PWD} ;
      cd "${arg_ref}" ;
      # Remove . and .. special symbols and make absolute.
      arg_ref=${PWD} ;
      cd "${current_directory}" ;
      return 0;
    else
      return 1;
    fi
  else
    return 1;
  fi
}

# This function performs a depth-first traversal of the directory list
# which was passed as a list of arguments.
#
# Parameters:
# Zero or more directory paths.
#
# Preconditions:
# 1) A directory path argument must be terminated with a slash character "/".
#
# Effects:
# 1) If no arguments were provided, then the function returned zero.
# 2) If arguments were provided, then each argument was inspected:
#    a) If the argument was the path for a git repository, then the path
#       of the directory was echoed if the repository was in a "non-trivial"
#       state.
#    b) If the argument was not the path for a git repository, then
#       GitDirectoryScanInternalRecursion was called with the list of paths of
#       the directories contained within the directory given by the argument.
#    After inspecting all arguments, zero was returned.
# 3) The state of a repository as mentioned in 2.a is non-trivial if
#    git status --porcelain=v1 produces a non-empty output.
function GitDirectoryScanInternalRecursion ()
{
  # Check for the absence of directory arguments.
  # (Terminal recursive condition.)
  if [[ $# == 0 ]]; then
    return 0;
  fi

  # Recursively iterate over all directory arguments.
  local i
  for (( i=1; i < ($# + 1); ++i)); do
    # Expand i to its numeric value. Then use this numeric value to get the
    # ith positional parameter value through position parameter expansion.
    local local_dir=${!i};
    # Does local_dir have a .git directory?
    if [[ -d ${local_dir}.git ]]; then

      ### START ### Potentially-variable git repository inspection code.

      # Simple git directory inspection.
      cd "${local_dir}";
      git status --porcelain=v1 >"/tmp/GitDirectoryScan";
      # Any content? If so, inform the user about the non-trivial state of the
      # repository.
      if [[ -s "/tmp/GitDirectoryScan" ]]; then
        echo "${local_dir}";
      fi
      rm "/tmp/GitDirectoryScan";

      ### END ### Potentially-variable git repository inspection code.

    else
      #    Perform depth-first search. The arguments are the result of an
      # expansion which produces the sorted list of any directories contained
      # within ${local_dir}. Note that trailing slashes are present in the
      # directory paths after expansion.
      #    Quoting is necessary to prevent word splitting before pathname
      # expansion. The list of words introduced by pathname expansion
      # is the list of arguments passed to the function. This list may be
      # empty. The arguments are not expanded or split after the pathname
      # expansion which generated them.
      GitDirectoryScanInternalRecursion "${local_dir}"*/ ;
    fi
  done
  return 0;
}

function GitDirectoryScan ()
{
  # Save the current directory to allow it to be restored after calling
  # GitDirectoryScanInternalRecursion.
  local working_directory=${PWD}

  # The recursive scan uses file name expansions which require:
  #   dotglob  off
  #   failglob off
  #   nullglob on

  # The status of these options is checked, each is set or cleared as needed,
  # and state is saved to allow the original status to be restored before exit.
  # 0 is true (on), 1 is false (off).
  local -A needed_glob_opt_status
  needed_glob_opt_status=([dotglob]=1 [failglob]=1 [nullglob]=0)
  # Keys are glob option names. A value is the status of the glob option that
  # should be present at exit.
  local -A invert_glob_option
  local glob_name
  for glob_name in ${!needed_glob_opt_status[@]}; do
    if shopt -q ${glob_name}; then
      if [[ ${needed_glob_opt_status[${glob_name}]} != 0 ]]; then
        shopt -qu ${glob_name};
        invert_glob_option[${glob_name}]=0;
      fi
    else
      if [[ ${needed_glob_opt_status[${glob_name}]} != 1 ]]; then
        shopt -qs ${glob_name};
        invert_glob_option[${glob_name}]=1;
      fi
    fi
  done

  GitDirectoryScanInternalRecursion "${1}"

  # Restore the original status of each relevant glob option.
  for glob_name in ${!invert_glob_option[@]}; do
    if [[ ${invert_glob_option[${glob_name}]} == 0 ]]; then
      shopt -qs ${glob_name};
    else
      shopt -qu ${glob_name};
    fi
  done

  # Restore the working directory to what it was upon function invocation.
  cd "${working_directory}"

  return 0
}

function script_entry_point ()
{
  local selected_dir
  if [[ ${1} ]]; then
    if [[ -d ${1} ]]; then
      selected_dir=${1} ;
    else
      echo "A non-directory argument was provided.";
      return 1;
    fi
  else
    selected_dir=${PWD};
  fi
  ConvertDirectoryPathToAbsolutePath selected_dir
  ConditionalTerminalSlashAddition selected_dir

  GitDirectoryScan "${selected_dir}"
}

# Script commands.

# Invokes the script logic with an argument if one is present. Exits back to
# the supershell.
script_entry_point "$1"
exit
