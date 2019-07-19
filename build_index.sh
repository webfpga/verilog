#!/bin/bash
# This script builds an index file that is crawlable by the frontend.
# It lets the frontend know the state of the repository.

{
    echo "["
    echo "  {\"git_commit\": \"$(git rev-parse HEAD)\"},"
    tree -J --noreport ./examples | tail +2
} | tee index.json
