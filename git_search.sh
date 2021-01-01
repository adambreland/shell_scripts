#!/bin/bash

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
      # Perform depth-first search. The arguments are the result of an
      # expansion which produces the sorted list of any directories contained
      # within ${local_dir}. Note that trailing slashes are present in the
      # directory paths after expansion.
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

function main ()
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

# Invoke the script logic with an argument if one is present and exit back to 
# the supershell.
main "$1"
exit
