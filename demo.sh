#!/bin/bash

# Set to nothing for interactive mode, anything else to do everything without
# prompting.
INTERACTIVE=1


ROOT="/tmp/gitforoperations"
[ -e "$ROOT" ] && echo "Root $ROOT already exists. Aborting." && exit 1
REPO_PATH="$ROOT/repo.git"
VERSIONED_FILE="code"
ALICE_CLONE_PATH="$ROOT/alice"
BOB_CLONE_PATH="$ROOT/bob"

_wait_for_user() {
    if [ -n "$INTERACTIVE" ] ; then
        echo "(enter to continue)"
        read _
    fi
}

preamble () {
    echo "###########################"
    echo "# GIT FOR OPERATIONS DEMO #"
    echo "###########################"
}

init () {
    #echo
    #echo "### Initializing..."

    #echo "# Creating root $ROOT"
    mkdir -p "$REPO_PATH"

    #echo "# Initializing bare and empty repo $REPO_PATH"
    git --git-dir "$REPO_PATH" init --bare

    #echo "# Cloning $REPO_PATH for Alice into $ALICE_CLONE_PATH"
    git clone "$REPO_PATH" "$ALICE_CLONE_PATH"

    #echo "# Using Alice's clone to add a file"
    pushd "$ALICE_CLONE_PATH" > /dev/null
    echo "Initial" > "$ALICE_CLONE_PATH/$VERSIONED_FILE"
    git add "$VERSIONED_FILE"
    git commit -m"Initial"
    # Stupid hack to turn off interactivity, caused by the stupid hack of
    # reusing push_from_clone, caused by the fact that I need a bare repo
    # because I can't push to a non-bare repo.
    ORIG_INTERACTIVE="$INTERACTIVE"
    INTERACTIVE=""
    push_from_clone "$ALICE_CLONE_PATH"
    INTERACTIVE="$ORIG_INTERACTIVE"
    popd > /dev/null

    #echo "# Cloning $REPO_PATH for Bob into $BOB_CLONE_PATH"
    git clone "$REPO_PATH" "$BOB_CLONE_PATH"

    echo "### Done initializing!"
    echo
    echo
}

commit_change () {
    path_to_clone="$1"
    contents_to_add="$2"
    echo
    echo "### Committing new contents '$contents_to_add' in clone $path_to_clone..."

    pushd "$path_to_clone" > /dev/null
    echo "$contents_to_add" >> "$VERSIONED_FILE"
    git commit -am "$contents_to_add"
    popd > /dev/null
}

push_from_clone () {
    path_to_clone="$1"
    echo
    echo "### Pushing from clone '$path_to_clone'..."

    pushd "$path_to_clone" > /dev/null
    git push origin master
    popd > /dev/null
}

cat_from_clone() {
    path_to_clone="$1"
    echo "### Contents of '$path_to_clone/$VERSIONED_FILE'..."
    cat "$path_to_clone/$VERSIONED_FILE"
    _wait_for_user
}

log_remote_from_clone() {
    path_to_clone="$1"
    echo
    echo "### HEAD of origin/master as seen by clone '$path_to_clone'..."
    pushd "$path_to_clone" > /dev/null
    git log --format=oneline --abbrev-commit origin/master
    popd > /dev/null
    _wait_for_user
}

pull_origin_master_from_clone() {
    path_to_clone="$1"
    echo
    echo "### Pulling origin master in clone '$path_to_clone'..."
    pushd "$path_to_clone" > /dev/null
    git pull origin master
    popd > /dev/null
    _wait_for_user
}

fetch_from_clone() {
    path_to_clone="$1"
    echo
    echo "### Fetching from clone '$path_to_clone'..."
    pushd "$path_to_clone" > /dev/null
    git fetch
    popd > /dev/null
    _wait_for_user
}

cleanup () {
    echo
    echo "### Cleaning up root $ROOT..."
    _wait_for_user
    rm -rf "$ROOT"
}

scenario_pull_origin_master_then_log () {
    init
    commit_change "$ALICE_CLONE_PATH" "First feature"
    push_from_clone "$ALICE_CLONE_PATH"

    log_remote_from_clone "$ALICE_CLONE_PATH"
    cat_from_clone "$ALICE_CLONE_PATH"

    log_remote_from_clone "$BOB_CLONE_PATH"
    cat_from_clone "$BOB_CLONE_PATH"

    pull_origin_master_from_clone "$BOB_CLONE_PATH"

    log_remote_from_clone "$BOB_CLONE_PATH"
    cat_from_clone "$BOB_CLONE_PATH"

    cleanup
}

scenario_pull_origin_master_and_fetch_then_log () {
    init
    commit_change "$ALICE_CLONE_PATH" "First feature"
    push_from_clone "$ALICE_CLONE_PATH"

    log_remote_from_clone "$ALICE_CLONE_PATH"
    cat_from_clone "$ALICE_CLONE_PATH"

    log_remote_from_clone "$BOB_CLONE_PATH"
    cat_from_clone "$BOB_CLONE_PATH"

    pull_origin_master_from_clone "$BOB_CLONE_PATH"
    fetch_from_clone "$BOB_CLONE_PATH"

    log_remote_from_clone "$BOB_CLONE_PATH"
    cat_from_clone "$BOB_CLONE_PATH"

    cleanup
}

###scenario_pull_origin_master_then_postreview () {
###    init
###    cleanup
###    commit_change "$ALICE_CLONE_PATH" "First feature"
###    push_from_clone "$ALICE_CLONE_PATH"
###}

main() {
    preamble
    scenario_pull_origin_master_then_log
    scenario_pull_origin_master_and_fetch_then_log
    ###scenario_pull_origin_master_then_postreview
}

main
