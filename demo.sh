#!/bin/bash

# Set to nothing for interactive mode, anything else to do everything without
# prompting.
INTERACTIVE=1


ROOT="/tmp/gitforoperations"
[ -e "$ROOT" ] && echo "Root $ROOT already exists. Aborting." && exit 1
REPO_PATH="$ROOT/repo.git"
VERSIONED_FILE="code"
ANOTHER_VERSIONED_FILE="config"
ALICE_CLONE_PATH="$ROOT/alice"
BOB_CLONE_PATH="$ROOT/bob"

_wait_for_user() {
    if [ -n "$INTERACTIVE" ] ; then
        echo "(enter to continue)"
        read _
    fi
}

init () {
    ##echo
    ##echo "### Initializing..."

    ##echo "# Creating root $ROOT"
    mkdir -p "$REPO_PATH"

    ##echo "# Initializing bare and empty repo $REPO_PATH"
    git --git-dir "$REPO_PATH" init --bare > /dev/null

    ##echo "# Cloning $REPO_PATH for Alice into $ALICE_CLONE_PATH"
    git clone "$REPO_PATH" "$ALICE_CLONE_PATH" > /dev/null 2>&1

    ##echo "# Using Alice's clone to add a file"
    pushd "$ALICE_CLONE_PATH" > /dev/null
    echo "Initial" > "$ALICE_CLONE_PATH/$VERSIONED_FILE"
    echo "Initial" > "$ALICE_CLONE_PATH/$ANOTHER_VERSIONED_FILE"
    git add "$VERSIONED_FILE" > /dev/null
    git add "$ANOTHER_VERSIONED_FILE" > /dev/null
    git commit -m"Initial" > /dev/null
    # Stupid hack to turn off interactivity, caused by the stupid hack of
    # reusing push_from_clone, caused by the fact that I need a bare repo
    # because I can't push to a non-bare repo.
    ORIG_INTERACTIVE="$INTERACTIVE"
    INTERACTIVE=""
    push_from_clone "$ALICE_CLONE_PATH" > /dev/null
    INTERACTIVE="$ORIG_INTERACTIVE"
    popd > /dev/null

    ##echo "# Cloning $REPO_PATH for Bob into $BOB_CLONE_PATH"
    git clone "$REPO_PATH" "$BOB_CLONE_PATH"

    echo "### Done initializing!"
    echo
    echo
}

commit_change () {
    path_to_clone="$1"
    contents_to_add="$2"
    file_to_modify="$3"
    [ -z "$3" ] && file_to_modify="$VERSIONED_FILE"
    echo
    echo "### Committing new contents '$contents_to_add' in clone $path_to_clone..."

    pushd "$path_to_clone" > /dev/null
    echo "$contents_to_add" >> "$file_to_modify"
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

branch_clone() {
    path_to_clone="$1"
    branch="$2"
    echo
    echo "### Creating branch '$branch' in clone '$path_to_clone'..."
    pushd "$path_to_clone" > /dev/null
    git checkout origin/master -b "$branch"
    popd > /dev/null
}

postreview_from_clone() {
    path_to_clone="$1"
    echo
    echo "### Postreview from clone '$path_to_clone'..."
    pushd "$path_to_clone" > /dev/null
    merge_base="$(git merge-base origin/master HEAD)"
    echo "# Merge-base: " $merge_base
    git log --oneline -n 1 "$merge_base"
    echo
    echo "# Diff: "
    git diff $merge_base..HEAD
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

    echo "###########################"
    echo "scenario_pull_origin_master_then_log"
    echo
    echo "git pull origin master"
    echo "git log origin/master"
    echo "###########################"

    commit_change "$ALICE_CLONE_PATH" "Alice's feature"
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

    echo "###########################"
    echo "scenario_pull_origin_master_and_fetch_then_log"
    echo
    echo "git pull origin master"
    echo "git fetch"
    echo "git log origin/master"
    echo "###########################"

    commit_change "$ALICE_CLONE_PATH" "Alice's feature"
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

scenario_branch_then_postreview () {
    init

    echo "###########################"
    echo "scenario_branch_then_postreview"
    echo
    echo "Bob cuts a branch and adds a feature"
    echo "Meanwhile Alice adds a feature to master"
    echo "Bob runs postreview"
    echo "###########################"

    branch_clone "$BOB_CLONE_PATH" "bob_branch"
    commit_change "$BOB_CLONE_PATH" "Bob's Big feature"

    commit_change "$ALICE_CLONE_PATH" "Alice's feature"
    push_from_clone "$ALICE_CLONE_PATH"

    postreview_from_clone "$BOB_CLONE_PATH"

    cleanup
}

scenario_branch_and_pull_master_then_postreview () {
    init

    echo "###########################"
    echo "scenario_branch_and_pull_master_then_postreview"
    echo
    echo "Bob cuts a branch and adds a feature"
    echo "Meanwhile Alice adds a feature to master"
    echo "Bob runs git pull origin master"
    echo "Bob runs postreview"
    echo "###########################"

    branch_clone "$BOB_CLONE_PATH" "bob_branch"
    commit_change "$BOB_CLONE_PATH" "Bob's Big feature"

    # Modify a different file to prevent a merge conflict;
    # that's not the point of this scenario.
    commit_change "$ALICE_CLONE_PATH" "Alice's Feature WHAT IS THIS DOING HERE???" "$ANOTHER_VERSIONED_FILE"
    push_from_clone "$ALICE_CLONE_PATH"

    pull_origin_master_from_clone "$BOB_CLONE_PATH"

    postreview_from_clone "$BOB_CLONE_PATH"

    cleanup
}

scenario_branch_and_pull_master_and_fetch_then_postreview () {
    init

    echo "###########################"
    echo "scenario_branch_and_pull_master_and_fetch_then_postreview"
    echo
    echo "Bob cuts a branch and adds a feature"
    echo "Meanwhile Alice adds a feature to master"
    echo "Bob runs git pull origin master"
    echo "Bob runs git fetch"
    echo "Bob runs postreview"
    echo "###########################"

    branch_clone "$BOB_CLONE_PATH" "bob_branch"
    commit_change "$BOB_CLONE_PATH" "Bob's Big feature"

    # Modify a different file to prevent a merge conflict;
    # that's not the point of this scenario.
    commit_change "$ALICE_CLONE_PATH" "Alice's Feature WHAT IS THIS DOING HERE???" "$ANOTHER_VERSIONED_FILE"
    push_from_clone "$ALICE_CLONE_PATH"

    pull_origin_master_from_clone "$BOB_CLONE_PATH"
    fetch_from_clone "$BOB_CLONE_PATH"

    postreview_from_clone "$BOB_CLONE_PATH"

    cleanup
}

main() {
    scenario_pull_origin_master_then_log
    scenario_pull_origin_master_and_fetch_then_log
    ###scenario_branch_then_postreview
    scenario_branch_and_pull_master_then_postreview
    scenario_branch_and_pull_master_and_fetch_then_postreview
}

main
